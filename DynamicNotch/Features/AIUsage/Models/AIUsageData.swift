//
//  AIUsageData.swift
//  DynamicNotch
//

import Foundation
import SwiftUI

// MARK: - Quota & Rate Limit Health

public enum AIQuotaHealth: String, Codable, Sendable {
    case optimal    // < 70% used
    case warning    // 70% - 89% used
    case critical   // >= 90% used

    public var color: Color {
        switch self {
        case .optimal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }

    public func title(isKorean: Bool) -> String {
        switch self {
        case .optimal:
            return isKorean ? "여유 있음" : "Optimal"
        case .warning:
            return isKorean ? "사용량 주의" : "High Usage"
        case .critical:
            return isKorean ? "한도 임박" : "Limit Reached"
        }
    }
}

// MARK: - Codenotch Rate Limit Window

public struct AIQuotaWindow: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let titleKo: String
    public let subtitle: String
    public let subtitleKo: String
    public let utilization: Double          // 0.0 to 100.0 (percentage consumed)
    public let resetsAt: Date
    public let totalLimitDesc: String?

    public nonisolated init(
        id: String = UUID().uuidString,
        title: String,
        titleKo: String,
        subtitle: String = "Rolling window",
        subtitleKo: String = "롤링 한도",
        utilization: Double,
        resetsAt: Date,
        totalLimitDesc: String? = nil
    ) {
        self.id = id
        self.title = title
        self.titleKo = titleKo
        self.subtitle = subtitle
        self.subtitleKo = subtitleKo
        self.utilization = max(0.0, min(100.0, utilization))
        self.resetsAt = resetsAt
        self.totalLimitDesc = totalLimitDesc
    }

    public var remainingPercentage: Double {
        max(0.0, min(100.0, 100.0 - utilization))
    }

    public var health: AIQuotaHealth {
        if utilization >= 90.0 {
            return .critical
        } else if utilization >= 70.0 {
            return .warning
        } else {
            return .optimal
        }
    }

    public func localizedTitle(isKorean: Bool) -> String {
        isKorean ? titleKo : title
    }

    public func localizedSubtitle(isKorean: Bool) -> String {
        isKorean ? subtitleKo : subtitle
    }

    public func formattedCountdown(isKorean: Bool, now: Date = Date()) -> String {
        if utilization <= 0.0 {
            return isKorean ? "한도 전체 사용 가능" : "Full Quota Available"
        }
        let diff = resetsAt.timeIntervalSince(now)
        if diff <= 0 {
            return isKorean ? "방금 리셋됨" : "Just reset"
        }
        let totalSeconds = Int(diff)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60

        if isKorean {
            if days > 0 {
                return "\(days)일 \(hours)시간 후 리셋"
            } else if hours > 0 {
                return "\(hours)시간 \(minutes)분 후 리셋"
            } else {
                return "\(max(1, minutes))분 후 리셋"
            }
        } else {
            if days > 0 {
                return "Resets in \(days)d \(hours)h"
            } else if hours > 0 {
                return "Resets in \(hours)h \(minutes)m"
            } else {
                return "Resets in \(max(1, minutes))m"
            }
        }
    }

    public func formattedExactTime(isKorean: Bool, now: Date = Date()) -> String {
        if utilization <= 0.0 {
            return isKorean ? "즉시 사용 가능" : "Ready"
        }
        if resetsAt <= now {
            return isKorean ? "방금" : "Just now"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isKorean ? "ko_KR" : "en_US")
        let isToday = Calendar.current.isDateInToday(resetsAt)
        let isTomorrow = Calendar.current.isDateInTomorrow(resetsAt)

        if isToday {
            formatter.dateFormat = isKorean ? "a h:mm" : "h:mm a"
            let timeStr = formatter.string(from: resetsAt)
            return isKorean ? "오늘 \(timeStr)" : "Today \(timeStr)"
        } else if isTomorrow {
            formatter.dateFormat = isKorean ? "a h:mm" : "h:mm a"
            let timeStr = formatter.string(from: resetsAt)
            return isKorean ? "내일 \(timeStr)" : "Tomorrow \(timeStr)"
        } else {
            formatter.dateFormat = isKorean ? "M월 d일 a h:mm" : "MMM d, h:mm a"
            return formatter.string(from: resetsAt)
        }
    }

    public func formattedResetDetail(isKorean: Bool, now: Date = Date(), includeCountdown: Bool = true) -> String {
        if utilization <= 0.0 {
            return isKorean ? "한도 전체 사용 가능 · 즉시 사용 가능" : "Full Quota Available · Ready"
        }
        let diff = resetsAt.timeIntervalSince(now)
        if diff <= 0 {
            return isKorean ? "방금 리셋됨" : "Just reset"
        }

        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(resetsAt)
        let isTomorrow = calendar.isDateInTomorrow(resetsAt)

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: isKorean ? "ko_KR" : "en_US")
        timeFormatter.dateFormat = isKorean ? "a h:mm" : "h:mm a"
        let timeStr = timeFormatter.string(from: resetsAt)

        let exactLabel: String
        if isToday {
            exactLabel = timeStr
        } else if isTomorrow {
            exactLabel = isKorean ? "내일 \(timeStr)" : "Tomorrow \(timeStr)"
        } else {
            let dayFormatter = DateFormatter()
            dayFormatter.locale = Locale(identifier: isKorean ? "ko_KR" : "en_US")
            dayFormatter.dateFormat = isKorean ? "E a h:mm" : "E h:mm a"
            exactLabel = dayFormatter.string(from: resetsAt)
        }

