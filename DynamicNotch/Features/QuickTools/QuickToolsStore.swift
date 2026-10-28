import Foundation
internal import AppKit
import Combine

enum NotchHubMode: String, CaseIterable, Identifiable {
    case nook
    case shots
    case tray
    case clips
    case notes
    case tools

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .nook: return "sparkles.rectangle.stack.fill"
        case .shots: return "photo.stack.fill"
        case .tray: return "tray.and.arrow.down.fill"
        case .clips: return "doc.on.clipboard.fill"
        case .notes: return "note.text"
        case .tools: return "square.grid.2x2.fill"
        }
    }

    var requiresExtendedHeight: Bool {
        switch self {
        case .nook, .tray:
            return false
        case .shots, .clips, .notes, .tools:
            return true
        }
    }
}

struct QuickToolTab: Identifiable, Equatable {
    let id: String
    let titleKey: String
    let systemImage: String

    static let allTabs: [QuickToolTab] = [
        QuickToolTab(id: "notes", titleKey: "settings.tools.notes", systemImage: "note.text"),
        QuickToolTab(id: "snippets", titleKey: "productivity.tool.snippets", systemImage: "doc.on.clipboard"),
        QuickToolTab(id: "tasks", titleKey: "productivity.tool.tasks", systemImage: "checklist"),
        QuickToolTab(id: "focus", titleKey: "productivity.tool.focus", systemImage: "timer"),
        QuickToolTab(id: "stopwatch", titleKey: "settings.tools.stopwatch", systemImage: "stopwatch"),
        QuickToolTab(id: "awake", titleKey: "settings.tools.awake", systemImage: "cup.and.saucer.fill"),
        QuickToolTab(id: "color", titleKey: "settings.tools.color", systemImage: "eyedropper.halffull"),
        QuickToolTab(id: "calculator", titleKey: "support.tool.calculator", systemImage: "plus.forwardslash.minus"),
        QuickToolTab(id: "shortcuts", titleKey: "support.tool.shortcuts", systemImage: "bolt.square"),
        QuickToolTab(id: "zip", titleKey: "support.tool.zip", systemImage: "doc.zipper"),
        QuickToolTab(id: "developer", titleKey: "support.tool.developer", systemImage: "curlybraces"),
        QuickToolTab(id: "cases", titleKey: "support.tool.cases", systemImage: "photo.on.rectangle.angled"),
        QuickToolTab(id: "reports", titleKey: "support.tool.reports", systemImage: "chart.bar.doc.horizontal"),
        QuickToolTab(id: "rules", titleKey: "productivity.tool.rules", systemImage: "macwindow.badge.plus"),
        QuickToolTab(id: "jobs", titleKey: "productivity.tool.jobs", systemImage: "terminal"),
        QuickToolTab(id: "status", titleKey: "productivity.tool.status", systemImage: "gauge.with.dots.needle.33percent")
    ]

    static let defaultEnabledIDs: [String] = [
        "notes", "snippets", "tasks", "focus", "stopwatch", "awake", "color", "calculator"
    ]
}

@MainActor
final class QuickToolsStore: ObservableObject {
    static let shared = QuickToolsStore()
    static let enabledTabsKey = "DynamicNotch.QuickTools.enabledTabs.v1"

    lazy var notes = QuickNotes()
    let stopwatch = StopwatchController()
    let awake = KeepAwakeController()
    lazy var focus = FocusSessionController()
    let jobs = LocalJobRunner()

    @Published var selectedTool = "notes"
    @Published var hubMode: NotchHubMode = .nook {
        didSet {
            guard oldValue != hubMode else { return }
            notchViewModel?.refreshPresentationGeometry()
        }
    }
    @Published var isNotchHubPinned = false
    @Published var isMirrorCameraActive = false
    @Published private(set) var enabledTabIDs: [String]
    @Published private(set) var sampledColor: String?

