import AppKit
import SwiftUI

final class IslandPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class IslandWindowController {
    private var panel: IslandPanel?
    let viewModel: IslandViewModel
    let settings: AppSettings

    init(viewModel: IslandViewModel, settings: AppSettings) {
        self.viewModel = viewModel
        self.settings = settings
        NotificationCenter.default.addObserver(
            forName: AppSettings.changed, object: nil, queue: .main
        ) { [weak self] _ in self?.reposition() }
    }

    func show() {
        guard panel == nil else { return }
        let size = NSSize(width: 560, height: 200)
        let p = IslandPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = .screenSaver
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.ignoresMouseEvents = false
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        p.hidesOnDeactivate = false

        let host = NSHostingView(
            rootView: IslandView()
                .environmentObject(viewModel)
                .environmentObject(settings)
        )
        host.frame = NSRect(origin: .zero, size: size)
        host.autoresizingMask = [.width, .height]
        p.contentView = host
        panel = p
        reposition()
        if settings.visible { p.orderFrontRegardless() }
    }

    func reposition() {
        guard let p = panel else { return }
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let size = p.frame.size

        // Position just below the notch/menu bar so content is never obscured.
        // safeAreaInsets.top > 0 means there's a notch.
        let hasNotch = screen.safeAreaInsets.top > 0
        let topY = hasNotch
            ? screen.frame.maxY - screen.safeAreaInsets.top
            : screen.visibleFrame.maxY
        let origin = NSPoint(
            x: screen.frame.midX - size.width / 2,
            y: topY - size.height - CGFloat(settings.verticalOffset)
        )
        p.setFrameOrigin(origin)

        if settings.visible {
            p.orderFrontRegardless()
        } else {
            p.orderOut(nil)
        }
    }

    func toggle() {
        settings.visible.toggle()
        reposition()
    }
}
