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

    private func checkForNotificationBanners() {
        guard activeNotification == nil else { return }
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

            DispatchQueue.main.async {
                let notif = IslandNotification(
                    id: UUID(),
                    kind: .general,
                    title: "Notification",
                    subtitle: "",
                    appName: "macOS",
                    appIcon: nil,
                    timestamp: Date()
                )
                self.activeNotification = notif
                self.scheduleAutoDismiss(seconds: 5)
            }
            return
        }
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
