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
    func testRejectedPasswordIsVisibleAfterRelaunchWithoutStartingEngine() {
        let name = "DynamicNotch.AuthRecovery.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(true, forKey: "DynamicNotch.HeyMac.lockScreenNeedsPassword")
        let controller = HeyMacFaceUnlockController(defaults: defaults,
            directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        XCTAssertTrue(controller.passwordNeedsUpdate)
        XCTAssertFalse(controller.status.isEmpty)
        XCTAssertFalse(controller.enabled)
        XCTAssertFalse(controller.busy)
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
}
