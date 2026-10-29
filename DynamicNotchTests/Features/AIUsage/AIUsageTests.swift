//
//  AIUsageTests.swift
//  DynamicNotchTests
//

import XCTest
import SwiftUI
@testable import DynamicNotch

@MainActor
final class AIUsageTests: XCTestCase {

    // MARK: - Claude Stats & Data Parsing Tests

    func testClaudeStatsDecodingAndAggregation() throws {
        let jsonString = """
        {
          "version": 2,
          "lastComputedDate": "2026-02-19",
          "dailyActivity": [
            {
              "date": "2026-02-10",
              "messageCount": 216,
              "sessionCount": 2,
              "toolCallCount": 83
            }
          ],
          "modelUsage": {
            "claude-opus-4-6": {
              "inputTokens": 10000,
              "outputTokens": 20000,
              "cacheReadInputTokens": 1000000,
              "cacheCreationInputTokens": 50000,
              "costUSD": 1.25
            },
            "claude-3-7-sonnet": {
              "inputTokens": 500,
              "outputTokens": 1000,
              "cacheReadInputTokens": 5000,
              "cacheCreationInputTokens": 0,
              "costUSD": 0.05
            }
          },
          "totalSessions": 10,
          "totalMessages": 2027,
          "firstSessionDate": "2026-02-10T09:52:09.510Z"
        }
        """

        let data = jsonString.data(using: .utf8)!
        let stats = try JSONDecoder().decode(ClaudeStatsData.self, from: data)

        XCTAssertEqual(stats.totalSessions, 10)
        XCTAssertEqual(stats.totalMessages, 2027)
        XCTAssertEqual(stats.lastComputedDate, "2026-02-19")
        XCTAssertEqual(stats.aggregatedInputTokens, 10500)
        XCTAssertEqual(stats.aggregatedOutputTokens, 21000)
        XCTAssertEqual(stats.aggregatedCacheTokens, 1055000)
        XCTAssertEqual(stats.aggregatedTotalTokens, 1086500)
        XCTAssertEqual(stats.formattedTokens, "1.1M")
        XCTAssertEqual(stats.primaryModelName, "claude-opus-4-6")
        XCTAssertEqual(stats.totalCostUSD, 1.30, accuracy: 0.001)
    }

    func testTokenFormatting() {
        XCTAssertEqual(ClaudeStatsData.formatTokenCount(450), "450")
        XCTAssertEqual(ClaudeStatsData.formatTokenCount(1200), "1.2K")
        XCTAssertEqual(ClaudeStatsData.formatTokenCount(95400), "95.4K")
        XCTAssertEqual(ClaudeStatsData.formatTokenCount(1500000), "1.5M")
        XCTAssertEqual(ClaudeStatsData.formatTokenCount(47700000), "47.7M")
    }

    func testClaudeHistoryEntry() {
        let entry = ClaudeHistoryEntry(
            id: "test-id",
            display: "Build a mac notch feature",
            timestamp: Date(timeIntervalSinceNow: -120),
            project: "/Users/developer/Projects/DynamicNotch",
            sessionId: "session-123"
        )

        XCTAssertEqual(entry.projectName, "DynamicNotch")
        XCTAssertFalse(entry.relativeTime.isEmpty)
    }

    func testCodexSessionAndConfigData() {
        let session = CodexSessionEntry(
            id: "codex-1",
            threadName: "DynamicNotch AI usage feature",
            updatedAt: Date(timeIntervalSinceNow: -60)
        )
        XCTAssertEqual(session.id, "codex-1")
        XCTAssertEqual(session.threadName, "DynamicNotch AI usage feature")
        XCTAssertFalse(session.relativeTime.isEmpty)

        let config = CodexConfigData(
            model: "gpt-6.1-sol",
            reasoningEffort: "low",
            sandboxMode: "danger-full-access",
            clientVersion: "0.165.0"
        )
        XCTAssertEqual(config.model, "gpt-6.1-sol")
        XCTAssertEqual(config.reasoningEffort, "low")
        XCTAssertEqual(config.sandboxMode, "danger-full-access")
        XCTAssertEqual(config.clientVersion, "0.165.0")
    }

    func testAIUsageServiceFileParsing() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let claudeDir = tempDir.appendingPathComponent(".claude")
        let codexDir = tempDir.appendingPathComponent(".codex")
        try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: codexDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Mock stats-cache.json
        let statsJson = """
        {
          "version": 2,
          "lastComputedDate": "2026-10-29",
          "totalSessions": 5,
          "totalMessages": 120,
          "modelUsage": {
            "claude-opus-4-6": {
              "inputTokens": 1000,
              "outputTokens": 2000,
              "cacheReadInputTokens": 10000,
              "cacheCreationInputTokens": 500,
              "costUSD": 0.5
            }
          }
        }
        """
        try statsJson.write(to: claudeDir.appendingPathComponent("stats-cache.json"), atomically: true, encoding: .utf8)

        // Mock history.jsonl
        let historyJsonl = """
        {"display":"prompt 1","timestamp":1700000000000,"project":"/Users/dev/Proj1","sessionId":"s1"}
        {"display":"prompt 2","timestamp":1700000060000,"project":"/Users/dev/Proj2","sessionId":"s2"}
        """
        try historyJsonl.write(to: claudeDir.appendingPathComponent("history.jsonl"), atomically: true, encoding: .utf8)

