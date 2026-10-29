import Foundation
import Combine

enum ShelfWidget: String, CaseIterable, Identifiable {
    case media, calendar, focus, stats, notes
    var id: String { rawValue }
    var title: String {
        switch self {
        case .media: privacyText("Now Playing", "지금 재생 중")
        case .calendar: privacyText("Calendar", "캘린더")
        case .focus: privacyText("Focus", "집중")
        case .stats: privacyText("System Stats", "시스템 상태")
        case .notes: privacyText("Notes", "메모")
        }
    }
    var symbol: String {
        switch self {
        case .media: "music.note"
        case .calendar: "calendar"
        case .focus: "timer"
        case .stats: "waveform.path.ecg"
        case .notes: "note.text"
        }
    }
}

@MainActor
final class ShelfPreferences: ObservableObject {
    static let widgetsKey = "DynamicNotch.Shelf.widgets.v1"
    @Published private(set) var widgets: [ShelfWidget]
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.stringArray(forKey: Self.widgetsKey) ?? ["media", "calendar", "stats"]
        var seen = Set<ShelfWidget>()
        let valid = saved.compactMap(ShelfWidget.init(rawValue:)).filter { seen.insert($0).inserted }
        widgets = valid.isEmpty ? [.media, .calendar, .stats] : Array(valid.prefix(3))
    }
    func replace(at index: Int, with widget: ShelfWidget) {
        guard widgets.indices.contains(index), widgets[index] != widget else { return }
        var next = widgets
        if let other = next.firstIndex(of: widget) { next.swapAt(index, other) }
        else { next[index] = widget }
        save(next)
    }
    func move(_ widget: ShelfWidget, by offset: Int) {
        guard let index = widgets.firstIndex(of: widget), widgets.indices.contains(index + offset) else { return }
        var next = widgets; next.swapAt(index, index + offset); save(next)
    }
    func reset() { save([.media, .calendar, .stats]) }
    private func save(_ next: [ShelfWidget]) {
        widgets = next
        defaults.set(next.map(\.rawValue), forKey: Self.widgetsKey)
    }
}

/// Monotonic reading progress. Runtime state is deliberately never restored as running.
@MainActor
final class TeleprompterController: ObservableObject {
    static let scriptKey = "DynamicNotch.Teleprompter.script.v1"
    static let speedKey = "DynamicNotch.Teleprompter.speed.v1"
    @Published var script: String { didSet { defaults.set(String(script.prefix(30_000)), forKey: Self.scriptKey) } }
    @Published var wordsPerMinute: Double { didSet { defaults.set(Self.clampSpeed(wordsPerMinute), forKey: Self.speedKey) } }
    @Published private(set) var position: Double = 0
    @Published private(set) var isRunning = false
    private let defaults: UserDefaults
    private var lastTick: TimeInterval?
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        script = String((defaults.string(forKey: Self.scriptKey) ?? "").prefix(30_000))
        wordsPerMinute = Self.clampSpeed(defaults.object(forKey: Self.speedKey) as? Double ?? 120)
    }
    static func clampSpeed(_ value: Double) -> Double { value.isFinite ? min(300, max(30, value)) : 120 }
    var words: [String] { script.split(whereSeparator: \.isWhitespace).map(String.init) }
    var currentIndex: Int { min(max(0, Int(position)), max(0, words.count - 1)) }
    func start(at uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard !words.isEmpty else { return }
        if position >= Double(words.count - 1) { position = 0 }
        isRunning = true; lastTick = uptime
    }
    func pause() { isRunning = false; lastTick = nil }
    func reset() { pause(); position = 0 }
    func advance(at uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard isRunning, let previous = lastTick else { return }
        // Discard long sleep/stall gaps; never skip the script after waking.
        let elapsed = min(1, max(0, uptime - previous)); lastTick = uptime
        position += elapsed * Self.clampSpeed(wordsPerMinute) / 60
        if position >= Double(words.count) { position = Double(max(0, words.count - 1)); pause() }
    }
}
