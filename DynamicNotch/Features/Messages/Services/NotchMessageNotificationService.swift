import Foundation
internal import AppKit
import SwiftUI
import Combine

@MainActor
public final class NotchMessageNotificationService: ObservableObject {
    public static let shared = NotchMessageNotificationService()

    @Published public private(set) var activeMessage: NotchIncomingMessage?
    @Published public private(set) var recentIncomingMessages: [NotchIncomingMessage] = []

    private var monitorTimer: AnyCancellable?
    private var lastSeenMessageId: String?
    private var lastKnownChatIds: Set<String> = []

    public init() {
        startMonitoring()
    }

    public func startMonitoring() {
        guard monitorTimer == nil else { return }
        // Poll for incoming message notifications periodically
        monitorTimer = Timer.publish(every: 2.5, tolerance: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkForIncomingBanners()
            }
    }

    public func stopMonitoring() {
        monitorTimer?.cancel()
        monitorTimer = nil
    }

    /// Posts an incoming message notification to the Notch Dynamic Island with quick reply capability.
    public func postIncomingMessage(_ message: NotchIncomingMessage) {
        self.activeMessage = message
        self.recentIncomingMessages.insert(message, at: 0)
        if self.recentIncomingMessages.count > 10 {
            self.recentIncomingMessages.removeLast()
        }

        let content = NotchMessageReplyContent(
            message: message,
            onSend: { [weak self] reply in
                self?.dispatchReply(reply, to: message)
            },
            onDismiss: { [weak self] in
                self?.dismissActiveMessage()
            }
        )

        // Show transient HUD / Interactive notification in Notch
        if let model = QuickToolsStore.shared.notchViewModel {
            model.send(.showTemporaryNotification(content, duration: 8.0))
        }
    }

    public func dismissActiveMessage() {
        guard let active = activeMessage else { return }
        self.activeMessage = nil
        if let model = QuickToolsStore.shared.notchViewModel {
            model.send(.hideLiveActivity(id: "message.reply." + active.id))
        }
    }

    public func dispatchReply(_ text: String, to message: NotchIncomingMessage) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch message.app {
        case .iMessage:
            if let chatId = message.chatId, !chatId.isEmpty {
                _ = DefaultMessagesProvider().sendMessage(text: trimmed, toChatId: chatId)
            } else if let firstConv = MessagesService.shared.conversations.first(where: { $0.displayName == message.sender }) {
                MessagesService.shared.sendMessage(text: trimmed, to: firstConv)
            } else if let topConv = MessagesService.shared.conversations.first {
                MessagesService.shared.sendMessage(text: trimmed, to: topConv)
            }
        case .slack:
            sendSlackReply(trimmed, sender: message.sender)
        case .other:
            // Fallback for generic messaging apps: activate app and copy reply
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(trimmed, forType: .string)
        }
    }

    private func sendSlackReply(_ text: String, sender: String) {
        // Find Slack running application and activate it with message staged
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.tinyspeck.slackmacgap")
        if let slack = apps.first {
            slack.activate(options: [.activateIgnoringOtherApps])
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            // Trigger paste action via CGEvent tap after brief focus delay
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 200_000_000)
                guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true), // 'V'
                      let up = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false) else { return }
                down.flags = .maskCommand
                up.flags = .maskCommand
                down.postToPid(slack.processIdentifier)
                up.postToPid(slack.processIdentifier)
            }
        }
    }

    /// Inspects NotificationCenter window list for active incoming message banners (Messages, Slack, etc.)
    public func checkForIncomingBanners() {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return }

        for win in list {
            guard let owner = win[kCGWindowOwnerName as String] as? String,
                  let name = win[kCGWindowName as String] as? String,
                  !name.isEmpty else { continue }

            let lowerOwner = owner.lowercased()
            let lowerName = name.lowercased()

            // Check if Notification Center has displayed a message banner
            if lowerOwner.contains("notificationcenter") || lowerOwner.contains("알림") {
                // Banner name format: "Sender — Text" or "App: Sender: Text"
                if lowerName.contains("slack") || lowerName.contains("메시지") || lowerName.contains("messages") {
                    let bannerId = "\(owner):\(name)"
                    if bannerId != lastSeenMessageId {
                        lastSeenMessageId = bannerId
                        parseAndPostBanner(name: name, owner: owner)
                    }
                }
            }
        }
    }

    private func parseAndPostBanner(name: String, owner: String) {
        let app: MessageAppSource = name.lowercased().contains("slack") ? .slack : .iMessage
        let clean = name.replacingOccurrences(of: "Slack: ", with: "")
                        .replacingOccurrences(of: "Messages: ", with: "")
                        .replacingOccurrences(of: "메시지: ", with: "")

        let parts = clean.components(separatedBy: " — ")
        let sender: String
        let text: String
        if parts.count >= 2 {
            sender = parts[0].trimmingCharacters(in: .whitespaces)
            text = parts[1].trimmingCharacters(in: .whitespaces)
        } else {
            sender = app.displayName
            text = clean
        }

        let incoming = NotchIncomingMessage(
            sender: sender,
            text: text,
            app: app
        )
        postIncomingMessage(incoming)
    }
}
