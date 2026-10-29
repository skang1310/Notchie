//
//  AIUsageService.swift
//  DynamicNotch
//

import Foundation
import Combine

@MainActor
public final class AIUsageService: ObservableObject {
    public static let shared = AIUsageService()

    @Published public private(set) var claudeStats: ClaudeStatsData?
    @Published public private(set) var claudeHistory: [ClaudeHistoryEntry] = []
    @Published public private(set) var codexSessions: [CodexSessionEntry] = []
    @Published public private(set) var codexConfig: CodexConfigData = CodexConfigData()
    @Published public private(set) var claudeSummary: AIProviderUsageSummary?
    @Published public private(set) var codexSummary: AIProviderUsageSummary?
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var lastRefreshed: Date?

    private let claudeDirectory: URL
    private let codexDirectory: URL
    private var refreshTask: Task<Void, Never>?

    public init(
        claudeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude"),
        codexDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
    ) {
        self.claudeDirectory = claudeDirectory
        self.codexDirectory = codexDirectory
    }

    public var isClaudeInstalled: Bool {
        FileManager.default.fileExists(atPath: claudeDirectory.path)
    }

    public var isCodexInstalled: Bool {
        FileManager.default.fileExists(atPath: codexDirectory.path)
    }

    public func summary(for provider: AIProviderType) -> AIProviderUsageSummary? {
        switch provider {
        case .claudeCode:
            return claudeSummary
        case .codex:
            return codexSummary
        }
    }

