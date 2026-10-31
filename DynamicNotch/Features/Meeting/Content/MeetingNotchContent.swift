//
//  MeetingNotchContent.swift
//  DynamicNotch
//

import SwiftUI

struct MeetingNotchContent: NotchContentProtocol, DynamicIslandCustomizable {
    let id = NotchContentRegistry.Meeting.active.id
    let service: MeetingControlService
    let accentColor: Color

    init(
        service: MeetingControlService = .shared,
        accentColor: Color = Color(red: 0.0, green: 0.75, blue: 0.45)
    ) {
        self.service = service
        self.accentColor = accentColor
    }

    var priority: Int { NotchContentRegistry.Meeting.active.priority }
    var isExpandable: Bool { true }
    var strokeColor: Color {
        (service.session.isMuted ? Color.red : Color(red: 0.0, green: 0.75, blue: 0.45)).opacity(0.4)
    }

    func compactSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        .init(width: baseWidth + 145, height: baseHeight)
    }

    func dynamicIslandSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        .init(width: baseWidth + 145, height: baseHeight)
    }

    func expandedSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        .init(width: max(520, baseWidth + 280), height: baseHeight + 58)
    }

    func expandedDynamicIslandSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        .init(width: max(500, baseWidth + 260), height: baseHeight + 52)
    }

    func expandedCornerRadius(baseRadius: CGFloat) -> (top: CGFloat, bottom: CGFloat) {
        (top: 19, bottom: 24)
    }

    func dynamicIslandCornerRadius(baseHeight: CGFloat) -> CGFloat {
        baseHeight * 0.5
    }

    func expandedDynamicIslandCornerRadius(baseHeight: CGFloat) -> CGFloat {
        baseHeight * 0.2
    }

    @MainActor
    func compactView() -> AnyView {
        AnyView(
            MeetingCompactNotchView(service: service)
        )
    }

    @MainActor
    func expandedView() -> AnyView {
        AnyView(
            MeetingNotchView(service: service, accentColor: accentColor)
        )
    }
}

struct MeetingCompactNotchView: View {
    @ObservedObject var service: MeetingControlService

    var body: some View {
        HStack(spacing: 0) {
            // Left: Platform Logo with status dot
            HStack(spacing: 5) {
                Circle()
                    .fill(service.session.isMuted ? Color.red : Color.green)
                    .frame(width: 6, height: 6)

                let platform = service.session.platform == .unknown ? MeetingPlatform.meet : service.session.platform
                Image(systemName: platform.iconName)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(platform.accentColor)
            }
            .padding(.leading, 8)

            Spacer()

            // Right: Duration + Mic indicator
            HStack(spacing: 5) {
                Text(service.session.formattedDuration)
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                Image(systemName: service.session.isMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(service.session.isMuted ? Color.red : Color.green)
            }
            .padding(.trailing, 8)
        }
    }
}
