import Foundation

nonisolated struct RecordedAIQuota: Codable, Sendable {
    let primary: AIQuotaWindow
    let secondary: AIQuotaWindow?
    let recordedAt: Date
    let plan: String?

    static func parseCodex(_ data: Data) -> Self? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              root["type"] as? String == "event_msg",
              let payload = root["payload"] as? [String: Any], payload["type"] as? String == "token_count",
              let limits = payload["rate_limits"] as? [String: Any],
              limits["limit_id"] == nil || limits["limit_id"] is NSNull || limits["limit_id"] as? String == "codex",
              let stamp = root["timestamp"] as? String,
              let date = ISO8601DateFormatter.withFractionalSeconds.date(from: stamp) ?? ISO8601DateFormatter().date(from: stamp),
              let primary = window(limits["primary"], id: "codex-primary") else { return nil }
        return Self(primary: primary, secondary: window(limits["secondary"], id: "codex-secondary"),
            recordedAt: date, plan: limits["plan_type"] as? String)
    }
    private static func window(_ value: Any?, id: String) -> AIQuotaWindow? {
        guard let json = value as? [String: Any],
              let used = json["used_percent"] as? Double, used.isFinite, (0...100).contains(used),
              let minutes = json["window_minutes"] as? Int, minutes > 0,
              let reset = json["resets_at"] as? Double, reset.isFinite, reset > 0 else { return nil }
        let en = minutes == 10080 ? "Weekly limit" : (minutes % 60 == 0 ? "\(minutes / 60)-hour limit" : "\(minutes)-minute limit")
        let ko = minutes == 10080 ? "주간 한도" : (minutes % 60 == 0 ? "\(minutes / 60)시간 한도" : "\(minutes)분 한도")
        return AIQuotaWindow(id: id, title: en, titleKo: ko, subtitle: "Recorded provider quota", subtitleKo: "서비스 한도 기록",
            utilization: used, resetsAt: Date(timeIntervalSince1970: reset))
    }
    static func latestCodex(in directory: URL, now: Date = .now) -> Self? {
        let fm = FileManager.default
        let calendar = Calendar(identifier: .gregorian)
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy/MM/dd"; formatter.timeZone = TimeZone(secondsFromGMT: 0)
        var files: [(URL, Date)] = []
        for offset in 0..<3 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: now),
                  let urls = try? fm.contentsOfDirectory(at: directory.appendingPathComponent("sessions/" + formatter.string(from: date)),
                    includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles) else { continue }
            for url in urls where url.pathExtension == "jsonl" {
                files.append((url, (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast))
            }
        }
        var latest: Self?
        for (url, _) in files.sorted(by: { $0.1 > $1.1 }).prefix(32) {
            guard let quota = RecordedQuotaFileCache.shared.read(url, now: now),
                  quota.recordedAt <= now.addingTimeInterval(60),
                  quota.recordedAt > (latest?.recordedAt ?? .distantPast) else { continue }
            latest = quota
        }
        return latest
    }
}

private extension ISO8601DateFormatter {
    static var withFractionalSeconds: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return formatter
    }
}

nonisolated private final class RecordedQuotaFileCache: @unchecked Sendable {
    static let shared = RecordedQuotaFileCache()
    private final class Entry: NSObject {
        let quota: RecordedAIQuota?
        init(_ quota: RecordedAIQuota?) { self.quota = quota }
    }
    private let cache = NSCache<NSString, Entry>()
    init() { cache.countLimit = 64 }
    private func key(_ url: URL) -> NSString? {
        guard let info = try? FileManager.default.attributesOfItem(atPath: url.path),
              let date = info[.modificationDate] as? Date else { return nil }
        return "\(url.path)|\(info[.systemFileNumber] ?? 0)|\(info[.size] ?? 0)|\(date.timeIntervalSince1970)" as NSString
    }
    func read(_ url: URL, now: Date) -> RecordedAIQuota? {
        guard let stamp = key(url) else { return nil }
        if let hit = cache.object(forKey: stamp) { return hit.quota }
        guard let file = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? file.close() }
        guard let size = try? file.seekToEnd() else { return nil }
        let offset = size > 1024 * 1024 ? size - 1024 * 1024 : 0
        var latest: RecordedAIQuota?
        do {
            try file.seek(toOffset: offset)
            guard let data = try file.read(upToCount: 1024 * 1024) else { return nil }
            for (index, line) in data.split(separator: 10).enumerated() {
                if offset > 0 && index == 0 { continue }
                guard line.range(of: Data("\"rate_limits\"".utf8)) != nil,
                      let quota = RecordedAIQuota.parseCodex(Data(line)), quota.recordedAt <= now.addingTimeInterval(60),
                      quota.recordedAt > (latest?.recordedAt ?? .distantPast) else { continue }
                latest = quota
            }
            if stamp == key(url) { cache.setObject(Entry(latest), forKey: stamp) }
        } catch { return nil }
        return latest
    }
}
