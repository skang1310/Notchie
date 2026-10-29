import SwiftUI

enum NotchBackgroundStyle: String, CaseIterable {
    case black
    case dynamicGlass
    case liquidGlass

    static var availableOptions: [Self] {
        return Array(allCases)
    }

    var title: LocalizedStringKey {
        switch self {
        case .black: return "settings.notch.backgroundStyle.black"
        case .dynamicGlass: return "shelf.finish.dynamic"
        case .liquidGlass: return "shelf.finish.liquid"
        }
    }

    var symbolName: String {
        switch self {
        case .black: return "circle.fill"
        case .dynamicGlass: return "circle.lefthalf.filled"
        case .liquidGlass: return "drop.fill"
        }
    }

    var isSupportedOnCurrentSystem: Bool {
        return true
    }

    static func resolved(_ rawValue: String?) -> NotchBackgroundStyle {
        guard let rawValue, let style = NotchBackgroundStyle(rawValue: rawValue) else {
            return .black
        }

        return style
    }
}
