import SwiftUI
internal import AppKit
import Combine
import UniformTypeIdentifiers

@MainActor
final class ProductivityCoordinator: ObservableObject {
    static let shared = ProductivityCoordinator()
    private let hotkey = GlobalHotkeyManager(identifier: 2)
    @Published private(set) var shortcutAvailable = false
    private var panel: NSPanel?
    private var observations = Set<AnyCancellable>()
    private var clipboardTimer: AnyCancellable?
    private var lastClipboardChangeCount: Int = NSPasteboard.general.changeCount
    func start() {
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .receive(on: RunLoop.main).sink { _ in NotificationCenter.default.post(name: .presentationRuleChanged, object: nil) }.store(in: &observations)
        ProductivityStorage.shared.$document.receive(on: RunLoop.main)
            .sink { _ in NotificationCenter.default.post(name: .presentationRuleChanged, object: nil) }.store(in: &observations)
        ProductivityStorage.shared.$isAutoCaptureClipboardEnabled.receive(on: RunLoop.main)
            .sink { [weak self] enabled in self?.configureClipboardAutoCapture(enabled: enabled) }.store(in: &observations)
        shortcutAvailable = hotkey.register(keyCode: 49, modifiers: [.control, .option]) { [weak self] in
            Task { @MainActor in self?.showPalette() }
        }
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
                _ = ProductivityStorage.shared.captureFromPasteboard()
            }
    }
    func openTool(_ id: String) {
        panel?.orderOut(nil)
        QuickToolsStore.shared.selectedTool = id
        NotificationCenter.default.post(name: .showQuickToolsInNotch, object: nil)
    }
    func showPalette() {
        if panel == nil {
            let view = CommandPaletteView(coordinator: self)
            let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 560, height: 430), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            p.title = L10n.app("productivity.palette")
            p.isReleasedWhenClosed = false; p.level = .floating
            p.contentView = NSHostingView(rootView: view); p.center(); panel = p
        }
        NSApp.activate(ignoringOtherApps: true); panel?.makeKeyAndOrderFront(nil)
    }
    func chooseApplication() {
        let chooser = NSOpenPanel(); chooser.allowedContentTypes = [.application]; chooser.canChooseDirectories = false
        guard chooser.runModal() == .OK, let url = chooser.url else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
    func shutdown() { clipboardTimer?.cancel(); clipboardTimer = nil; SupportDeskCoordinator.shared.shutdown(); observations.removeAll(); hotkey.unregister(); panel?.orderOut(nil); QuickToolsStore.shared.focus.stop(); QuickToolsStore.shared.jobs.shutdown() }
}
struct CommandPaletteView: View {
    @ObservedObject var coordinator: ProductivityCoordinator
    @ObservedObject private var notes = QuickToolsStore.shared.notes
    @State private var query = ""
    @FocusState private var searching: Bool
    private let tools = ["notes", "stopwatch", "awake", "color", "focus", "tasks", "snippets", "rules", "jobs", "status", "calculator", "shortcuts", "zip", "developer", "reports", "cases"]
    private var matches: [String] { tools.filter { query.isEmpty || L10n.app(($0 == "calculator" || $0 == "shortcuts" || $0 == "zip" || $0 == "developer" || $0 == "reports" || $0 == "cases") ? "support.tool.\($0)" : "productivity.tool.\($0)").localizedCaseInsensitiveContains(query) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("productivity.palette.search", text: $query).textFieldStyle(.roundedBorder).focused($searching)
                .onSubmit { if let first = matches.first { coordinator.openTool(first) } }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(matches, id: \.self) { id in
                        Button { coordinator.openTool(id) } label: { Label(L10n.app(["calculator","shortcuts","zip","developer","reports","cases"].contains(id) ? "support.tool.\(id)" : "productivity.tool.\(id)"), systemImage: "arrow.up.forward.app") }.buttonStyle(.plain).padding(7)
                    }
                    if !query.isEmpty {
                        ForEach(notes.notes.filter { $0.text.localizedCaseInsensitiveContains(query) }.prefix(8)) { note in
                            Button(note.title) { if !notes.hasUnsavedChanges { notes.edit(note) }; coordinator.openTool("notes") }
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Button("productivity.launchApp") { coordinator.chooseApplication() }
                Spacer(); Text("⌃⌥Space").font(.caption).foregroundStyle(.secondary)
            }
        }.padding(20).onAppear { searching = true }
    }
}
