import Foundation
import SwiftUI

public struct MessageConversation: Identifiable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let handle: String
    public let service: String
    public var lastMessageText: String?
    public var lastMessageDate: Date

    public init(
        id: String,
        displayName: String,
        handle: String,
        service: String = "iMessage",
        lastMessageText: String? = nil,
        lastMessageDate: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.handle = handle
        self.service = service
        self.lastMessageText = lastMessageText
        self.lastMessageDate = lastMessageDate
    }

    public var avatarInitials: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "?" }
        let components = trimmed.components(separatedBy: " ").filter { !$0.isEmpty }
        if components.count >= 2 {
            let first = components[0].prefix(1)
            let second = components[1].prefix(1)
            return "\(first)\(second)".uppercased()
        } else {
            return String(trimmed.prefix(2)).uppercased()
        }
    }
}

public enum MessageDeliveryStatus: String, Sendable {
    case sending
    case sent
    case failed
}

public struct ChatMessageItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let text: String
    public let isFromMe: Bool
    public let date: Date
    public var status: MessageDeliveryStatus

    public init(
        id: UUID = UUID(),
        text: String,
        isFromMe: Bool = true,
        date: Date = Date(),
        status: MessageDeliveryStatus = .sent
    ) {
        self.id = id
        self.text = text
        self.isFromMe = isFromMe
        self.date = date
        self.status = status
    }

    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

public enum MessageAppSource: String, CaseIterable, Identifiable, Sendable {
    case iMessage
    case slack
    case other

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .iMessage: return "Messages"
        case .slack: return "Slack"
        case .other: return "Message"
        }
    }

    public var iconName: String {
        switch self {
        case .iMessage: return "bubble.left.and.bubble.right.fill"
        case .slack: return "number"
        case .other: return "envelope.fill"
        }
    }

    public var accentColor: Color {
        switch self {
        case .iMessage: return Color(red: 0.18, green: 0.55, blue: 1.0)
        case .slack: return Color(red: 0.88, green: 0.11, blue: 0.45)
        case .other: return Color.green
        }
    }
}

public struct NotchIncomingMessage: Identifiable, Sendable {
    public let id: String
    public let sender: String
    public let text: String
    public let app: MessageAppSource
    public let chatId: String?
    public let date: Date

    public init(
        id: String = UUID().uuidString,
        sender: String,
        text: String,
        app: MessageAppSource = .iMessage,
        chatId: String? = nil,
        date: Date = Date()
    ) {
        self.id = id
        self.sender = sender
        self.text = text
        self.app = app
        self.chatId = chatId
        self.date = date
    }

    public var avatarInitials: String {
        let trimmed = sender.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "?" }
        let comps = trimmed.components(separatedBy: " ").filter { !$0.isEmpty }
        if comps.count >= 2 {
            return "\(comps[0].prefix(1))\(comps[1].prefix(1))".uppercased()
        }
        return String(trimmed.prefix(2)).uppercased()
    }
}