        // Mock session_index.jsonl
        let codexJsonl = """
        {"id":"01","thread_name":"Build Snake","updated_at":"2026-10-29T10:00:00.000000Z"}
        {"id":"02","thread_name":"Build Notch","updated_at":"2026-10-29T11:00:00.000000Z"}
        """
        try codexJsonl.write(to: codexDir.appendingPathComponent("session_index.jsonl"), atomically: true, encoding: .utf8)

        // Mock config.toml
        let configToml = """
        model = "gpt-6.1-sol"
        model_reasoning_effort = "medium"
        sandbox_mode = "danger-full-access"
        """
        try configToml.write(to: codexDir.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        // Mock version.json
        let versionJson = """
        {"latest_version":"0.165.0"}
        """
        try versionJson.write(to: codexDir.appendingPathComponent("version.json"), atomically: true, encoding: .utf8)

        let service = AIUsageService(claudeDirectory: claudeDir, codexDirectory: codexDir)
        XCTAssertTrue(service.isClaudeInstalled)
        XCTAssertTrue(service.isCodexInstalled)

        service.refresh()

        // Give async task a brief moment to finish
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNotNil(service.claudeStats)
        XCTAssertEqual(service.claudeStats?.totalSessions, 5)
        XCTAssertEqual(service.claudeStats?.totalMessages, 120)
        XCTAssertEqual(service.claudeHistory.count, 2)
        XCTAssertEqual(service.claudeHistory.first?.display, "prompt 2") // Reversed (most recent first)

        XCTAssertEqual(service.codexSessions.count, 2)
        XCTAssertEqual(service.codexSessions.first?.threadName, "Build Notch")
        XCTAssertEqual(service.codexConfig.model, "gpt-6.1-sol")
        XCTAssertEqual(service.codexConfig.reasoningEffort, "medium")
        XCTAssertEqual(service.codexConfig.sandboxMode, "danger-full-access")
        XCTAssertEqual(service.codexConfig.clientVersion, "0.165.0")
    }

    // MARK: - Fluid Dynamic Island Animation Preset Tests

    func testNotchAnimationPresetCasesAndResolved() {
        XCTAssertEqual(NotchAnimationPreset.allCases.count, 2)
        XCTAssertTrue(NotchAnimationPreset.allCases.contains(.fluid))
        XCTAssertTrue(NotchAnimationPreset.allCases.contains(.balanced))

        XCTAssertEqual(NotchAnimationPreset.resolved("fluid"), .fluid)
        XCTAssertEqual(NotchAnimationPreset.resolved("balanced"), .balanced)
        XCTAssertEqual(NotchAnimationPreset.resolved("unknown"), .fluid)
        XCTAssertEqual(NotchAnimationPreset.resolved(nil), .fluid)

        XCTAssertFalse(NotchAnimationPreset.fluid.description.isEmpty)
        XCTAssertFalse(NotchAnimationPreset.balanced.description.isEmpty)
    }

    func testFluidAnimationPresetValues() {
        let fluid = NotchAnimations.preset(.fluid)
        let balanced = NotchAnimations.preset(.balanced)

        // Fluid preset has snappier transition and pacing delays
        XCTAssertEqual(fluid.transitionDelay, 0.22, accuracy: 0.001)
        XCTAssertEqual(fluid.queuePacingDelay, 0.20, accuracy: 0.001)

        XCTAssertEqual(balanced.transitionDelay, 0.32, accuracy: 0.001)
        XCTAssertEqual(balanced.queuePacingDelay, 0.30, accuracy: 0.001)
    }

    func testApplicationSettingsStoreAnimationPreset() {
        let suite = "DynamicNotch.AnimationPresetTest.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = ApplicationSettingsStore(defaults: defaults)
        XCTAssertEqual(store.notchAnimationPreset, .fluid)

        store.notchAnimationPreset = .balanced
        XCTAssertEqual(store.notchAnimationPreset, .balanced)

        let restored = ApplicationSettingsStore(defaults: defaults)
        XCTAssertEqual(restored.notchAnimationPreset, .balanced)
    }

    // MARK: - QuickToolsStore AI Tab Integration Tests

    func testQuickToolsStoreIncludesAITab() {
        let suite = "DynamicNotch.QuickToolsAITest.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = QuickToolsStore(defaults: defaults)
        XCTAssertTrue(QuickToolTab.allTabs.contains(where: { $0.id == "ai" }))
        XCTAssertTrue(store.visibleTabs.contains(where: { $0.id == "ai" }))
        XCTAssertTrue(store.isTabEnabled("ai"))

        let aiTab = QuickToolTab.allTabs.first(where: { $0.id == "ai" })
        XCTAssertEqual(aiTab?.titleKey, "shelf.tool.ai")
        XCTAssertEqual(aiTab?.systemImage, "sparkles")

        store.selectedTool = "ai"
        store.hubMode = .tools
        let extraHeight = store.shelfExtraHeight(isIsland: false)
        XCTAssertEqual(extraHeight, 230)
    }
}
