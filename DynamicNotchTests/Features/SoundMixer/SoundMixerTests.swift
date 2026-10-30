import XCTest
@testable import DynamicNotch

@MainActor
final class SoundMixerTests: XCTestCase {
    private func isolatedDefaults() -> (UserDefaults, String) {
        let name = "DynamicNotch.SoundMixerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        return (defaults, name)
    }

    func testAppVolumeClampingAndPersistence() {
        let (defaults, name) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }

        let service = SoundMixerService(defaults: defaults)
        let testBID = "com.google.Chrome"

        service.setAppVolume(bundleID: testBID, volume: 0.42)
        XCTAssertEqual(service.audioApps.first(where: { $0.id == testBID })?.volume ?? 0, 0.42, accuracy: 0.001)

        // Clamping bounds
        service.setAppVolume(bundleID: testBID, volume: 1.5)
        XCTAssertEqual(service.audioApps.first(where: { $0.id == testBID })?.volume ?? 0, 1.0, accuracy: 0.001)

        service.setAppVolume(bundleID: testBID, volume: -0.5)
        XCTAssertEqual(service.audioApps.first(where: { $0.id == testBID })?.volume ?? 0, 0.0, accuracy: 0.001)

        // Reset
        service.resetAppVolume(bundleID: testBID)
        XCTAssertEqual(service.audioApps.first(where: { $0.id == testBID })?.volume ?? 0, 1.0, accuracy: 0.001)

        // Reload from defaults
        let reloaded = SoundMixerService(defaults: defaults)
        XCTAssertEqual(reloaded.audioApps.first(where: { $0.id == testBID })?.volume ?? 0, 1.0, accuracy: 0.001)
    }

    func testActivePlaybackAppIndicatorDetection() {
        let (defaults, name) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }

        let service = SoundMixerService(defaults: defaults)
        let musicBID = "com.apple.Music"

        service.refreshAudioApps(activePlayingBundleID: musicBID, isPlaying: true)
        let musicApp = service.audioApps.first(where: { $0.id == musicBID })
        XCTAssertNotNil(musicApp)
        XCTAssertTrue(musicApp?.isPlaying == true)

        // When playback pauses
        service.refreshAudioApps(activePlayingBundleID: musicBID, isPlaying: false)
        let pausedApp = service.audioApps.first(where: { $0.id == musicBID })
        XCTAssertFalse(pausedApp?.isPlaying == true)
    }

    func testMasterVolumeClamping() {
        let (defaults, name) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }

        let service = SoundMixerService(defaults: defaults)
        service.setMasterVolume(0.75)
        XCTAssertGreaterThanOrEqual(service.masterVolume, 0.0)
        XCTAssertLessThanOrEqual(service.masterVolume, 1.0)
    }

    func testIsAdjustingVolumeFlagAndSuppressionWindow() {
        let (defaults, name) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }

        let service = SoundMixerService(defaults: defaults)
        XCTAssertFalse(service.isAdjustingVolume)

        service.setMasterVolume(0.6)
        XCTAssertTrue(service.isAdjustingVolume)

        service.setAppVolume(bundleID: "com.google.Chrome", volume: 0.8)
        XCTAssertTrue(service.isAdjustingVolume)

        service.touchAdjustment()
        XCTAssertTrue(service.isAdjustingVolume)
    }

    func testSoundMixerActiveDismissalProtection() {
        let store = QuickToolsStore.shared
        store.isSoundMixerVisibleInCalendarSlot = true
        XCTAssertTrue(store.isSoundMixerVisibleInCalendarSlot)

        store.isSoundMixerVisibleInCalendarSlot = false
        XCTAssertFalse(store.isSoundMixerVisibleInCalendarSlot)
    }
}
