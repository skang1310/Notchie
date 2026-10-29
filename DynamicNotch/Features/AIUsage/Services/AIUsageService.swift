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

    public func refresh() {
        refreshTask?.cancel()
        isLoading = true

        let claudeDir = claudeDirectory
        let codexDir = codexDirectory

        refreshTask = Task.detached(priority: .userInitiated) {
            let (stats, history) = Self.loadClaudeData(from: claudeDir)
            let (sessions, config) = Self.loadCodexData(from: codexDir)

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.claudeStats = stats
                self.claudeHistory = history
                self.codexSessions = sessions
                self.codexConfig = config
                self.isLoading = false
                self.lastRefreshed = Date()
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
}
