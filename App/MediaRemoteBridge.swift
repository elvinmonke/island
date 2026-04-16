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

    private let _getNowPlayingInfo: ((@convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void))?
    private let _registerNotifications: ((@convention(c) (DispatchQueue) -> Void))?
    private let _sendCommand: ((@convention(c) (UInt32, CFDictionary?) -> Bool))?

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
    }

    var isAvailable: Bool { _getNowPlayingInfo != nil }

    func register() {
        _registerNotifications?(DispatchQueue.main)
    }

    func fetch(completion: @escaping (NowPlayingInfo) -> Void) {
        guard let fn = _getNowPlayingInfo else {
            completion(NowPlayingInfo())
            return
        }

        fn(DispatchQueue.main) { dict in
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

    func togglePlayPause() { _ = _sendCommand?(2, nil) }
    func nextTrack() { _ = _sendCommand?(4, nil) }
    func previousTrack() { _ = _sendCommand?(5, nil) }
}
