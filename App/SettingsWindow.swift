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
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 420),
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

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    section("Appearance") {
                        Toggle("Show Island", isOn: $settings.visible)
                        Toggle("Expand on hover", isOn: $settings.expandOnHover)
                        Toggle("Show album artwork when expanded", isOn: $settings.showArtwork)
                    }
                    section("Position") {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Vertical offset")
                                Spacer()
                                Text("\(Int(settings.verticalOffset)) px")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            Slider(value: $settings.verticalOffset, in: -10...200)
                            Text("Moves the pill further below the menu bar / notch.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    section("About") {
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
                .padding(20)
            }
        }
        .frame(minWidth: 420, minHeight: 420)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "capsule.fill")
                .font(.system(size: 18, weight: .semibold))
            Text("Island")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private func section<Content: View>(
        _ title: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .kerning(0.6)
            VStack(alignment: .leading, spacing: 10) { content() }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08))
                        )
                )
        }
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}
