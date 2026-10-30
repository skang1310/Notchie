import Foundation
import Combine
internal import AppKit

struct SavedSnippet: Codable, Identifiable {
    var id = UUID()
    var text: String
    var date = Date()
    var isFavorite: Bool? = nil
    var sourceAppName: String? = nil

    init(id: UUID = UUID(), text: String, date: Date = Date(), isFavorite: Bool? = nil, sourceAppName: String? = nil) {
        self.id = id
        self.text = text
        self.date = date
        self.isFavorite = isFavorite
        self.sourceAppName = sourceAppName
    }
}

struct ProductivityDocument: Codable {
    var version = 1
    var snippets: [SavedSnippet] = []

    // Preserved for backwards compatibility when decoding existing user documents
    private var focusHistory: [String]? = nil
    private var tasks: [String]? = nil
    private var hiddenBundleIDs: [String]? = nil

    init(version: Int = 1, snippets: [SavedSnippet] = []) {
        self.version = version
        self.snippets = snippets
    }

    private enum CodingKeys: String, CodingKey {
        case version, snippets, focusHistory, tasks, hiddenBundleIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        self.snippets = try container.decodeIfPresent([SavedSnippet].self, forKey: .snippets) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(snippets, forKey: .snippets)
    }
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
