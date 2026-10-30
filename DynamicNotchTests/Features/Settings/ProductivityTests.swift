import XCTest
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers
@testable import DynamicNotch

@MainActor
final class ProductivityTests: XCTestCase {
    private func storage() -> (ProductivityStorage, URL) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return (ProductivityStorage(url: folder.appendingPathComponent("document.json")), folder)
    }

    func testCorruptProductivityDocumentIsPreserved() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("document.json"), bytes = Data("broken".utf8)
        try bytes.write(to: url)
        let store = ProductivityStorage(url: url)
        XCTAssertFalse(store.saveSnippet("Do not overwrite"))
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }

    func testExplicitSnippetDeduplicationSearchAndPermissions() throws {
        let (store, folder) = storage(); defer { try? FileManager.default.removeItem(at: folder) }
        XCTAssertTrue(store.saveSnippet("explicit only"))
        XCTAssertTrue(store.saveSnippet("explicit only"))
        XCTAssertEqual(store.document.snippets.count, 1)
        XCTAssertTrue(store.saveSnippet("Notchie clipboard search item"))
        XCTAssertEqual(store.filteredSnippets(query: "notchie").count, 1)
        XCTAssertEqual(store.filteredSnippets(query: "EXPLICIT").count, 1)
        XCTAssertEqual(store.filteredSnippets(query: "   ").count, 2)
        XCTAssertTrue(store.filteredSnippets(query: "nonexistent").isEmpty)
        let id = try XCTUnwrap(store.document.snippets.first?.id)
        store.toggleSnippetFavorite(id)
        XCTAssertEqual(store.filteredSnippets(query: "", favoritesOnly: true).count, 1)
        let reload = ProductivityStorage(url: folder.appendingPathComponent("document.json"))
        XCTAssertEqual(reload.document.snippets.count, 2)
        let mode = try FileManager.default.attributesOfItem(atPath: folder.appendingPathComponent("document.json").path)[.posixPermissions] as? Int
        XCTAssertEqual(mode.map { $0 & 0o777 }, 0o600)
    }

    func testMeetingLinksRejectLookalikesCredentialsAndNonHTTPS() throws {
        XCTAssertTrue(MeetingLink.accepted(try XCTUnwrap(URL(string: "https://company.zoom.us/j/123"))))
        for text in ["https://zoom.us.evil.test/j/1", "https://evilzoom.us/j/1", "http://meet.google.com/a", "https://user:password@zoom.us/j/1", "https://zoom.us:8080/j/1", "file:///tmp/a"] {
            XCTAssertFalse(MeetingLink.accepted(try XCTUnwrap(URL(string: text))), text)
        }
        XCTAssertEqual(MeetingLink.first(url: nil, notes: "Join https://meet.google.com/abc-defg-hij", location: nil)?.host, "meet.google.com")
        XCTAssertNil(MeetingLink.first(url: nil, notes: "https://evil.test/zoom.us", location: nil))
    }

    func testImageConversionProducesResizedCopyAndRejectsInvalidInput() throws {
        let context = try XCTUnwrap(CGContext(data: nil, width: 200, height: 100, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 0.5)); context.fill(CGRect(x: 0, y: 0, width: 200, height: 100))
        let sourceData = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(sourceData, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try XCTUnwrap(context.makeImage()), nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let original = sourceData as Data
        let converted = try LocalImageConverter.data(from: original, format: .jpeg, maxEdge: 100)
        let output = try XCTUnwrap(CGImageSourceCreateWithData(converted as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(output, 0, nil))
        XCTAssertEqual(image.width, 100); XCTAssertEqual(image.height, 50)
        XCTAssertEqual(sourceData as Data, original)
        XCTAssertThrowsError(try LocalImageConverter.data(from: Data("invalid".utf8), format: .png))
        XCTAssertThrowsError(try LocalImageConverter.data(from: original, format: .png, maxEdge: 0))
    }
}
