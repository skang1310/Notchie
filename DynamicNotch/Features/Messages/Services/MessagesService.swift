import Foundation
internal import AppKit
import SwiftUI
import Combine

public protocol MessagesProviderProtocol: Sendable {
    func fetchRecentConversations(limit: Int) -> [MessageConversation]
    func sendMessage(text: String, toChatId: String) -> Bool
}

public final class DefaultMessagesProvider: MessagesProviderProtocol, @unchecked Sendable {
    public init() {}

    public func fetchRecentConversations(limit: Int) -> [MessageConversation] {
        let maxLimit = max(1, min(30, limit))
        let scriptSource = """
        tell application "Messages"
            set out to ""
            set cCount to count of chats
            if cCount > \(maxLimit) then set cCount to \(maxLimit)
            repeat with i from 1 to cCount
                set c to chat i
                set cId to id of c
                set cName to ""
                set cHandle to ""
                try
                    set p to 1st participant of c
                    set cName to name of p
                    set cHandle to handle of p
                    if cName is missing value or cName is "" then
                        set cName to cHandle
                    end if
                on error
                    set cName to name of c
                end try
                if cName is missing value or cName is "" then set cName to "Group"
                if cHandle is missing value then set cHandle to ""
                set out to out & cId & "::" & cName & "::" & cHandle & "\\n"
            end repeat
            return out
        end tell
        """

        guard let script = NSAppleScript(source: scriptSource) else { return [] }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        guard error == nil, let stringValue = result.stringValue else { return [] }

        var list: [MessageConversation] = []
        let lines = stringValue.components(separatedBy: "\n")
        for line in lines {
            let parts = line.components(separatedBy: "::")
            guard parts.count >= 2 else { continue }
            let id = parts[0].trimmingCharacters(in: .whitespaces)
            let name = parts[1].trimmingCharacters(in: .whitespaces)
            let handle = parts.count > 2 ? parts[2].trimmingCharacters(in: .whitespaces) : ""
            if !id.isEmpty && !name.isEmpty {
                list.append(
                    MessageConversation(
                        id: id,
                        displayName: name,
                        handle: handle.isEmpty ? name : handle,
                        service: id.contains("chat") ? "Group" : "iMessage"
                    )
                )
            }
        }
        return list
    }

    public func sendMessage(text: String, toChatId: String) -> Bool {
        let cleanText = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let cleanId = toChatId
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let scriptSource = """
        tell application "Messages"
            set targetChat to chat id "\(cleanId)"
            send "\(cleanText)" to targetChat
        end tell
        """

        guard let script = NSAppleScript(source: scriptSource) else { return false }
        var error: NSDictionary?
        _ = script.executeAndReturnError(&error)
        return error == nil
    }
}

@MainActor
public final class MessagesService: ObservableObject {
    public static let shared = MessagesService()

    @Published public private(set) var conversations: [MessageConversation] = []
    @Published public var selectedConversation: MessageConversation?
    @Published public private(set) var messagesByChatId: [String: [ChatMessageItem]] = [:]
    @Published public private(set) var isLoading: Bool = false

    private let provider: MessagesProviderProtocol

    public init(provider: MessagesProviderProtocol = DefaultMessagesProvider()) {
        self.provider = provider
        loadConversations()
    }

    public func loadConversations(limit: Int = 15) {
        isLoading = true
        let prov = provider
        Task.detached {
            let items = prov.fetchRecentConversations(limit: limit)
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.conversations = items
                self.isLoading = false
                if self.selectedConversation == nil || !items.contains(where: { $0.id == self.selectedConversation?.id }) {
                    self.selectedConversation = items.first
                }
            }
        }
    }

    public func selectConversation(_ conv: MessageConversation) {
        self.selectedConversation = conv
    }

    public func sendMessage(text: String, to conversation: MessageConversation) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let item = ChatMessageItem(text: trimmed, isFromMe: true, date: Date(), status: .sent)
        var current = messagesByChatId[conversation.id] ?? []
        current.append(item)
        messagesByChatId[conversation.id] = current

        // Sound feedback
        NSSound(named: "Pop")?.play()

        let prov = provider
        let chatId = conversation.id
        Task.detached {
            _ = prov.sendMessage(text: trimmed, toChatId: chatId)
        }
    }

    public func sendReaction(emoji: String, to conversation: MessageConversation) {
        sendMessage(text: emoji, to: conversation)
    }

    public func openMessagesApp() {
        if let url = URL(string: "messages://") {
            NSWorkspace.shared.open(url)
        }
    }
}
