import Foundation
import AppKit
import CoreGraphics
import Combine

// MARK: - Models

enum NotificationKind: Equatable {
    case call, general
}

struct IslandNotification: Equatable {
    let id: UUID
    let kind: NotificationKind
    let title: String
    let subtitle: String
    let appName: String
    let appIcon: NSImage?
    let timestamp: Date

    static func == (lhs: IslandNotification, rhs: IslandNotification) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Monitor

final class NotificationMonitor: ObservableObject {
    @Published var activeNotification: IslandNotification?

    private var pollTimer: Timer?
    private var autoDismissWork: DispatchWorkItem?

    init() {
        startPolling()
        listenForDistributedNotifications()
    }

    deinit {
        pollTimer?.invalidate()
        DistributedNotificationCenter.default().removeObserver(self)
    }

    // MARK: - Polling

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.checkForCalls()
            self.checkForNotificationBanners()
        }
    }

    // MARK: - Call detection

    private let callProcesses: Set<String> = [
        "FaceTime", "FaceTimeNotificationService", "callservicesd"
    ]

    private func checkForCalls() {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly], kCGNullWindowID
        ) as? [[String: Any]] else { return }

        var callFound = false
        for win in list {
            guard let name = win[kCGWindowOwnerName as String] as? String,
                  callProcesses.contains(name),
                  let b = win[kCGWindowBounds as String] as? [String: CGFloat],
                  let h = b["Height"], h > 50 else { continue }
            callFound = true
            break
        }

        DispatchQueue.main.async {
            if callFound && self.activeNotification?.kind != .call {
                self.activeNotification = IslandNotification(
                    id: UUID(),
                    kind: .call,
                    title: "Incoming Call",
                    subtitle: "FaceTime",
                    appName: "FaceTime",
                    appIcon: NSWorkspace.shared.icon(
                        forFile: "/System/Applications/FaceTime.app"
                    ),
                    timestamp: Date()
                )
            } else if !callFound && self.activeNotification?.kind == .call {
                self.activeNotification = nil
            }
        }
    }

    // MARK: - Generic notification banners

    private var lastNotifBannerTime: Date = .distantPast

    private func checkForNotificationBanners() {
        guard activeNotification == nil else { return }
        guard Date().timeIntervalSince(lastNotifBannerTime) > 3 else { return }
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly], kCGNullWindowID
        ) as? [[String: Any]] else { return }

        for win in list {
            guard let name = win[kCGWindowOwnerName as String] as? String,
                  name == "NotificationCenter",
                  let layer = win[kCGWindowLayer as String] as? Int,
                  layer > 0,
                  let b = win[kCGWindowBounds as String] as? [String: CGFloat],
                  let h = b["Height"], h > 30 else { continue }

            lastNotifBannerTime = Date()

            let info = readNotificationContent()
            let appName = info.appName ?? "Notification"
            let title = info.title ?? appName
            let subtitle = info.subtitle ?? ""
            let icon = iconForApp(appName)

            DispatchQueue.main.async {
                let notif = IslandNotification(
                    id: UUID(),
                    kind: .general,
                    title: title,
                    subtitle: subtitle,
                    appName: appName,
                    appIcon: icon,
                    timestamp: Date()
                )
                self.activeNotification = notif
                self.scheduleAutoDismiss(seconds: 5)
            }
            return
        }
    }

    private func readNotificationContent() -> (appName: String?, title: String?, subtitle: String?) {
        let script = """
        tell application "System Events"
            tell process "NotificationCenter"
                try
                    set w to window 1
                    set allText to {}
                    repeat with e in (UI elements of w)
                        try
                            set end of allText to (value of static text 1 of e) as text
                        end try
                        try
                            set end of allText to (value of static text 2 of e) as text
                        end try
                        repeat with g in (groups of e)
                            try
                                set end of allText to (value of static text 1 of g) as text
                            end try
                            try
                                set end of allText to (value of static text 2 of g) as text
                            end try
                        end repeat
                    end repeat
                    set d to ""
                    repeat with t in allText
                        set d to d & t & "|||"
                    end repeat
                    return d
                on error
                    return ""
                end try
            end tell
        end tell
        """
        var error: NSDictionary?
        guard let result = NSAppleScript(source: script)?.executeAndReturnError(&error),
              let text = result.stringValue, !text.isEmpty else {
            return (nil, nil, nil)
        }
        let parts = text.components(separatedBy: "|||").filter { !$0.isEmpty }
        switch parts.count {
        case 0: return (nil, nil, nil)
        case 1: return (parts[0], parts[0], nil)
        case 2: return (parts[0], parts[1], nil)
        default: return (parts[0], parts[1], parts[2])
        }
    }

    private func iconForApp(_ name: String) -> NSImage? {
        if let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.localizedName == name
        }), let url = app.bundleURL {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        let paths = [
            "/Applications/\(name).app",
            "/System/Applications/\(name).app",
            "/Applications/Utilities/\(name).app",
            "/System/Library/CoreServices/\(name).app"
        ]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return NSWorkspace.shared.icon(forFile: path)
            }
        }
        if let bundleID = NSWorkspace.shared.runningApplications.first(where: {
            ($0.localizedName ?? "").lowercased().contains(name.lowercased())
        })?.bundleIdentifier, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return nil
    }

    // MARK: - Distributed notifications

    private func listenForDistributedNotifications() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(onDistributedNotification(_:)),
            name: nil,
            object: nil
        )
    }

    @objc private func onDistributedNotification(_ note: Notification) {
        let n = note.name.rawValue.lowercased()
        if n.contains("call") || n.contains("telephony") || n.contains("facetime") {
            checkForCalls()
        }
    }

    // MARK: - Actions

    func acceptCall() {
        let script = """
        tell application "System Events"
            tell process "NotificationCenter"
                try
                    click button "Accept" of group 1 of UI element 1 of scroll area 1 of window 1
                on error
                    try
                        click button "Accept" of window 1
                    end try
                end try
            end tell
        end tell
        """
        runAppleScript(script)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.activeNotification = nil
        }
    }

    func declineCall() {
        let script = """
        tell application "System Events"
            tell process "NotificationCenter"
                try
                    click button "Decline" of group 1 of UI element 1 of scroll area 1 of window 1
                on error
                    try
                        click button "Decline" of window 1
                    end try
                end try
            end tell
        end tell
        """
        runAppleScript(script)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.activeNotification = nil
        }
    }

    func dismissNotification() {
        autoDismissWork?.cancel()
        DispatchQueue.main.async { self.activeNotification = nil }
    }

    // MARK: - Helpers

    private func scheduleAutoDismiss(seconds: Double) {
        autoDismissWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.activeNotification = nil
        }
        autoDismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func runAppleScript(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            if let script = NSAppleScript(source: source) {
                script.executeAndReturnError(&error)
            }
        }
    }
}