    public func refresh() {
        refreshTask?.cancel()
        isLoading = true

        let claudeDir = claudeDirectory
        let codexDir = codexDirectory

        refreshTask = Task.detached(priority: .userInitiated) {
            let (stats, history) = Self.loadClaudeData(from: claudeDir)
            let (sessions, config) = Self.loadCodexData(from: codexDir)

            let now = Date()
            let claudeSumm = Self.computeClaudeSummary(stats: stats, history: history, now: now)
            let codexSumm = Self.computeCodexSummary(sessions: sessions, config: config, now: now)

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.claudeStats = stats
                self.claudeHistory = history
                self.codexSessions = sessions
                self.codexConfig = config
                self.claudeSummary = claudeSumm
                self.codexSummary = codexSumm
                self.isLoading = false
                self.lastRefreshed = now
            }
        }
    }

    // MARK: - Claude Data Parsing

    private nonisolated static func loadClaudeData(from directory: URL) -> (ClaudeStatsData?, [ClaudeHistoryEntry]) {
        let statsURL = directory.appendingPathComponent("stats-cache.json")
        var stats: ClaudeStatsData?
        if let data = try? Data(contentsOf: statsURL) {
            let decoder = JSONDecoder()
            stats = try? decoder.decode(ClaudeStatsData.self, from: data)
        }

        let historyURL = directory.appendingPathComponent("history.jsonl")
        var history: [ClaudeHistoryEntry] = []
        if let content = try? String(contentsOf: historyURL, encoding: .utf8) {
            let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            // Take the latest 20 lines (reversed)
            let recentLines = lines.suffix(20).reversed()
            for line in recentLines {
                if let data = line.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let display = json["display"] as? String ?? ""
                    let project = json["project"] as? String ?? ""
                    let sessionId = json["sessionId"] as? String ?? ""
                    let timestampMs = json["timestamp"] as? Double ?? 0
                    let timestamp = timestampMs > 0 ? Date(timeIntervalSince1970: timestampMs / 1000.0) : Date()

                    if !display.isEmpty {
                        history.append(ClaudeHistoryEntry(
                            display: display,
                            timestamp: timestamp,
                            project: project,
                            sessionId: sessionId
                        ))
                    }
                }
            }
        }

        return (stats, history)
    }

    // MARK: - Codex Data Parsing

    private nonisolated static func loadCodexData(from directory: URL) -> ([CodexSessionEntry], CodexConfigData) {
        var sessions: [CodexSessionEntry] = []
        let sessionIndexURL = directory.appendingPathComponent("session_index.jsonl")
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let content = try? String(contentsOf: sessionIndexURL, encoding: .utf8) {
            let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            // Take the latest 25 lines (reversed)
            let recentLines = lines.suffix(25).reversed()
            for line in recentLines {
                if let data = line.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let id = json["id"] as? String ?? UUID().uuidString
                    let threadName = json["thread_name"] as? String ?? "Session"
                    let updatedAtStr = json["updated_at"] as? String ?? ""
                    let updatedAt = isoFormatter.date(from: updatedAtStr) ?? Date()

                    sessions.append(CodexSessionEntry(
                        id: id,
                        threadName: threadName,
                        updatedAt: updatedAt
                    ))
                }
            }
        }

        var config = CodexConfigData()
        let configURL = directory.appendingPathComponent("config.toml")
        if let configContent = try? String(contentsOf: configURL, encoding: .utf8) {
            for rawLine in configContent.components(separatedBy: .newlines) {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("model =") {
                    let parts = line.components(separatedBy: "=")
                    if parts.count >= 2 {
                        config.model = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
                    }
                } else if line.hasPrefix("model_reasoning_effort =") {
                    let parts = line.components(separatedBy: "=")
                    if parts.count >= 2 {
                        config.reasoningEffort = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
                    }
                } else if line.hasPrefix("sandbox_mode =") {
                    let parts = line.components(separatedBy: "=")
                    if parts.count >= 2 {
                        config.sandboxMode = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
                    }
                }
            }
        }

        let versionURL = directory.appendingPathComponent("version.json")
        if let data = try? Data(contentsOf: versionURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let version = json["latest_version"] as? String {
            config.clientVersion = version
        }

        return (sessions, config)
    }

    // MARK: - Quota Calculation (Codenotch Logic)

    internal nonisolated static func computeClaudeSummary(
        stats: ClaudeStatsData?,
        history: [ClaudeHistoryEntry],
        now: Date = Date()
    ) -> AIProviderUsageSummary {
        let fiveHoursAgo = now.addingTimeInterval(-5 * 3600)
        let recentEntries = history.filter { $0.timestamp >= fiveHoursAgo }

        let sessionUtilization: Double
        let sessionResetsAt: Date

        if !recentEntries.isEmpty {
            // Earliest message in current 5-hour window rolls off 5 hours after its timestamp
            let earliestTimestamp = recentEntries.map(\.timestamp).min() ?? now
            sessionResetsAt = earliestTimestamp.addingTimeInterval(5 * 3600)
            // Benchmark: ~45 messages in 5h rolling window
            sessionUtilization = min(100.0, max(4.0, (Double(recentEntries.count) / 45.0) * 100.0))
        } else {
            sessionResetsAt = now.addingTimeInterval(5 * 3600)
            sessionUtilization = 0.0
        }

        let primaryWindow = AIQuotaWindow(
            id: "claude-5h",
            title: "5-Hour Session Window",
            titleKo: "5시간 세션 롤링 창",
            subtitle: "Rolling rate limit",
            subtitleKo: "5시간 단위 롤링 한도",
            utilization: sessionUtilization,
            resetsAt: sessionResetsAt,
            totalLimitDesc: "Sonnet & Opus"
        )

        // Weekly quota calculation
        var weeklyMessages = 0
        let calendar = Calendar.current
        if let daily = stats?.dailyActivity {
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            let isoFormatter = DateFormatter()
            isoFormatter.dateFormat = "yyyy-MM-dd"
            for act in daily {
                if let date = isoFormatter.date(from: act.date), date >= sevenDaysAgo {
                    weeklyMessages += act.messageCount
                }
            }
        }
        if weeklyMessages == 0 {
            weeklyMessages = history.count
        }

        let weeklyUtilization = min(100.0, max(2.0, (Double(weeklyMessages) / 350.0) * 100.0))
        let weeklyResetDate = calendar.date(byAdding: .day, value: 5, to: now) ?? now.addingTimeInterval(5 * 86400)

        let secondaryWindow = AIQuotaWindow(
            id: "claude-7d",
            title: "7-Day Weekly Limit",
            titleKo: "주간 쿼터 한도",
            subtitle: "Weekly allowance",
            subtitleKo: "7일 단위 누적 한도",
            utilization: weeklyUtilization,
            resetsAt: weeklyResetDate,
            totalLimitDesc: "All Models"
        )

        return AIProviderUsageSummary(
            id: "claude-summary",
            provider: .claudeCode,
            primaryWindow: primaryWindow,
            secondaryWindow: secondaryWindow,
            activeModel: stats?.primaryModelName ?? "claude-3-7-sonnet",
            isLiveAPI: false,
            lastUpdated: now
        )
    }

    internal nonisolated static func computeCodexSummary(
        sessions: [CodexSessionEntry],
        config: CodexConfigData,
        now: Date = Date()
    ) -> AIProviderUsageSummary {
        let fiveHoursAgo = now.addingTimeInterval(-5 * 3600)
        let recentSessions = sessions.filter { $0.updatedAt >= fiveHoursAgo }

        let sessionUtilization: Double
        let sessionResetsAt: Date

        if !recentSessions.isEmpty {
            let earliestTimestamp = recentSessions.map(\.updatedAt).min() ?? now
            sessionResetsAt = earliestTimestamp.addingTimeInterval(5 * 3600)
            sessionUtilization = min(100.0, max(4.0, (Double(recentSessions.count) / 25.0) * 100.0))
        } else {
            sessionResetsAt = now.addingTimeInterval(5 * 3600)
            sessionUtilization = 0.0
        }

        let primaryWindow = AIQuotaWindow(
            id: "codex-session",
            title: "Session Rate Limit",
            titleKo: "코덱스 세션 창",
            subtitle: "Active rolling window",
            subtitleKo: "롤링 작업 세션 한도",
            utilization: sessionUtilization,
            resetsAt: sessionResetsAt,
            totalLimitDesc: config.model
        )

        let calendar = Calendar.current
        let nextMidnight = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(86400)

        let todaySessions = sessions.filter { calendar.isDateInToday($0.updatedAt) }.count
        let dailyUtilization = min(100.0, max(2.0, (Double(todaySessions) / 40.0) * 100.0))

        let secondaryWindow = AIQuotaWindow(
            id: "codex-daily",
            title: "Daily Quota",
            titleKo: "일일 쿼터 한도",
            subtitle: "24-hour limit",
            subtitleKo: "24시간 쿼터 한도",
            utilization: dailyUtilization,
            resetsAt: nextMidnight,
            totalLimitDesc: "Effort: \(config.reasoningEffort)"
        )

        return AIProviderUsageSummary(
            id: "codex-summary",
            provider: .codex,
            primaryWindow: primaryWindow,
            secondaryWindow: secondaryWindow,
            activeModel: config.model,
            isLiveAPI: false,
            lastUpdated: now
        )
    }
}
