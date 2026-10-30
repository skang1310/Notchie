import XCTest
@testable import DynamicNotch

@MainActor
final class ProductivityMigrationTests: XCTestCase {
    func testLegacyProductivityDocumentDecodesWithoutLosingSnippets() throws {
        // Document containing legacy deleted fields (tasks, focusHistory, hiddenBundleIDs)
        let legacyJSON = """
        {
            "version": 1,
            "tasks": [{"id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F", "day": "2026-10-30", "text": "Old task", "done": false}],
            "focusHistory": [{"id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F", "date": 750000000, "seconds": 1500}],
            "hiddenBundleIDs": ["com.example.hidden"],
            "snippets": [{"id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F", "text": "Preserved snippet", "date": 750000000, "isFavorite": true}]
        }
        """

        let decoded = try JSONDecoder().decode(ProductivityDocument.self, from: Data(legacyJSON.utf8))
        XCTAssertEqual(decoded.version, 1)
        XCTAssertEqual(decoded.snippets.count, 1)
        XCTAssertEqual(decoded.snippets.first?.text, "Preserved snippet")
        XCTAssertEqual(decoded.snippets.first?.isFavorite, true)
    }

    func testQuickToolsStoreMigratesLegacyDeletedTabsToDefaults() {
        let name = "DynamicNotch.MigrationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }

        // Set deleted tab IDs in preferences
        defaults.set(["notes", "stopwatch", "awake", "calculator", "zip", "developer", "rules", "jobs"], forKey: QuickToolsStore.enabledTabsKey)

        let store = QuickToolsStore(defaults: defaults)

        // All deleted tabs should be pruned; should fall back to default enabled IDs
        XCTAssertEqual(store.enabledTabIDs, QuickToolTab.defaultEnabledIDs)
        XCTAssertTrue(store.enabledTabIDs.contains("stats"))
        XCTAssertFalse(store.enabledTabIDs.contains("notes"))
        XCTAssertFalse(store.enabledTabIDs.contains("stopwatch"))
        XCTAssertFalse(store.enabledTabIDs.contains("awake"))
        XCTAssertFalse(store.enabledTabIDs.contains("calculator"))
        XCTAssertFalse(store.enabledTabIDs.contains("rules"))
        XCTAssertFalse(store.enabledTabIDs.contains("jobs"))
    }

    func testProductivityCoordinatorShutdownHaltsCleanly() {
        let coordinator = ProductivityCoordinator.shared
        coordinator.start()
        coordinator.shutdown()
        // Calling shutdown multiple times is safe and does not crash
        coordinator.shutdown()
    }
}
