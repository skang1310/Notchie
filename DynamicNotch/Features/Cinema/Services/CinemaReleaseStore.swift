//
//  CinemaReleaseStore.swift
//  DynamicNotch
//

import Foundation
internal import AppKit
import SwiftUI
import Combine

@MainActor
public final class CinemaReleaseStore: ObservableObject {
    public static let shared = CinemaReleaseStore()

    /// Raw JSON on the default branch. The repository root contains `DynamicNotch/Resources`,
    /// so the path must not repeat the `DynamicNotch` folder (the old URL always returned 404).
    nonisolated static let remoteDataURL = URL(string: "https://raw.githubusercontent.com/skang1310/Notchie/main/DynamicNotch/Resources/cinema_releases.json")!

    @Published public var selectedFilter: CinemaPlatform = .all
    @Published public var selectedPeriodFilter: String = "all"
    @Published public var selectedItem: CinemaReleaseItem?
    @Published public var selectedDate: Date? = nil
    @Published public var isCalendarMode: Bool = false
    @Published public var searchText: String = ""
    @Published public var isRefreshing: Bool = false
    /// Time of the last successful remote sync. `nil` until one succeeds, which lets the view
    /// trigger the first sync on appear (it was set in `init`, so auto-sync never ran).
    @Published public private(set) var lastUpdatedDate: Date? = nil
    /// `true` when the most recent remote sync failed and bundled data is shown.
    @Published public private(set) var lastRefreshFailed: Bool = false
    @Published public private(set) var releases: [CinemaReleaseItem] = []

    /// Period chips derived from the data instead of hard-coded months that go stale.
    public var availablePeriods: [(id: String, en: String, ko: String)] {
        var periods: [(id: String, en: String, ko: String)] = [
            ("all", "All Dates", "전체"),
            ("upcoming", "Upcoming", "개봉 예정")
        ]
        let years = Set(releases.compactMap { $0.releaseDay?.year }).sorted()
        periods += years.map { ("\($0)", "\($0)", "\($0)년") }
        return periods
    }

    public init(initialReleases: [CinemaReleaseItem]? = nil) {
        self.releases = Self.validated(initialReleases ?? Self.loadBundledReleases())
        self.selectedItem = Self.defaultSelection(in: self.releases)
    }

    public var filteredReleases: [CinemaReleaseItem] {
        var list = releases

        // 1. Platform Filter
        if selectedFilter != .all {
            list = list.filter { $0.platform == selectedFilter }
        }

        // 2. Period Filter: "upcoming", a year ("2026") or a month ("2026.11")
        switch selectedPeriodFilter {
        case "all":
            break
        case "upcoming":
            list = list.filter { $0.daysRemaining >= 0 }
        case let period where period.contains("."):
            list = list.filter { $0.yearMonthKey == period }
        case let year:
            list = list.filter { $0.releaseDateString.hasPrefix(year + "-") }
        }

        // 3. Calendar Date Filter
        if let selectedDate {
            let cal = Calendar.current
            list = list.filter { cal.isDate($0.releaseDate, inSameDayAs: selectedDate) }
        }

        // 4. Search Filter
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            list = list.filter {
                $0.title.lowercased().contains(query) ||
                $0.originalTitle.lowercased().contains(query) ||
                $0.genre.lowercased().contains(query) ||
                $0.directorOrCast.lowercased().contains(query) ||
                $0.synopsis.lowercased().contains(query)
            }
        }

