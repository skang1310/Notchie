//
//  NowPlayingLyricsTests.swift
//  DynamicNotchTests
//

import XCTest
import SwiftUI
@testable import DynamicNotch

@MainActor
final class NowPlayingLyricsTests: XCTestCase {

    func testAppleMusicLyricsParserSyncedLRC() {
        let lrcText = """
        [00:12.50]First line of the song
        [00:18.25]Second line of the song
        [00:25.00]Third line of the song
        """

        let lyrics = AppleMusicLyricsProvider.parseLyrics(lrcText, trackKey: "test-track-1")
        XCTAssertNotNil(lyrics)
        XCTAssertEqual(lyrics?.trackKey, "test-track-1")
        XCTAssertTrue(lyrics?.isSynced == true)
        XCTAssertEqual(lyrics?.lines.count, 3)

        XCTAssertEqual(lyrics?.lines[0].text, "First line of the song")
        XCTAssertEqual(lyrics?.lines[0].startTime ?? 0, 12.50, accuracy: 0.01)

        XCTAssertEqual(lyrics?.lines[1].text, "Second line of the song")
        XCTAssertEqual(lyrics?.lines[1].startTime ?? 0, 18.25, accuracy: 0.01)

        XCTAssertEqual(lyrics?.lines[2].text, "Third line of the song")
        XCTAssertEqual(lyrics?.lines[2].startTime ?? 0, 25.00, accuracy: 0.01)

        // Active line index lookup
        XCTAssertEqual(lyrics?.activeLineIndex(at: 10.0), 0)
        XCTAssertEqual(lyrics?.activeLineIndex(at: 15.0), 0)
        XCTAssertEqual(lyrics?.activeLineIndex(at: 20.0), 1)
        XCTAssertEqual(lyrics?.activeLineIndex(at: 30.0), 2)
    }

    func testAppleMusicLyricsParserPlainText() {
        let plainText = """
        Hello from the other side
        I must have called a thousand times
        To tell you I'm sorry
        """

        let lyrics = AppleMusicLyricsProvider.parseLyrics(plainText, trackKey: "test-plain-1")
        XCTAssertNotNil(lyrics)
        XCTAssertEqual(lyrics?.trackKey, "test-plain-1")
        XCTAssertFalse(lyrics?.isSynced == true)
        XCTAssertEqual(lyrics?.lines.count, 3)
        XCTAssertEqual(lyrics?.lines[0].text, "Hello from the other side")
        XCTAssertNil(lyrics?.lines[0].startTime)
        XCTAssertEqual(lyrics?.lines[1].text, "I must have called a thousand times")
        XCTAssertEqual(lyrics?.lines[2].text, "To tell you I'm sorry")
    }

    func testQuickToolsStoreLyricsSlotToggle() {
        let suite = "DynamicNotch.QuickToolsLyricsTest.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = QuickToolsStore(defaults: defaults)
        XCTAssertFalse(store.isLyricsVisibleInCalendarSlot)

        store.toggleLyricsInCalendarSlot()
        XCTAssertTrue(store.isLyricsVisibleInCalendarSlot)

        store.toggleLyricsInCalendarSlot()
        XCTAssertFalse(store.isLyricsVisibleInCalendarSlot)
    }

    func testKugouLyricsCleanTitle() {
        XCTAssertEqual(
            KugouLyricsProvider.cleanTitle("Here Comes Santa Claus (Down Santa Claus Lane)"),
            "Here Comes Santa Claus"
        )
        XCTAssertEqual(
            KugouLyricsProvider.cleanTitle("Shape of You (feat. Stormzy)"),
            "Shape of You"
        )
        XCTAssertEqual(
            KugouLyricsProvider.cleanTitle("Cruel Summer [Live from The Eras Tour]"),
            "Cruel Summer"
        )
        XCTAssertEqual(
            KugouLyricsProvider.cleanTitle("Ditto - Single Version"),
            "Ditto"
        )
    }

    func testKugouLyricsParserSyncedLRC() {
        let lrcText = """
        [ti:Ditto]
        [ar:NewJeans]
        [00:00.00]Ditto - NewJeans
        [00:14.64]Stay in the middle
        [00:16.37]Like you a little
        [00:18.13]Don't want no riddle
        """

        let lyrics = KugouLyricsProvider.parseLyrics(lrcText, trackKey: "newjeans-ditto")
        XCTAssertNotNil(lyrics)
        XCTAssertTrue(lyrics?.isSynced == true)
        XCTAssertEqual(lyrics?.lines.count, 4)

        XCTAssertEqual(lyrics?.lines[0].text, "Ditto - NewJeans")
        XCTAssertEqual(lyrics?.lines[0].startTime ?? 0, 0.0, accuracy: 0.01)

        XCTAssertEqual(lyrics?.lines[1].text, "Stay in the middle")
        XCTAssertEqual(lyrics?.lines[1].startTime ?? 0, 14.64, accuracy: 0.01)

        XCTAssertEqual(lyrics?.lines[2].text, "Like you a little")
        XCTAssertEqual(lyrics?.lines[2].startTime ?? 0, 16.37, accuracy: 0.01)

        XCTAssertEqual(lyrics?.lines[3].text, "Don't want no riddle")
        XCTAssertEqual(lyrics?.lines[3].startTime ?? 0, 18.13, accuracy: 0.01)

        // Active line index lookup with 0.18s lead
        XCTAssertEqual(lyrics?.activeLineIndex(at: 10.0), 0)
        XCTAssertEqual(lyrics?.activeLineIndex(at: 15.0), 1)
        XCTAssertEqual(lyrics?.activeLineIndex(at: 17.0), 2)
        XCTAssertEqual(lyrics?.activeLineIndex(at: 20.0), 3)
    }

    func testNowPlayingViewModelLyricsPresentationActive() {
        let suite = "DynamicNotch.LyricsReloadTest.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let vm = NowPlayingViewModel(
            service: InactiveNowPlayingService(),
            favoritesStore: defaults
        )

        XCTAssertEqual(vm.lyricsState, .idle)
        XCTAssertFalse(vm.isLyricsPresentationActive)

        vm.setLyricsPresentationActive(true)
        XCTAssertTrue(vm.isLyricsPresentationActive)

        vm.setLyricsPresentationActive(false)
        XCTAssertFalse(vm.isLyricsPresentationActive)
    }
}
