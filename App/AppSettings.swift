import Foundation
import Combine

final class AppSettings: ObservableObject {
    static let changed = Notification.Name("IslandSettingsChanged")

    @Published var visible: Bool {
        didSet { save(); notify() }
    }
    @Published var verticalOffset: Double {
        didSet { save(); notify() }
    }
    @Published var showArtwork: Bool {
        didSet { save() }
    }
    @Published var glassEffect: Bool {
        didSet { save() }
    }
    @Published var hudEnabled: Bool {
        didSet { save() }
    }
    @Published var showCalendar: Bool {
        didSet { save() }
    }

    private let defaults = UserDefaults.standard

    init() {
        self.visible = defaults.object(forKey: "visible") as? Bool ?? true
        self.verticalOffset = defaults.object(forKey: "verticalOffset") as? Double ?? 0
        self.showArtwork = defaults.object(forKey: "showArtwork") as? Bool ?? true
        self.glassEffect = defaults.object(forKey: "glassEffect") as? Bool ?? false
        self.hudEnabled = defaults.object(forKey: "hudEnabled") as? Bool ?? true
        self.showCalendar = defaults.object(forKey: "showCalendar") as? Bool ?? true
    }

    private func save() {
        defaults.set(visible, forKey: "visible")
        defaults.set(verticalOffset, forKey: "verticalOffset")
        defaults.set(showArtwork, forKey: "showArtwork")
        defaults.set(glassEffect, forKey: "glassEffect")
        defaults.set(hudEnabled, forKey: "hudEnabled")
        defaults.set(showCalendar, forKey: "showCalendar")
    }

    private func notify() {
        NotificationCenter.default.post(name: AppSettings.changed, object: nil)
    }
}
