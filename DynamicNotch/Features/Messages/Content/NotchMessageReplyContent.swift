import SwiftUI

struct NotchMessageReplyContent: NotchContentProtocol, DynamicIslandCustomizable {
    let message: NotchIncomingMessage
    let onSend: (String) -> Void
    let onDismiss: () -> Void

    var id: String { "message.reply." + message.id }
    var priority: Int { 950 } // High alert priority
    var strokeColor: Color { message.app.accentColor.opacity(0.65) }

    var isExpandable: Bool { true }
    var expandsOnTap: Bool { true }
    var pinsExpandedInteraction: Bool { true }
    var allowsPressScaleEffect: Bool { false }

    func compactSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        CGSize(width: max(320, baseWidth + 180), height: baseHeight + 36)
    }

    func expandedSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        CGSize(width: max(420, baseWidth + 260), height: baseHeight + 165)
    }

    func dynamicIslandSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        compactSize(baseWidth: baseWidth, baseHeight: baseHeight)
    }

    func compactCornerRadius(baseRadius: CGFloat) -> (top: CGFloat, bottom: CGFloat) {
        (top: 24, bottom: 32)
    }

    func expandedCornerRadius(baseRadius: CGFloat) -> (top: CGFloat, bottom: CGFloat) {
        (top: 28, bottom: 36)
    }

    func dynamicIslandCornerRadius(baseHeight: CGFloat) -> CGFloat {
        baseHeight * 0.35
    }

    @MainActor
    func compactView() -> AnyView {
        AnyView(
            HStack(spacing: 8) {
                // App Icon Badge
                ZStack {
                    Circle()
                        .fill(message.app.accentColor)
                        .frame(width: 22, height: 22)

                    Image(systemName: message.app.iconName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(message.sender)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(message.app.displayName)
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundStyle(message.app.accentColor)
                    }

                    Text(message.text)
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 3) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.system(size: 9))
                    Text(privacyText("Reply", "답장"))
                        .font(.system(size: 9.5, weight: .bold))
                }
                .foregroundStyle(message.app.accentColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(message.app.accentColor.opacity(0.2))
                )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        )
    }

    @MainActor
    func expandedView() -> AnyView {
        AnyView(
            NotchMessageQuickReplyView(
                message: message,
                onDismiss: onDismiss,
                onSend: onSend
            )
        )
    }
}
