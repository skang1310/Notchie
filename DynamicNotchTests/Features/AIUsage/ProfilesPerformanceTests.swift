import XCTest
import ImageIO
import UniformTypeIdentifiers
@testable import DynamicNotch

@MainActor
final class ProfilesPerformanceTests: XCTestCase {
    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    func testQuotaSettingsPersistWithoutEnablingWarningsByDefault() throws {
        let suite = "AISettingsTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite)); defer { defaults.removePersistentDomain(forName: suite) }
        let first = AIUsagePreferences(defaults: defaults)
        XCTAssertFalse(first.alertsEnabled); XCTAssertEqual(first.threshold, 90); XCTAssertTrue(first.countdownEnabled)
        first.alertsEnabled = true; first.threshold = 80; first.countdownEnabled = false
        let next = AIUsagePreferences(defaults: defaults)
        XCTAssertTrue(next.alertsEnabled); XCTAssertEqual(next.threshold, 80); XCTAssertFalse(next.countdownEnabled)
    }
    func testWarningDeduplicationHysteresisAndExpiredData() {
        let now = Date()
        func summary(_ used: Double, reset: Date? = nil, updated: Date? = nil) -> AIProviderUsageSummary {
            AIProviderUsageSummary(provider: .claudeCode,
                primaryWindow: AIQuotaWindow(id: "session", title: "Session", titleKo: "세션", utilization: used,
                    resetsAt: reset ?? now.addingTimeInterval(3600)), activeModel: "local", quotaRecordedAt: updated ?? now, lastUpdated: updated ?? now)
        }
        var gate = AIQuotaAlertGate()
        XCTAssertTrue(gate.evaluate(summary(89), threshold: 90, now: now).isEmpty)
        XCTAssertEqual(gate.evaluate(summary(90), threshold: 90, now: now).count, 1)
        XCTAssertTrue(gate.evaluate(summary(95), threshold: 90, now: now).isEmpty)
        XCTAssertTrue(gate.evaluate(summary(87), threshold: 90, now: now).isEmpty)
        XCTAssertTrue(gate.evaluate(summary(95), threshold: 90, now: now).isEmpty)
        _ = gate.evaluate(summary(0, reset: now), threshold: 90, now: now)
        XCTAssertEqual(gate.evaluate(summary(95), threshold: 90, now: now).count, 1)
        var fresh = AIQuotaAlertGate()
        XCTAssertTrue(fresh.evaluate(summary(99, reset: now.addingTimeInterval(-1)), threshold: 90, now: now).isEmpty)
        XCTAssertTrue(fresh.evaluate(summary(99, updated: now.addingTimeInterval(-1800)), threshold: 90, now: now).isEmpty)
        XCTAssertEqual(fresh.evaluate(summary(99), threshold: 90, now: now).count, 1)
    }
    func testStreamingAcrossBlocksUnicodeAndIncompleteAppend() throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("log.jsonl")
        let longText = String(repeating: "한글🙂", count: 25_000)
        let json = try JSONSerialization.data(withJSONObject: ["type": "user", "content": longText])
        var input = json; input.append(contentsOf: [13, 10]); input.append(Data("{\"type\":\"user\",\"content\":\"tail".utf8))
        try input.write(to: url)
        let reader = AIUsageLogReader()
        let first = reader.records(url)
        XCTAssertEqual(first.count, 1); XCTAssertEqual(first.first?.text, String(longText.prefix(512)))
        let file = try FileHandle(forWritingTo: url); try file.seekToEnd(); try file.write(contentsOf: Data("\"}\n".utf8)); try file.close()
        XCTAssertEqual(reader.records(url).map(\.text).last, "tail")
    }
    func testUnchangedFilesReuseParseAndReplacementsInvalidateCache() throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("log.jsonl")
        try Data("{\"display\":\"first\"}\n".utf8).write(to: url)
        let reader = AIUsageLogReader()
        for _ in 0..<20 { XCTAssertEqual(reader.records(url).first?.text, "first") }
        XCTAssertEqual(reader.diskReadCount, 1)
        try Data("{\"display\":\"other\"}\n".utf8).write(to: url, options: .atomic)
        XCTAssertEqual(reader.records(url).first?.text, "other"); XCTAssertEqual(reader.diskReadCount, 2)
    }
    func testOversizeLineDoesNotSwallowNextValidRecord() throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("log.jsonl")
        var bytes = Data(repeating: 97, count: JSONLStream.maximumLineBytes + 1)
        bytes.append(Data("\n{\"display\":\"valid\"}\n".utf8)); try bytes.write(to: url)
        XCTAssertEqual(AIUsageLogReader().records(url).map(\.text), ["valid"])
    }
    func testDirectoryWatcherSeesWritesAndRebindsReplacement() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let watched = root.appendingPathComponent("watched")
        try FileManager.default.createDirectory(at: watched, withIntermediateDirectories: true)
        let watcher = DirectoryEventWatcher(); defer { watcher.stop() }
        let first = expectation(description: "directory write")
        watcher.onChange = { first.fulfill() }
        watcher.update([watched]); XCTAssertEqual(watcher.watchedCount, 1)
        try Data("one".utf8).write(to: watched.appendingPathComponent("one.png"))
        await fulfillment(of: [first], timeout: 3)
        watcher.onChange = nil
        watcher.stop()
        try FileManager.default.moveItem(at: watched, to: root.appendingPathComponent("old"))
        try FileManager.default.createDirectory(at: watched, withIntermediateDirectories: true)
        watcher.update([watched])
        let second = expectation(description: "replacement directory write")
        watcher.onChange = { second.fulfill() }
        try Data("two".utf8).write(to: watched.appendingPathComponent("two.png"))
        await fulfillment(of: [second], timeout: 3)
        watcher.stop(); XCTAssertEqual(watcher.watchedCount, 0)
    }
}
