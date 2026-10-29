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
}
