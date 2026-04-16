import Foundation
import AppKit
import UserNotifications

final class TimerManager: ObservableObject {
    @Published var isRunning: Bool = false
    @Published var remainingSeconds: Int = 0
    @Published var totalSeconds: Int = 0

    private var timer: Timer?

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
    }

    var timeString: String {
        let h = remainingSeconds / 3600
        let m = (remainingSeconds % 3600) / 60
        let s = remainingSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    func start(minutes: Int) {
        totalSeconds = minutes * 60
        remainingSeconds = totalSeconds
        isRunning = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.remainingSeconds > 0 {
                self.remainingSeconds -= 1
            } else {
                self.finish()
            }
        }
    }

    func toggle() {
        if isRunning {
            isRunning = false
            timer?.invalidate()
        } else if remainingSeconds > 0 {
            isRunning = true
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                guard let self else { return }
                if self.remainingSeconds > 0 {
                    self.remainingSeconds -= 1
                } else {
                    self.finish()
                }
            }
        }
    }

    func reset() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        remainingSeconds = 0
        totalSeconds = 0
    }

    private func finish() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        NSSound(named: "Glass")?.play()
        sendNotification()
    }

    private func sendNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Island Timer"
        content.body = "Time's up!"
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
