internal import AppKit

final class OverlayPanelWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override var isKeyWindow: Bool { true }
    override var isMainWindow: Bool { true }

    override func setContentSize(_ size: NSSize) {
        if let targetScreen = self.screen ?? NSScreen.main {
            let newX = floor(targetScreen.frame.midX - size.width / 2)
            let newY = self.frame.maxY - size.height
            super.setFrame(NSRect(x: newX, y: newY, width: size.width, height: size.height), display: true)
        } else {
            super.setContentSize(size)
        }
    }
}
