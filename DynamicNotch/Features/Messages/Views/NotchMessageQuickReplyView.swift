import SwiftUI
internal import AppKit

public struct NotchMessageQuickReplyView: View {
    public let message: NotchIncomingMessage
    public let onDismiss: () -> Void
    public let onSend: (String) -> Void

    @State private var replyText: String = ""
    @State private var isSent: Bool = false
    @FocusState private var isInputFocused: Bool

    private let quickEmojis = ["👍", "❤️", "😂", "🎉", "🙏", "🔥"]

    public init(
        message: NotchIncomingMessage,
        onDismiss: @escaping () -> Void,
        onSend: @escaping (String) -> Void
    ) {
        self.message = message
        self.onDismiss = onDismiss
        self.onSend = onSend
    }

    private func text(_ en: String, _ ko: String) -> String {
        privacyText(en, ko)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: App Icon, Sender & Close Button
            HStack(spacing: 7) {
                // Sender Avatar
                ZStack {
                    Circle()
                        .fill(message.app.accentColor)
                        .frame(width: 22, height: 22)

                    Text(message.avatarInitials)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(message.sender)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(message.app.displayName)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(message.app.accentColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(
                                Capsule()
                                    .fill(message.app.accentColor.opacity(0.18))
                            )
                    }
                }

                Spacer()

                if isSent {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.green)
                        Text(text("Sent", "전송됨"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.green)
                    }
                    .transition(.opacity)
                }

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help(text("Dismiss", "닫기"))
            }

            // Incoming Message Bubble
            Text(message.text)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .lineLimit(3)

            // Quick Emoji Reaction Buttons
            HStack(spacing: 5) {
                ForEach(quickEmojis, id: \.self) { emoji in
                    Button {
                        submitReply(emoji)
                    } label: {
                        Text(emoji)
                            .font(.system(size: 13))
                            .padding(.horizontal, 5.5)
                            .padding(.vertical, 2.5)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.6))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Inline Reply Field & Send Button
            HStack(spacing: 6) {
                TextField(text("Type a reply…", "답장 입력…"), text: $replyText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
                    .focused($isInputFocused)
                    .onSubmit {
                        submitReply(replyText)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(isInputFocused ? message.app.accentColor.opacity(0.7) : Color.white.opacity(0.12), lineWidth: 0.8)
                            )
                    )

                Button {
                    submitReply(replyText)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(!replyText.trimmingCharacters(in: .whitespaces).isEmpty ? message.app.accentColor : Color.white.opacity(0.2))
                }
                .buttonStyle(.plain)
                .disabled(replyText.trimmingCharacters(in: .whitespaces).isEmpty)
                .help(text("Send Reply", "답장 보내기"))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            isInputFocused = true
        }
    }

    private func submitReply(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSend(trimmed)
        withAnimation(.easeOut(duration: 0.2)) {
            isSent = true
            replyText = ""
        }
        NSSound(named: "Pop")?.play()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            onDismiss()
        }
    }
}
