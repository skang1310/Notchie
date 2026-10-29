//
//  AIUsageService.swift
//  DynamicNotch
//

import Foundation
import Combine
import SQLite3

@MainActor
public final class AIUsageService: ObservableObject {
    public static let shared = AIUsageService()

    @Published public private(set) var claudeStats: ClaudeStatsData?
    @Published public private(set) var claudeHistory: [ClaudeHistoryEntry] = []
    @Published public private(set) var codexSessions: [CodexSessionEntry] = []
    @Published public private(set) var codexConfig: CodexConfigData = CodexConfigData()
    @Published public private(set) var geminiSessions: [GeminiSessionEntry] = []
    @Published public private(set) var claudeSummary: AIProviderUsageSummary?
    @Published public private(set) var codexSummary: AIProviderUsageSummary?
    @Published public private(set) var geminiSummary: AIProviderUsageSummary?
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var lastRefreshed: Date?

    private let claudeDirectory: URL
    private let codexDirectory: URL
    private let geminiDirectory: URL
    private var refreshTask: Task<Void, Never>?

    public init(
        claudeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude"),
        codexDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex"),
        geminiDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".gemini")
    ) {
        self.claudeDirectory = claudeDirectory
        self.codexDirectory = codexDirectory
        self.geminiDirectory = geminiDirectory
    }

    public var isClaudeInstalled: Bool {
        FileManager.default.fileExists(atPath: claudeDirectory.path)
    }

    public var isCodexInstalled: Bool {
        FileManager.default.fileExists(atPath: codexDirectory.path)
    }

    public var isGeminiInstalled: Bool {
        FileManager.default.fileExists(atPath: geminiDirectory.path)
    }

    public func summary(for provider: AIProviderType) -> AIProviderUsageSummary? {
        switch provider {
        case .claudeCode:
            return claudeSummary
        case .codex:
            return codexSummary
        case .gemini:
            return geminiSummary
        }
    }

    @discardableResult
    public func refresh() -> Task<Void, Never> {
        refreshTask?.cancel()
        isLoading = true

        let claudeDir = claudeDirectory
        let codexDir = codexDirectory
        let geminiDir = geminiDirectory

        let task = Task.detached(priority: .userInitiated) {
            let (stats, history, claudeModel) = Self.loadClaudeData(from: claudeDir)
            let (sessions, config) = Self.loadCodexData(from: codexDir)
            let (geminiSess, geminiModel) = Self.loadGeminiData(from: geminiDir)

            let now = Date()
            let claudeSumm = Self.computeClaudeSummary(stats: stats, history: history, activeModel: claudeModel, now: now)
            let codexSumm = Self.computeCodexSummary(sessions: sessions, config: config, now: now)
            let geminiSumm = Self.computeGeminiSummary(sessions: geminiSess, modelName: geminiModel, now: now)

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.claudeStats = stats
                self.claudeHistory = history
                self.codexSessions = sessions
                self.codexConfig = config
                self.geminiSessions = geminiSess
                self.claudeSummary = claudeSumm
                self.codexSummary = codexSumm
                self.geminiSummary = geminiSumm
                self.isLoading = false
                self.lastRefreshed = now
            }
        }
        refreshTask = task
        return task
    }

    public func refreshAsync() async {
        await refresh().value
    }

    // MARK: - Claude Data Parsing

    private nonisolated static func loadClaudeData(from directory: URL) -> (ClaudeStatsData?, [ClaudeHistoryEntry], String) {
        let statsURL = directory.appendingPathComponent("stats-cache.json")
        var stats: ClaudeStatsData?
        if let data = try? Data(contentsOf: statsURL) {
            let decoder = JSONDecoder()
            stats = try? decoder.decode(ClaudeStatsData.self, from: data)
        }

        var history: [ClaudeHistoryEntry] = []
        var detectedModel: String?
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackIso = ISO8601DateFormatter()
        fallbackIso.formatOptions = [.withInternetDateTime]

        let fileManager = FileManager.default

        // 1. Scan modern project session files in ~/.claude/projects/*/*.jsonl
        let projectsURL = directory.appendingPathComponent("projects")
        if let projectDirs = try? fileManager.contentsOfDirectory(at: projectsURL, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles) {
            let now = Date()
            let cutoff = now.addingTimeInterval(-7 * 86400) // 7 days

            for pDir in projectDirs {
                guard let sessionFiles = try? fileManager.contentsOfDirectory(at: pDir, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles) else {
                    continue
                }
                for sFile in sessionFiles where sFile.pathExtension == "jsonl" {
                    if let values = try? sFile.resourceValues(forKeys: [.contentModificationDateKey]),
                       let modDate = values.contentModificationDate,
                       modDate < cutoff {
                        continue
                    }
                    guard let content = try? String(contentsOf: sFile, encoding: .utf8) else {
                        continue
                    }
                    let lines = content.components(separatedBy: .newlines)
                    for line in lines where !line.isEmpty {
                        guard let data = line.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                            continue
                        }
                        let type = json["type"] as? String ?? ""
                        if type == "user" {
                            let timestampStr = json["timestamp"] as? String ?? ""
                            let timestamp = isoFormatter.date(from: timestampStr) ?? fallbackIso.date(from: timestampStr) ?? Date()
                            var prompt = ""
                            if let msg = json["message"] as? [String: Any],
                               let contentStr = msg["content"] as? String {
                                prompt = contentStr
                            } else if let contentStr = json["content"] as? String {
                                prompt = contentStr
                            }
                            if prompt.isEmpty {
                                prompt = "Claude Interaction"
                            }
                            history.append(ClaudeHistoryEntry(
                                id: UUID().uuidString,
                                display: prompt,
                                timestamp: timestamp,
                                project: pDir.lastPathComponent,
                                sessionId: sFile.deletingPathExtension().lastPathComponent
                            ))
                        } else if type == "assistant" && detectedModel == nil {
                            if let msg = json["message"] as? [String: Any],
                               let model = msg["model"] as? String, !model.isEmpty {
                                detectedModel = model
                            }
                        }
                    }
                }
            }
        }

        // 2. Also read legacy flat history.jsonl
        let historyURL = directory.appendingPathComponent("history.jsonl")
        if let content = try? String(contentsOf: historyURL, encoding: .utf8) {
            let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            for line in lines.suffix(20) {
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

        history.sort { $0.timestamp > $1.timestamp }
        let resolvedModel = detectedModel ?? stats?.primaryModelName ?? "claude-sonnet-5-5"
        return (stats, history, resolvedModel)
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
        activeModel: String = "claude-sonnet-5-5",
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
            sessionUtilization = min(100.0, max(5.0, (Double(recentEntries.count) / 45.0) * 100.0))
        } else {
            sessionResetsAt = now
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
            totalLimitDesc: activeModel
        )

        // Weekly quota calculation
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now.addingTimeInterval(-7 * 86400)
        let weeklyEntries = history.filter { $0.timestamp >= sevenDaysAgo }
        var weeklyCount = weeklyEntries.count

        if weeklyCount == 0, let daily = stats?.dailyActivity {
            let isoFormatter = DateFormatter()
            isoFormatter.dateFormat = "yyyy-MM-dd"
            for act in daily {
                if let date = isoFormatter.date(from: act.date), date >= sevenDaysAgo {
                    weeklyCount += act.messageCount
                }
            }
        }
        if weeklyCount == 0 {
            weeklyCount = history.count
        }

        let weeklyUtilization = min(100.0, max(2.0, (Double(weeklyCount) / 350.0) * 100.0))
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
            activeModel: activeModel,
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
            sessionUtilization = min(100.0, max(5.0, (Double(recentSessions.count) / 25.0) * 100.0))
        } else {
            sessionResetsAt = now
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

    // MARK: - Gemini Data Parsing

    private nonisolated static func loadGeminiData(from directory: URL) -> ([GeminiSessionEntry], String) {
        var sessions: [GeminiSessionEntry] = []
        var modelName = "gemini-2.5-pro"

        // 1. Try reading model from antigravity_state.pbtxt
        let stateURL = directory.appendingPathComponent("antigravity").appendingPathComponent("antigravity_state.pbtxt")
        if let stateContent = try? String(contentsOf: stateURL, encoding: .utf8) {
            for rawLine in stateContent.components(separatedBy: .newlines) {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("last_selected_agent_model:") {
                    let parts = line.components(separatedBy: ":")
                    if parts.count >= 2 {
                        let rawModel = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
                        if !rawModel.isEmpty {
                            modelName = formatGeminiModel(rawModel)
                        }
                    }
                }
            }
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackIso = ISO8601DateFormatter()
        fallbackIso.formatOptions = [.withInternetDateTime]

        let fileManager = FileManager.default
        let brainURL = directory.appendingPathComponent("antigravity").appendingPathComponent("brain")
        let now = Date()
        let cutoff = now.addingTimeInterval(-7 * 86400) // last 7 days

        // 2. Scan recent transcript.jsonl files under ~/.gemini/antigravity/brain/*/.system_generated/logs/transcript.jsonl
        if let convoDirs = try? fileManager.contentsOfDirectory(at: brainURL, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles) {
            for convoDir in convoDirs {
                let transcriptURL = convoDir.appendingPathComponent(".system_generated").appendingPathComponent("logs").appendingPathComponent("transcript.jsonl")
                guard fileManager.fileExists(atPath: transcriptURL.path) else { continue }
                if let values = try? transcriptURL.resourceValues(forKeys: [.contentModificationDateKey]),
                   let modDate = values.contentModificationDate,
                   modDate < cutoff {
                    continue
                }

                if let content = try? String(contentsOf: transcriptURL, encoding: .utf8) {
                    for line in content.components(separatedBy: .newlines) where !line.isEmpty {
                        guard let data = line.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                            continue
                        }
                        let type = json["type"] as? String ?? ""
                        if type == "USER_INPUT" {
                            let dateStr = json["created_at"] as? String ?? ""
                            let date = isoFormatter.date(from: dateStr) ?? fallbackIso.date(from: dateStr) ?? Date()
                            var snippet = (json["content"] as? String ?? "")
                                .replacingOccurrences(of: "<USER_REQUEST>", with: "")
                                .replacingOccurrences(of: "</USER_REQUEST>", with: "")
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            if snippet.isEmpty { snippet = "Gemini Request" }

                            sessions.append(GeminiSessionEntry(
                                id: UUID().uuidString,
                                title: String(snippet.prefix(50)),
                                stepCount: 1,
                                lastModified: date
                            ))
                        }
                    }
                }
            }
        }

        // 3. Fallback: if sessions empty, query conversation_summaries.db
        if sessions.isEmpty {
            let dbURL = directory.appendingPathComponent("antigravity").appendingPathComponent("conversation_summaries.db")
            if fileManager.fileExists(atPath: dbURL.path) {
                var db: OpaquePointer?
                if sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK {
                    defer { sqlite3_close(db) }
                    let query = "SELECT conversation_id, title, step_count, last_modified_time FROM conversation_summaries ORDER BY last_modified_time DESC LIMIT 20;"
                    var stmt: OpaquePointer?
                    if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                        defer { sqlite3_finalize(stmt) }
                        while sqlite3_step(stmt) == SQLITE_ROW {
                            let id = sqlite3_column_text(stmt, 0).map { String(cString: $0) } ?? UUID().uuidString
                            let title = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? "Conversation"
                            let steps = Int(sqlite3_column_int(stmt, 2))
                            let dateText = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""
                            let normalized = dateText.replacingOccurrences(of: " ", with: "T")
                            let date = isoFormatter.date(from: normalized) ?? fallbackIso.date(from: normalized) ?? Date()

                            sessions.append(GeminiSessionEntry(
                                id: id,
                                title: title,
                                stepCount: min(10, steps),
                                lastModified: date
                            ))
                        }
                    }
                }
            }
        }

        // Sort descending
        sessions.sort { $0.lastModified > $1.lastModified }
        return (sessions, modelName)
    }

    private nonisolated static func formatGeminiModel(_ raw: String) -> String {
        if raw.contains("M318") || raw.contains("pro") {
            return "gemini-2.5-pro"
        } else if raw.contains("flash") {
            return "gemini-2.5-flash"
        }
        return raw.lowercased()
    }

    internal nonisolated static func computeGeminiSummary(
        sessions: [GeminiSessionEntry],
        modelName: String,
        now: Date = Date()
    ) -> AIProviderUsageSummary {
        let fiveHoursAgo = now.addingTimeInterval(-5 * 3600)
        let recentSessions = sessions.filter { $0.lastModified >= fiveHoursAgo }

        let sessionUtilization: Double
        let sessionResetsAt: Date

        if !recentSessions.isEmpty {
            let earliestTimestamp = recentSessions.map(\.lastModified).min() ?? now
            sessionResetsAt = earliestTimestamp.addingTimeInterval(5 * 3600)
            // Count actual user prompts sent in 5-hour rolling session window (benchmark ~50 prompts)
            sessionUtilization = min(100.0, max(5.0, (Double(recentSessions.count) / 50.0) * 100.0))
        } else {
            sessionResetsAt = now
            sessionUtilization = 0.0
        }

        let primaryWindow = AIQuotaWindow(
            id: "gemini-5h",
            title: "5-Hour Session Window",
            titleKo: "5시간 세션 롤링 창",
            subtitle: "Rolling rate limit",
            subtitleKo: "5시간 단위 롤링 한도",
            utilization: sessionUtilization,
            resetsAt: sessionResetsAt,
            totalLimitDesc: modelName
        )

        let calendar = Calendar.current
        let nextMidnight = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(86400)

        let todaySessions = sessions.filter { calendar.isDateInToday($0.lastModified) }
        let dailyUtilization = min(100.0, max(2.0, (Double(todaySessions.count) / 200.0) * 100.0))

        let secondaryWindow = AIQuotaWindow(
            id: "gemini-daily",
            title: "Daily Request Quota",
            titleKo: "일일 쿼터 한도",
            subtitle: "24-hour limit",
            subtitleKo: "24시간 요청 쿼터 한도",
            utilization: dailyUtilization,
            resetsAt: nextMidnight,
            totalLimitDesc: "Google AI"
        )

        return AIProviderUsageSummary(
            id: "gemini-summary",
            provider: .gemini,
            primaryWindow: primaryWindow,
            secondaryWindow: secondaryWindow,
            activeModel: modelName,
            isLiveAPI: false,
            lastUpdated: now
        )
    }
}
