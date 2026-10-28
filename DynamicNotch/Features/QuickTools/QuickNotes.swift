import Foundation
import Combine

struct QuickNote: Identifiable, Codable, Equatable, Sendable {
    var id: UUID = UUID()
    var text: String
    var pinned = false
    var updatedAt: Date = .now
    var title: String { String(text.split(separator: "\n").first.map(String.init)?.prefix(60) ?? "Untitled".prefix(60)) }
}
@MainActor
final class QuickNotes: ObservableObject {
    @Published private(set) var notes: [QuickNote] = []
    @Published private(set) var error: String?
    @Published var query = ""
    @Published var draft = ""
    @Published private(set) var editingID: UUID?
    private var readable = false
    private let file: URL
    struct Document: Codable { var version = 1; var notes: [QuickNote] }
    init(file: URL? = nil) {
        self.file = file ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DynamicNotch", isDirectory: true).appendingPathComponent("quick-notes.json")
        load()
    }
    var hasUnsavedChanges: Bool {
        if let editingID, let note = notes.first(where: { $0.id == editingID }) { return note.text != draft }
        return !draft.isEmpty
    }
    var filtered: [QuickNote] {
        notes.filter { query.isEmpty || $0.text.localizedStandardContains(query) }.sorted {
            if $0.pinned != $1.pinned { return $0.pinned }
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
    func load() {
        do {
            if FileManager.default.fileExists(atPath: file.path) {
                let document = try JSONDecoder().decode(Document.self, from: Data(contentsOf: file))
                guard document.version == 1 else { throw CocoaError(.fileReadCorruptFile) }
                notes = document.notes
            } else { notes = [] }
            readable = true
            error = nil
        } catch {
            readable = false
            self.error = "Could not read notes. Original file preserved: " + error.localizedDescription
        }
    }
    func edit(_ note: QuickNote?) { editingID = note?.id; draft = note?.text ?? "" }
    @discardableResult
    func saveDraft() -> Bool {
        guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        var candidate = notes
        let id: UUID
        if let editingID, let index = candidate.firstIndex(where: { $0.id == editingID }) {
            candidate[index].text = draft
            candidate[index].updatedAt = .now
            id = editingID
        } else {
            let note = QuickNote(text: draft)
            candidate.append(note)
            id = note.id
        }
        guard persist(candidate) else { return false }
        editingID = id
        return true
    }
    func togglePin(_ id: UUID) {
        var candidate = notes
        guard let index = candidate.firstIndex(where: { $0.id == id }) else { return }
        candidate[index].pinned.toggle()
        _ = persist(candidate)
    }
    private func persist(_ candidate: [QuickNote]) -> Bool {
        guard readable else { return false }
        do {
            let directory = file.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let data = try JSONEncoder().encode(Document(notes: candidate))
            try data.write(to: file, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
            notes = candidate
            error = nil
            return true
        } catch {
            self.error = "Could not save notes: " + error.localizedDescription
            return false
        }
    }
}
