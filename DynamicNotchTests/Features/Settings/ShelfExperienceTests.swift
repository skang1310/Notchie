import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import DynamicNotch

@MainActor
final class ShelfExperienceTests: XCTestCase {
    private func isolated(_ run: (UserDefaults) throws -> Void) rethrows {
        let name = "DynamicNotch.ShelfTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        try run(defaults)
    }

    func testWidgetLayoutSwapsDuplicatesAndPersistsOrder() {
        isolated { defaults in
            let store = ShelfPreferences(defaults: defaults)
            XCTAssertEqual(store.widgets, [.media, .calendar, .stats])
            store.replace(at: 0, with: .stats)
            XCTAssertEqual(store.widgets, [.stats, .calendar, .media])
            store.move(.media, by: -1)
            XCTAssertEqual(store.widgets.count, 3)
        }
    }

    func testMalformedWidgetPreferencesDoNotDuplicateOrCrash() {
        isolated { defaults in
            defaults.set(["unknown", "stats", "stats", "media"], forKey: ShelfPreferences.widgetsKey)
            XCTAssertEqual(ShelfPreferences(defaults: defaults).widgets, [.stats, .media])
            defaults.set(["unknown"], forKey: ShelfPreferences.widgetsKey)
            XCTAssertEqual(ShelfPreferences(defaults: defaults).widgets, [.media, .calendar, .stats])
        }
    }

    func testCPUUsesDeltaRatherThanLifetimeAverage() throws {
        let old = ShelfCPUSample(user: 20, system: 10, idle: 70, nice: 0)
        let new = ShelfCPUSample(user: 35, system: 20, idle: 145, nice: 0)
        XCTAssertEqual(try XCTUnwrap(new.utilization(since: old)), 0.25, accuracy: 0.0001)
        XCTAssertNil(old.utilization(since: old))
        XCTAssertNil(old.utilization(since: new))
    }

    func testGlassMaterialSelectionRoundTripsWithoutTouchingTheme() {
        isolated { defaults in
            let settings = ApplicationSettingsStore(defaults: defaults)
            let theme = settings.appearanceMode
            settings.notchBackgroundStyle = .dynamicGlass
            XCTAssertEqual(ApplicationSettingsStore(defaults: defaults).notchBackgroundStyle, .dynamicGlass)
            settings.notchBackgroundStyle = .liquidGlass
            XCTAssertEqual(ApplicationSettingsStore(defaults: defaults).notchBackgroundStyle, .liquidGlass)
            XCTAssertEqual(settings.appearanceMode, theme)
            XCTAssertEqual(NotchBackgroundStyle.resolved("unknown"), .black)
        }
    }

    func testFavoriteMigrationRecaptureAndRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("document.json")
        let old = ProductivityDocument(snippets: [SavedSnippet(text: "old")])
        try JSONEncoder().encode(old).write(to: url)
        let storage = ProductivityStorage(url: url)
        let id = try XCTUnwrap(storage.document.snippets.first?.id)
        storage.toggleSnippetFavorite(id)
        XCTAssertTrue(storage.saveSnippet("new"))
        XCTAssertEqual(storage.filteredSnippets(query: "").first?.id, id)
        XCTAssertTrue(storage.saveSnippet("old"))
        XCTAssertEqual(storage.document.snippets.first?.id, id)
        XCTAssertEqual(storage.document.snippets.first?.isFavorite, true)
        XCTAssertEqual(ProductivityStorage(url: url).filteredSnippets(query: "OLD").first?.isFavorite, true)
    }

    func testToolLibraryFindsKoreanEnglishAndIDsWithoutChangingEnabledTabs() {
        XCTAssertEqual(ShelfToolSearch.matches("파일 변환").map(\.id), ["transform"])
        XCTAssertEqual(ShelfToolSearch.matches("transform").map(\.id), ["transform"])
        XCTAssertEqual(ShelfToolSearch.matches("  Stats  ").map(\.id), ["stats"])
        XCTAssertTrue(ShelfToolSearch.matches("no such tool 71290").isEmpty)
        XCTAssertEqual(ShelfToolSearch.matches(" ").count, QuickToolTab.allTabs.count)
    }

    func testPDFCombinesActualImageAndPDFInOrderAndPreservesSources() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let context = try XCTUnwrap(CGContext(data: nil, width: 80, height: 40, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let png = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(png, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try XCTUnwrap(context.makeImage()), nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let source = folder.appendingPathComponent("original.png")
        try (png as Data).write(to: source)
        let pdf = try ShelfTransform.combinedPDF([source])
        let pdfURL = folder.appendingPathComponent("first.pdf"); try pdf.write(to: pdfURL)
        let combined = try ShelfTransform.combinedPDF([source, pdfURL])
        let result = try XCTUnwrap(CGPDFDocument(try XCTUnwrap(CGDataProvider(data: combined as CFData))))
        XCTAssertEqual(result.numberOfPages, 2)
        XCTAssertEqual(result.page(at: 1)?.getBoxRect(.mediaBox).width, 80)
        XCTAssertEqual(result.page(at: 2)?.getBoxRect(.mediaBox).height, 40)
        XCTAssertEqual(try Data(contentsOf: source), png as Data)
        XCTAssertEqual(try Data(contentsOf: pdfURL), pdf)
        XCTAssertThrowsError(try ShelfTransform.combinedPDF([]))
        XCTAssertThrowsError(try ShelfTransform.combinedPDF(Array(repeating: source, count: 21)))
        let broken = folder.appendingPathComponent("broken.png"); try Data("bad".utf8).write(to: broken)
        XCTAssertThrowsError(try ShelfTransform.boundedImage(broken))
        XCTAssertThrowsError(try ShelfTransform.removeBackground(broken))
    }
}
