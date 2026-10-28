//
//  FaceIDNotchContent.swift
//  DynamicNotch
//

import SwiftUI

struct FaceIDNotchContent: NotchContentProtocol, DynamicIslandCustomizable {
    let id: String = NotchContentRegistry.FaceID.scanning.id
    var priority: Int { NotchContentPriority.faceID }

    let service: FaceIDService
    var style: FaceIDPresentationStyle = .expanded

    var strokeColor: Color {
        let accent = ApplicationSettingsStore.currentCustomAccentColor()
        if service.state.isSuccess {
            return accent.opacity(0.45)
        } else if service.state.isFailed {
            return .red.opacity(0.35)
        } else {
            return accent.opacity(0.28)
        }
    }

    func compactSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        switch style {
        case .expanded:
            return CGSize(width: baseWidth + 46, height: baseHeight + 130)
        case .compact:
            return CGSize(width: baseWidth + 95, height: baseHeight + 10)
        }
    }

    func dynamicIslandSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        switch style {
        case .expanded:
            return CGSize(width: baseWidth + 46, height: baseHeight + 124)
        case .compact:
            return CGSize(width: baseWidth + 95, height: baseHeight + 10)
        }
    }

    func compactCornerRadius(baseRadius: CGFloat) -> (top: CGFloat, bottom: CGFloat) {
        switch style {
        case .expanded:
            return (top: 24, bottom: 44)
        case .compact:
            return (top: max(4, baseRadius - 2), bottom: baseRadius + 3)
        }
    }

    func dynamicIslandCornerRadius(baseHeight: CGFloat) -> CGFloat {
        switch style {
        case .expanded:
            return baseHeight * 0.25
        case .compact:
            return (baseHeight + 6) * 0.5
        }
    }

    @MainActor
    func compactView() -> AnyView {
        AnyView(
            FaceIDNotchView(style: style, service: service)
        )
    }
}
