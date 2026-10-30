import SwiftUI
internal import AppKit

/// View-local schedules must stop even when NSPanel is ordered out without unmounting SwiftUI.
struct PresentationVisibilityReader: NSViewRepresentable {
    @Binding var isVisible: Bool
    func makeNSView(context: Context) -> VisibilityView {
        let view = VisibilityView()
        view.onChange = { isVisible = $0 }
        return view
    }
    func updateNSView(_ view: VisibilityView, context: Context) {
        view.onChange = { isVisible = $0 }
        view.publish()
    }
    static func dismantleNSView(_ view: VisibilityView, coordinator: ()) { view.stop() }
    final class VisibilityView: NSView {
        var onChange: ((Bool) -> Void)?
        private var observer: NSObjectProtocol?
        private var lastVisibility: Bool?
        private var revision = UUID()
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stop()
            if let window {
                observer = NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification,
                    object: window, queue: .main) { [weak self] _ in
                        MainActor.assumeIsolated { self?.publish() }
                    }
            }
            publish()
        }
        func publish() {
            let visible = !isHiddenOrHasHiddenAncestor && (window.map { $0.isVisible && $0.occlusionState.contains(.visible) } ?? false)
            guard visible != lastVisibility else { return }
            lastVisibility = visible
            let token = UUID(); revision = token
            DispatchQueue.main.async { [weak self] in
                guard let self, self.revision == token else { return }
                self.onChange?(visible)
            }
        }
        override func viewDidHide() { super.viewDidHide(); publish() }
        override func viewDidUnhide() { super.viewDidUnhide(); publish() }
        func stop() {
            revision = UUID(); lastVisibility = nil
            if let observer { NotificationCenter.default.removeObserver(observer) }; observer = nil
        }
        deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
    }
}

struct PresentationTick { let date: Date }

struct PresentationTimeline<Content: View>: View {
    let interval: TimeInterval
    var paused = false
    var content: (PresentationTick) -> Content
    init(interval: TimeInterval, paused: Bool = false, @ViewBuilder content: @escaping (PresentationTick) -> Content) {
        self.interval = interval; self.paused = paused; self.content = content
    }
    @State private var visible = false
    var body: some View {
        TimelineView(.animation(minimumInterval: interval, paused: paused || !visible)) { context in
            content(PresentationTick(date: context.date))
        }
        .background(PresentationVisibilityReader(isVisible: $visible).frame(width: 0, height: 0))
    }
}