        if includeCountdown {
            let totalSeconds = Int(diff)
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60

            if isKorean {
                let countdownPart = hours > 0 ? "\(hours)시간 \(minutes)분 후" : "\(max(1, minutes))분 후"
                let suffix = utilization >= 100.0 ? " (한도 소진)" : ""
                return "\(exactLabel) 리셋 · \(countdownPart)\(suffix)"
            } else {
                let countdownPart = hours > 0 ? "in \(hours) hr \(minutes) min" : "in \(max(1, minutes)) min"
                let suffix = utilization >= 100.0 ? " (Limit Reached)" : ""
                return "Resets \(exactLabel) · \(countdownPart)\(suffix)"
            }
        } else {
            return isKorean ? "\(exactLabel) 리셋" : "Resets \(exactLabel)"
        }
    }
}

// MARK: - Provider Usage Summary (Codenotch Style)

public struct AIProviderUsageSummary: Identifiable, Equatable, Sendable {
    public let id: String
    public let provider: AIProviderType
    public let primaryWindow: AIQuotaWindow     // 5-Hour rolling window
    public let secondaryWindow: AIQuotaWindow?  // 7-Day weekly quota
    public let activeModel: String
    public let isLiveAPI: Bool                  // True if fetched from OAuth /usage API
    public let lastUpdated: Date
    public let tierBadge: String                // e.g. "Max 5x", "Plus", "Advanced"
    public let activeSessionTitle: String?      // e.g. "DynamicNotch", "Droppy 기능 적용", etc.
    public let activeSessionSubtitle: String?   // snippet or prompt
    public let activeSessionDate: Date?         // last session timestamp
    public let isSessionActive: Bool            // true if active session running or recent

    public nonisolated init(
        id: String = UUID().uuidString,
        provider: AIProviderType,
        primaryWindow: AIQuotaWindow,
        secondaryWindow: AIQuotaWindow? = nil,
        activeModel: String,
        isLiveAPI: Bool = false,
        lastUpdated: Date = Date(),
        tierBadge: String = "Pro",
        activeSessionTitle: String? = nil,
        activeSessionSubtitle: String? = nil,
        activeSessionDate: Date? = nil,
        isSessionActive: Bool = false
    ) {
        self.id = id
        self.provider = provider
        self.primaryWindow = primaryWindow
        self.secondaryWindow = secondaryWindow
        self.activeModel = activeModel
        self.isLiveAPI = isLiveAPI
        self.lastUpdated = lastUpdated
        self.tierBadge = tierBadge
        self.activeSessionTitle = activeSessionTitle
        self.activeSessionSubtitle = activeSessionSubtitle
        self.activeSessionDate = activeSessionDate
        self.isSessionActive = isSessionActive
    }

    public func localizedTimeAgo(isKorean: Bool, now: Date = Date()) -> String? {
        guard let date = activeSessionDate else { return nil }
        let diff = max(0, Int(now.timeIntervalSince(date)))
        if diff < 60 {
            return isKorean ? "방금 전" : "just now"
        } else if diff < 3600 {
            let m = max(1, diff / 60)
            return isKorean ? "\(m)분 전" : "\(m) min ago"
        } else if diff < 86400 {
            let h = diff / 3600
            return isKorean ? "\(h)시간 전" : "\(h)h ago"
        } else {
            let d = diff / 86400
            return isKorean ? "\(d)일 전" : "\(d)d ago"
        }
    }
}

// MARK: - Anthropic OAuth Response Model

public struct AnthropicOAuthUsageResponse: Codable, Sendable {
    public struct QuotaTier: Codable, Sendable {
        public let utilization: Double?
        public let resets_at: String?
    }

    public let five_hour: QuotaTier?
    public let seven_day: QuotaTier?
    public let seven_day_sonnet: QuotaTier?
    public let seven_day_opus: QuotaTier?
}

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

    public nonisolated var primaryModelName: String {
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
    public var isRateLimited: Bool
    public var rateLimitResetsAt: Date?

    public init(
        model: String = "gpt-6.1-sol",
        reasoningEffort: String = "low",
        sandboxMode: String = "danger-full-access",
        clientVersion: String = "0.165.0",
        isRateLimited: Bool = false,
        rateLimitResetsAt: Date? = nil
    ) {
        self.model = model
        self.reasoningEffort = reasoningEffort
        self.sandboxMode = sandboxMode
        self.clientVersion = clientVersion
        self.isRateLimited = isRateLimited
        self.rateLimitResetsAt = rateLimitResetsAt
    }
}

// MARK: - Gemini Models

public struct GeminiSessionEntry: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let stepCount: Int
    public let lastModified: Date

    public init(
        id: String = UUID().uuidString,
        title: String,
        stepCount: Int = 0,
        lastModified: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.stepCount = stepCount
        self.lastModified = lastModified
    }
}

// MARK: - AI Provider

public enum AIProviderType: String, CaseIterable, Identifiable {
    case claudeCode = "claude"
    case codex = "codex"
    case gemini = "gemini"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .codex: return "OpenAI Codex"
        case .gemini: return "Google Gemini"
        }
    }

    public var shortDisplayName: String {
        switch self {
        case .claudeCode: return "Claude"
        case .codex: return "Codex"
        case .gemini: return "Gemini"
        }
    }

    public var iconName: String {
        switch self {
        case .claudeCode: return "sparkles"
        case .codex: return "terminal.fill"
        case .gemini: return "wand.and.stars"
        }
    }
}
