import XCTest
internal import IOKit.pwr_mgt
@testable import DynamicNotch

@MainActor
final class SecurityAndQuickToolsTests: XCTestCase {
    func testHeyMacAdapterRequiresExplicitSetupAndKeepsLegacyPreferences() throws {
        let name = "DynamicNotch.HeyMacTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(true, forKey: "launchAtLogin")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let controller = HeyMacFaceUnlockController(defaults: defaults, directory: directory)
        XCTAssertFalse(controller.enabled)
        XCTAssertFalse(controller.enrolled)
        XCTAssertFalse(controller.hasPassword)
        XCTAssertFalse(controller.busy)
        controller.setEnabled(true)
        XCTAssertFalse(controller.enabled)
        XCTAssertFalse(defaults.bool(forKey: HeyMacFaceUnlockController.enabledKey))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
        XCTAssertTrue(defaults.bool(forKey: "launchAtLogin"))
        defaults.set(true, forKey: HeyMacFaceUnlockController.enabledKey)
        controller.setEnabled(false)
        XCTAssertFalse(defaults.bool(forKey: HeyMacFaceUnlockController.enabledKey))
    }
    func testSavedFaceFilesDoNotAutomaticallyEnableCameraOrEngine() throws {
        let name = "DynamicNotch.HeyMacTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            defaults.removePersistentDomain(forName: name)
            try? FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not-a-valid-enrollment".utf8).write(to: directory.appendingPathComponent("face-centroid"))
        try Data("not-a-valid-password".utf8).write(to: directory.appendingPathComponent("login-password"))
        defaults.set(true, forKey: HeyMacFaceUnlockController.enabledKey)
        let controller = HeyMacFaceUnlockController(defaults: defaults, directory: directory)
        XCTAssertTrue(controller.enrolled)
        XCTAssertTrue(controller.hasPassword)
        XCTAssertFalse(controller.enabled)
        XCTAssertFalse(controller.busy)
        controller.shutdown()
    }
    func testPrivacyConnectionsDefaultOffAndPersistExplicitChoices() {
        let name = "DynamicNotch.PrivacyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let preferences = PrivacyPreferences(defaults: defaults)
        XCTAssertFalse(preferences.onlineLyrics)
        XCTAssertFalse(preferences.ipLookup)
        XCTAssertFalse(preferences.localMusicRemote)
        preferences.onlineLyrics = true
        XCTAssertTrue(PrivacyPreferences(defaults: defaults).onlineLyrics)
        preferences.onlineLyrics = false
        XCTAssertFalse(PrivacyPolicy.allows(PrivacyPolicy.onlineLyricsKey, defaults: defaults))
    }
    func testFaceUnlockNeverSucceedsOrCapturesCredentials() {
        XCTAssertFalse(PrivacyPolicy.passwordUnlockSupported)
        let service = FaceIDService()
        var result: Bool?
        service.startScan { result = $0 }
        XCTAssertEqual(result, false)
        XCTAssertTrue(service.state.isFailed)
        XCTAssertEqual(service.detectedFaceCount, 0)
        service.cancelScan()
        XCTAssertEqual(service.state, .idle)
    }
    func testIPLookupCanBeDeniedBeforeAnyRequest() async {
        let service = VPNLocationService(allowLookup: { false })
        let result = await service.fetchCurrentLocation()
        XCTAssertNil(result)
    }
    func testNotesRoundTripPinsSearchAndCorruptionProtection() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("notes.json")
        let notes = QuickNotes(file: file)
        notes.draft = "Private local note\nSearchable body"
        XCTAssertTrue(notes.saveDraft())
        let id = try XCTUnwrap(notes.notes.first?.id)
        notes.togglePin(id)
        let restored = QuickNotes(file: file)
        XCTAssertEqual(restored.notes.count, 1)
        XCTAssertTrue(try XCTUnwrap(restored.notes.first).pinned)
        restored.query = "SEARCHABLE"
        XCTAssertEqual(restored.filtered.count, 1)
        let corrupt = Data("broken".utf8)
        try corrupt.write(to: file)
        let unreadable = QuickNotes(file: file)
        unreadable.draft = "Cannot overwrite"
        XCTAssertFalse(unreadable.saveDraft())
        XCTAssertEqual(try Data(contentsOf: file), corrupt)
    }
    func testStopwatchIgnoresUIUpdatesAndPreservesPausedIntervals() {
        let start = ContinuousClock.now
        var watch = StopwatchState()
        watch.start(at: start)
        watch.pause(at: start.advanced(by: .seconds(12)))
        XCTAssertEqual(watch.elapsed(at: start.advanced(by: .seconds(100))), .seconds(12))
        watch.start(at: start.advanced(by: .seconds(100)))
        XCTAssertEqual(watch.elapsed(at: start.advanced(by: .seconds(105))), .seconds(17))
        watch.reset()
        XCTAssertEqual(watch.accumulated, .zero)
        XCTAssertFalse(watch.isRunning)
    }
    func testKeepAwakeExpiresReleasesAndDoesNotLeakOnReplacement() async throws {
        let backend = TestPowerAccess()
        let controller = KeepAwakeController(access: backend)
        controller.start(seconds: 0.03)
        XCTAssertNotNil(controller.until)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertNil(controller.until)
        XCTAssertEqual(backend.released, [1])
        controller.start(seconds: 60)
        controller.start(seconds: 120)
        XCTAssertEqual(backend.released, [1, 2])
        controller.stop()
        XCTAssertEqual(backend.released, [1, 2, 3])
        controller.start(seconds: .infinity)
        XCTAssertNil(controller.until)
    }
    func testColorConversionClampsAndFormats() {
        XCTAssertEqual(QuickToolsStore.hex(red: 1, green: 0.5, blue: 0), "#FF8000")
        XCTAssertEqual(QuickToolsStore.hex(red: -1, green: 2, blue: 0), "#00FF00")
    }
}
@MainActor
private final class TestPowerAccess: KeepAwakeAccess {
    var next: IOPMAssertionID = 0
    var released: [IOPMAssertionID] = []
    func acquire() throws -> IOPMAssertionID { next += 1; return next }
    func release(_ id: IOPMAssertionID) { released.append(id) }
}
