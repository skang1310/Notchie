import SwiftUI
internal import AppKit
import Combine
import UniformTypeIdentifiers

@MainActor
final class ProductivityCoordinator: ObservableObject {
    static let shared = ProductivityCoordinator()

    private var observations = Set<AnyCancellable>()
    private var clipboardTimer: AnyCancellable?
    private var lastClipboardChangeCount: Int = NSPasteboard.general.changeCount

    func start() {
        AIQuotaMonitor.shared.start()
        ProductivityStorage.shared.$isAutoCaptureClipboardEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                self?.configureClipboardAutoCapture(enabled: enabled)
            }
            .store(in: &observations)
    }

    private func configureClipboardAutoCapture(enabled: Bool) {
        clipboardTimer?.cancel()
        clipboardTimer = nil
        guard enabled, !AppEnvironment.isRunningTests else { return }
        lastClipboardChangeCount = NSPasteboard.general.changeCount
        clipboardTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, ProductivityStorage.shared.isAutoCaptureClipboardEnabled else { return }
                let currentCount = NSPasteboard.general.changeCount
                guard currentCount != self.lastClipboardChangeCount else { return }
                self.lastClipboardChangeCount = currentCount
                let foreground = NSWorkspace.shared.frontmostApplication
                let source = foreground?.bundleIdentifier == Bundle.main.bundleIdentifier ? nil : foreground?.localizedName
                _ = ProductivityStorage.shared.captureFromPasteboard(sourceAppName: source)
            }
    }

    func openTool(_ id: String) {
        QuickToolsStore.shared.selectedTool = id
        QuickToolsStore.shared.hubMode = .tools
        NotificationCenter.default.post(name: .showQuickToolsInNotch, object: nil)
    }

    func shutdown() {
        AIQuotaMonitor.shared.stop()
        clipboardTimer?.cancel()
        clipboardTimer = nil
        observations.removeAll()
    }
}
