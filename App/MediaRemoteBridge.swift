import Foundation
import AppKit

struct NowPlayingInfo {
    var title: String = ""
    var artist: String = ""
    var album: String = ""
    var artwork: NSImage?
    var elapsed: Double = 0
    var duration: Double = 0
    var isPlaying: Bool = false
    var playbackRate: Double = 0
    var timestamp: Date = Date()
}

final class MediaRemoteBridge {
    static let shared = MediaRemoteBridge()

    static let infoChanged = Notification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification")
    static let appPlayingChanged = Notification.Name("kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification")
    static let playerChanged = Notification.Name("kMRMediaRemoteNowPlayingApplicationDidChangeNotification")
    static let activePlayerChanged = Notification.Name("kMRMediaRemoteActivePlayerDidChange")

    private let _getNowPlayingInfo: ((@convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void))?
    private let _registerNotifications: ((@convention(c) (DispatchQueue) -> Void))?
    private let _sendCommand: ((@convention(c) (UInt32, CFDictionary?) -> Bool))?
    private let _getIsPlaying: ((@convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void))?

    private var cachedArtwork: NSImage?
    private var cachedArtworkTitle: String = ""
    private var nativeAPIWorks = true

    private static let cliPath: String? = {
        for path in ["/opt/homebrew/bin/nowplaying-cli", "/usr/local/bin/nowplaying-cli"] {
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        return nil
    }()

    private init() {
        let url = NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")
        let bundle = CFBundleCreate(kCFAllocatorDefault, url)

        func load<T>(_ name: String) -> T? {
            guard let b = bundle,
                  let ptr = CFBundleGetFunctionPointerForName(b, name as CFString) else { return nil }
            return unsafeBitCast(ptr, to: T.self)
        }

        _getNowPlayingInfo = load("MRMediaRemoteGetNowPlayingInfo")
        _registerNotifications = load("MRMediaRemoteRegisterForNowPlayingNotifications")
        _sendCommand = load("MRMediaRemoteSendCommand")
        _getIsPlaying = load("MRMediaRemoteGetNowPlayingApplicationIsPlaying")

        islandLog("MediaRemote: native=\(_getNowPlayingInfo != nil) cli=\(Self.cliPath != nil)")
    }

    var isAvailable: Bool { _getNowPlayingInfo != nil || Self.cliPath != nil }

    func register() {
        _registerNotifications?(DispatchQueue.main)
    }

    func fetch(completion: @escaping (NowPlayingInfo) -> Void) {
        if !nativeAPIWorks {
            fetchViaCLI(completion: completion)
            return
        }

        guard let fn = _getNowPlayingInfo else {
            nativeAPIWorks = false
            fetchViaCLI(completion: completion)
            return
        }

        fn(DispatchQueue.main) { [weak self] dict in
            if dict.isEmpty {
                self?.nativeAPIWorks = false
                islandLog("Native MediaRemote returned empty, switching to CLI fallback")
                self?.fetchViaCLI(completion: completion)
                return
            }

            var info = NowPlayingInfo()
            info.title = dict["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
            info.artist = dict["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
            info.album = dict["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? ""
            info.elapsed = dict["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double ?? 0
            info.duration = dict["kMRMediaRemoteNowPlayingInfoDuration"] as? Double ?? 0
            info.playbackRate = dict["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0
            info.isPlaying = info.playbackRate > 0

            if let data = dict["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data {
                info.artwork = NSImage(data: data)
            }

            if let ts = dict["kMRMediaRemoteNowPlayingInfoTimestamp"] as? Date {
                info.timestamp = ts
            } else {
                info.timestamp = Date()
            }

            completion(info)
        }
    }

    private func fetchViaCLI(completion: @escaping (NowPlayingInfo) -> Void) {
        guard let cli = Self.cliPath else {
            completion(NowPlayingInfo())
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: cli)
            proc.arguments = ["get", "title", "artist", "album", "playbackRate", "duration", "elapsedTime"]
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = FileHandle.nullDevice

            do {
                try proc.run()
                proc.waitUntilExit()
            } catch {
                DispatchQueue.main.async { completion(NowPlayingInfo()) }
                return
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let lines = output.components(separatedBy: "\n")

            var info = NowPlayingInfo()
            if lines.count >= 6 {
                info.title = lines[0] == "null" ? "" : lines[0]
                info.artist = lines[1] == "null" ? "" : lines[1]
                info.album = lines[2] == "null" ? "" : lines[2]
                info.playbackRate = Double(lines[3]) ?? 0
                info.duration = Double(lines[4]) ?? 0
                info.elapsed = Double(lines[5]) ?? 0
                info.isPlaying = info.playbackRate > 0
                info.timestamp = Date()
            }

            // Reuse cached artwork if same track
            if let self = self, info.title == self.cachedArtworkTitle, let cached = self.cachedArtwork {
                info.artwork = cached
            } else if !info.title.isEmpty {
                let artProc = Process()
                artProc.executableURL = URL(fileURLWithPath: cli)
                artProc.arguments = ["get", "artworkData"]
                let artPipe = Pipe()
                artProc.standardOutput = artPipe
                artProc.standardError = FileHandle.nullDevice
                try? artProc.run()
                artProc.waitUntilExit()
                let artData = artPipe.fileHandleForReading.readDataToEndOfFile()
                let artStr = String(data: artData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if artStr != "null" && !artStr.isEmpty, let imgData = Data(base64Encoded: artStr) {
                    info.artwork = NSImage(data: imgData)
                    self?.cachedArtwork = info.artwork
                    self?.cachedArtworkTitle = info.title
                }
            }

            DispatchQueue.main.async { completion(info) }
        }
    }

    func togglePlayPause() {
        if _sendCommand != nil { _ = _sendCommand?(2, nil) }
        else { runCLI("togglePlayPause") }
    }

    func nextTrack() {
        if _sendCommand != nil { _ = _sendCommand?(4, nil) }
        else { runCLI("next") }
    }

    func previousTrack() {
        if _sendCommand != nil { _ = _sendCommand?(5, nil) }
        else { runCLI("previous") }
    }

    private func runCLI(_ command: String) {
        guard let cli = Self.cliPath else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: cli)
            proc.arguments = [command]
            proc.standardOutput = FileHandle.nullDevice
            proc.standardError = FileHandle.nullDevice
            try? proc.run()
        }
    }
}
