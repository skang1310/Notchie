import Foundation
import SwiftUI

enum NotchAnimationPreset: String, CaseIterable, Identifiable {
    case fluid
    case balanced

    var id: String { rawValue }

    static func resolved(_ rawValue: String?) -> NotchAnimationPreset {
        guard let rawValue, let preset = NotchAnimationPreset(rawValue: rawValue) else {
            return .fluid
        }
        return preset
    }

    var title: LocalizedStringKey {
        switch self {
        case .fluid:
            return "settings.general.animation.fluid"
        case .balanced:
            return "settings.general.animation.balanced"
        }
    }

    var symbolName: String {
        switch self {
        case .fluid:
            return "waveform.path.ecg.rectangle.fill"
        case .balanced:
            return "gauge"
        }
    }

    var description: String {
        switch self {
        case .fluid:
            return privacyText(
                "Organic, fluid spring motion with lively bounce matching Apple's Dynamic Island.",
                "애플 다이내믹 아일랜드 특유의 탄력적이고 유기적인 스프링 애니메이션입니다."
            )
        case .balanced:
            return privacyText(
                "Default motion with a balanced spring feel for everyday use.",
                "일상적인 사용에 적합한 균형 잡힌 스프링 모션입니다."
            )
        }
    }
}
