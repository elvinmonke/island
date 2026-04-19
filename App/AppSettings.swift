import Foundation
import Combine
import ServiceManagement

final class AppSettings: ObservableObject {
    static let changed = Notification.Name("IslandSettingsChanged")

    // MARK: - General
    @Published var visible: Bool { didSet { save(); notify() } }
    @Published var launchAtLogin: Bool { didSet { save(); setLoginItem() } }
    @Published var expandOnHover: Bool { didSet { save() } }
    @Published var hideMenuBarIcon: Bool { didSet { save() } }
    @Published var hideInFullscreen: Bool { didSet { save() } }
    @Published var hideFromScreenCapture: Bool { didSet { save(); notify() } }

    // MARK: - Appearance / Tuning
    @Published var verticalOffset: Double { didSet { save(); notify() } }
    @Published var glassEffect: Bool { didSet { save() } }
    @Published var showArtwork: Bool { didSet { save() } }

    // MARK: - Features (enable/disable entire modules)
    @Published var enableNowPlaying: Bool { didSet { save() } }
    @Published var enableVolume: Bool { didSet { save() } }
    @Published var enableBrightness: Bool { didSet { save() } }
    @Published var enableBattery: Bool { didSet { save() } }
    @Published var enableCalendar: Bool { didSet { save() } }
    @Published var enableTimer: Bool { didSet { save() } }

    // MARK: - Now Playing
    @Published var hideWhileSourceIsActive: Bool { didSet { save() } }

    // MARK: - HUD
    @Published var showHUDPercentage: Bool { didSet { save() } }
    @Published var hudSpeed: HUDSpeed { didSet { save() } }

    // MARK: - Battery
    @Published var hideBatteryPercentage: Bool { didSet { save() } }
    @Published var warnOnLowBattery: Bool { didSet { save() } }

    // MARK: - Lock Screen
    @Published var enableLockScreen: Bool { didSet { save() } }
    @Published var playSoundOnLock: Bool { didSet { save() } }
    @Published var playSoundOnUnlock: Bool { didSet { save() } }
    @Published var showOnScreenSaver: Bool { didSet { save() } }
    @Published var allowBatteryWhenLocked: Bool { didSet { save() } }
    @Published var allowVolumeWhenLocked: Bool { didSet { save() } }
    @Published var allowBrightnessWhenLocked: Bool { didSet { save() } }
    @Published var allowNowPlayingWhenLocked: Bool { didSet { save() } }

    // MARK: - Sounds
    @Published var enableSounds: Bool { didSet { save() } }

    enum HUDSpeed: String, CaseIterable {
        case smooth, fast, instant
        var duration: Double {
            switch self {
            case .smooth: return 2.5
            case .fast: return 1.5
            case .instant: return 0.8
            }
        }
    }

    private let defaults = UserDefaults.standard

