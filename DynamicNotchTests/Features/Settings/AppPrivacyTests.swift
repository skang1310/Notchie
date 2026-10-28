import XCTest
import HeyMacEngine
@testable import DynamicNotch

@MainActor
final class AppPrivacyTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!
    override func setUp() async throws {
        suite = "DynamicNotch.AppPrivacyTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
    }
    override func tearDown() async throws { defaults.removePersistentDomain(forName: suite) }
    func testDefaultOffAndDoesNotAdoptHeyMacOrLoginSettings() {
        defaults.set(true, forKey: "appLock.enabled")
        defaults.set(true, forKey: "launchAtLogin")
        let model = AppPrivacyState(defaults: defaults)
        XCTAssertFalse(model.store.enabled)
        XCTAssertFalse(model.useFace)
        XCTAssertTrue(model.store.apps.isEmpty)
        model.enable(true)
        model.enable(false)
        XCTAssertTrue(defaults.bool(forKey: "launchAtLogin"))
        XCTAssertTrue(defaults.bool(forKey: "appLock.enabled"))
    }
    func testExplicitChoicesPersistButSessionsDoNot() {
        let model = AppPrivacyState(defaults: defaults)
        XCTAssertTrue(model.add(bundleID: "example.private", name: "Example"))
        model.setPolicy(.afterMinutes(15), for: "example.private")
        model.useFace = true; model.enable(true)
        model.sessions.unlock("example.private", policy: .afterMinutes(15))
        let restored = AppPrivacyState(defaults: defaults)
        XCTAssertTrue(restored.store.enabled)
        XCTAssertTrue(restored.useFace)
        XCTAssertEqual(restored.store.app("example.private")?.policy, .afterMinutes(15))
        XCTAssertTrue(restored.needsShield("example.private"))
    }
    func testRecoveryToolsAndOwnAppCannotBeAdded() {
        let model = AppPrivacyState(defaults: defaults)
        for id in ["com.apple.finder", "com.apple.systempreferences", "com.apple.Terminal", "com.apple.dt.Xcode", "com.Jackson.DynamicNotch", "com.Jackson.DynamicNotch.LocalTests", ""] {
            XCTAssertFalse(model.add(bundleID: id, name: "Recovery"), id)
        }
        XCTAssertTrue(model.store.apps.isEmpty)
        XCTAssertTrue(model.add(bundleID: "example.private", name: "Example"))
        XCTAssertFalse(model.add(bundleID: "example.private", name: "Duplicate"))
    }
    func testTimedAuthenticationExpiresAtMonotonicDeadline() {
        var clock = 100.0
        let model = AppPrivacyState(defaults: defaults, now: { clock })
        model.add(bundleID: "example.private", name: "Example"); model.enable(true)
        model.sessions.unlock("example.private", policy: .afterMinutes(5))
        clock = 399.9
        XCTAssertFalse(model.needsShield("example.private"))
        clock = 400
        XCTAssertTrue(model.needsShield("example.private"))
    }
    func testEverySwitchAndFocusLossGraceAreDifferent() {
        var clock = 100.0
        let model = AppPrivacyState(defaults: defaults, now: { clock })
        model.add(bundleID: "example.private", name: "Example"); model.enable(true)
        model.sessions.unlock("example.private", policy: .everyTime)
        model.sessions.focusLost("example.private")
        XCTAssertTrue(model.needsShield("example.private"))
        model.sessions.unlock("example.private", policy: .afterFocusLossMinutes(5))
        model.sessions.focusLost("example.private")
        clock = 200
        model.sessions.focusGained("example.private")
        clock = 500
        XCTAssertFalse(model.needsShield("example.private"))
        model.sessions.focusLost("example.private")
        clock = 800
        model.sessions.focusGained("example.private")
        XCTAssertTrue(model.needsShield("example.private"))
    }
    func testPolicyChangesRemovalAndDisableRevokeSessions() {
        let model = AppPrivacyState(defaults: defaults)
        model.add(bundleID: "example.private", name: "Example"); model.enable(true)
        model.sessions.unlock("example.private", policy: .afterMinutes(15))
        model.setPolicy(.everyTime, for: "example.private")
        XCTAssertTrue(model.needsShield("example.private"))
        model.sessions.unlock("example.private", policy: .afterMinutes(15))
        model.enable(false)
        XCTAssertFalse(model.sessions.isUnlocked("example.private"))
        XCTAssertFalse(model.needsShield("example.private"))
        model.remove("example.private")
        XCTAssertTrue(model.store.apps.isEmpty)
    }
    func testPauseExpiresAndRelockCancelsPause() {
        var clock = 10.0
        let model = AppPrivacyState(defaults: defaults, now: { clock })
        model.add(bundleID: "example.private", name: "Example"); model.enable(true)
        model.sessions.unlock("example.private", policy: .afterMinutes(15))
        model.pause(minutes: 5)
        XCTAssertEqual(model.pauseSeconds, 300)
        XCTAssertFalse(model.sessions.isUnlocked("example.private"))
        XCTAssertFalse(model.needsShield("example.private"))
        clock = 310
        XCTAssertTrue(model.needsShield("example.private"))
        model.pause(minutes: 15)
        model.relockAll()
        XCTAssertFalse(model.isPaused)
        XCTAssertTrue(model.needsShield("example.private"))
    }
    func testUnsupportedDurationsDoNotPersistOrPause() {
        let model = AppPrivacyState(defaults: defaults)
        model.add(bundleID: "example.private", name: "Example")
        model.setPolicy(.afterMinutes(-1), for: "example.private")
        XCTAssertEqual(model.store.app("example.private")?.policy, .everyTime)
        model.pause(minutes: -1)
        XCTAssertFalse(model.isPaused)
    }
}
