//
//  AIUsageData.swift
//  DynamicNotch
//

import Foundation

// MARK: - Claude Code Models

public struct ClaudeModelUsageStats: Codable, Equatable, Sendable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheReadInputTokens: Int
    public let cacheCreationInputTokens: Int
    public let costUSD: Double?

    public init(
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        cacheReadInputTokens: Int = 0,
        cacheCreationInputTokens: Int = 0,
        costUSD: Double? = 0
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.costUSD = costUSD
    }

    public var totalTokens: Int {
        inputTokens + outputTokens + cacheReadInputTokens + cacheCreationInputTokens
    }
}

public struct ClaudeDailyActivity: Codable, Equatable, Sendable {
    public let date: String
    public let messageCount: Int
    public let sessionCount: Int
    public let toolCallCount: Int?

    public init(
        date: String,
        messageCount: Int,
        sessionCount: Int,
        toolCallCount: Int? = nil
    ) {
        self.date = date
        self.messageCount = messageCount
        self.sessionCount = sessionCount
        self.toolCallCount = toolCallCount
    }
}

public struct ClaudeStatsData: Codable, Equatable, Sendable {
    public let version: Int?
    public let lastComputedDate: String?
    public let totalSessions: Int
    public let totalMessages: Int
    public let firstSessionDate: String?
    public let dailyActivity: [ClaudeDailyActivity]?
    public let modelUsage: [String: ClaudeModelUsageStats]?

    public init(
        version: Int? = 2,
        lastComputedDate: String? = nil,
        totalSessions: Int = 0,
        totalMessages: Int = 0,
        firstSessionDate: String? = nil,
        dailyActivity: [ClaudeDailyActivity]? = nil,
        modelUsage: [String: ClaudeModelUsageStats]? = nil
    ) {
        self.version = version
        self.lastComputedDate = lastComputedDate
        self.totalSessions = totalSessions
        self.totalMessages = totalMessages
        self.firstSessionDate = firstSessionDate
        self.dailyActivity = dailyActivity
        self.modelUsage = modelUsage
    }

    public var aggregatedInputTokens: Int {
        modelUsage?.values.reduce(0) { $0 + $1.inputTokens } ?? 0
    }

    public var aggregatedOutputTokens: Int {
        modelUsage?.values.reduce(0) { $0 + $1.outputTokens } ?? 0
    }

    public var aggregatedCacheTokens: Int {
        modelUsage?.values.reduce(0) { $0 + $1.cacheReadInputTokens + $1.cacheCreationInputTokens } ?? 0
    }

    public var aggregatedTotalTokens: Int {
        aggregatedInputTokens + aggregatedOutputTokens + aggregatedCacheTokens
    }

    public var totalCostUSD: Double {
        modelUsage?.values.compactMap(\.costUSD).reduce(0, +) ?? 0.0
    }

    public var primaryModelName: String {
        guard let modelUsage, !modelUsage.isEmpty else { return "claude-opus-4-6" }
        let sorted = modelUsage.sorted { $0.value.totalTokens > $1.value.totalTokens }
        return sorted.first?.key ?? "claude-opus-4-6"
    }

    public var formattedTokens: String {
        Self.formatTokenCount(aggregatedTotalTokens)
    }

    public static func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000.0)
        } else {
            return "\(count)"
        }
    }
}

public struct ClaudeHistoryEntry: Identifiable, Equatable, Sendable {
    public let id: String
    public let display: String
    public let timestamp: Date
    public let project: String
    public let sessionId: String

    public init(
        id: String = UUID().uuidString,
        display: String,
        timestamp: Date,
        project: String,
        sessionId: String
    ) {
        self.id = id
        self.display = display
        self.timestamp = timestamp
        self.project = project
        self.sessionId = sessionId
    }

    public var projectName: String {
        (project as NSString).lastPathComponent
    }

    public var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

// MARK: - OpenAI Codex Models

public struct CodexSessionEntry: Identifiable, Equatable, Sendable {
    public let id: String
    public let threadName: String
    public let updatedAt: Date

    public init(
        id: String,
        threadName: String,
        updatedAt: Date
    ) {
        self.id = id
        self.threadName = threadName
        self.updatedAt = updatedAt
    }

    public var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: updatedAt, relativeTo: Date())
    }
}

public struct CodexConfigData: Equatable, Sendable {
    public var model: String
    public var reasoningEffort: String
    public var sandboxMode: String
    public var clientVersion: String

    public init(
        model: String = "gpt-6.1-sol",
        reasoningEffort: String = "low",
        sandboxMode: String = "danger-full-access",
        clientVersion: String = "0.165.0"
    ) {
        self.model = model
        self.reasoningEffort = reasoningEffort
        self.sandboxMode = sandboxMode
        self.clientVersion = clientVersion
    }
}

// MARK: - AI Provider

public enum AIProviderType: String, CaseIterable, Identifiable {
    case claudeCode = "claude"
    case codex = "codex"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .codex: return "OpenAI Codex"
        }
    }

    public var iconName: String {
        switch self {
        case .claudeCode: return "sparkles"
        case .codex: return "terminal.fill"
        }
    }
}
