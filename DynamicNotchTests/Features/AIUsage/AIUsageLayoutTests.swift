import XCTest
@testable import DynamicNotch

final class AIUsageLayoutTests: XCTestCase {
    func testAIUsageMetricsFixedBoundsAcrossSizes() {
        // Standard notch size
        let standardSize = CGSize(width: 780, height: 260)
        let metrics = AIUsagePanelMetrics(size: standardSize)

        XCTAssertEqual(AIUsagePanelMetrics.controlsHeight, 20)
        XCTAssertEqual(AIUsagePanelMetrics.footerHeight, 12)
        XCTAssertGreaterThan(metrics.cardWidth, 0)
        XCTAssertGreaterThan(metrics.cardsHeight, 0)

        // Small vertical monitor size
        let smallSize = CGSize(width: 400, height: 120)
        let smallMetrics = AIUsagePanelMetrics(size: smallSize)

        XCTAssertEqual(AIUsagePanelMetrics.controlsHeight, 20)
        XCTAssertEqual(AIUsagePanelMetrics.footerHeight, 12)
        XCTAssertGreaterThanOrEqual(smallMetrics.cardWidth, 0)
        XCTAssertGreaterThanOrEqual(smallMetrics.cardsHeight, 0)

        // Ensure vertical bounds calculation never overflows or becomes negative
        let zeroSize = CGSize.zero
        let zeroMetrics = AIUsagePanelMetrics(size: zeroSize)
        XCTAssertEqual(zeroMetrics.cardWidth, 0)
        XCTAssertEqual(zeroMetrics.cardsHeight, 0)
    }

    func testCardsHeightIsDeterministic() {
        let sizeA = CGSize(width: 700, height: 250)
        let metricsA = AIUsagePanelMetrics(size: sizeA)
        let expectedHeight = max(0, 250 - AIUsagePanelMetrics.verticalPadding * 2 - AIUsagePanelMetrics.controlsHeight - AIUsagePanelMetrics.footerHeight - AIUsagePanelMetrics.spacing * 2)
        XCTAssertEqual(metricsA.cardsHeight, expectedHeight)
    }
}
