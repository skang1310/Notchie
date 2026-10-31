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
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")

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
}
