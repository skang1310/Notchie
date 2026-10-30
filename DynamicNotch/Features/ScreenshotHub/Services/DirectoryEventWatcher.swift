import Foundation
import Darwin

@MainActor
final class DirectoryEventWatcher {
    private var sources: [String: DispatchSourceFileSystemObject] = [:]
    private var identities: [String: UInt64] = [:]
    var onChange: (() -> Void)?
    var watchedCount: Int { sources.count }
    func update(_ directories: [URL]) {
        let paths = Set(directories.map { $0.standardizedFileURL.path })
        for path in Array(sources.keys) where !paths.contains(path) { remove(path) }
        for path in paths {
            let inode = (try? FileManager.default.attributesOfItem(atPath: path)[.systemFileNumber] as? NSNumber)?.uint64Value
            if identities[path] != inode { remove(path) }
            guard sources[path] == nil, let inode else { continue }
            let descriptor = open(path, O_EVTONLY)
            guard descriptor >= 0 else { continue }
            let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor,
                eventMask: [.write, .extend, .attrib, .rename, .delete, .revoke], queue: .main)
            source.setEventHandler { [weak self] in
                Task { @MainActor [weak self] in self?.onChange?() }
            }
            source.setCancelHandler { close(descriptor) }
            sources[path] = source; identities[path] = inode
            source.resume()
        }
    }
    private func remove(_ path: String) { sources.removeValue(forKey: path)?.cancel(); identities.removeValue(forKey: path) }
    func stop() { for path in Array(sources.keys) { remove(path) } }
    deinit { for source in sources.values { source.cancel() } }
}
