import Foundation
import Combine
import AppKit

final class IslandViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var artist: String = ""
    @Published var isPlaying: Bool = false
    @Published var forceExpanded: Bool = false
    @Published var isHovering: Bool = false
    @Published var album: String = ""

    let notificationMonitor = NotificationMonitor()

    var hasContent: Bool { !title.isEmpty }

    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        notificationMonitor.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    deinit { timer?.invalidate() }

    // MARK: - Notification shortcuts

    var activeNotification: IslandNotification? { notificationMonitor.activeNotification }

    func acceptCall() { notificationMonitor.acceptCall() }
    func declineCall() { notificationMonitor.declineCall() }
    func dismissNotification() { notificationMonitor.dismissNotification() }

    // MARK: - Now Playing

    func refresh() {
        NowPlaying.fetch { [weak self] info in
            DispatchQueue.main.async {
                guard let self else { return }
                self.title = info.title
                self.artist = info.artist
                self.album = info.album
                self.isPlaying = info.isPlaying
            }
        }
    }

    func playPause() { NowPlaying.run("playpause"); bounce() }
    func next() { NowPlaying.run("next"); bounce() }
    func previous() { NowPlaying.run("previous"); bounce() }

    private func bounce() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.refresh() }
    }
}

enum NowPlaying {
    struct Info { let title: String; let artist: String; let album: String; let isPlaying: Bool }

    static func fetch(completion: @escaping (Info) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let info = query(app: "Spotify"), info.isPlaying || !info.title.isEmpty {
                completion(info); return
            }
            if let info = query(app: "Music"), info.isPlaying || !info.title.isEmpty {
                completion(info); return
            }
            completion(Info(title: "", artist: "", album: "", isPlaying: false))
        }
    }

    private static func query(app: String) -> Info? {
        let script = """
        if application "\(app)" is running then
            tell application "\(app)"
                try
                    set t to name of current track
                    set a to artist of current track
                    set al to album of current track
                    set s to player state as string
                    return t & "|||" & a & "|||" & al & "|||" & s
                on error
                    return "|||" & "|||" & "|||" & "stopped"
                end try
            end if
            return "|||" & "|||" & "|||" & "stopped"
        end if
        """
        guard let out = runAppleScript(script) else { return nil }
        let parts = out.components(separatedBy: "|||")
        guard parts.count == 4 else { return nil }
        let state = parts[3].lowercased()
        return Info(
            title: parts[0].trimmingCharacters(in: .whitespacesAndNewlines),
            artist: parts[1].trimmingCharacters(in: .whitespacesAndNewlines),
            album: parts[2].trimmingCharacters(in: .whitespacesAndNewlines),
            isPlaying: state.contains("playing")
        )
    }

    static func run(_ command: String) {
        let script = """
        if application "Spotify" is running then
            tell application "Spotify" to \(command)
        else if application "Music" is running then
            tell application "Music" to \(command)
        end if
        """
        _ = runAppleScript(script)
    }

    private static func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let result = script.executeAndReturnError(&error)
        if error != nil { return nil }
        return result.stringValue
    }
}
