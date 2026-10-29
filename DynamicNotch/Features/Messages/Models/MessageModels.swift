import Foundation

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
