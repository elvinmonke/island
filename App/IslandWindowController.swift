import AppKit
import SwiftUI
import Combine

// MARK: - CGS Private API

typealias CGSConnectionID = UInt32
typealias CGSWindowID = UInt32

@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> CGSConnectionID

@_silgen_name("CGSSetWindowTags")
func CGSSetWindowTags(_ cid: CGSConnectionID, _ wid: CGSWindowID, _ tags: UnsafeMutablePointer<UInt64>, _ tagSize: Int32) -> Int32

private func setLoginWindowTag(for window: NSWindow) {
    let cid = CGSMainConnectionID()
    let wid = CGSWindowID(window.windowNumber)
    var tags: UInt64 = 0x200
    CGSSetWindowTags(cid, wid, &tags, 32)
    islandLog("setLoginWindowTag wid=\(wid)")
}

// MARK: - Main Island Panel

final class IslandPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    var pillWidth: CGFloat = 200
    var pillHeight: CGFloat = 32

    private var trackingArea: NSTrackingArea?
    private var mouseInPill = false

    func updatePillTrackingArea() {
        guard let cv = contentView else { return }
        if let old = trackingArea { cv.removeTrackingArea(old) }
        let cx = cv.bounds.midX
        let topY = cv.bounds.maxY
        let m: CGFloat = 6
        let rect = NSRect(
            x: cx - pillWidth / 2 - m,
            y: topY - pillHeight - m,
            width: pillWidth + m * 2,
            height: pillHeight + m * 2
        )
        let ta = NSTrackingArea(
            rect: rect,
            options: [.mouseEnteredAndExited, .activeAlways, .mouseMoved],
            owner: self
        )
        cv.addTrackingArea(ta)
        trackingArea = ta

        let mouseLocation = NSEvent.mouseLocation
        let windowFrame = self.frame
        let localPoint = NSPoint(
            x: mouseLocation.x - windowFrame.origin.x,
            y: mouseLocation.y - windowFrame.origin.y
        )
        let inside = rect.contains(localPoint)
        if inside != mouseInPill {
            mouseInPill = inside
            ignoresMouseEvents = !inside
            if !inside { resignKey() }
        }
    }

    override func mouseEntered(with event: NSEvent) {
        mouseInPill = true
        ignoresMouseEvents = false
    }

    override func mouseExited(with event: NSEvent) {
        mouseInPill = false
        ignoresMouseEvents = true
        resignKey()
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown && mouseInPill {
            makeKey()
        }
        super.sendEvent(event)
    }
}

// MARK: - Main Island Window Controller

final class IslandWindowController {
    private var panel: IslandPanel?
    private var hostView: NSHostingView<AnyView>?
    let viewModel: IslandViewModel
    let settings: AppSettings
    private var cancellables = Set<AnyCancellable>()

    private static let maxWidth: CGFloat = 624
    private static let maxHeight: CGFloat = 320

    init(viewModel: IslandViewModel, settings: AppSettings) {
        self.viewModel = viewModel
        self.settings = settings

        NotificationCenter.default.addObserver(
            forName: AppSettings.changed, object: nil, queue: .main
        ) { [weak self] _ in self?.reposition() }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("IslandLockStateChanged"), object: nil, queue: .main
        ) { [weak self] _ in
            self?.bringToFrontAggressively()
        }

        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.bringToFrontAggressively()
        }
    }

    func show() {
        guard panel == nil else { return }
        let winSize = NSSize(width: Self.maxWidth, height: Self.maxHeight)
        let p = IslandPanel(
            contentRect: NSRect(origin: .zero, size: winSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        p.hidesOnDeactivate = false
        p.canBecomeVisibleWithoutLogin = true
        if settings.hideFromScreenCapture {
            p.sharingType = .none
        }

        let host = NSHostingView(
            rootView: AnyView(
                IslandView()
                    .environmentObject(viewModel)
                    .environmentObject(settings)
            )
        )
        host.frame = NSRect(origin: .zero, size: winSize)
        host.autoresizingMask = [.width, .height]
        p.contentView = host
        hostView = host
        panel = p
        reposition()
        setLoginWindowTag(for: p)

        if settings.visible { p.orderFrontRegardless() }
        p.updatePillTrackingArea()
        observeChanges()
    }

    private func observeChanges() {
        viewModel.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                DispatchQueue.main.async { self?.updatePillSize() }
            }
            .store(in: &cancellables)

        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.panel?.sharingType = self.settings.hideFromScreenCapture ? .none : .readOnly
                }
            }
            .store(in: &cancellables)
    }

    private func updatePillSize() {
        let vm = viewModel
        let isExpanded = vm.isHovering && settings.expandOnHover
        let hasLock = vm.lockState != nil && settings.enableLockScreen
        let hasHUD = vm.activeHUD != nil && (settings.enableVolume || settings.enableBrightness)
        let hasAirpods = vm.audioDeviceMonitor.connectedDevice != nil
        let hasCall = vm.activeNotification?.kind == .call
        let hasNotif = vm.activeNotification != nil
        let isActive = (vm.isPlaying && settings.enableNowPlaying) || (vm.timerManager.isRunning && settings.enableTimer)

        var w: CGFloat = 200
        var h: CGFloat = 32

        if hasLock {
            w = vm.lockState == .locking ? 200 : 300; h = 38
        } else if hasAirpods {
            w = 240; h = 120
        } else if hasHUD {
            w = 380; h = 60
        } else if hasCall {
            w = 500; h = 82
        } else if hasNotif {
            w = 380; h = 52
        } else if isExpanded {
            w = 340; h = 230
        } else if isActive {
            w = 280; h = 38
        }

        panel?.pillWidth = w
        panel?.pillHeight = h
        panel?.updatePillTrackingArea()
    }

    private func bringToFrontAggressively() {
        guard let p = panel else { return }
        p.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        p.orderFrontRegardless()
        setLoginWindowTag(for: p)

        for delay in [0.1, 0.5, 1.0, 2.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.panel?.orderFrontRegardless()
            }
        }
    }

    func reposition() {
        guard let p = panel else { return }
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let winSize = NSSize(width: Self.maxWidth, height: Self.maxHeight)

        let origin = NSPoint(
            x: screen.frame.midX - winSize.width / 2,
            y: screen.frame.maxY - winSize.height
        )

        p.setFrame(NSRect(origin: origin, size: winSize), display: true)

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
