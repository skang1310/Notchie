import XCTest
@testable import DynamicNotch

@MainActor
final class SystemUsageQuotaTests: XCTestCase {
    private func fixture(used: Double = 31, secondary: Double = 68, recorded: Date = .now, reset: Date? = nil) throws -> Data {
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return try JSONSerialization.data(withJSONObject: ["type": "event_msg", "timestamp": formatter.string(from: recorded),
            "payload": ["type": "token_count", "rate_limits": ["limit_id": "codex", "plan_type": "plus",
                "primary": ["used_percent": used, "window_minutes": 300, "resets_at": (reset ?? recorded.addingTimeInterval(3600)).timeIntervalSince1970],
                "secondary": ["used_percent": secondary, "window_minutes": 10080, "resets_at": recorded.addingTimeInterval(86400).timeIntervalSince1970]]]])
    }
    func testProviderQuotaUsesRecordedPercentAndWindowDuration() throws {
        let now = Date()
        let snapshot = try XCTUnwrap(RecordedAIQuota.parseCodex(fixture(recorded: now)))
        let summary = AIUsageService.computeCodexSummary(sessions: [], config: CodexConfigData(), now: now, quota: snapshot)
        XCTAssertTrue(summary.hasRecordedQuota); XCTAssertTrue(summary.isQuotaFresh(at: now))
        XCTAssertEqual(summary.primaryWindow.utilization, 31)
        XCTAssertEqual(summary.secondaryWindow?.utilization, 68)
        XCTAssertEqual(summary.primaryWindow.titleKo, "5시간 한도")
        XCTAssertEqual(summary.secondaryWindow?.titleKo, "주간 한도")
        XCTAssertEqual(summary.tierBadge, "plus")
        XCTAssertEqual(summary.primaryWindow.resetsAt.timeIntervalSince1970, now.addingTimeInterval(3600).timeIntervalSince1970, accuracy: 0.01)
    }
    func testNoInventedQuotasEvenWithManySessionsOrGenericLimitError() {
        let now = Date()
        let claude = (0..<200).map { ClaudeHistoryEntry(display: "prompt", timestamp: now, project: "project", sessionId: "\($0)") }
        let codex = (0..<100).map { CodexSessionEntry(id: "\($0)", threadName: "session", updatedAt: now) }
        let gemini = (0..<100).map { GeminiSessionEntry(id: "\($0)", title: "session", stepCount: 1000, lastModified: now) }
        let summaries = [AIUsageService.computeClaudeSummary(stats: nil, history: claude, now: now),
            AIUsageService.computeCodexSummary(sessions: codex,
                config: CodexConfigData(isRateLimited: true, rateLimitResetsAt: now.addingTimeInterval(1000)), now: now),
            AIUsageService.computeGeminiSummary(sessions: gemini, modelName: "unknown", now: now)]
        var gate = AIQuotaAlertGate()
        for summary in summaries {
            XCTAssertFalse(summary.hasRecordedQuota); XCTAssertNil(summary.secondaryWindow); XCTAssertEqual(summary.tierBadge, "—")
            XCTAssertTrue(gate.evaluate(summary, threshold: 70, now: now).isEmpty)
        }
    }
    func testOldQuotaKeepsOriginalRecordTimeAndCannotNotify() throws {
        let now = Date()
        let snapshot = try XCTUnwrap(RecordedAIQuota.parseCodex(fixture(used: 99, recorded: now.addingTimeInterval(-3600))))
        let summary = AIUsageService.computeCodexSummary(sessions: [], config: CodexConfigData(), now: now, quota: snapshot)
        XCTAssertFalse(summary.isQuotaFresh(at: now)); XCTAssertNotEqual(summary.quotaRecordedAt, summary.lastUpdated)
        var gate = AIQuotaAlertGate()
        XCTAssertTrue(gate.evaluate(summary, threshold: 90, now: now).isEmpty)
        XCTAssertNil(RecordedAIQuota.parseCodex(try fixture(used: 120)))
        XCTAssertNil(RecordedAIQuota.parseCodex(Data("{\"type\":\"message\",\"content\":\"rate_limits\"}".utf8)))
    }
    func testQuotaReaderFindsLatestRecordAndInvalidatesChangedFile() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy/MM/dd"; formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let now = Date(), folder = root.appendingPathComponent("sessions/" + formatter.string(from: now))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("session.jsonl")
        try fixture(used: 20, recorded: now.addingTimeInterval(-60)).write(to: url)
        XCTAssertEqual(RecordedAIQuota.latestCodex(in: root, now: now)?.primary.utilization, 20)
        try fixture(used: 25, recorded: now).write(to: url, options: .atomic)
        XCTAssertEqual(RecordedAIQuota.latestCodex(in: root, now: now)?.primary.utilization, 25)
        // A second source with a later mtime but older record must not replace the newer quota.
        try fixture(used: 10, recorded: now.addingTimeInterval(-300)).write(to: folder.appendingPathComponent("other.jsonl"))
        XCTAssertEqual(RecordedAIQuota.latestCodex(in: root, now: now)?.primary.utilization, 25)
    }
    func testNetworkDeltasIgnoreNewDisconnectedAndResetInterfaces() throws {
        let old = ["en0": ShelfNetworkCounter(received: 1000, sent: 500)]
        let current = ["en0": ShelfNetworkCounter(received: 5000, sent: 1500), "en1": ShelfNetworkCounter(received: 999_999, sent: 999_999)]
        let rates = try XCTUnwrap(ShelfNetworkCounter.rates(current: current, previous: old, seconds: 2))
        XCTAssertEqual(rates.0, 2000); XCTAssertEqual(rates.1, 500)
        XCTAssertNil(ShelfNetworkCounter.rates(current: ["en0": ShelfNetworkCounter(received: 5, sent: 2)], previous: old, seconds: 2))
        XCTAssertNil(ShelfNetworkCounter.rates(current: current, previous: old, seconds: 0))
        XCTAssertEqual(ShelfSystemStats.rate(nil), "—")
    }
    func testSharedStatsSamplingSubscriptionsAndHostSnapshot() {
        let stats = ShelfSystemStats(), a = UUID(), b = UUID()
        stats.acquire(a); stats.acquire(b); XCTAssertEqual(stats.consumerCount, 2)
        stats.release(a); XCTAssertEqual(stats.consumerCount, 1)
        stats.release(b); XCTAssertEqual(stats.consumerCount, 0)
        stats.sample()
        XCTAssertGreaterThan(stats.totalMemoryBytes, 0)
        XCTAssertNotNil(stats.usedMemoryBytes)
        XCTAssertNil(stats.cpu, "The first CPU sample needs a baseline")
        stats.sample()
        if let used = stats.usedMemoryBytes { XCTAssertLessThanOrEqual(used, stats.totalMemoryBytes) }
        stats.acquire(a); stats.release(a); XCTAssertEqual(stats.consumerCount, 0)
    }
}
