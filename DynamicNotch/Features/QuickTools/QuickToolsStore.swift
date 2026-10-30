import Foundation
internal import AppKit
import SwiftUI
import Combine

enum NotchHubMode: String, CaseIterable, Identifiable {
    case nook
    case shots
    case tray
    case clips
    case tools
    case widgets
    case transform
    case ai
    case meeting
    case messages

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .nook: return "sparkles.rectangle.stack.fill"
        case .shots: return "photo.stack.fill"
        case .tray: return "tray.and.arrow.down.fill"
        case .clips: return "doc.on.clipboard.fill"
        case .widgets: return "square.grid.2x2.fill"
        case .tools: return "square.grid.2x2.fill"
        case .transform: return "wand.and.stars"
        case .ai: return "sparkles"
        case .meeting: return "video.fill"
        case .messages: return "bubble.left.and.bubble.right.fill"
        }
    }

    var requiresExtendedHeight: Bool {
        switch self {
        case .nook, .tray, .widgets:
            return false
        case .shots, .clips, .tools, .transform, .ai, .meeting, .messages:
            return true
        }
    }
}

struct QuickToolTab: Identifiable, Equatable {
    let id: String
    let titleKey: String
    let systemImage: String

    static let allTabs: [QuickToolTab] = [
        QuickToolTab(id: "meeting", titleKey: "shelf.tool.meeting", systemImage: "video.fill"),
        QuickToolTab(id: "messages", titleKey: "shelf.tool.messages", systemImage: "bubble.left.and.bubble.right.fill"),
        QuickToolTab(id: "ai", titleKey: "shelf.tool.ai", systemImage: "sparkles"),
        QuickToolTab(id: "transform", titleKey: "shelf.tool.transform", systemImage: "wand.and.stars"),
        QuickToolTab(id: "stats", titleKey: "shelf.tool.stats", systemImage: "waveform.path.ecg"),
        QuickToolTab(id: "snippets", titleKey: "productivity.tool.snippets", systemImage: "doc.on.clipboard"),
        QuickToolTab(id: "status", titleKey: "productivity.tool.status", systemImage: "gauge.with.dots.needle.33percent")
    ]

    static let defaultEnabledIDs: [String] = [
        "meeting", "messages", "ai", "transform", "stats", "snippets"
    ]
}

@MainActor
final class QuickToolsStore: ObservableObject {
    static let shared = QuickToolsStore()
    static let enabledTabsKey = "DynamicNotch.QuickTools.enabledTabs.v1"

    lazy var shelf = ShelfPreferences(defaults: defaults)

    @Published var selectedTool = "stats" {
        didSet {
            if oldValue != selectedTool { notchViewModel?.refreshPresentationGeometry() }
        }
    }
    @Published var hubMode: NotchHubMode = .nook {
        didSet {
            guard oldValue != hubMode else { return }
            notchViewModel?.refreshPresentationGeometry()
        }
    }
    @Published var isNotchHubPinned = false
    @Published var isSoundMixerVisibleInCalendarSlot = false
    @Published var isCalendarFullScheduleVisible = false
    @Published var isLyricsVisibleInCalendarSlot = false {
        didSet {
            guard oldValue != isLyricsVisibleInCalendarSlot else { return }
            if isLyricsVisibleInCalendarSlot {
                nowPlayingViewModel?.setLyricsPresentationActive(true)
            } else {
                nowPlayingViewModel?.setLyricsPresentationActive(false)
            }
        }
    }
    @Published private(set) var enabledTabIDs: [String]

    func toggleLyricsInCalendarSlot() {
        if !isLyricsVisibleInCalendarSlot {
            isSoundMixerVisibleInCalendarSlot = false
            isCalendarFullScheduleVisible = false
        }
        isLyricsVisibleInCalendarSlot.toggle()
    }

    func toggleSoundMixerInCalendarSlot() {
        if !isSoundMixerVisibleInCalendarSlot {
            isLyricsVisibleInCalendarSlot = false
            isCalendarFullScheduleVisible = false
        }
        isSoundMixerVisibleInCalendarSlot.toggle()
    }

