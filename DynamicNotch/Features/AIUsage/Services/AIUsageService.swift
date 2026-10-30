//
//  AIUsageService.swift
//  DynamicNotch
//

import Foundation
import Combine
import SQLite3
internal import AppKit

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
    @Published private(set) var codexLiveQueryFailed = false
    private var quotaRefreshTask: Task<Void, Never>?

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
        // Multiple visible consumers can request the same disk/database scan.
        // Share the active task instead of starting overlapping detached work.
        if let refreshTask { return refreshTask }
        isLoading = true

        let teamEnabled = ClaudeTeamConnection.shared.enabled && !AppEnvironment.isRunningTests
        let teamSnapshot = teamEnabled ? ClaudeTeamConnection.shared.snapshot : nil
        let chromePID = teamEnabled ? NSRunningApplication.runningApplications(withBundleIdentifier: "com.google.Chrome").first?.processIdentifier : nil
        let claudeDir = claudeDirectory
        let codexDir = codexDirectory
        let geminiDir = geminiDirectory

        let task = Task.detached(priority: .userInitiated) {
            let (stats, history, claudeModel) = Self.loadClaudeData(from: claudeDir)
            let (sessions, config) = Self.loadCodexData(from: codexDir)
            let (geminiSess, geminiModel) = Self.loadGeminiData(from: geminiDir)

            let now = Date()
            let capturedTeamQuota = chromePID.flatMap { ClaudeTeamQuotaReader.capture(browserPID: $0, now: now) }
            let claudeSumm = Self.computeClaudeSummary(stats: stats, history: history, activeModel: claudeModel, now: now,
                quota: capturedTeamQuota ?? teamSnapshot)
            let recorded = RecordedAIQuota.latestCodex(in: codexDir, now: now)
            let codexSumm = Self.computeCodexSummary(sessions: sessions, config: config, now: now, quota: recorded)
            let geminiSumm = Self.computeGeminiSummary(sessions: geminiSess, modelName: geminiModel, now: now)

            await MainActor.run { [weak self] in
                guard let self else { return }
                if let capturedTeamQuota { ClaudeTeamConnection.shared.save(capturedTeamQuota) }
                self.claudeStats = stats
                self.claudeHistory = history
                self.codexSessions = sessions
                self.codexConfig = config
                self.geminiSessions = geminiSess
                self.claudeSummary = ClaudeTeamConnection.shared.enabled ? claudeSumm :
                    Self.computeClaudeSummary(stats: stats, history: history, activeModel: claudeModel, now: now)
                if (self.codexSummary?.quotaRecordedAt ?? .distantPast) <= (codexSumm.quotaRecordedAt ?? .distantPast) {
                    self.codexSummary = codexSumm
                }
                if (self.geminiSummary?.quotaRecordedAt ?? .distantPast) <= (geminiSumm.quotaRecordedAt ?? .distantPast) {
                    self.geminiSummary = geminiSumm
                }
                self.isLoading = false
                self.refreshTask = nil
                self.lastRefreshed = now
            }
        }
        refreshTask = task
        return task
    }

    public func refreshAsync() async {
        await refresh().value
    }

    public func refreshIfNeeded(maxAge: TimeInterval = 45) async {
        if let lastRefreshed, Date().timeIntervalSince(lastRefreshed) < maxAge { return }
        await refreshAsync()
    }

    func refreshQuotasAsync() async {
        if let quotaRefreshTask { await quotaRefreshTask.value; return }
        let work = Task { @MainActor [weak self] in
            guard let self else { return }
            let antigravity = AppEnvironment.isRunningTests ? nil : await AntigravityQuotaClient.shared.read()
            if let antigravity {
                self.geminiSummary = Self.computeGeminiSummary(sessions: self.geminiSessions,
                    modelName: self.geminiSummary?.activeModel ?? "Unknown", quota: antigravity)
            }
            let live = AppEnvironment.isRunningTests ? nil : await CodexLiveQuotaClient.shared.read()
            if let live {
                self.codexSummary = Self.computeCodexSummary(sessions: self.codexSessions, config: self.codexConfig,
                    now: .now, quota: live, isLive: true)
                self.codexLiveQueryFailed = false
            } else { self.codexLiveQueryFailed = !AppEnvironment.isRunningTests }
            let connection = ClaudeTeamConnection.shared
            let pid = connection.enabled && !AppEnvironment.isRunningTests
                ? NSRunningApplication.runningApplications(withBundleIdentifier: "com.google.Chrome").first?.processIdentifier : nil
            let captured = await Task.detached(priority: .utility) {
                pid.flatMap { ClaudeTeamQuotaReader.capture(browserPID: $0) }
            }.value
            if let captured { connection.save(captured) }
            self.claudeSummary = Self.computeClaudeSummary(stats: self.claudeStats, history: self.claudeHistory,
                activeModel: self.claudeSummary?.activeModel ?? "Unknown", now: .now,
                quota: connection.enabled ? connection.snapshot : nil)
        }
        quotaRefreshTask = work
        await work.value
        quotaRefreshTask = nil
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
                    for row in AIUsageLogReader.shared.records(sFile) {
                        if row.type == "user" {
                            let timestamp = isoFormatter.date(from: row.date) ?? fallbackIso.date(from: row.date)
                            guard let timestamp, timestamp >= cutoff else { continue }
                            let raw = pDir.lastPathComponent
                            let project = row.project.isEmpty
                                ? (raw.hasPrefix("-") ? raw.components(separatedBy: "-").last ?? raw : raw)
                                : URL(fileURLWithPath: row.project).lastPathComponent
                            history.append(ClaudeHistoryEntry(id: sFile.path + row.date,
                                display: row.text.isEmpty ? "Claude Interaction" : row.text,
                                timestamp: timestamp, project: project,
                                sessionId: sFile.deletingPathExtension().lastPathComponent))
                        } else if row.type == "assistant", detectedModel == nil, !row.model.isEmpty {
                            detectedModel = row.model
                        }
                    }
                }
            }
        }

        // 2. Also read legacy flat history.jsonl
        let historyURL = directory.appendingPathComponent("history.jsonl")
        for row in AIUsageLogReader.shared.records(historyURL, tail: 20) where !row.text.isEmpty {
            guard row.milliseconds > 0 else { continue }
            history.append(ClaudeHistoryEntry(display: row.text,
                timestamp: Date(timeIntervalSince1970: row.milliseconds / 1000),
                project: row.project, sessionId: row.id))
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

        for row in AIUsageLogReader.shared.records(sessionIndexURL, tail: 25).reversed() {
            guard let date = isoFormatter.date(from: row.date) ?? ISO8601DateFormatter().date(from: row.date) else { continue }
            sessions.append(CodexSessionEntry(id: row.id, threadName: row.text, updatedAt: date))
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

        // 2. Query state_5.sqlite for recent threads
        let stateDB = directory.appendingPathComponent("state_5.sqlite")
        if FileManager.default.fileExists(atPath: stateDB.path) {
            var db: OpaquePointer?
            if sqlite3_open_v2(stateDB.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK {
                defer { sqlite3_close(db) }
                let query = "SELECT id, title, updated_at FROM threads ORDER BY updated_at DESC LIMIT 20;"
                var stmt: OpaquePointer?
                if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                    defer { sqlite3_finalize(stmt) }
                    while sqlite3_step(stmt) == SQLITE_ROW {
                        let id = sqlite3_column_text(stmt, 0).map { String(cString: $0) } ?? UUID().uuidString
                        let title = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? "Session"
                        let updatedSec = sqlite3_column_int64(stmt, 2)
                        let updated = updatedSec > 0 ? Date(timeIntervalSince1970: Double(updatedSec)) : Date()

                        if !sessions.contains(where: { $0.id == id }) {
                            sessions.append(CodexSessionEntry(id: id, threadName: title, updatedAt: updated))
                        }
                    }
                }
            }
        }

        // 3. Query thread_history_1.sqlite for rate limit / quota exhaustion
        let historyDB = directory.appendingPathComponent("thread_history_1.sqlite")
        if FileManager.default.fileExists(atPath: historyDB.path) {
            var db: OpaquePointer?
            if sqlite3_open_v2(historyDB.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK {
                defer { sqlite3_close(db) }
                let query = "SELECT error_json, completed_at FROM thread_turns WHERE error_json IS NOT NULL ORDER BY completed_at DESC LIMIT 5;"
                var stmt: OpaquePointer?
                if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                    defer { sqlite3_finalize(stmt) }
                    while sqlite3_step(stmt) == SQLITE_ROW {
                        if let errorC = sqlite3_column_text(stmt, 0) {
                            let errorStr = String(cString: errorC)
                            if errorStr.contains("usageLimitExceeded") || errorStr.contains("hit your usage limit") {
                                if let range = errorStr.range(of: "try again at ") {
                                    let sub = String(errorStr[range.upperBound...])
                                    let cleaned = sub.replacingOccurrences(of: "st,", with: ",")
                                                     .replacingOccurrences(of: "nd,", with: ",")
                                                     .replacingOccurrences(of: "rd,", with: ",")
                                                     .replacingOccurrences(of: "th,", with: ",")
                                                     .replacingOccurrences(of: ".", with: "")
                                                     .replacingOccurrences(of: "\"", with: "")
                                                     .trimmingCharacters(in: .whitespacesAndNewlines)
                                    let df = DateFormatter()
                                    df.locale = Locale(identifier: "en_US_POSIX")
                                    df.dateFormat = "MMM d, yyyy h:mm a"
                                    if let resetDate = df.date(from: cleaned), resetDate > Date() {
                                        config.isRateLimited = true
                                        config.rateLimitResetsAt = resetDate
                                        break
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        sessions.sort { $0.updatedAt > $1.updatedAt }
        return (sessions, config)
    }

    // Local activity is not a subscription quota. Only recorded provider windows may supply percentages.
    private nonisolated static func unknownWindow(now: Date) -> AIQuotaWindow {
        AIQuotaWindow(id: "unavailable", title: "Quota unavailable", titleKo: "한도 정보 없음", utilization: 0, resetsAt: now)
    }
    internal nonisolated static func computeClaudeSummary(
        stats: ClaudeStatsData?, history: [ClaudeHistoryEntry], activeModel: String = "Unknown", now: Date = Date(), quota: RecordedAIQuota? = nil
    ) -> AIProviderUsageSummary {
        let latest = history.max(by: { $0.timestamp < $1.timestamp })
        return AIProviderUsageSummary(id: "claude-summary", provider: .claudeCode,
            primaryWindow: quota?.primary ?? unknownWindow(now: now), secondaryWindow: quota?.secondary,
            activeModel: activeModel, quotaRecordedAt: quota?.recordedAt, lastUpdated: now, tierBadge: quota == nil ? "—" : "Team",
            activeSessionTitle: latest?.projectName, activeSessionSubtitle: latest?.display,
            activeSessionDate: latest?.timestamp,
            isSessionActive: latest.map { (0..<1800).contains(now.timeIntervalSince($0.timestamp)) } ?? false)
    }
    internal nonisolated static func computeCodexSummary(
        sessions: [CodexSessionEntry], config: CodexConfigData, now: Date = Date(), quota: RecordedAIQuota? = nil, isLive: Bool = false
    ) -> AIProviderUsageSummary {
        let latest = sessions.max(by: { $0.updatedAt < $1.updatedAt })
        return AIProviderUsageSummary(id: "codex-summary", provider: .codex,
            primaryWindow: quota?.primary ?? unknownWindow(now: now), secondaryWindow: quota?.secondary,
            activeModel: config.model, isLiveAPI: isLive, quotaRecordedAt: quota?.recordedAt, lastUpdated: now, tierBadge: quota?.plan ?? "—",
            activeSessionTitle: latest?.threadName, activeSessionSubtitle: "Codex Session", activeSessionDate: latest?.updatedAt,
            isSessionActive: latest.map { (0..<1800).contains(now.timeIntervalSince($0.updatedAt)) } ?? false)
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

        // Preload conversation titles and active states from conversation_summaries.db
        var convoMetadata: [String: (title: String, notIdle: Bool)] = [:]
        let dbURL = directory.appendingPathComponent("antigravity").appendingPathComponent("conversation_summaries.db")
        if fileManager.fileExists(atPath: dbURL.path) {
            var db: OpaquePointer?
            if sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK {
                defer { sqlite3_close(db) }
                let query = "SELECT conversation_id, title, not_fully_idle FROM conversation_summaries ORDER BY last_modified_time DESC LIMIT 30;"
                var stmt: OpaquePointer?
                if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                    defer { sqlite3_finalize(stmt) }
                    while sqlite3_step(stmt) == SQLITE_ROW {
                        if let idStr = sqlite3_column_text(stmt, 0).map({ String(cString: $0) }) {
                            let title = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? "Conversation"
                            let notIdle = sqlite3_column_int(stmt, 2) != 0
                            convoMetadata[idStr] = (title, notIdle)
                        }
                    }
                }
            }
        }

        // 2. Scan recent transcript.jsonl files under ~/.gemini/antigravity/brain/*/.system_generated/logs/transcript.jsonl
        if let convoDirs = try? fileManager.contentsOfDirectory(at: brainURL, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles) {
            for convoDir in convoDirs {
                let convoId = convoDir.lastPathComponent
                let transcriptURL = convoDir.appendingPathComponent(".system_generated").appendingPathComponent("logs").appendingPathComponent("transcript.jsonl")
                guard fileManager.fileExists(atPath: transcriptURL.path) else { continue }
                if let values = try? transcriptURL.resourceValues(forKeys: [.contentModificationDateKey]),
                   let modDate = values.contentModificationDate,
                   modDate < cutoff {
                    continue
                }

                for row in AIUsageLogReader.shared.records(transcriptURL) where row.type == "USER_INPUT" {
                    guard let date = isoFormatter.date(from: row.date) ?? fallbackIso.date(from: row.date), date >= cutoff else { continue }
                    let snippet = row.text.replacingOccurrences(of: "<USER_REQUEST>", with: "")
                        .replacingOccurrences(of: "</USER_REQUEST>", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                    sessions.append(GeminiSessionEntry(id: convoId,
                        title: convoMetadata[convoId]?.title ?? String(snippet.prefix(50)),
                        stepCount: 1, lastModified: date))
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
        sessions: [GeminiSessionEntry], modelName: String, now: Date = Date(), quota: AntigravityQuotaClient.Snapshot? = nil
    ) -> AIProviderUsageSummary {
        let latest = sessions.max(by: { $0.lastModified < $1.lastModified })
        return AIProviderUsageSummary(id: "gemini-summary", provider: .gemini,
            primaryWindow: quota?.windows.first ?? unknownWindow(now: now),
            secondaryWindow: quota.flatMap { $0.windows.dropFirst().first },
            additionalWindows: quota.map { Array($0.windows.dropFirst(2)) } ?? [],
            activeModel: modelName, isLiveAPI: quota != nil, quotaRecordedAt: quota?.recordedAt, lastUpdated: now, tierBadge: quota == nil ? "—" : "IDE",
            activeSessionTitle: latest?.title, activeSessionSubtitle: "Local Antigravity session", activeSessionDate: latest?.lastModified,
            isSessionActive: latest.map { (0..<1800).contains(now.timeIntervalSince($0.lastModified)) } ?? false)
    }
}
