import XCTest
import SwiftUI
import AppKit
@testable import DynamicNotch

@MainActor
final class AIUsagePanelLayoutTests: XCTestCase {
    func testAllColumnsAndChromeStayInsideSmallPanel() {
        for size in [CGSize(width: 660, height: 190), CGSize(width: 720, height: 230), CGSize(width: 940, height: 300)] {
            let layout = AIUsagePanelMetrics(size: size)
            XCTAssertGreaterThan(layout.cardsHeight, 0)
            let totalHeight = AIUsagePanelMetrics.controlsHeight + AIUsagePanelMetrics.footerHeight + layout.cardsHeight
                + AIUsagePanelMetrics.spacing * 2 + AIUsagePanelMetrics.verticalPadding * 2
            XCTAssertEqual(totalHeight, size.height, accuracy: 0.001)
            XCTAssertLessThanOrEqual(layout.cardWidth * 3 + AIUsagePanelMetrics.spacing * 2 + AIUsagePanelMetrics.horizontalPadding * 2, size.width + 0.001)
        }
    }
    func testLoadingAndUnavailableResultsDoNotIncreasePanelMinimumHeight() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let service = AIUsageService(claudeDirectory: directory, codexDirectory: directory, geminiDirectory: directory)
        let host = NSHostingView(rootView: AIUsageNotchView(service: service))
        host.sizingOptions = []
        host.frame = CGRect(x: 0, y: 0, width: 690, height: 190)
        host.layoutSubtreeIfNeeded()
        XCTAssertLessThanOrEqual(host.fittingSize.height, 190)
        await service.refreshAsync()
        XCTAssertNotNil(service.claudeSummary); XCTAssertNotNil(service.codexSummary); XCTAssertNotNil(service.geminiSummary)
        host.layoutSubtreeIfNeeded()
        XCTAssertLessThanOrEqual(host.fittingSize.height, 190, "Provider results must not push the outer hub menu beyond its mask")
    }
    func testVerySmallViewportHasNoNegativeScrollGeometry() {
        let layout = AIUsagePanelMetrics(size: CGSize(width: 10, height: 12))
        XCTAssertEqual(layout.cardsHeight, 0); XCTAssertEqual(layout.cardWidth, 0)
    }
}
