//
//  CinemaReleasesTests.swift
//  DynamicNotchTests
//

import XCTest
@testable import DynamicNotch

final class CinemaReleasesTests: XCTestCase {
    @MainActor
    func testCinemaPlatformProperties() {
        XCTAssertEqual(CinemaPlatform.all.localizedName(isKorean: true), "전체")
        XCTAssertEqual(CinemaPlatform.all.localizedName(isKorean: false), "All")
        XCTAssertEqual(CinemaPlatform.netflix.localizedName(isKorean: true), "넷플릭스")
        XCTAssertEqual(CinemaPlatform.theater.localizedName(isKorean: true), "극장 개봉")
        XCTAssertEqual(CinemaPlatform.disney.localizedName(isKorean: true), "Disney+")
        XCTAssertEqual(CinemaPlatform.apple.localizedName(isKorean: true), "Apple TV+")

        XCTAssertEqual(CinemaPlatform.netflix.iconName, "play.rectangle.fill")
        XCTAssertEqual(CinemaPlatform.theater.iconName, "film.fill")
    }

    @MainActor
    func testCinemaReleaseItemDDayCalculation() {
        // Release days are local calendar days, so format them in the current zone.
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let releaseInFiveDays = cal.date(byAdding: .day, value: 5, to: today)!

        let item = CinemaReleaseItem(
            title: "테스트 영화",
            originalTitle: "Test Movie",
            platform: .netflix,
            releaseDateString: formatter.string(from: releaseInFiveDays),
            genre: "액션",
            directorOrCast: "감독 이름",
            synopsis: "줄거리 내용",
            trailerURL: URL(string: "https://www.youtube.com/watch?v=12345")
        )

        XCTAssertEqual(item.daysRemaining, 5)
        XCTAssertEqual(item.formattedDDay, "D-5")

        let dDayItem = CinemaReleaseItem(
            title: "오늘 개봉작",
            originalTitle: "Today Release",
            platform: .theater,
            releaseDateString: formatter.string(from: today),
            genre: "드라마",
            directorOrCast: "감독",
            synopsis: "줄거리",
            trailerURL: nil
        )
        XCTAssertEqual(dDayItem.daysRemaining, 0)
        XCTAssertEqual(dDayItem.formattedDDay, "D-DAY")
    }

    @MainActor
    func testCinemaReleaseStoreFilteringAndSelection() {
        let store = CinemaReleaseStore.shared
        XCTAssertFalse(store.releases.isEmpty)

        // Default all
        store.selectedFilter = .all
        store.selectedPeriodFilter = "all"
        store.searchText = ""
        store.selectedDate = nil
        XCTAssertEqual(store.filteredReleases.count, store.releases.count)

        // Filter by Netflix
        store.selectedFilter = .netflix
        let netflixReleases = store.filteredReleases
        XCTAssertFalse(netflixReleases.isEmpty)
        XCTAssertTrue(netflixReleases.allSatisfy { $0.platform == .netflix })

        // Filter by Theater
        store.selectedFilter = .theater
        let theaterReleases = store.filteredReleases
        XCTAssertFalse(theaterReleases.isEmpty)
        XCTAssertTrue(theaterReleases.allSatisfy { $0.platform == .theater })

        // Search text filtering
        store.selectedFilter = .all
        store.searchText = "오징어 게임"
        let searchResults = store.filteredReleases
        XCTAssertEqual(searchResults.count, 1)
        XCTAssertTrue(searchResults.first?.title.contains("오징어 게임") == true)

        // Period filter 2024.11
        store.searchText = ""
        store.selectedPeriodFilter = "2024.11"
        let novReleases = store.filteredReleases
        XCTAssertFalse(novReleases.isEmpty)
        XCTAssertTrue(novReleases.allSatisfy { $0.yearMonthKey == "2024.11" })

        // Date selection
        if let first = store.releases.first {
            store.selectDate(first.releaseDate)
            XCTAssertNotNil(store.selectedDate)
            XCTAssertEqual(store.selectedItem?.id, first.id)

            // Deselect on 2nd click
            store.selectDate(first.releaseDate)
            XCTAssertNil(store.selectedDate)
        }
    }

    @MainActor
    func testHubModeCinemaShelfHeight() {
        let store = QuickToolsStore.shared
        store.hubMode = .cinema
        XCTAssertEqual(store.shelfExtraHeight(isIsland: true), 290)
        XCTAssertEqual(store.shelfExtraHeight(isIsland: false), 300)
    }

    // MARK: - Review fixes

    private func makeItem(
        _ date: String,
        platform: CinemaPlatform = .theater,
        title: String = "테스트",
        trailer: URL? = nil
    ) -> CinemaReleaseItem {
        CinemaReleaseItem(
            title: title,
            originalTitle: "Test",
            platform: platform,
            releaseDateString: date,
            genre: "드라마",
            directorOrCast: "감독",
            synopsis: "줄거리",
            trailerURL: trailer
        )
    }

    @MainActor
    func testReleaseDayParsingRejectsMalformedAndImpossibleDates() {
        XCTAssertEqual(CinemaReleaseItem.parseReleaseDay("2026-12-18"), DateComponents(year: 2026, month: 12, day: 18))
        XCTAssertNil(CinemaReleaseItem.parseReleaseDay("2026-02-30"))
        XCTAssertNil(CinemaReleaseItem.parseReleaseDay("2026-13-01"))
        XCTAssertNil(CinemaReleaseItem.parseReleaseDay("26-12-18"))
        XCTAssertNil(CinemaReleaseItem.parseReleaseDay(""))
        XCTAssertFalse(makeItem("not-a-date").hasValidReleaseDate)
    }

