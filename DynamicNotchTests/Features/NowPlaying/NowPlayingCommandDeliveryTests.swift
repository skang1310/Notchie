import XCTest
@testable import DynamicNotch

@MainActor
final class NowPlayingCommandDeliveryTests: XCTestCase {
    func testMusicFallbackRecognizesStateAndNeverTogglesAlreadySatisfiedRequest() {
        XCTAssertEqual(MusicAccessibilityPlayback.action(for: .play, label: "일시 정지"), .alreadySatisfied)
        XCTAssertEqual(MusicAccessibilityPlayback.action(for: .pause, label: "재생"), .alreadySatisfied)
        XCTAssertEqual(MusicAccessibilityPlayback.action(for: .play, label: "Play"), .press)
        XCTAssertEqual(MusicAccessibilityPlayback.action(for: .pause, label: "Pause"), .press)
        XCTAssertEqual(MusicAccessibilityPlayback.action(for: .togglePlayPause, label: "Unknown"), .unsupported)
        XCTAssertEqual(MusicAccessibilityPlayback.action(for: .seek(10), label: "Play"), .unsupported)
    }
    func testAcknowledgedAppCommandDoesNotAlsoSendGlobalToggle() async {
        var fallbackCalls = 0
        let delivered = await NowPlayingCommandDelivery.deliver(application: { true }, fallback: { fallbackCalls += 1 })
        XCTAssertTrue(delivered); XCTAssertEqual(fallbackCalls, 0)
    }
    func testFailedOrUnsupportedApplicationCommandFallsBackOnce() async {
        var fallbackCalls = 0
        let delivered = await NowPlayingCommandDelivery.deliver(application: { false }, fallback: { fallbackCalls += 1 })
        XCTAssertFalse(delivered); XCTAssertEqual(fallbackCalls, 1)
    }
    func testFallbackWaitsForApplicationResultInsteadOfRacingIt() async {
        var events: [String] = []
        _ = await NowPlayingCommandDelivery.deliver(application: {
            events.append("app-start")
            try? await Task.sleep(for: .milliseconds(15))
            events.append("app-failed")
            return false
        }, fallback: { events.append("fallback") })
        XCTAssertEqual(events, ["app-start", "app-failed", "fallback"])
    }
}
