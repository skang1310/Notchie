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
    func testFocusPauseCancelDoesNotRecordAndCompletionPersistsOnce() throws {
        let (store, folder) = storage(); defer { try? FileManager.default.removeItem(at: folder) }
        let focus = FocusSessionController(storage: store)
        focus.startFocus(minutes: 0); XCTAssertEqual(focus.phase, .idle)
        focus.startFocus(minutes: 1); XCTAssertEqual(focus.phase, .focus)
        focus.pauseOrResume(); XCTAssertEqual(focus.timer.state, .paused)
        focus.pauseOrResume(); XCTAssertEqual(focus.timer.state, .running)
        focus.stop(); XCTAssertTrue(store.document.focusHistory.isEmpty)
        focus.startFocus(minutes: 1); focus.timer.stop(); focus.finished(); focus.finished()
        XCTAssertEqual(focus.phase, .readyForBreak)
        XCTAssertEqual(store.document.focusHistory.count, 1)
        let reloaded = ProductivityStorage(url: folder.appendingPathComponent("document.json"))
        XCTAssertEqual(reloaded.document.focusHistory.first?.seconds, 60)
        focus.startBreak(minutes: 1); XCTAssertEqual(focus.phase, .rest)
        focus.stop()
    }
    func testCorruptProductivityDocumentIsPreserved() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("document.json"), bytes = Data("broken".utf8)
        try bytes.write(to: url)
        let store = ProductivityStorage(url: url)
        XCTAssertFalse(store.addTask("Do not overwrite"))
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }
    func testThreeTasksRoundTripAndExplicitSnippetDeduplication() throws {
        let (store, folder) = storage(); defer { try? FileManager.default.removeItem(at: folder) }
        XCTAssertTrue(store.addTask("One")); XCTAssertTrue(store.addTask("Two")); XCTAssertTrue(store.addTask("Three"))
        XCTAssertFalse(store.addTask("Four")); XCTAssertFalse(store.addTask(" "))
        let id = try XCTUnwrap(store.todayTasks.first?.id); store.toggleTask(id)
        XCTAssertTrue(try XCTUnwrap(store.todayTasks.first).done)
        XCTAssertTrue(store.saveSnippet("explicit only")); XCTAssertTrue(store.saveSnippet("explicit only"))
        XCTAssertEqual(store.document.snippets.count, 1)
        XCTAssertTrue(store.saveSnippet("Notchie clipboard search item"))
        XCTAssertEqual(store.filteredSnippets(query: "notchie").count, 1)
        XCTAssertEqual(store.filteredSnippets(query: "EXPLICIT").count, 1)
        XCTAssertEqual(store.filteredSnippets(query: "   ").count, 2)
        XCTAssertTrue(store.filteredSnippets(query: "nonexistent").isEmpty)
        let reload = ProductivityStorage(url: folder.appendingPathComponent("document.json"))
        XCTAssertEqual(reload.todayTasks.count, 3)
        XCTAssertTrue(try XCTUnwrap(reload.todayTasks.first).done)
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
    func testRulesUseExactBundleIDAndDoNotHideOwnApp() {
        XCTAssertTrue(AppPresentationPolicy.hides(bundleID: "com.example.Game", rules: ["com.example.Game"]))
        XCTAssertFalse(AppPresentationPolicy.hides(bundleID: "com.example.Game2", rules: ["com.example.Game"]))
        XCTAssertFalse(AppPresentationPolicy.hides(bundleID: "com.Jackson.DynamicNotch", rules: ["com.Jackson.DynamicNotch"]))
        XCTAssertFalse(AppPresentationPolicy.hides(bundleID: nil, rules: ["anything"]))
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
    func testLocalJobRunsActualSHA256AndReportsNonzeroFailureWithoutShell() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("name with spaces $(not-a-command).txt")
        try Data("abc".utf8).write(to: file)
        let runner = LocalJobRunner()
        runner.run(executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "exit 0"])
        if case .failed = runner.state {} else { XCTFail("Shell executable should be refused") }
        runner.run(executable: URL(fileURLWithPath: "/usr/bin/shasum"), arguments: ["-a", "256", "--", file.path])
        for _ in 0..<300 { if !runner.isRunning { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(runner.state, .completed(0))
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertTrue(runner.output.contains("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"))
        runner.run(executable: URL(fileURLWithPath: "/usr/bin/shasum"), arguments: ["--", folder.appendingPathComponent("missing").path])
        for _ in 0..<300 { if !runner.isRunning { break }; try await Task.sleep(for: .milliseconds(10)) }
        if case .completed(let code) = runner.state { XCTAssertNotEqual(code, 0) } else { XCTFail("Missing file should report actual exit failure") }
    }

}