    @MainActor
    func testReleaseDateIsLocalMidnightOfTheReleaseDay() {
        let item = makeItem("2025-11-27")
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour], from: item.releaseDate)
        XCTAssertEqual(parts.year, 2025)
        XCTAssertEqual(parts.month, 11)
        XCTAssertEqual(parts.day, 27)
        XCTAssertEqual(parts.hour, 0)
        XCTAssertEqual(item.yearMonthKey, "2025.11")
        XCTAssertEqual(item.shortDateString, "11.27")
    }

    @MainActor
    func testDDayLabelsAreLocalizedAndCoverAllStreamingPlatforms() {
        let cal = Calendar.current
        let tenDaysAgo = cal.date(byAdding: .day, value: -10, to: cal.startOfDay(for: Date()))!
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: tenDaysAgo)
        let date = String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)

        XCTAssertEqual(makeItem(date, platform: .disney).formattedDDay(isKorean: true), "스트리밍 중")
        XCTAssertEqual(makeItem(date, platform: .apple).formattedDDay(isKorean: false), "Streaming")
        XCTAssertEqual(makeItem(date, platform: .theater).formattedDDay(isKorean: false), "In Theaters")
        XCTAssertEqual(makeItem("2001-01-01").formattedDDay(isKorean: false), "Released")
    }

    @MainActor
    func testMissingTrailerFallsBackToYouTubeSearch() throws {
        let direct = URL(string: "https://www.youtube.com/watch?v=4rgYUipGJNo")!
        XCTAssertEqual(makeItem("2024-11-13", trailer: direct).resolvedTrailerURL, direct)

        let fallback = try XCTUnwrap(makeItem("2024-12-24", title: "하얼빈").resolvedTrailerURL)
        XCTAssertEqual(fallback.host, "www.youtube.com")
        XCTAssertEqual(fallback.path, "/results")
        let query = URLComponents(url: fallback, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "search_query" })?.value
        XCTAssertEqual(query, "하얼빈 Test 예고편")
    }

    @MainActor
    func testRemoteDataURLMatchesRepositoryLayout() {
        XCTAssertEqual(
            CinemaReleaseStore.remoteDataURL.absoluteString,
            "https://raw.githubusercontent.com/skang1310/Notchie/main/DynamicNotch/Resources/cinema_releases.json"
        )
        XCTAssertFalse(CinemaReleaseStore.remoteDataURL.path.contains("DynamicNotch/DynamicNotch"))
    }

    @MainActor
    func testStoreDropsInvalidDatesAndDerivesPeriodsFromData() {
        let store = CinemaReleaseStore(initialReleases: [
            makeItem("2025-03-01", title: "A"),
            makeItem("2099-01-01", title: "Future"),
            makeItem("broken", title: "Broken")
        ])
        XCTAssertEqual(store.releases.map(\.title), ["A", "Future"])
        XCTAssertEqual(store.availablePeriods.map(\.id), ["all", "upcoming", "2025", "2099"])
        XCTAssertEqual(store.selectedItem?.title, "Future", "nearest upcoming release is selected first")

        store.selectedPeriodFilter = "upcoming"
        XCTAssertEqual(store.filteredReleases.map(\.title), ["Future"])
        store.selectedPeriodFilter = "2025"
        XCTAssertEqual(store.filteredReleases.map(\.title), ["A"])
        store.selectedPeriodFilter = "2025.03"
        XCTAssertEqual(store.filteredReleases.map(\.title), ["A"])
    }

    @MainActor
    func testRefreshFailureIsNotReportedAsLatest() {
        let store = CinemaReleaseStore(initialReleases: [makeItem("2025-03-01")])
        XCTAssertNil(store.lastUpdatedDate, "no remote sync has happened yet")
        XCTAssertFalse(store.lastRefreshFailed)
    }

    @MainActor
    func testICSContainsRequiredFieldsAndEscapesText() {
        let item = CinemaReleaseItem(
            title: "듄; 파트 3, 메시아",
            originalTitle: "Dune",
            platform: .theater,
            releaseDateString: "2026-12-31",
            genre: "SF",
            directorOrCast: "감독",
            synopsis: "첫 줄\n둘째 줄",
            trailerURL: nil
        )
        let ics = CinemaReleaseStore.makeICS(for: item, now: Date(timeIntervalSince1970: 0))
        XCTAssertTrue(ics.contains("\r\n"))
        XCTAssertTrue(ics.contains("UID:\(item.id.uuidString.lowercased())@notchie.local"))
        XCTAssertTrue(ics.contains("DTSTAMP:19700101T000000Z"))
        XCTAssertTrue(ics.contains("DTSTART;VALUE=DATE:20261231"))
        XCTAssertTrue(ics.contains("DTEND;VALUE=DATE:20270101"), "end date rolls over the year")
        XCTAssertTrue(ics.contains("듄\\; 파트 3\\, 메시아"))
        XCTAssertTrue(ics.contains("첫 줄\\n둘째 줄"))
        XCTAssertEqual(CinemaReleaseStore.escapeICSText("a\\b"), "a\\\\b")
    }

    @MainActor
    func testBundledDataHasValidDatesAndUniqueIDs() {
        let store = CinemaReleaseStore()
        XCTAssertFalse(store.releases.isEmpty, "bundled cinema_releases.json must decode")
        XCTAssertEqual(Set(store.releases.map(\.id)).count, store.releases.count)
        XCTAssertTrue(store.releases.allSatisfy(\.hasValidReleaseDate))
    }
}
