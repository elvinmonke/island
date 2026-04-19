import ScreenSaver
import AppKit

class IslandLockView: ScreenSaverView {
    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        animationTimeInterval = 1.0 / 30.0
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var hasConfigureSheet: Bool { false }
    override var configureSheet: NSWindow? { nil }

    override func draw(_ rect: NSRect) {
        // Full black background
        NSColor.black.setFill()
        bounds.fill()

        // Position pill below the notch
        let screen = NSScreen.main ?? NSScreen.screens.first
        let safeTop = screen?.safeAreaInsets.top ?? 0
        let hasNotch = safeTop > 0

        let pillWidth: CGFloat = 48
        let pillHeight: CGFloat = 36
        let pillX = bounds.midX - pillWidth / 2
        let pillY: CGFloat
        if hasNotch {
            pillY = bounds.maxY - safeTop - pillHeight + 2
        } else {
            pillY = bounds.maxY - pillHeight - 6
        }

        // Draw pill shape
        let pillRect = NSRect(x: pillX, y: pillY, width: pillWidth, height: pillHeight)
        let pillPath = NSBezierPath(roundedRect: pillRect, xRadius: pillHeight / 2, yRadius: pillHeight / 2)
        NSColor(white: 0.05, alpha: 1.0).setFill()
        pillPath.fill()

        // Draw lock icon using SF Symbol
        if let lockImage = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
            let configured = lockImage.withSymbolConfiguration(config) ?? lockImage
            let imgSize = configured.size
            let imgRect = NSRect(
                x: pillRect.midX - imgSize.width / 2,
                y: pillRect.midY - imgSize.height / 2,
                width: imgSize.width,
                height: imgSize.height
            )

            // Tint white
            let tinted = NSImage(size: imgSize, flipped: false) { drawRect in
                configured.draw(in: drawRect)
                NSColor.white.set()
                drawRect.fill(using: .sourceAtop)
                return true
            }
            tinted.draw(in: imgRect, from: .zero, operation: .sourceOver, fraction: 0.9)
        }
    }

    override func animateOneFrame() {
        // Static display, no animation needed
    }
}
