import AppKit
import SwiftUI
import Combine

final class IslandPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class IslandWindowController {
    private var panel: IslandPanel?
    let viewModel: IslandViewModel
    let settings: AppSettings
    private var cancellables = Set<AnyCancellable>()

    private let shadowPad: CGFloat = 40

    init(viewModel: IslandViewModel, settings: AppSettings) {
        self.viewModel = viewModel
        self.settings = settings

        NotificationCenter.default.addObserver(
            forName: AppSettings.changed, object: nil, queue: .main
        ) { [weak self] _ in self?.resize() }

        viewModel.$isHovering
            .removeDuplicates()
            .sink { [weak self] _ in self?.resize() }
            .store(in: &cancellables)

        viewModel.$isPlaying
            .removeDuplicates()
            .sink { [weak self] _ in self?.resize() }
            .store(in: &cancellables)
    }

    private var currentState: IslandState {
        if viewModel.isHovering && settings.expandOnHover { return .expanded }
        if viewModel.isPlaying { return .active }
        return .idle
    }

    private var pillSize: NSSize {
        switch currentState {
        case .idle:    return NSSize(width: 190, height: 34)
        case .active:  return NSSize(width: 340, height: 38)
        case .expanded: return NSSize(width: 420, height: 150)
        }
    }

    func show() {
        guard panel == nil else { return }
        let ps = pillSize
        let winSize = NSSize(
            width: ps.width + shadowPad * 2,
            height: ps.height + shadowPad
        )
        let p = IslandPanel(
            contentRect: NSRect(origin: .zero, size: winSize),
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
        host.frame = NSRect(origin: .zero, size: winSize)
        host.autoresizingMask = [.width, .height]
        p.contentView = host
        panel = p
        resize()
        if settings.visible { p.orderFrontRegardless() }
    }

    func resize() {
        guard let p = panel else { return }
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let ps = pillSize
        let winSize = NSSize(
            width: ps.width + shadowPad * 2,
            height: ps.height + shadowPad
        )

        let hasNotch = screen.safeAreaInsets.top > 0
        let topY = hasNotch
            ? screen.frame.maxY - screen.safeAreaInsets.top
            : screen.visibleFrame.maxY

        let origin = NSPoint(
            x: screen.frame.midX - winSize.width / 2,
            y: topY - winSize.height - CGFloat(settings.verticalOffset)
        )

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.45
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            p.animator().setFrame(NSRect(origin: origin, size: winSize), display: true)
        }

        if settings.visible {
            p.orderFrontRegardless()
        } else {
            p.orderOut(nil)
        }
    }

    func toggle() {
        settings.visible.toggle()
        resize()
    }
}
