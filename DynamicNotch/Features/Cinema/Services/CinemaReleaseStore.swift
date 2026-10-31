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
    @Published public var selectedPeriodFilter: String = "all"
    @Published public var selectedItem: CinemaReleaseItem?
    @Published public var selectedDate: Date? = nil
    @Published public var isCalendarMode: Bool = false
    @Published public var searchText: String = ""
    @Published public var isRefreshing: Bool = false
    @Published public var lastUpdatedDate: Date? = nil
    @Published public private(set) var releases: [CinemaReleaseItem] = []

    public let availablePeriods: [(id: String, en: String, ko: String)] = [
        ("all", "All Dates", "전체"),
        ("2024.11", "Nov 2024", "11월"),
        ("2024.12", "Dec 2024", "12월"),
        ("2025", "2025 Lineup", "2025년"),
        ("2026", "2026 Blockbusters", "2026년")
    ]

    public init() {
        self.releases = Self.loadInitialReleases()
        self.selectedItem = self.releases.first
        self.lastUpdatedDate = Date()
    }

    public var filteredReleases: [CinemaReleaseItem] {
        var list = releases

        // 1. Platform Filter
        if selectedFilter != .all {
            list = list.filter { $0.platform == selectedFilter }
        }

        // 2. Period Filter
        if selectedPeriodFilter != "all" {
            if selectedPeriodFilter == "2024.11" {
                list = list.filter { $0.yearMonthKey == "2024.11" }
            } else if selectedPeriodFilter == "2024.12" {
                list = list.filter { $0.yearMonthKey == "2024.12" }
            } else if selectedPeriodFilter == "2025" {
                list = list.filter { $0.releaseDateString.hasPrefix("2025") }
            } else if selectedPeriodFilter == "2026" {
                list = list.filter { $0.releaseDateString.hasPrefix("2026") }
            }
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
        guard let url = item.trailerURL else { return }
        NSWorkspace.shared.open(url)
    }

    public func addToCalendar(for item: CinemaReleaseItem) {
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

    public func refreshReleases() async {
        guard !isRefreshing else { return }
        isRefreshing = true

        let urlString = "https://raw.githubusercontent.com/skang1310/Notchie/main/DynamicNotch/DynamicNotch/Resources/cinema_releases.json"
        guard let url = URL(string: urlString) else {
            isRefreshing = false
            return
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 4.0
            request.cachePolicy = .reloadIgnoringLocalCacheData

            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                let items = try decoder.decode([CinemaReleaseItem].self, from: data)
                if !items.isEmpty {
                    self.releases = items
                    if let first = items.first(where: { $0.id == self.selectedItem?.id }) ?? items.first {
                        self.selectedItem = first
                    }
                }
            }
        } catch {
            // Offline or fallback to bundled items
        }

        self.lastUpdatedDate = Date()
        self.isRefreshing = false
    }

    private static func formatIcsDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        return f.string(from: date)
    }

    private static func loadInitialReleases() -> [CinemaReleaseItem] {
        // 1. Try to load from Bundle cinema_releases.json
        if let bundleURL = Bundle.main.url(forResource: "cinema_releases", withExtension: "json") {
            if let data = try? Data(contentsOf: bundleURL) {
                if let items = try? JSONDecoder().decode([CinemaReleaseItem].self, from: data), !items.isEmpty {
                    return items
                }
            }
        }

        // 2. Direct embedded authoritative Korean & Global 2024–2026 dataset
        return [
            CinemaReleaseItem(
                title: "청설",
                originalTitle: "Hear Me: Our Summer",
                platform: .theater,
                releaseDateString: "2024-11-06",
                genre: "청춘 로맨스 · 드라마",
                directorOrCast: "조선호 감독 / 홍경, 노윤서, 김민주",
                synopsis: "손으로 진심을 전하는 여름과 그녀에게 첫눈에 반한 용준. 떨리는 눈빛과 손짓으로 시작된 가장 청량한 사랑의 계절.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=oE7k8i5QZ4I"),
                rating: "전체",
                posterColors: ["#38BDF8", "#0C4A6E"],
                iconSymbol: "heart.fill"
            ),
            CinemaReleaseItem(
                title: "레드 원",
                originalTitle: "Red One",
                platform: .theater,
                releaseDateString: "2024-11-06",
                genre: "코믹 액션 · 블록버스터",
                directorOrCast: "제이크 캐스단 감독 / 드웨인 존슨, 크리스 에반스, J.K. 시몬스",
                synopsis: "크리스마스 이브, 코드명 '레드 원' 산타클로스가 납치됐다! E.L.F 특수요원과 악명 높은 추적자의 전 세계를 넘나드는 구출 대작전.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=U8QkH_R1W3Y"),
                rating: "12+",
                posterColors: ["#DC2626", "#450A0A"],
                iconSymbol: "gift.fill"
            ),
            CinemaReleaseItem(
                title: "강남 비-사이드",
                originalTitle: "Gangnam B-Side",
                platform: .disney,
                releaseDateString: "2024-11-06",
                genre: "범죄 액션 · 하드보일드 추격극",
                directorOrCast: "박누리 감독 / 조우진, 지창욱, 하윤경, 김형서(비비)",
                synopsis: "강남에서 사라진 클럽 에이스를 찾는 형사와 의문의 브로커, 검사가 얽히며 강남 이면의 거대한 카르텔을 파헤치는 추격극.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=q6_yXb5yDqY"),
                rating: "청불",
                posterColors: ["#2563EB", "#0F172A"],
                iconSymbol: "person.badge.shield.checkmark.fill"
            ),
            CinemaReleaseItem(
                title: "글래디에이터 Ⅱ",
                originalTitle: "Gladiator II",
                platform: .theater,
                releaseDateString: "2024-11-13",
                genre: "대서사 액션 · 시대극 · 로마",
                directorOrCast: "리들리 스콧 감독 / 폴 메스칼, 페드로 파스칼, 덴젤 워싱턴",
                synopsis: "막시무스의 죽음 20여 년 후, 콜로세움을 뒤흔들 새로운 영웅 루시우스의 거대한 운명과 로마 제국을 향한 복수가 펼쳐진다.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=4rgYUipGJNo"),
                rating: "청불",
                posterColors: ["#F59E0B", "#451A03"],
                iconSymbol: "shield.fill"
            ),
            CinemaReleaseItem(
                title: "사흘",
                originalTitle: "Devils Stay",
                platform: .theater,
                releaseDateString: "2024-11-14",
                genre: "오컬트 호러 · 미스터리",
                directorOrCast: "현문섭 감독 / 박신양, 이민기, 이레",
                synopsis: "심장이식 수술 후 사망한 딸의 장례를 치르는 사흘 동안, 심장에서 깨어나는 악마와 사투를 벌이는 흉부외과의사와 구마사제.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=Tq_Yl0YhP0s"),
                rating: "15+",
                posterColors: ["#475569", "#0F172A"],
                iconSymbol: "cross.fill"
            ),
            CinemaReleaseItem(
                title: "위키드",
                originalTitle: "Wicked",
                platform: .theater,
                releaseDateString: "2024-11-20",
                genre: "판타지 · 뮤지컬 대작",
                directorOrCast: "존 추 감독 / 신시아 에리보, 아리아나 그란데, 조나단 베일리",
                synopsis: "오즈의 마법사 이전의 숨겨진 이야기. 초록 피부의 엘파바와 눈부신 글린다, 진정한 우정과 세상을 뒤흔들 마법의 비밀.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=6COmYeLsz4c"),
                rating: "전체",
                posterColors: ["#10B981", "#064E3B"],
                iconSymbol: "wand.and.stars"
            ),
            CinemaReleaseItem(
                title: "모아나 2",
                originalTitle: "Moana 2",
                platform: .theater,
                releaseDateString: "2024-11-27",
                genre: "디즈니 애니메이션 · 해양 모험 · 뮤지컬",
                directorOrCast: "데이브 데릭 주니어 감독 / 아우이 크라발호, 드웨인 존슨",
                synopsis: "조상들의 부름을 받은 모아나와 마우이, 다시 한번 미지의 바다 너머로 떠나는 숨 막히는 대항해와 신비로운 모험.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=hDZ7y8RP5HE"),
                rating: "전체",
                posterColors: ["#06B6D4", "#083344"],
                iconSymbol: "water.waves"
            ),
            CinemaReleaseItem(
                title: "트렁크",
                originalTitle: "The Trunk",
                platform: .netflix,
                releaseDateString: "2024-11-29",
                genre: "미스터리 · 멜로 · 서스펜스",
                directorOrCast: "김규태 감독 / 서현진, 공유, 정윤하",
                synopsis: "호숫가에 떠오른 트렁크로 인해 밝혀지는 비밀스러운 기간제 결혼 서비스와, 그 안에서 얽히는 두 남녀의 기묘한 관계.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=FjC30l7554E"),
                rating: "청불",
                posterColors: ["#E11D48", "#1E1B4B"],
                iconSymbol: "lock.fill"
            ),
            CinemaReleaseItem(
                title: "1승",
                originalTitle: "One Win",
                platform: .theater,
                releaseDateString: "2024-12-04",
                genre: "스포츠 드라마 · 코미디",
                directorOrCast: "신연식 감독 / 송강호, 박정민, 장윤주",
                synopsis: "지도자 인생에서 단 한 번도 이겨본 적 없는 배구 감독 김우진과 해체 직전의 여자배구단 핑크스톰이 단 1승을 위해 뭉쳤다.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=pYq_Z6X6t3k"),
                rating: "12+",
                posterColors: ["#EC4899", "#831843"],
                iconSymbol: "trophy.fill"
            ),
            CinemaReleaseItem(
                title: "소방관",
                originalTitle: "Firefighters",
                platform: .theater,
                releaseDateString: "2024-12-04",
                genre: "휴먼 실화 드라마",
                directorOrCast: "곽경택 감독 / 주원, 유재명, 이유영, 곽도원",
                synopsis: "2001년 홍제동 화재 참사 실화. 열악한 환경 속에서도 오직 한 사람의 생명을 구하기 위해 화염 속으로 뛰어든 서부소방서 대원들.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=Yk8_Zk2p2hY"),
                rating: "12+",
                posterColors: ["#EA580C", "#431407"],
                iconSymbol: "flame.fill"
            ),
            CinemaReleaseItem(
                title: "조명가게",
                originalTitle: "Light Shop",
                platform: .disney,
                releaseDateString: "2024-12-04",
                genre: "미스터리 판타지 · 휴먼",
                directorOrCast: "김희원 감독 / 주지훈, 박보영, 배성우, 엄태구 / 강풀 극본",
                synopsis: "어두운 골목 끝, 24시간 불이 켜져 있는 조명가게. 산 자와 죽은 자의 경계에서 저마다의 사연을 품은 손님들이 찾아온다.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=K_N0_Dk8B6k"),
                rating: "15+",
                posterColors: ["#FACC15", "#1E293B"],
                iconSymbol: "lightbulb.fill"
            ),
            CinemaReleaseItem(
                title: "대가족",
                originalTitle: "About Family",
                platform: .theater,
                releaseDateString: "2024-12-11",
                genre: "가족 드라마 · 코믹",
                directorOrCast: "양우석 감독 / 김윤석, 이승기, 김성령",
                synopsis: "대대로 내려오는 만두 명가 '평만옥'의 고집불통 사장 무옥. 승려가 되어 출가한 외아들 대신 뜻밖의 어린 손자들이 찾아오면서 벌어지는 대소동.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=Kz6X3VpGv4I"),
                rating: "12+",
                posterColors: ["#14B8A6", "#042F2E"],
                iconSymbol: "person.3.fill"
            ),
            CinemaReleaseItem(
                title: "서브스턴스",
                originalTitle: "The Substance",
                platform: .theater,
                releaseDateString: "2024-12-11",
                genre: "파격 바디 호러 · 스릴러",
                directorOrCast: "코랄리 파르자 감독 / 데미 무어, 마거릿 퀄리",
                synopsis: "칸 영화제 각본상 수상작. 더 젊고 완벽한 '또 다른 나'를 만들어내는 기적의 약물을 투여한 여배우의 충격적이고 파격적인 욕망의 끝.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=LNlrGhPdnk8"),
                rating: "청불",
                posterColors: ["#9333EA", "#2E1065"],
                iconSymbol: "syringe.fill"
            ),
            CinemaReleaseItem(
                title: "하얼빈",
                originalTitle: "Harbin",
                platform: .theater,
                releaseDateString: "2024-12-25",
                genre: "시대극 · 첩보 액션 · 대작",
                directorOrCast: "우민호 감독 / 현빈, 박정민, 조우진, 전여빈",
                synopsis: "1909년 하얼빈, 단 하나의 목표인 늙은 늑대를 처단하기 위해 목숨을 건 독립투사들과 그들을 쫓는 자들의 숨 막히는 추적과 결의.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=f2W2L-0LhyU"),
                rating: "15+",
                posterColors: ["#64748B", "#0F172A"],
                iconSymbol: "mountain.2.fill"
            ),
            CinemaReleaseItem(
                title: "오징어 게임 시즌 2",
                originalTitle: "Squid Game: Season 2",
                platform: .netflix,
                releaseDateString: "2024-12-26",
                genre: "데스게임 · 서바이벌 · 스릴러",
                directorOrCast: "황동혁 감독 / 이정재, 이병헌, 임시완, 강하늘, 박규영, 조유리",
                synopsis: "게임을 멈추기 위해 다시 456번 초록색 트레이닝복을 입은 성기훈. 새로운 456명의 참가자들과 더 잔혹해진 게임의 실체가 밝혀진다.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=lQBmZkPrtGE"),
                rating: "청불",
                posterColors: ["#E50914", "#180305"],
                iconSymbol: "circle.grid.cross.fill"
            ),
            CinemaReleaseItem(
                title: "보고타: 마지막 기회의 땅",
                originalTitle: "Bogota: City of the Lost",
                platform: .theater,
                releaseDateString: "2024-12-31",
                genre: "범죄 드라마 · 누아르",
                directorOrCast: "김성제 감독 / 송중기, 이희준, 권해효",
                synopsis: "희망 없는 삶을 뒤로하고 콜롬비아 보고타로 떠난 국희. 보고타 한인 상권을 장악하기 위해 생존을 건 도박을 시작한다.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=Qx8J4B8W4Nk"),
                rating: "15+",
                posterColors: ["#D97706", "#451A03"],
                iconSymbol: "building.2.fill"
            ),
            CinemaReleaseItem(
                title: "세브란스: 단절 시즌 2",
                originalTitle: "Severance Season 2",
                platform: .apple,
                releaseDateString: "2025-01-17",
                genre: "SF 심리 스릴러",
                directorOrCast: "벤 스틸러 감독 / 애덤 스콧, 패트리샤 아켓, 존 터투로",
                synopsis: "직장 자아와 일상 자아를 영구히 분리하는 단절 수술. 루몬 인더스트리의 감춰진 비밀과 거짓이 폭로된다.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=aNyT4Z3pUvU"),
                rating: "15+",
                posterColors: ["#0284C7", "#082F49"],
                iconSymbol: "brain.head.profile"
            ),
            CinemaReleaseItem(
                title: "중증외상센터",
                originalTitle: "The Trauma Code: Heroes on Call",
                platform: .netflix,
                releaseDateString: "2025-01-24",
                genre: "메디컬 액션 · 휴먼 드라마",
                directorOrCast: "이도윤 감독 / 주지훈, 추영우, 윤경호, 정재광",
                synopsis: "전쟁터를 누비던 외상외과 천재 전문의 백강혁이 적자투성이 한국 대학병원 중증외상팀에 부임하며 벌어지는 통쾌한 생명 구출기.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=kRj8W4_mK2k"),
                rating: "15+",
                posterColors: ["#EF4444", "#1E1B4B"],
                iconSymbol: "cross.case.fill"
            ),
            CinemaReleaseItem(
                title: "캡틴 아메리카: 브레이브 뉴 월드",
                originalTitle: "Captain America: Brave New World",
                platform: .theater,
                releaseDateString: "2025-02-14",
                genre: "마블 슈퍼히어로 · 첩보 액션",
                directorOrCast: "줄리어스 오나 감독 / 앤서니 매키, 해리슨 포드, 시라 하스",
                synopsis: "새로운 캡틴 샘 윌슨, 백악관 국제 회담을 뒤흔든 암살 음모 속에서 붉은 거인 레드 헐크와 정면 격돌한다.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=1pHDWnXmK7Y"),
                rating: "12+",
                posterColors: ["#2563EB", "#7F1D1D"],
                iconSymbol: "shield.lefthalf.filled"
            ),
            CinemaReleaseItem(
                title: "계시록",
                originalTitle: "Revelations",
                platform: .netflix,
                releaseDateString: "2025-03-21",
                genre: "미스터리 범죄 스릴러",
                directorOrCast: "연상호 감독 / 류준열, 신현빈",
                synopsis: "실종 사건의 범인을 단죄하라는 신의 계시를 받은 목사와 죽은 동생의 환영에 시달리는 형사의 숨 막히는 추적.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=pAk6k0ZkGg8"),
                rating: "청불",
                posterColors: ["#831843", "#18020C"],
                iconSymbol: "eye.fill"
            ),
            CinemaReleaseItem(
                title: "미키 17",
                originalTitle: "Mickey 17",
                platform: .theater,
                releaseDateString: "2025-04-18",
                genre: "SF 블랙 코미디 · 모험",
                directorOrCast: "봉준호 감독 / 로버트 패틴슨, 나오미 애키, 스티븐 연",
                synopsis: "얼음 행성 개척에 투입된 복제 인간 익스펜더블 '미키'. 17번째 죽음 직전, 뜻밖에도 이전 번호의 미키와 마주친다.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=osYpGSz_mMk"),
                rating: "15+",
                posterColors: ["#38BDF8", "#022C22"],
                iconSymbol: "person.crop.circle.badge.plus"
            ),
            CinemaReleaseItem(
                title: "광장",
                originalTitle: "The Square",
                platform: .netflix,
                releaseDateString: "2025-05-16",
                genre: "누아르 액션 · 하드보일드",
                directorOrCast: "최성은 감독 / 소지섭, 허준호, 안길강, 이준혁",
                synopsis: "스스로 아킬레스건을 끊고 조직을 떠났던 기준. 동생의 의문사를 계기로 11년 만에 다시 피의 복수를 위해 돌아온다.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=vV_3K3k0v70"),
                rating: "청불",
                posterColors: ["#475569", "#0F172A"],
                iconSymbol: "suit.club.fill"
            ),
            CinemaReleaseItem(
                title: "기묘한 이야기 시즌 5",
                originalTitle: "Stranger Things 5",
                platform: .netflix,
                releaseDateString: "2025-07-15",
                genre: "SF · 미스터리 · 호러 대서사",
                directorOrCast: "더퍼 형제 / 밀리 바비 브라운, 핀 울프하드, 위노나 라이더",
                synopsis: "뒤집힌 세계와의 최종 결전. 호킨스 마을을 지키기 위한 일레븐과 친구들의 마지막 대서사시.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=b9EkMc79ZSU"),
                rating: "15+",
                posterColors: ["#B91C1C", "#18020C"],
                iconSymbol: "bolt.fill"
            ),
            CinemaReleaseItem(
                title: "가능한 사랑",
                originalTitle: "Possible Love",
                platform: .netflix,
                releaseDateString: "2026-04-10",
                genre: "감성 멜로 · 휴먼 드라마",
                directorOrCast: "이창동 감독 / 전도연, 설경구, 조인성",
                synopsis: "삶의 변곡점에서 마주한 남녀의 운명적 만남. 거장 이창동 감독과 전도연, 설경구의 만남.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=lQBmZkPrtGE"),
                rating: "15+",
                posterColors: ["#BE185D", "#500724"],
                iconSymbol: "sparkles"
            ),
            CinemaReleaseItem(
                title: "어벤져스: 둠스데이",
                originalTitle: "Avengers: Doomsday",
                platform: .theater,
                releaseDateString: "2026-05-01",
                genre: "마블 블록버스터 · SF 대서사",
                directorOrCast: "루소 형제 / 로버트 다우니 주니어, 페드로 파스칼",
                synopsis: "닥터 둠으로 돌아온 로버트 다우니 주니어. 멀티버스의 존망을 걸고 집결하는 어벤져스의 거대한 전쟁.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=1pHDWnXmK7Y"),
                rating: "12+",
                posterColors: ["#15803D", "#052E16"],
                iconSymbol: "crown.fill"
            ),
            CinemaReleaseItem(
                title: "듄: 파트 3",
                originalTitle: "Dune: Part Three (Messiah)",
                platform: .theater,
                releaseDateString: "2026-12-18",
                genre: "SF 대서사시 · 스페이스 오페라",
                directorOrCast: "드니 빌뇌브 감독 / 티모시 샬라메, 젠데이아",
                synopsis: "아라키스의 황제가 된 폴 아트레이데스의 성전과 메시아로서의 비극적 운명을 다룬 듄 대서사시의 완결편.",
                trailerURL: URL(string: "https://www.youtube.com/watch?v=4rgYUipGJNo"),
                rating: "12+",
                posterColors: ["#D97706", "#451A03"],
                iconSymbol: "sun.max.fill"
            )
        ]
    }
}
