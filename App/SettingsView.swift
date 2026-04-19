import AppKit
import SwiftUI

final class SettingsWindowController {
    private var window: NSWindow?
    private let settings: AppSettings

    init(settings: AppSettings) { self.settings = settings }

    func show() {
        if let w = window {
            NSApp.activate(ignoringOtherApps: true)
            w.makeKeyAndOrderFront(nil)
            return
        }
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        w.title = "Island Settings"
        w.titlebarAppearsTransparent = true
        w.isReleasedWhenClosed = false
        w.center()
        w.contentView = NSHostingView(
            rootView: SettingsView().environmentObject(settings)
        )
        window = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }
}

enum SettingsTab: String, CaseIterable {
    case general = "General"
    case nowPlaying = "Now Playing"
    case hud = "HUD"
    case battery = "Battery"
    case calendar = "Calendar"
    case lockScreen = "Lock Screen"
    case about = "About"

    var icon: String {
        switch self {
        case .general:    return "gear"
        case .nowPlaying: return "music.note"
        case .hud:        return "speaker.wave.2.fill"
        case .battery:    return "battery.100percent"
        case .calendar:   return "calendar"
        case .lockScreen: return "lock.fill"
        case .about:      return "info.circle"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider().opacity(0.3)
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 560, minHeight: 600)
    }

    private var sidebar: some View {
        VStack(spacing: 2) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tab }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .frame(width: 18)
                            .foregroundStyle(selectedTab == tab ? .white : .secondary)
                        Text(tab.rawValue)
                            .foregroundStyle(selectedTab == tab ? .white : .primary)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selectedTab == tab ? Color.accentColor : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(12)
        .frame(width: 170)
    }

    @ViewBuilder
    private var tabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch selectedTab {
                case .general:    GeneralSettings()
                case .nowPlaying: NowPlayingSettings()
                case .hud:        HUDSettings()
                case .battery:    BatterySettings()
                case .calendar:   CalendarSettings()
                case .lockScreen: LockScreenSettings()
                case .about:      AboutSettings()
                }
            }
            .padding(24)
        }
    }
}

// MARK: - Glass Section

struct GlassSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .kerning(0.6)

            VStack(alignment: .leading, spacing: 10) { content }
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                        )
                }
        }
    }
}

struct GlassInfoText: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

struct GlassToggle: View {
    let title: String
    @Binding var isOn: Bool
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(title, isOn: $isOn)
                .toggleStyle(.switch)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - General

struct GeneralSettings: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        GlassSection("Behaviour") {
            GlassToggle(title: "Show Island", isOn: $settings.visible)
            GlassToggle(title: "Expand on hover", isOn: $settings.expandOnHover,
                        subtitle: "Show the expanded island when hovering over it.")
            GlassToggle(title: "Launch at login", isOn: $settings.launchAtLogin)
            GlassToggle(title: "Hide menu bar icon", isOn: $settings.hideMenuBarIcon)
        }

        GlassSection("Display") {
            GlassToggle(title: "Glass effect (vibrancy)", isOn: $settings.glassEffect)
            GlassToggle(title: "Hide in fullscreen apps", isOn: $settings.hideInFullscreen)
            GlassToggle(title: "Hide from screen capture", isOn: $settings.hideFromScreenCapture,
                        subtitle: "Prevents Island from appearing in screenshots and recordings.")
        }

        GlassSection("Tuning") {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Vertical offset")
                    Spacer()
                    Text("\(Int(settings.verticalOffset)) px")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $settings.verticalOffset, in: -10...200)
                GlassInfoText(text: "Moves the pill further below the menu bar / notch.")
            }
        }

        GlassSection("Features") {
            GlassToggle(title: "Now Playing", isOn: $settings.enableNowPlaying)
            GlassToggle(title: "Volume HUD", isOn: $settings.enableVolume)
            GlassToggle(title: "Brightness HUD", isOn: $settings.enableBrightness)
            GlassToggle(title: "Battery", isOn: $settings.enableBattery)
            GlassToggle(title: "Calendar", isOn: $settings.enableCalendar)
            GlassToggle(title: "Timer", isOn: $settings.enableTimer)
        }
    }
}

// MARK: - Now Playing

struct NowPlayingSettings: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        GlassSection("Now Playing") {
            GlassToggle(title: "Show album artwork", isOn: $settings.showArtwork)
            GlassToggle(title: "Hide while source app is active", isOn: $settings.hideWhileSourceIsActive,
                        subtitle: "Hide the compact now playing bar when the music app is in the foreground.")
        }
    }
}

// MARK: - HUD

struct HUDSettings: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        GlassSection("HUD") {
            GlassToggle(title: "Show percentage", isOn: $settings.showHUDPercentage)

            VStack(alignment: .leading, spacing: 6) {
                Text("Speed")
                Picker("Speed", selection: $settings.hudSpeed) {
                    ForEach(AppSettings.HUDSpeed.allCases, id: \.self) { speed in
                        Text(speed.rawValue.capitalized).tag(speed)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                GlassInfoText(text: "How quickly the HUD appears and disappears.")
            }
        }
    }
}

// MARK: - Battery

struct BatterySettings: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        GlassSection("Battery") {
            GlassToggle(title: "Hide percentage label", isOn: $settings.hideBatteryPercentage)
            GlassToggle(title: "Warn on low battery", isOn: $settings.warnOnLowBattery,
                        subtitle: "Shows a notification when battery drops below 20%.")
        }
    }
}

// MARK: - Calendar

struct CalendarSettings: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        GlassSection("Calendar") {
            GlassToggle(title: "Enable calendar", isOn: $settings.enableCalendar,
                        subtitle: "Show upcoming events in the expanded view.")
        }
    }
}

// MARK: - Lock Screen

struct LockScreenSettings: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        GlassSection("Lock Screen") {
            GlassToggle(title: "Enable lock screen", isOn: $settings.enableLockScreen,
                        subtitle: "Show the lock/unlock animation on the lock screen.")
            GlassToggle(title: "Show on screen saver", isOn: $settings.showOnScreenSaver)
        }

        GlassSection("Sounds") {
            GlassToggle(title: "Play sound on lock", isOn: $settings.playSoundOnLock)
            GlassToggle(title: "Play sound on unlock", isOn: $settings.playSoundOnUnlock)
        }

        GlassSection("Widgets on Lock Screen") {
            GlassToggle(title: "Battery", isOn: $settings.allowBatteryWhenLocked)
            GlassToggle(title: "Volume", isOn: $settings.allowVolumeWhenLocked)
            GlassToggle(title: "Brightness", isOn: $settings.allowBrightnessWhenLocked)
            GlassToggle(title: "Now Playing", isOn: $settings.allowNowPlayingWhenLocked)
            GlassInfoText(text: "Choose which widgets appear on the lock screen alongside the lock icon.")
        }
    }
}

// MARK: - About

struct AboutSettings: View {
    var body: some View {
        GlassSection("About") {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "capsule.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Island").font(.headline)
                    Text("Dynamic Island for macOS")
                        .foregroundStyle(.secondary)
                    Text("Version \(version) · MIT · by Elvin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Link("GitHub",
                     destination: URL(string: "https://github.com/elvinmonke/island")!)
                Spacer()
                Button("Quit Island") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
        }
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}
