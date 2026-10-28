import Foundation
import Combine

@MainActor
final class SupportCaseStore: ObservableObject {
    static let shared = SupportCaseStore()
    @Published private(set) var document = SupportCasesDocument()
    @Published var selected: UUID?
    @Published private(set) var busy = false
    @Published private(set) var message = ""
    let root: URL
    private var readable = true
    private var importFailures = 0
    init(root: URL? = nil) {
        self.root = root ?? (AppEnvironment.isRunningTests
            ? FileManager.default.temporaryDirectory.appendingPathComponent("DynamicNotch-support-tests-\(ProcessInfo.processInfo.processIdentifier)")
            : FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("DynamicNotch/SupportCases"))
        let url = self.root.appendingPathComponent("cases.json")
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let bytes = try Data(contentsOf: url)
                guard bytes.count <= 25 * 1024 * 1024 else { throw SupportToolError.limit }
                let loaded = try JSONDecoder().decode(SupportCasesDocument.self, from: bytes)
                guard loaded.version == 1, loaded.cases.allSatisfy({ c in c.screenshots.count <= 200 && c.screenshots.allSatisfy { shot in
                    shot.file == URL(fileURLWithPath: shot.file).lastPathComponent && !shot.file.contains("..") && shot.width > 0 && shot.height > 0 && shot.width <= 20_000 && shot.height <= 20_000 && shot.redactions.allSatisfy(\.valid)
                } }) else { throw SupportToolError.invalid }
                document = loaded
            } catch { readable = false; message = error.localizedDescription }
        }
        selected = document.cases.last?.id
    }
    var current: SupportCase? { document.cases.first { $0.id == selected } }
    func file(_ screenshot: SupportScreenshot) -> URL { root.appendingPathComponent("images").appendingPathComponent(screenshot.file) }
    @discardableResult func newCase(title: String) -> UUID? {
        var next = document; let item = SupportCase(title: String(title.prefix(200)))
        next.cases.append(item)
        guard commit(next) else { return nil }; selected = item.id; return item.id
    }
    @discardableResult func update(_ id: UUID, change: (inout SupportCase) -> Void) -> Bool {
        var next = document; guard let i = next.cases.firstIndex(where: { $0.id == id }) else { return false }
        change(&next.cases[i]); return commit(next)
    }
    @discardableResult private func commit(_ next: SupportCasesDocument) -> Bool {
        guard readable else { return false }
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions:0o700])
            let url = root.appendingPathComponent("cases.json")
            let data = try JSONEncoder().encode(next)
            guard data.count <= 25 * 1024 * 1024 else { throw SupportToolError.limit }
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions:0o600], ofItemAtPath: url.path)
            document = next; return true
        } catch { message = error.localizedDescription; return false }
    }
    func importFiles(_ urls: [URL], ownedStaging: [URL] = []) {
        guard !busy, !urls.isEmpty, readable else { return }
        guard urls.count <= 200 else { message = SupportToolError.limit.localizedDescription; return }
        if selected == nil { _ = newCase(title: Bundle.main.localizedString(forKey:"support.case.untitled",value:"New report comparison",table:nil)) }
        guard let target = selected else { return }
        busy = true; importFailures = 0
        Task {
            for url in urls.prefix(200) {
                do {
                    let loaded = try await Task.detached { try SupportImages.load(url) }.value
                    try accept(loaded, caseID: target)
                } catch { importFailures += 1; message = error.localizedDescription }
            }
            if importFailures == 0 { message = Bundle.main.localizedString(forKey:"support.case.imported",value:"Import complete",table:nil) }
            for url in ownedStaging where url.deletingLastPathComponent().standardizedFileURL == root.appendingPathComponent("staging").standardizedFileURL {
                try? FileManager.default.removeItem(at: url)
            }
            busy = false
        }
    }
    /// Exposed internally for deterministic persistence/dedup tests; always preserves source files.
    func accept(_ loaded: SupportImages.Loaded, caseID: UUID) throws {
        guard let item = document.cases.first(where: { $0.id == caseID }), readable else { throw SupportToolError.invalid }
        if item.screenshots.contains(where: { $0.digest == loaded.digest }) { return }
        guard item.screenshots.count < 200 else { throw SupportToolError.limit }
        let folder = root.appendingPathComponent("images")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions:0o700])
        let shot = SupportScreenshot(file: UUID().uuidString + "." + loaded.suffix, digest: loaded.digest, capturedAt: loaded.date, width: loaded.width, height: loaded.height)
        let target = folder.appendingPathComponent(shot.file)
        try loaded.bytes.write(to: target, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions:0o600], ofItemAtPath: target.path)
        guard update(caseID, change: { $0.screenshots.append(shot) }) else { try? FileManager.default.removeItem(at: target); throw SupportToolError.invalid }
    }
    func export(_ id: UUID, to destination: URL) async throws -> URL {
        guard let item = document.cases.first(where: { $0.id == id }) else { throw SupportToolError.invalid }
        let sourceRoot = root
        return try await Task.detached {
            let fm = FileManager.default
            let folder = destination.appendingPathComponent("Support-Evidence-" + UUID().uuidString.prefix(8))
            try fm.createDirectory(at: folder.appendingPathComponent("images"), withIntermediateDirectories: true, attributes: [.posixPermissions:0o700])
            do {
                for (i, shot) in item.screenshots.enumerated() {
                    let url = sourceRoot.appendingPathComponent("images").appendingPathComponent(shot.file)
                    let output = try SupportImages.png(url: url, maxPixel: max(shot.width, shot.height), redactions: shot.redactions)
                    try output.write(to: folder.appendingPathComponent("images/\(i+1).png"), options: .atomic)
                }
                try SupportImages.markdown(item).write(to: folder.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
                return folder
            } catch { try? fm.removeItem(at: folder); throw error }
        }.value
    }
}
