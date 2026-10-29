import XCTest
import AppKit
@testable import DynamicNotch

@MainActor
final class ClipboardExperienceTests: XCTestCase {
    private func withStorage(_ action: (ProductivityStorage, URL) throws -> Void) throws {
        let name = "DynamicNotch.ClipboardTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        defer { defaults.removePersistentDomain(forName: name); try? FileManager.default.removeItem(at: folder) }
        try action(ProductivityStorage(url: folder.appendingPathComponent("data.json"), defaults: defaults), folder)
    }
    func testKindClassificationAndBoundedTwoLinePreviewPreserveOriginal() {
        XCTAssertEqual(ClipboardKind.classify("https://example.com/a?q=one"), .links)
        XCTAssertEqual(ClipboardKind.classify("https://example.com and words"), .text)
        XCTAssertEqual(ClipboardKind.classify("file:///tmp/example"), .text)
        XCTAssertEqual(ClipboardKind.classify("const response = fetch('/api');"), .code)
        let original = "\n First line\n\n    second line\n" + String(repeating: "x", count: 10_000)
        let item = SavedSnippet(text: original)
        XCTAssertEqual(item.previewLines, ["First line", "second line"])
        XCTAssertEqual(item.text, original)
    }
    func testSourceSearchKindsFavoritesAndSortCompose() throws {
        try withStorage { store, _ in
            let oldest = Date(timeIntervalSince1970: 1)
            let newest = Date(timeIntervalSince1970: 3)
            let link = SavedSnippet(text: "https://example.com", date: oldest, sourceAppName: "Safari")
            let code = SavedSnippet(text: "const answer = 42;", date: newest, isFavorite: true, sourceAppName: "Code")
            let text = SavedSnippet(text: "Meeting moved", date: Date(timeIntervalSince1970: 2))
            XCTAssertTrue(store.update { $0.snippets = [link, code, text] })
            XCTAssertEqual(store.filteredSnippets(query: "sAFari").map(\.id), [link.id])
            XCTAssertEqual(store.filteredSnippets(query: "", kind: .links).map(\.id), [link.id])
            XCTAssertEqual(store.filteredSnippets(query: "", kind: .text, favoritesOnly: true).count, 0)
            XCTAssertEqual(store.filteredSnippets(query: "", favoritesOnly: true).map(\.id), [code.id])
            XCTAssertEqual(store.filteredSnippets(query: "", oldestFirst: true).map(\.id), [code.id, link.id, text.id])
            XCTAssertEqual(store.filteredSnippets(query: "").map(\.id), [code.id, text.id, link.id])
        }
    }
    func testRecapturePreservesFavoriteAndSourceAndClearKeepsStars() throws {
        try withStorage { store, folder in
            XCTAssertTrue(store.saveSnippet("Pinned", sourceAppName: "Original App"))
            let id = try XCTUnwrap(store.document.snippets.first?.id)
            store.toggleSnippetFavorite(id)
            XCTAssertTrue(store.saveSnippet("Pinned"))
            XCTAssertEqual(store.document.snippets.first?.sourceAppName, "Original App")
            XCTAssertEqual(store.document.snippets.first?.id, id)
            XCTAssertTrue(store.saveSnippet("Temporary", sourceAppName: "Other App"))
            XCTAssertTrue(store.removeUnstarredSnippets())
            let restored = ProductivityStorage(url: folder.appendingPathComponent("data.json"))
            XCTAssertEqual(restored.document.snippets.count, 1)
            XCTAssertEqual(restored.document.snippets.first?.id, id)
            XCTAssertEqual(restored.document.snippets.first?.sourceAppName, "Original App")
            XCTAssertEqual(restored.document.snippets.first?.isFavorite, true)
        }
    }
    func testConcealedPasteboardStillExcludedWithSourceMetadata() throws {
        try withStorage { store, _ in
            let board = NSPasteboard.withUniqueName(); defer { board.releaseGlobally() }
            board.declareTypes([.string, NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")], owner: nil)
            board.setString("test-only concealed", forType: .string)
            XCTAssertFalse(store.captureFromPasteboard(board, sourceAppName: "Test App"))
            XCTAssertTrue(store.document.snippets.isEmpty)
            board.clearContents(); board.setString("public test text", forType: .string)
            XCTAssertTrue(store.captureFromPasteboard(board, sourceAppName: "Test App"))
            XCTAssertEqual(store.document.snippets.first?.sourceAppName, "Test App")
        }
    }
    func testClipboardExpandsWithoutChangingOtherToolGeometry() {
        let name = "DynamicNotch.ClipboardGeometry.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = QuickToolsStore(defaults: defaults)
        store.hubMode = .tools; store.selectedTool = "notes"
        let content = QuickToolsNotchContent(store: store)
        let normal = content.expandedSize(baseWidth: 190, baseHeight: 38)
        store.selectedTool = "snippets"
        let clipboard = content.expandedSize(baseWidth: 190, baseHeight: 38)
        XCTAssertGreaterThan(clipboard.height, normal.height)
        XCTAssertEqual(clipboard.width, normal.width)
        store.selectedTool = "notes"
        XCTAssertEqual(content.expandedSize(baseWidth: 190, baseHeight: 38), normal)
    }
}