    weak var nowPlayingViewModel: NowPlayingViewModel?
    weak var calendarViewModel: CalendarViewModel?
    weak var fileTrayViewModel: FileTrayViewModel?
    weak var airDropViewModel: AirDropNotchViewModel?
    weak var screenshotViewModel: ScreenshotViewModel?
    weak var mediaSettings: MediaAndFilesSettingsStore?
    weak var applicationSettings: ApplicationSettingsStore?
    weak var notchViewModel: NotchViewModel?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let validIDs = Set(QuickToolTab.allTabs.map(\.id))
        if let saved = defaults.stringArray(forKey: Self.enabledTabsKey) {
            var seen = Set<String>()
            let filtered = saved.filter { validIDs.contains($0) && seen.insert($0).inserted }
            self.enabledTabIDs = filtered.isEmpty ? QuickToolTab.defaultEnabledIDs : filtered
        } else {
            self.enabledTabIDs = QuickToolTab.defaultEnabledIDs
        }
        if !validIDs.contains(selectedTool) {
            self.selectedTool = "stats"
        } else if !self.enabledTabIDs.contains(selectedTool), let first = self.enabledTabIDs.first {
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
        let tabMap = Dictionary(uniqueKeysWithValues: QuickToolTab.allTabs.map { ($0.id, $0) })
        let ordered = enabledTabIDs.compactMap { tabMap[$0] }
        return ordered.isEmpty ? QuickToolTab.allTabs : ordered
    }

    func isTabEnabled(_ id: String) -> Bool {
        enabledTabIDs.contains(id)
    }

    func setTabEnabled(_ id: String, enabled: Bool) {
        let validIDs = Set(QuickToolTab.allTabs.map(\.id))
        guard validIDs.contains(id) else { return }

        var updated = enabledTabIDs
        if enabled {
            if !updated.contains(id) {
                updated.append(id)
            }
        } else if updated.count > 1 {
            updated.removeAll { $0 == id }
        }

        enabledTabIDs = updated
        defaults.set(enabledTabIDs, forKey: Self.enabledTabsKey)

        if !enabledTabIDs.contains(selectedTool), let first = enabledTabIDs.first {
            selectedTool = first
        }
    }

    func moveTab(_ id: String, by offset: Int) {
        guard let index = enabledTabIDs.firstIndex(of: id) else { return }
        let targetIndex = index + offset
        guard enabledTabIDs.indices.contains(targetIndex) else { return }
        var updated = enabledTabIDs
        updated.swapAt(index, targetIndex)
        enabledTabIDs = updated
        defaults.set(enabledTabIDs, forKey: Self.enabledTabsKey)
    }

    func moveTab(fromOffsets source: IndexSet, toOffset destination: Int) {
        var updated = enabledTabIDs
        updated.move(fromOffsets: source, toOffset: destination)
        enabledTabIDs = updated
        defaults.set(enabledTabIDs, forKey: Self.enabledTabsKey)
    }

    func resetEnabledTabs() {
        enabledTabIDs = QuickToolTab.defaultEnabledIDs
        defaults.set(enabledTabIDs, forKey: Self.enabledTabsKey)
        if !enabledTabIDs.contains(selectedTool), let first = enabledTabIDs.first {
            selectedTool = first
        }
    }

    func shelfExtraHeight(isIsland: Bool) -> CGFloat {
        if hubMode == .nook || hubMode == .widgets { return isIsland ? 198 : 206 }
        if hubMode == .tools && selectedTool == "stats" { return isIsland ? 290 : 300 }
        if hubMode == .clips || (hubMode == .tools && selectedTool == "snippets") { return isIsland ? 384 : 394 }
        if hubMode == .messages || (hubMode == .tools && selectedTool == "messages") { return isIsland ? 280 : 290 }
        if hubMode == .meeting || (hubMode == .tools && selectedTool == "meeting") { return isIsland ? 54 : 58 }
        if hubMode == .ai || (hubMode == .tools && selectedTool == "ai") { return isIsland ? 260 : 270 }
        if hubMode == .transform || (hubMode == .tools && selectedTool == "transform") { return isIsland ? 220 : 230 }
        return hubMode.requiresExtendedHeight ? (isIsland ? 200 : 210) : (isIsland ? 164 : 172)
    }

    func shutdown() {}
}

extension Notification.Name {
    static let presentationRuleChanged = Notification.Name("DynamicNotch.PresentationRuleChanged")
    static let closeQuickToolsInNotch = Notification.Name("DynamicNotch.CloseQuickToolsInNotch")
    static let showQuickToolsInNotch = Notification.Name("DynamicNotch.ShowQuickToolsInNotch")
}
