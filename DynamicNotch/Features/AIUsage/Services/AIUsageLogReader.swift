import Foundation

/// Bounded input buffer; complete JSON records can span multiple read blocks.
nonisolated enum JSONLStream {
    static let maximumLineBytes = 4 * 1024 * 1024
    static func read(_ url: URL, consume: (Data) -> Void) throws {
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        var pending = Data()
        var skippingOversizeLine = false
        while let block = try file.read(upToCount: 64 * 1024), !block.isEmpty {
            var start = block.startIndex
            while start < block.endIndex {
                let newline = block[start...].firstIndex(of: 10)
                let end = newline ?? block.endIndex
                if !skippingOversizeLine {
                    if pending.count + end - start <= maximumLineBytes {
                        pending.append(contentsOf: block[start..<end])
                    } else {
                        pending.removeAll(keepingCapacity: false)
                        skippingOversizeLine = true
                    }
                }
                if let newline {
                    if !skippingOversizeLine, !pending.isEmpty { consume(pending) }
                    pending.removeAll(keepingCapacity: true)
                    skippingOversizeLine = false
                    start = newline + 1
                } else { break }
            }
        }
        if !skippingOversizeLine, !pending.isEmpty { consume(pending) }
    }
}

nonisolated struct AIUsageLogRecord: Sendable {
    let type: String
    let date: String
    let milliseconds: Double
    let text: String
    let project: String
    let id: String
    let model: String
}

nonisolated final class AIUsageLogReader: @unchecked Sendable {
    static let shared = AIUsageLogReader()
    private final class Entry: NSObject {
        let records: [AIUsageLogRecord]
        init(_ records: [AIUsageLogRecord]) { self.records = records }
    }
    private let metricsLock = NSLock()
    private var diskReads = 0
    var diskReadCount: Int { metricsLock.lock(); defer { metricsLock.unlock() }; return diskReads }
    private let cache = NSCache<NSString, Entry>()
    init() { cache.countLimit = 128; cache.totalCostLimit = 8 * 1024 * 1024 }
    private func signature(_ url: URL) -> String? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size], let date = attrs[.modificationDate] as? Date,
              let inode = attrs[.systemFileNumber] else { return nil }
        return "\(url.path)|\(inode)|\(size)|\(date.timeIntervalSince1970)"
    }
    func records(_ url: URL, tail: Int? = nil) -> [AIUsageLogRecord] {
        let before = signature(url)
        let key = before.map { "\($0)|\(tail ?? -1)" as NSString }
        if let key, let hit = cache.object(forKey: key) { return hit.records }
        metricsLock.lock(); diskReads += 1; metricsLock.unlock()
        var rows: [AIUsageLogRecord] = []
        var hasModel = false
        do {
            try JSONLStream.read(url) { data in
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
                let type = json["type"] as? String ?? ""
                guard type.isEmpty || ["user", "assistant", "USER_INPUT"].contains(type) else { return }
                let message = json["message"] as? [String: Any]
                let model = message?["model"] as? String ?? ""
                if type == "assistant" {
                    guard !hasModel, !model.isEmpty else { return }
                    hasModel = true
                }
                let text = message?["content"] as? String ?? json["content"] as? String ?? json["display"] as? String ?? json["thread_name"] as? String ?? ""
                let row = AIUsageLogRecord(type: type,
                    date: json["timestamp"] as? String ?? json["created_at"] as? String ?? json["updated_at"] as? String ?? "",
                    milliseconds: json["timestamp"] as? Double ?? 0,
                    text: String(text.prefix(512)),
                    project: json["cwd"] as? String ?? json["project"] as? String ?? "",
                    id: json["sessionId"] as? String ?? json["id"] as? String ?? "",
                    model: model)
                rows.append(row)
                if let tail, rows.count > tail { rows.removeFirst(rows.count - tail) }
            }
        } catch { return [] }
        if let key, before == signature(url) {
            let cost = rows.reduce(0) { $0 + $1.text.utf8.count + $1.project.utf8.count + 256 }
            if cost <= 8 * 1024 * 1024 { cache.setObject(Entry(rows), forKey: key, cost: cost) }
        }
        return rows
    }
}
