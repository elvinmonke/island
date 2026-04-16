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

    private let defaults = UserDefaults.standard

    init() {
        self.visible = defaults.object(forKey: "visible") as? Bool ?? true
        self.verticalOffset = defaults.object(forKey: "verticalOffset") as? Double ?? 0
        self.showArtwork = defaults.object(forKey: "showArtwork") as? Bool ?? true
    }

    private func save() {
        defaults.set(visible, forKey: "visible")
        defaults.set(verticalOffset, forKey: "verticalOffset")
        defaults.set(showArtwork, forKey: "showArtwork")
    }

    private func notify() {
        NotificationCenter.default.post(name: AppSettings.changed, object: nil)
    }
}
