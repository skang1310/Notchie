import Foundation

/// The host owns the panel size. Quota/error content may scroll but cannot resize the hub header.
nonisolated struct AIUsagePanelMetrics {
    static let spacing: CGFloat = 8
    static let controlsHeight: CGFloat = 20
    static let footerHeight: CGFloat = 12
    static let horizontalPadding: CGFloat = 6
    static let verticalPadding: CGFloat = 4
    let cardWidth: CGFloat
    let cardsHeight: CGFloat
    init(size: CGSize) {
        cardWidth = max(0, (size.width - Self.horizontalPadding * 2 - Self.spacing * 2) / 3)
        cardsHeight = max(0, size.height - Self.verticalPadding * 2 - Self.controlsHeight - Self.footerHeight - Self.spacing * 2)
    }
}
