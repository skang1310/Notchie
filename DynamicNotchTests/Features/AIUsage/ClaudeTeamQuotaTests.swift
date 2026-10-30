import XCTest
@testable import DynamicNotch

@MainActor
final class ClaudeTeamQuotaTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!; return calendar
    }
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 11, minute: 30))! }
    private func elements(team: Bool = true) -> [ClaudeUsageElement] {
        [.init(label: team ? "사용 한도 팀" : "사용 한도 Pro"), .init(label: "현재 세션"),
         .init(label: "오후 1:50에 초기화"), .init(label: "현재 세션", value: 18), .init(label: "18% 사용됨"),
         .init(label: "주간 한도"), .init(label: "모든 모델"), .init(label: "(목) 오전 11:00에 초기화"),
         .init(label: "모든 모델", value: 12)]
    }
    func testTeamPersonalPercentagesAndDisplayedResetDates() throws {
        let quota = try XCTUnwrap(ClaudeTeamQuotaReader.parse(elements: elements(), now: now, calendar: calendar))
        XCTAssertEqual(quota.primary.utilization, 18); XCTAssertEqual(quota.primary.remainingPercentage, 82)
        XCTAssertEqual(quota.secondary?.remainingPercentage, 88)
        XCTAssertEqual(quota.plan, "Team · Personal")
        let primary = calendar.dateComponents([.year,.month,.day,.hour,.minute], from: quota.primary.resetsAt)
        XCTAssertEqual(primary.day, 30); XCTAssertEqual(primary.hour, 13); XCTAssertEqual(primary.minute, 50)
        let secondary = calendar.dateComponents([.month,.day,.hour], from: try XCTUnwrap(quota.secondary?.resetsAt))
        XCTAssertEqual(secondary.month, 11); XCTAssertEqual(secondary.day, 5); XCTAssertEqual(secondary.hour, 11)
        let summary = AIUsageService.computeClaudeSummary(stats: nil, history: [], now: now, quota: quota)
        XCTAssertTrue(summary.hasRecordedQuota); XCTAssertEqual(summary.tierBadge, "Team")
    }
    func testRejectsPersonalPlanOtherWebPagesAndInvalidPercentages() {
        XCTAssertNil(ClaudeTeamQuotaReader.parse(elements: elements(team: false), now: now, calendar: calendar))
        var invalid = elements(); invalid[3] = .init(label: "현재 세션", value: 150)
        XCTAssertNil(ClaudeTeamQuotaReader.parse(elements: invalid, now: now, calendar: calendar))
        XCTAssertTrue(ClaudeTeamQuotaReader.isUsageURL(URL(string: "https://claude.ai/new#settings/usage")!))
        XCTAssertTrue(ClaudeTeamQuotaReader.isUsageURL(URL(string: "https://claude.ai/settings/usage")!))
        for url in ["https://claude.ai/new", "https://evil.test/settings/usage", "http://claude.ai/settings/usage", "https://claude.ai/new#settings/general"] {
            XCTAssertFalse(ClaudeTeamQuotaReader.isUsageURL(URL(string: url)!))
        }
    }
    func testExpiredSessionTimeCannotBecomeTomorrowReset() {
        let afterReset = calendar.date(byAdding: .hour, value: 3, to: now)!
        XCTAssertNil(ClaudeTeamQuotaReader.parse(elements: elements(), now: afterReset, calendar: calendar))
        XCTAssertNil(ClaudeTeamQuotaReader.resetDate("초기화 시간 없음", now: now, calendar: calendar))
        XCTAssertNil(ClaudeTeamQuotaReader.resetDate("Resets 99:99 PM", now: now, calendar: calendar))
    }
    func testEnglishTeamUsageAndAbsentWeeklyWindow() throws {
        let rows: [ClaudeUsageElement] = [.init(label: "Usage limits Team"), .init(label: "Resets 1:50 PM"),
            .init(label: "Current session", value: 0)]
        let quota = try XCTUnwrap(ClaudeTeamQuotaReader.parse(elements: rows, now: now, calendar: calendar))
        XCTAssertEqual(quota.primary.remainingPercentage, 100); XCTAssertNil(quota.secondary)
    }
    func testObservedPageLayoutWithSeparateTeamBadgeAndTextPercent() throws {
        // Layout observed on claude.ai settings > usage (2026-10-30): heading and 팀 badge are separate,
        // the bar carries an unlabeled value and the percentage is a sibling text.
        let rows: [ClaudeUsageElement] = [.init(label: "Session tips 현재 세션 정리"), .init(label: "사용 한도"), .init(label: "팀"),
            .init(label: "현재 세션"), .init(label: "오후 1:50에 초기화"), .init(label: "", value: 42), .init(label: "42% 사용됨"),
            .init(label: "주간 한도"), .init(label: "사용량 제한에 대해 더 알아보기"), .init(label: "모든 모델"),
            .init(label: "(목) 오전 11:00에 초기화"), .init(label: "16% 사용됨"), .init(label: "제한 초기화"), .init(label: "현재 초기화 없음")]
        let quota = try XCTUnwrap(ClaudeTeamQuotaReader.parse(elements: Array(rows.dropFirst()), now: now, calendar: calendar))
        XCTAssertEqual(quota.primary.remainingPercentage, 58); XCTAssertEqual(quota.secondary?.remainingPercentage, 84)
        XCTAssertEqual(calendar.component(.hour, from: quota.primary.resetsAt), 13)
        XCTAssertEqual(calendar.component(.weekday, from: try XCTUnwrap(quota.secondary?.resetsAt)), 5)
        XCTAssertEqual(ClaudeTeamQuotaReader.percentUsed("42% used"), 42)
        XCTAssertNil(ClaudeTeamQuotaReader.percentUsed("142% 사용됨"))
        XCTAssertNil(ClaudeTeamQuotaReader.percentUsed("사용량 제한에 대해 더 알아보기"))
        // A personal (non-Team) page with the same rows must not be accepted.
        var personal = Array(rows.dropFirst()); personal[1] = .init(label: "Pro")
        XCTAssertNil(ClaudeTeamQuotaReader.parse(elements: personal, now: now, calendar: calendar))
    }
    func testConnectionIsOptInAndSnapshotPersistsWithoutCredentials() throws {
        let suite = "ClaudeTeamTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite)); defer { defaults.removePersistentDomain(forName: suite) }
        let connection = ClaudeTeamConnection(defaults: defaults)
        let quota = try XCTUnwrap(ClaudeTeamQuotaReader.parse(elements: elements(), now: now, calendar: calendar))
        XCTAssertFalse(connection.enabled); connection.save(quota); XCTAssertNil(connection.snapshot)
        connection.enabled = true; connection.save(quota)
        let restored = ClaudeTeamConnection(defaults: defaults)
        XCTAssertTrue(restored.enabled); XCTAssertEqual(restored.snapshot?.primary.utilization, 18)
        restored.enabled = false
        XCTAssertFalse(ClaudeTeamConnection(defaults: defaults).enabled)
        let data = try XCTUnwrap(defaults.data(forKey: "aiUsage.claudeTeam.snapshot"))
        let payload = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(payload.contains("token")); XCTAssertFalse(payload.contains("cookie"))
    }
}
