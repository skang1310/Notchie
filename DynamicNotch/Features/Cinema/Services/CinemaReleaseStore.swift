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

    @Published public var selectedFilter: CinemaPlatform = .all
    @Published public var selectedItem: CinemaReleaseItem?
    @Published public var selectedDate: Date? = nil
    @Published public var isCalendarMode: Bool = false
    @Published public var searchText: String = ""
    @Published public private(set) var releases: [CinemaReleaseItem] = []

    public init() {
        self.releases = Self.generateCuratedReleases()
        self.selectedItem = self.releases.first
    }

    public var filteredReleases: [CinemaReleaseItem] {
        var list = releases

        if selectedFilter != .all {
            list = list.filter { $0.platform == selectedFilter }
        }

        if let selectedDate {
            let cal = Calendar.current
            list = list.filter { cal.isDate($0.releaseDate, inSameDayAs: selectedDate) }
        }

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
            // Deselect on second click
            selectedDate = nil
        } else {
            selectedDate = date
            if let date, let first = releasesOnDate(date).first {
                selectedItem = first
            }
        }
    }

    public func openTrailer(for item: CinemaReleaseItem) {
        guard let url = item.trailerURL else { return }
        NSWorkspace.shared.open(url)
    }

    public func addToCalendar(for item: CinemaReleaseItem) {
        // Build .ics temporary file and open in Calendar app
        let icsContent = """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//Notchie//Cinema Trailers//EN
        CALSCALE:GREGORIAN
        METHOD:PUBLISH
        BEGIN:VEVENT
        SUMMARY:🎬 [개봉] \(item.title) (\(item.platform.localizedName(isKorean: true)))
        DESCRIPTION:\(item.genre) | \(item.directorOrCast)\\n\(item.synopsis)\\n예고편: \(item.trailerURL?.absoluteString ?? "")
        DTSTART;VALUE=DATE:\(Self.formatIcsDate(item.releaseDate))
        DTEND;VALUE=DATE:\(Self.formatIcsDate(Calendar.current.date(byAdding: .day, value: 1, to: item.releaseDate) ?? item.releaseDate))
        STATUS:CONFIRMED
        END:VEVENT
        END:VCALENDAR
        """

        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("\(item.id.uuidString).ics")
        do {
            try icsContent.write(to: tempFile, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(tempFile)
        } catch {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
                NSWorkspace.shared.open(appURL)
            }
        }
    }

    private static func formatIcsDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        return f.string(from: date)
    }

    private static func relativeDate(days: Int) -> Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return cal.date(byAdding: .day, value: days, to: today) ?? today
    }

    private static func generateCuratedReleases() -> [CinemaReleaseItem] {
        [
            CinemaReleaseItem(
                title: "오징어 게임 시즌 2",
                originalTitle: "Squid Game: Season 2",
                platform: .netflix,
                releaseDate: relativeDate(days: 3),
                genre: "서스펜스 · 스릴러 · 드라마",
                directorOrCast: "황동혁 감독 / 이정재, 이병헌, 임시완, 강하늘, 박규영",
                synopsis: "게임을 끝내기 위해 다시 돌아온 기훈. 더 잔혹해진 데스 매치와 새로운 참가자들의 치열한 두뇌 싸움이 시작된다.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=lQBmZkPrtGE"),
                rating: "청불",
                posterGradient: [Color(red: 0.85, green: 0.08, blue: 0.16), Color(red: 0.12, green: 0.02, blue: 0.04)],
                iconSymbol: "circle.grid.cross.fill"
            ),
            CinemaReleaseItem(
                title: "글래디에이터 II",
                originalTitle: "Gladiator II",
                platform: .theater,
                releaseDate: relativeDate(days: 6),
                genre: "대서사 액션 · 시대극 · 드라마",
                directorOrCast: "리들리 스콧 감독 / 폴 메스칼, 페드로 파스칼, 덴젤 워싱턴",
                synopsis: "막시무스의 죽음 20여 년 후, 콜로세움을 뒤흔들 새로운 영웅 루시우스의 거대한 운명과 복수가 펼쳐진다.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=4rgYUipGJNo"),
                rating: "15+",
                posterGradient: [Color(red: 0.85, green: 0.55, blue: 0.10), Color(red: 0.18, green: 0.10, blue: 0.02)],
                iconSymbol: "shield.fill"
            ),
            CinemaReleaseItem(
                title: "모아나 2",
                originalTitle: "Moana 2",
                platform: .theater,
                releaseDate: relativeDate(days: 10),
                genre: "애니메이션 · 뮤지컬 · 해양 어드벤처",
                directorOrCast: "데이브 데릭 주니어 감독 / 아우이 크라발호, 드웨인 존슨",
                synopsis: "조상들의 부름을 받은 모아나와 마우이, 다시 한번 미지의 바다 너머로 떠나는 장대한 대항해.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=hDZ7y8RP5HE"),
                rating: "전체",
                posterGradient: [Color(red: 0.08, green: 0.65, blue: 0.82), Color(red: 0.02, green: 0.15, blue: 0.28)],
                iconSymbol: "water.waves"
            ),
            CinemaReleaseItem(
                title: "위키드",
                originalTitle: "Wicked",
                platform: .theater,
                releaseDate: relativeDate(days: 14),
                genre: "판타지 · 뮤지컬",
                directorOrCast: "존 추 감독 / 신시아 에리보, 아리아나 그란데, 조나단 베일리",
                synopsis: "오즈의 마법사 이전, 초록 마녀 엘파바와 착한 마녀 글린다의 특별한 우정과 세상이 알지 못한 진실.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=6COmYeLsz4c"),
                rating: "전체",
                posterGradient: [Color(red: 0.12, green: 0.72, blue: 0.38), Color(red: 0.04, green: 0.18, blue: 0.08)],
                iconSymbol: "wand.and.stars"
            ),
            CinemaReleaseItem(
                title: "기묘한 이야기 시즌 5",
                originalTitle: "Stranger Things 5",
                platform: .netflix,
                releaseDate: relativeDate(days: 18),
                genre: "SF · 미스터리 · 호러",
                directorOrCast: "더퍼 형제 / 밀리 바비 브라운, 핀 울프하드, 위노나 라이더",
                synopsis: "뒤집힌 세계와의 최종 결전. 호킨스 마을을 지키기 위한 일레븐과 친구들의 마지막 대서사시.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=b9EkMc79ZSU"),
                rating: "15+",
                posterGradient: [Color(red: 0.75, green: 0.08, blue: 0.22), Color(red: 0.05, green: 0.02, blue: 0.15)],
                iconSymbol: "flame.fill"
            ),
            CinemaReleaseItem(
                title: "하얼빈",
                originalTitle: "Harbin",
                platform: .theater,
                releaseDate: relativeDate(days: 22),
                genre: "시대극 · 첩보 액션 · 드라마",
                directorOrCast: "우민호 감독 / 현빈, 박정민, 조우진, 전여빈",
                synopsis: "1909년 하얼빈, 단 하나의 목표를 향해 목숨을 건 독립투사들의 숨 막히는 추적과 결의.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=f2W2L-0LhyU"),
                rating: "15+",
                posterGradient: [Color(red: 0.40, green: 0.45, blue: 0.52), Color(red: 0.08, green: 0.10, blue: 0.14)],
                iconSymbol: "mountain.2.fill"
            ),
            CinemaReleaseItem(
                title: "계시록",
                originalTitle: "Revelations",
                platform: .netflix,
                releaseDate: relativeDate(days: 27),
                genre: "범죄 스릴러 · 미스터리",
                directorOrCast: "연상호 감독 / 류준열, 신현빈",
                synopsis: "실종 사건의 범인을 쫓는 형사와 신의 계시를 믿는 목사, 예측할 수 없는 혼돈 속의 진실 추적.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=pAk6k0ZkGg8"),
                rating: "청불",
                posterGradient: [Color(red: 0.55, green: 0.12, blue: 0.28), Color(red: 0.10, green: 0.04, blue: 0.08)],
                iconSymbol: "cross.fill"
            ),
            CinemaReleaseItem(
                title: "캡틴 아메리카: 브레이브 뉴 월드",
                originalTitle: "Captain America: Brave New World",
                platform: .theater,
                releaseDate: relativeDate(days: 32),
                genre: "슈퍼히어로 · 첩보 액션",
                directorOrCast: "줄리어스 오나 감독 / 앤서니 매키, 해리슨 포드, 지안카를로 에스포지토",
                synopsis: "새로운 캡틴 샘 윌슨, 국제적 음모의 중심에서 붉은 거인 레드 헐크와 정면 격돌한다.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=1pHDWnXmK7Y"),
                rating: "12+",
                posterGradient: [Color(red: 0.15, green: 0.38, blue: 0.82), Color(red: 0.58, green: 0.12, blue: 0.16)],
                iconSymbol: "shield.lefthalf.filled"
            ),
            CinemaReleaseItem(
                title: "미키 17",
                originalTitle: "Mickey 17",
                platform: .theater,
                releaseDate: relativeDate(days: 38),
                genre: "SF · 블랙 코미디 · 모험",
                directorOrCast: "봉준호 감독 / 로버트 패틴슨, 나오미 애키, 스티븐 연",
                synopsis: "얼음 행성 개척에 투입된 복제인간 익스펜더블 '미키', 열일곱 번째 죽음 직면에서 마주한 뜻밖의 자아.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=osYpGSz_mMk"),
                rating: "15+",
                posterGradient: [Color(red: 0.35, green: 0.65, blue: 0.85), Color(red: 0.05, green: 0.10, blue: 0.20)],
                iconSymbol: "person.crop.circle.badge.plus"
            ),
            CinemaReleaseItem(
                title: "세브란스: 단절 시즌 2",
                originalTitle: "Severance Season 2",
                platform: .apple,
                releaseDate: relativeDate(days: 44),
                genre: "SF · 심리 스릴러",
                directorOrCast: "벤 스틸러 감독 / 애덤 스콧, 패트리샤 아켓, 존 터투로",
                synopsis: "직장 자아와 일상 자아를 영구히 분리하는 단절 수술. 루몬 인더스트리의 감춰진 비밀이 폭로된다.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=aNyT4Z3pUvU"),
                rating: "15+",
                posterGradient: [Color(red: 0.22, green: 0.68, blue: 0.75), Color(red: 0.04, green: 0.14, blue: 0.18)],
                iconSymbol: "brain.head.profile"
            )
        ]
    }
}
