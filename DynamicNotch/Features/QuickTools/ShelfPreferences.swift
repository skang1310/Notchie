import Foundation
import Combine

enum ShelfWidget: String, CaseIterable, Identifiable {
    case media, calendar, stats
    var id: String { rawValue }
    var title: String {
        switch self {
        case .media: privacyText("Now Playing", "지금 재생 중")
        case .calendar: privacyText("Calendar", "캘린더")
        case .stats: privacyText("System Stats", "시스템 상태")
        }
    }
    var symbol: String {
        switch self {
        case .media: "music.note"
        case .calendar: "calendar"
        case .stats: "waveform.path.ecg"
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
