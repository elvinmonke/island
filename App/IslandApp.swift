import SwiftUI
import AppKit

@main
struct IslandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settingsModel = AppSettings()
    private let viewModel = IslandViewModel()
    private var islandController: IslandWindowController?
    private var settingsWindow: SettingsWindowController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        viewModel.settings = settingsModel
        islandController = IslandWindowController(
            viewModel: viewModel, settings: settingsModel
        )
        islandController?.show()
        settingsWindow = SettingsWindowController(settings: settingsModel)
        setupStatusItem()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "capsule.fill", accessibilityDescription: "Island")
            button.image?.isTemplate = true
        }
        item.menu = buildMenu()
        statusItem = item
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        let toggle = NSMenuItem(
            title: settingsModel.visible ? "Hide Island" : "Show Island",
            action: #selector(toggleIsland), keyEquivalent: "i"
        )
        toggle.target = self
        menu.addItem(toggle)

        let refresh = NSMenuItem(
            title: "Refresh Now Playing", action: #selector(refreshNowPlaying), keyEquivalent: "r"
        )
        refresh.target = self
        menu.addItem(refresh)

        menu.addItem(NSMenuItem.separator())

        let prefs = NSMenuItem(
            title: "Settings…", action: #selector(openSettings), keyEquivalent: ","
        )
        prefs.target = self
        menu.addItem(prefs)

        let about = NSMenuItem(
            title: "About Island", action: #selector(openAbout), keyEquivalent: ""
        )
        about.target = self
        menu.addItem(about)

        let github = NSMenuItem(
            title: "View on GitHub", action: #selector(openGitHub), keyEquivalent: ""
        )
        github.target = self
        menu.addItem(github)

        menu.addItem(NSMenuItem.separator())

        let quit = NSMenuItem(
            title: "Quit Island", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"
        )
        menu.addItem(quit)

        return menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        if let first = menu.items.first {
            first.title = settingsModel.visible ? "Hide Island" : "Show Island"
        }
    }

    @objc private func toggleIsland() { islandController?.toggle() }
    @objc private func refreshNowPlaying() { viewModel.refresh() }
    @objc private func openSettings() { settingsWindow?.show() }
    @objc private func openGitHub() {
        NSWorkspace.shared.open(URL(string: "https://github.com/elvinmonke/island")!)
    }
    @objc private func openAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Island"
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        alert.informativeText = "Version \(v)\n\nDynamic Island for macOS.\nOpen source, MIT. By Elvin."
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "GitHub")
        if alert.runModal() == .alertSecondButtonReturn { openGitHub() }
    }
}
