import Foundation
import Combine
import Darwin

@MainActor
final class SupportFolderWatcher: ObservableObject {
    @Published private(set) var folder: URL?
    @Published private(set) var running = false
    private let store: SupportCaseStore
    init(store: SupportCaseStore? = nil) { self.store = store ?? .shared }
    private var source: DispatchSourceFileSystemObject?
    private var scope: URL?
    private var known = Set<String>()
    private var pending: Task<Void,Never>?
    func start(_ url: URL) throws {
        stop()
        let active = url.startAccessingSecurityScopedResource()
        let baseline: [URL]
        do { baseline = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) }
        catch { if active { url.stopAccessingSecurityScopedResource() }; throw error }
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { if active { url.stopAccessingSecurityScopedResource() }; throw SupportToolError.invalid }
        scope = active ? url : nil; folder = url; running = true
        known = Set(baseline.map(\.lastPathComponent))
        let watcher = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write,.rename,.delete], queue: DispatchQueue.global(qos: .utility))
        watcher.setEventHandler { @Sendable [weak self] in Task { @MainActor [weak self] in self?.scheduleScan() } }
        watcher.setCancelHandler { @Sendable in close(fd) }
        source = watcher; watcher.resume()
    }
    private func scheduleScan() {
        pending?.cancel()
        pending = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(700)) } catch { return }
            guard let self, self.running, let folder = self.folder else { return }
            if self.store.busy { self.scheduleScan(); return }
            guard let urls = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { return }
            let fresh = urls.filter { !self.known.contains($0.lastPathComponent) && ["png","jpg","jpeg","heic","tif","tiff"].contains($0.pathExtension.lowercased()) }
            self.known.formUnion(fresh.map(\.lastPathComponent))
            self.store.importFiles(fresh)
        }
    }
    func stop() {
        pending?.cancel(); pending = nil
        source?.cancel(); source = nil
        scope?.stopAccessingSecurityScopedResource(); scope = nil
        running = false; folder = nil; known.removeAll()
    }
}