    weak var nowPlayingViewModel: NowPlayingViewModel?
    weak var calendarViewModel: CalendarViewModel?
    weak var fileTrayViewModel: FileTrayViewModel?
    weak var airDropViewModel: AirDropNotchViewModel?
    weak var screenshotViewModel: ScreenshotViewModel?
    weak var mediaSettings: MediaAndFilesSettingsStore?
    weak var applicationSettings: ApplicationSettingsStore?
    weak var notchViewModel: NotchViewModel?

    private let defaults: UserDefaults
    private let colorSampler = NSColorSampler()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let validIDs = Set(QuickToolTab.allTabs.map(\.id))
        if let saved = defaults.stringArray(forKey: Self.enabledTabsKey) {
            let filtered = saved.filter { validIDs.contains($0) }
            self.enabledTabIDs = filtered.isEmpty ? QuickToolTab.defaultEnabledIDs : filtered
        } else {
            self.enabledTabIDs = QuickToolTab.defaultEnabledIDs
        }
        if !self.enabledTabIDs.contains(selectedTool), let first = self.enabledTabIDs.first {
            self.selectedTool = first
        }
    }

    func bind(container: AppContainer) {
        self.nowPlayingViewModel = container.nowPlayingViewModel
        self.calendarViewModel = container.calendarViewModel
        self.fileTrayViewModel = container.fileTrayViewModel
        self.airDropViewModel = container.airDropViewModel
        self.screenshotViewModel = container.screenshotViewModel
        self.mediaSettings = container.settingsViewModel.mediaAndFiles
        self.applicationSettings = container.settingsViewModel.application
        self.notchViewModel = container.notchViewModel
    }

    var visibleTabs: [QuickToolTab] {
        let enabledSet = Set(enabledTabIDs)
        let matching = QuickToolTab.allTabs.filter { enabledSet.contains($0.id) }
        return matching.isEmpty ? QuickToolTab.allTabs : matching
    }

    func isTabEnabled(_ id: String) -> Bool {
        enabledTabIDs.contains(id)
    }

    func setTabEnabled(_ id: String, enabled: Bool) {
        let validIDs = QuickToolTab.allTabs.map(\.id)
        guard validIDs.contains(id) else { return }

        var current = Set(enabledTabIDs)
        if enabled {
            current.insert(id)
        } else if current.count > 1 {
            current.remove(id)
        }

        enabledTabIDs = validIDs.filter { current.contains($0) }
        defaults.set(enabledTabIDs, forKey: Self.enabledTabsKey)

        if !enabledTabIDs.contains(selectedTool), let first = enabledTabIDs.first {
            selectedTool = first
        }
    }

    func resetEnabledTabs() {
        enabledTabIDs = QuickToolTab.defaultEnabledIDs
        defaults.set(enabledTabIDs, forKey: Self.enabledTabsKey)
        if !enabledTabIDs.contains(selectedTool), let first = enabledTabIDs.first {
            selectedTool = first
        }
    }

    func sampleColor() {
        colorSampler.show { [weak self] color in
            guard let color = color?.usingColorSpace(.sRGB) else { return }
            let value = Self.hex(red: color.redComponent, green: color.greenComponent, blue: color.blueComponent)
            Task { @MainActor [weak self] in self?.sampledColor = value }
        }
    }

    nonisolated static func hex(red: CGFloat, green: CGFloat, blue: CGFloat) -> String {
        let values = [red, green, blue].map { Int((min(1, max(0, $0)) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", values[0], values[1], values[2])
    }

    func copyColor() {
        guard let sampledColor else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(sampledColor, forType: .string)
    }

    func shutdown() { awake.stop() }
}

extension Notification.Name {
    static let presentationRuleChanged = Notification.Name("DynamicNotch.PresentationRuleChanged")
    static let closeQuickToolsInNotch = Notification.Name("DynamicNotch.CloseQuickToolsInNotch")
    static let showQuickToolsInNotch = Notification.Name("DynamicNotch.ShowQuickToolsInNotch")
}
