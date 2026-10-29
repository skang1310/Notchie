import SwiftUI

public struct MessagesNotchView: View {
    @ObservedObject var service: MessagesService
    var accentColor: Color

    @State private var replyText: String = ""
    @FocusState private var isInputFocused: Bool

    public init(
        service: MessagesService = .shared,
        accentColor: Color = .blue
    ) {
        self.service = service
        self.accentColor = accentColor
    }

    private func text(_ en: String, _ ko: String) -> String {
        Locale.preferredLanguages.first?.hasPrefix("ko") == true ? ko : en
    }

    private let quickEmojis = ["👍", "❤️", "😂", "🎉", "🙏", "🔥", "👎", "🚀"]

    public var body: some View {
        VStack(spacing: 8) {
            headerBar

            if service.conversations.isEmpty {
                emptyStateView
            } else {
                contactsCarousel

                chatThreadAndInputArea
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(red: 0.18, green: 0.55, blue: 1.0))

                Text(text("Messages Quick Reply", "메시지 즉시 답장"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Spacer()

            if let selected = service.selectedConversation {
                Text(selected.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            }

            // Refresh
            Button {
                service.loadConversations()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help(text("Refresh Chats", "대화 새로고침"))

            // Open Messages App
            Button {
                service.openMessagesApp()
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help(text("Open Messages App", "메시지 앱 열기"))
        }
    }

    // MARK: - Contacts Carousel

    private var contactsCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(service.conversations) { conv in
                    let isSelected = service.selectedConversation?.id == conv.id
                    Button {
                        service.selectConversation(conv)
                    } label: {
                        HStack(spacing: 6) {
                            // Avatar Circle
                            ZStack {
                                Circle()
                                    .fill(
                                        isSelected
                                            ? Color.blue.opacity(0.85)
                                            : Color.white.opacity(0.12)
                                    )
                                    .frame(width: 22, height: 22)

                                Text(conv.avatarInitials)
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundStyle(.white)
                            }

                            Text(conv.displayName)
                                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                .foregroundStyle(isSelected ? .white : .white.opacity(0.8))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isSelected ? Color.blue.opacity(0.3) : Color.white.opacity(0.05))
                                .overlay(
                                    Capsule(style: .continuous)
                                        .strokeBorder(
                                            isSelected ? Color.blue.opacity(0.6) : Color.white.opacity(0.1),
                                            lineWidth: 0.8
                                        )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .frame(height: 32)
    }

    // MARK: - Chat Thread & Input Area

    private var chatThreadAndInputArea: some View {
        VStack(spacing: 8) {
            // Message Bubbles Scroll Area
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        let currentMessages = (service.selectedConversation.flatMap { service.messagesByChatId[$0.id] }) ?? []

                        if currentMessages.isEmpty {
                            VStack(spacing: 4) {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white.opacity(0.35))
                                    .padding(.top, 8)

                                Text(text("Send a quick reply to", "노치에서 즉시 메시지 보내기:") + " \(service.selectedConversation?.displayName ?? "")")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                        } else {
                            ForEach(currentMessages) { msg in
                                HStack {
                                    Spacer(minLength: 40)

                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(msg.text)
                                            .font(.system(size: 12, weight: .regular))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(Color(red: 0.0, green: 0.48, blue: 1.0))
                                            )

                                        HStack(spacing: 3) {
                                            Text(msg.formattedTime)
                                                .font(.system(size: 8.5))
                                                .foregroundStyle(.white.opacity(0.5))

                                            Text(text("Delivered", "전송됨"))
                                                .font(.system(size: 8.5, weight: .medium))
                                                .foregroundStyle(.white.opacity(0.5))
                                        }
                                    }
                                }
                                .id(msg.id)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(maxHeight: 88)
                .onChange(of: service.messagesByChatId.count) { _ in
                    if let last = service.selectedConversation.flatMap({ service.messagesByChatId[$0.id]?.last }) {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Quick Emoji Reaction Bar
            HStack(spacing: 6) {
                ForEach(quickEmojis, id: \.self) { emoji in
                    Button {
                        if let selected = service.selectedConversation {
                            service.sendReaction(emoji: emoji, to: selected)
                        }
                    } label: {
                        Text(emoji)
                            .font(.system(size: 14))
                            .frame(width: 28, height: 26)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .help(text("React with", "반응 보내기:") + " \(emoji)")
                }

                Spacer()
            }

            // Quick Reply Input Field
            HStack(spacing: 6) {
                TextField(
                    text("Reply to", "답장 입력:") + " \(service.selectedConversation?.displayName ?? "Chat")...",
                    text: $replyText
                )
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .focused($isInputFocused)
                .onSubmit {
                    sendReply()
                }

                if !replyText.isEmpty {
                    Button {
                        replyText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    sendReply()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(
                            replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color.white.opacity(0.25)
                                : Color(red: 0.0, green: 0.48, blue: 1.0)
                        )
                }
                .buttonStyle(.plain)
                .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help(text("Send Reply (Return)", "답장 전송 (Return)"))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.8)
                    )
            )
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
                )
        )
    }

    private func sendReply() {
        let textToSend = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textToSend.isEmpty, let selected = service.selectedConversation else { return }
        service.sendMessage(text: textToSend, to: selected)
        replyText = ""
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.exclamationmark.bubble.right.fill")
                .font(.system(size: 24))
                .foregroundStyle(.white.opacity(0.4))

            Text(text("No Messages Conversations Found", "메시지 대화 목록을 불러올 수 없습니다"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)

            Button {
                service.openMessagesApp()
            } label: {
                Text(text("Open Messages", "메시지 앱 열기"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.blue)
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