        return list.sorted { $0.releaseDate < $1.releaseDate }
    }

    public func releasesOnDate(_ date: Date) -> [CinemaReleaseItem] {
        let cal = Calendar.current
        return releases.filter { cal.isDate($0.releaseDate, inSameDayAs: date) }
    }

    public func selectDate(_ date: Date?) {
        if let current = selectedDate, let date, Calendar.current.isDate(current, inSameDayAs: date) {
            selectedDate = nil
        } else {
            selectedDate = date
            if let date, let first = releasesOnDate(date).first {
                selectedItem = first
            }
        }
    }

    public func openTrailer(for item: CinemaReleaseItem) {
        guard let url = item.resolvedTrailerURL else { return }
        NSWorkspace.shared.open(url)
    }

    public func addToCalendar(for item: CinemaReleaseItem) {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("\(item.id.uuidString).ics")
        do {
            try Self.makeICS(for: item).write(to: tempFile, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(tempFile)
        } catch {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
                NSWorkspace.shared.open(appURL)
            }
        }
    }

    /// RFC 5545 all-day event. Includes the required UID/DTSTAMP, escapes text values and
    /// uses CRLF line endings; dates come from the release day, not a locale-dependent formatter.
    static func makeICS(for item: CinemaReleaseItem, now: Date = Date()) -> String {
        let start = item.releaseDay
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(identifier: "UTC")!
        let startDate = start.flatMap { gregorian.date(from: $0) } ?? now
        let endDate = gregorian.date(byAdding: .day, value: 1, to: startDate) ?? startDate

        func day(_ date: Date) -> String {
            let c = gregorian.dateComponents([.year, .month, .day], from: date)
            return String(format: "%04d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
        }
        let stamp: String = {
            let c = gregorian.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)
            return String(format: "%04d%02d%02dT%02d%02d%02dZ", c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0, c.second ?? 0)
        }()

        let summary = "🎬 [개봉] \(item.title) (\(item.platform.localizedName(isKorean: true)))"
        var description = "\(item.genre) | \(item.directorOrCast)\n\(item.synopsis)"
        if let trailer = item.resolvedTrailerURL?.absoluteString {
            description += "\n예고편: \(trailer)"
        }

        let lines = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//Notchie//Cinema Trailers//EN",
            "CALSCALE:GREGORIAN",
            "METHOD:PUBLISH",
            "BEGIN:VEVENT",
            "UID:\(item.id.uuidString.lowercased())@notchie.local",
            "DTSTAMP:\(stamp)",
            "SUMMARY:\(escapeICSText(summary))",
            "DESCRIPTION:\(escapeICSText(description))",
            "DTSTART;VALUE=DATE:\(day(startDate))",
            "DTEND;VALUE=DATE:\(day(endDate))",
            "TRANSP:TRANSPARENT",
            "END:VEVENT",
            "END:VCALENDAR"
        ]
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    static func escapeICSText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\r\n", with: "\\n")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    public func refreshReleases() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        var request = URLRequest(url: Self.remoteDataURL)
        request.timeoutInterval = 6.0
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                lastRefreshFailed = true
                return
            }
            let items = Self.validated(try JSONDecoder().decode([CinemaReleaseItem].self, from: data))
            guard !items.isEmpty else {
                lastRefreshFailed = true
                return
            }
            apply(items)
            lastUpdatedDate = Date()
            lastRefreshFailed = false
        } catch {
            // Offline or malformed payload: keep showing the bundled/previous data.
            lastRefreshFailed = true
        }
    }

    func apply(_ items: [CinemaReleaseItem]) {
        releases = items
        selectedItem = items.first(where: { $0.id == selectedItem?.id }) ?? Self.defaultSelection(in: items)
    }

    /// Drops entries whose date cannot be parsed (they used to silently become "today").
    static func validated(_ items: [CinemaReleaseItem]) -> [CinemaReleaseItem] {
        items.filter(\.hasValidReleaseDate)
    }

    /// Prefer the nearest upcoming release over the oldest entry in the list.
    static func defaultSelection(in items: [CinemaReleaseItem]) -> CinemaReleaseItem? {
        let sorted = items.sorted { $0.releaseDate < $1.releaseDate }
        return sorted.first(where: { $0.daysRemaining >= 0 }) ?? sorted.last
    }

    /// The bundled JSON is the single source of truth; the previous ~340-line Swift copy of
    /// the same data drifted from it and has been removed.
    private static func loadBundledReleases() -> [CinemaReleaseItem] {
        guard let url = Bundle.main.url(forResource: "cinema_releases", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([CinemaReleaseItem].self, from: data) else {
            return []
        }
        return items
    }
}