    init() {
        self.visible = defaults.object(forKey: "visible") as? Bool ?? true
        self.launchAtLogin = defaults.object(forKey: "launchAtLogin") as? Bool ?? false
        self.expandOnHover = defaults.object(forKey: "expandOnHover") as? Bool ?? true
        self.hideMenuBarIcon = defaults.object(forKey: "hideMenuBarIcon") as? Bool ?? false
        self.hideInFullscreen = defaults.object(forKey: "hideInFullscreen") as? Bool ?? false
        self.hideFromScreenCapture = defaults.object(forKey: "hideFromScreenCapture") as? Bool ?? false

        self.verticalOffset = defaults.object(forKey: "verticalOffset") as? Double ?? 0
        self.glassEffect = defaults.object(forKey: "glassEffect") as? Bool ?? false
        self.showArtwork = defaults.object(forKey: "showArtwork") as? Bool ?? true

        self.enableNowPlaying = defaults.object(forKey: "enableNowPlaying") as? Bool ?? true
        self.enableVolume = defaults.object(forKey: "enableVolume") as? Bool ?? true
        self.enableBrightness = defaults.object(forKey: "enableBrightness") as? Bool ?? true
        self.enableBattery = defaults.object(forKey: "enableBattery") as? Bool ?? true
        self.enableCalendar = defaults.object(forKey: "enableCalendar") as? Bool ?? true
        self.enableTimer = defaults.object(forKey: "enableTimer") as? Bool ?? true

        self.hideWhileSourceIsActive = defaults.object(forKey: "hideWhileSourceIsActive") as? Bool ?? false

        self.showHUDPercentage = defaults.object(forKey: "showHUDPercentage") as? Bool ?? true
        self.hudSpeed = HUDSpeed(rawValue: defaults.string(forKey: "hudSpeed") ?? "") ?? .fast

        self.hideBatteryPercentage = defaults.object(forKey: "hideBatteryPercentage") as? Bool ?? false
        self.warnOnLowBattery = defaults.object(forKey: "warnOnLowBattery") as? Bool ?? true

        self.enableLockScreen = defaults.object(forKey: "enableLockScreen") as? Bool ?? true
        self.playSoundOnLock = defaults.object(forKey: "playSoundOnLock") as? Bool ?? true
        self.playSoundOnUnlock = defaults.object(forKey: "playSoundOnUnlock") as? Bool ?? true
        self.showOnScreenSaver = defaults.object(forKey: "showOnScreenSaver") as? Bool ?? true
        self.allowBatteryWhenLocked = defaults.object(forKey: "allowBatteryWhenLocked") as? Bool ?? true
        self.allowVolumeWhenLocked = defaults.object(forKey: "allowVolumeWhenLocked") as? Bool ?? true
        self.allowBrightnessWhenLocked = defaults.object(forKey: "allowBrightnessWhenLocked") as? Bool ?? true
        self.allowNowPlayingWhenLocked = defaults.object(forKey: "allowNowPlayingWhenLocked") as? Bool ?? true

        self.enableSounds = defaults.object(forKey: "enableSounds") as? Bool ?? true
    }

    private func save() {
        let d = defaults
        d.set(visible, forKey: "visible")
        d.set(launchAtLogin, forKey: "launchAtLogin")
        d.set(expandOnHover, forKey: "expandOnHover")
        d.set(hideMenuBarIcon, forKey: "hideMenuBarIcon")
        d.set(hideInFullscreen, forKey: "hideInFullscreen")
        d.set(hideFromScreenCapture, forKey: "hideFromScreenCapture")
        d.set(verticalOffset, forKey: "verticalOffset")
        d.set(glassEffect, forKey: "glassEffect")
        d.set(showArtwork, forKey: "showArtwork")
        d.set(enableNowPlaying, forKey: "enableNowPlaying")
        d.set(enableVolume, forKey: "enableVolume")
        d.set(enableBrightness, forKey: "enableBrightness")
        d.set(enableBattery, forKey: "enableBattery")
        d.set(enableCalendar, forKey: "enableCalendar")
        d.set(enableTimer, forKey: "enableTimer")
        d.set(hideWhileSourceIsActive, forKey: "hideWhileSourceIsActive")
        d.set(showHUDPercentage, forKey: "showHUDPercentage")
        d.set(hudSpeed.rawValue, forKey: "hudSpeed")
        d.set(hideBatteryPercentage, forKey: "hideBatteryPercentage")
        d.set(warnOnLowBattery, forKey: "warnOnLowBattery")
        d.set(enableLockScreen, forKey: "enableLockScreen")
        d.set(playSoundOnLock, forKey: "playSoundOnLock")
        d.set(playSoundOnUnlock, forKey: "playSoundOnUnlock")
        d.set(showOnScreenSaver, forKey: "showOnScreenSaver")
        d.set(allowBatteryWhenLocked, forKey: "allowBatteryWhenLocked")
        d.set(allowVolumeWhenLocked, forKey: "allowVolumeWhenLocked")
        d.set(allowBrightnessWhenLocked, forKey: "allowBrightnessWhenLocked")
        d.set(allowNowPlayingWhenLocked, forKey: "allowNowPlayingWhenLocked")
        d.set(enableSounds, forKey: "enableSounds")
    }

    private func notify() {
        NotificationCenter.default.post(name: AppSettings.changed, object: nil)
    }

    private func setLoginItem() {
        try? SMAppService.mainApp.register()
    }
}
