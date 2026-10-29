import Foundation
import Combine
internal import AppKit

struct FocusCompletion: Codable, Identifiable { var id = UUID(); var date: Date; var seconds: Int }
struct DailyTask: Codable, Identifiable { var id = UUID(); var text: String; var day: String; var done = false
    init(id: UUID = UUID(), day: String, text: String, done: Bool = false) {
        self.id = id; self.day = day; self.text = text; self.done = done
    }
}
struct SavedSnippet: Codable, Identifiable { var id = UUID(); var text: String; var date = Date(); var isFavorite: Bool? = nil; var sourceAppName: String? = nil }
struct ProductivityDocument: Codable {
    var version = 1
    var focusHistory: [FocusCompletion] = []
    var tasks: [DailyTask] = []
    var snippets: [SavedSnippet] = []
    var hiddenBundleIDs: [String] = []
}

@MainActor
final class ProductivityStorage: ObservableObject {
    static let shared = ProductivityStorage()
    static let autoCaptureClipboardKey = "DynamicNotch.Clipboard.autoCapture.v1"

    @Published private(set) var document = ProductivityDocument()
    @Published private(set) var error: String?
    @Published var isAutoCaptureClipboardEnabled: Bool {
        didSet {
            defaults.set(isAutoCaptureClipboardEnabled, forKey: Self.autoCaptureClipboardKey)
        }
    }

    private let url: URL
    private let defaults: UserDefaults
    private var readable = true

    init(url: URL? = nil, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isAutoCaptureClipboardEnabled = defaults.bool(forKey: Self.autoCaptureClipboardKey)
        self.url = url ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("DynamicNotch/productivity.json")
        if FileManager.default.fileExists(atPath: self.url.path) {
            do {
                let decoded = try JSONDecoder().decode(ProductivityDocument.self, from: Data(contentsOf: self.url))
                guard decoded.version == 1 else { throw CocoaError(.coderReadCorrupt) }
                document = decoded
            } catch { readable = false; self.error = error.localizedDescription }
        }
    }

    @discardableResult func update(_ change: (inout ProductivityDocument) -> Void) -> Bool {
        guard readable else { return false }
        var next = document; change(&next)
        do {
            let folder = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try JSONEncoder().encode(next).write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            document = next; error = nil; return true
        } catch { self.error = error.localizedDescription; return false }
    }

    static func dayKey(_ date: Date = .now, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    var todayTasks: [DailyTask] { document.tasks.filter { $0.day == Self.dayKey() } }

    @discardableResult func addTask(_ text: String) -> Bool {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, todayTasks.count < 3 else { return false }
        return update { $0.tasks.append(DailyTask(day: Self.dayKey(), text: String(clean.prefix(300)))) }
    }

    func toggleTask(_ id: UUID) { update { doc in if let i = doc.tasks.firstIndex(where: { $0.id == id }) { doc.tasks[i].done.toggle() } } }
    func removeTask(_ id: UUID) { update { $0.tasks.removeAll { $0.id == id } } }

    @discardableResult func saveSnippet(_ text: String, sourceAppName: String? = nil) -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.utf8.count <= 100_000,
              document.snippets.count < 100 || document.snippets.contains(where: { $0.text == text }) else { return false }
        return update { doc in
            if let index = doc.snippets.firstIndex(where: { $0.text == text }) {
                var existing = doc.snippets.remove(at: index)
                existing.date = .now
                if let sourceAppName { existing.sourceAppName = String(sourceAppName.prefix(100)) }
                doc.snippets.insert(existing, at: 0)
            } else {
                doc.snippets.insert(SavedSnippet(text: text, sourceAppName: sourceAppName.map { String($0.prefix(100)) }), at: 0)
            }
            // Refuse automatic eviction of personal snippets; the user can remove them explicitly.
        }
    }

    func toggleSnippetFavorite(_ id: UUID) {
        update { doc in
            if let index = doc.snippets.firstIndex(where: { $0.id == id }) {
                doc.snippets[index].isFavorite = !(doc.snippets[index].isFavorite ?? false)
            }
        }
    }

    func filteredSnippets(query: String, kind: ClipboardKind = .all, favoritesOnly: Bool = false, oldestFirst: Bool = false) -> [SavedSnippet] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = document.snippets.filter { item in
            (trimmed.isEmpty || item.text.localizedCaseInsensitiveContains(trimmed) || item.sourceAppName?.localizedCaseInsensitiveContains(trimmed) == true)
                && (kind == .all || item.clipboardKind == kind)
                && (!favoritesOnly || item.isFavorite == true)
        }.sorted { oldestFirst ? $0.date < $1.date : $0.date > $1.date }
        return matches.filter { $0.isFavorite == true } + matches.filter { $0.isFavorite != true }
    }

    @discardableResult func removeUnstarredSnippets() -> Bool {
        update { $0.snippets.removeAll { $0.isFavorite != true } }
    }

    @discardableResult func captureFromPasteboard(_ pasteboard: NSPasteboard = .general, sourceAppName: String? = nil) -> Bool {
        let concealedTypes = [
            "org.nspasteboard.ConcealedType",
            "org.nspasteboard.TransientType",
            "org.nspasteboard.AutoGeneratedType"
        ]
        let isConcealed = pasteboard.types?.contains { concealedTypes.contains($0.rawValue) } ?? false
        guard !isConcealed, let text = pasteboard.string(forType: .string) else { return false }
        return saveSnippet(text, sourceAppName: sourceAppName)
    }
}
