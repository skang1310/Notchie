//
//  CinemaTrailersNotchView.swift
//  DynamicNotch
//

import SwiftUI
internal import AppKit

public struct CinemaTrailersNotchView: View {
    @ObservedObject private var store = CinemaReleaseStore.shared
    var accentColor: Color

    private var isKorean: Bool {
        let raw = UserDefaults.standard.string(forKey: GeneralSettingsStorage.Keys.appLanguage) ?? DynamicNotchLanguage.system.rawValue
        return DynamicNotchLanguage.resolved(raw).locale.language.languageCode?.identifier == "ko"
    }

    private func text(_ en: String, _ ko: String) -> String {
        privacyText(en, ko)
    }

    public init(accentColor: Color = .blue) {
        self.accentColor = accentColor
    }

    public var body: some View {
        VStack(spacing: 8) {
            topFilterBar

            if store.isCalendarMode {
                fullCalendarView
            } else {
                spotlightAndScheduleRow
            }

            bottomPostersCarousel
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            if store.lastUpdatedDate == nil {
                await store.refreshReleases()
            }
        }
    }

    // MARK: - Top Filter & Mode Switcher Bar

    private var topFilterBar: some View {
        HStack(spacing: 5) {
            // Platform Filter Chips
            ForEach(CinemaPlatform.allCases) { platform in
                let isSelected = store.selectedFilter == platform
                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                        store.selectedFilter = platform
                    }
                } label: {
                    HStack(spacing: 3.5) {
                        Image(systemName: platform.iconName)
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundStyle(isSelected ? platform.accentColor : .white.opacity(0.65))

                        Text(platform.localizedName(isKorean: isKorean))
                            .font(.system(size: 9.5, weight: isSelected ? .bold : .medium, design: .rounded))
                            .foregroundStyle(isSelected ? .white : .white.opacity(0.8))
                    }
                    .padding(.horizontal, 6.5)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(isSelected ? platform.accentColor.opacity(0.26) : Color.white.opacity(0.06))
                            .overlay(
                                Capsule().strokeBorder(
                                    isSelected ? platform.accentColor.opacity(0.6) : Color.white.opacity(0.1),
                                    lineWidth: 0.8
                                )
                            )
                    )
                }
                .buttonStyle(.plain)
            }

            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1, height: 14)
                .padding(.horizontal, 1)

            // Period Filter Chips (전체, 11월, 12월, 2025년, 2026년)
            ForEach(store.availablePeriods, id: \.id) { period in
                let isSelected = store.selectedPeriodFilter == period.id
                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                        store.selectedPeriodFilter = period.id
                    }
                } label: {
                    Text(isKorean ? period.ko : period.en)
                        .font(.system(size: 9.5, weight: isSelected ? .bold : .medium, design: .rounded))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.75))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(isSelected ? accentColor.opacity(0.32) : Color.white.opacity(0.05))
                                .overlay(
                                    Capsule().strokeBorder(
                                        isSelected ? accentColor.opacity(0.65) : Color.clear,
                                        lineWidth: 0.8
                                    )
                                )
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Live Network Refresh Button
            Button {
                Task {
                    await store.refreshReleases()
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 8.5, weight: .bold))
                        .rotationEffect(.degrees(store.isRefreshing ? 360 : 0))
                        .animation(store.isRefreshing ? .linear(duration: 0.9).repeatForever(autoreverses: false) : .default, value: store.isRefreshing)
                    Text(store.isRefreshing ? text("Updating", "업데이트 중") : text("Live", "실시간 최신"))
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Color.green)
                .padding(.horizontal, 6.5)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.12), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.green.opacity(0.35), lineWidth: 0.8))
            }
            .buttonStyle(.plain)
            .help(text("Fetch latest online releases", "온라인 최신 개봉 데이터 새로고침"))

            // View Mode Toggle (Spotlight vs Calendar)
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                    store.isCalendarMode.toggle()
                }
            } label: {
                HStack(spacing: 3.5) {
                    Image(systemName: store.isCalendarMode ? "play.rectangle.on.rectangle.fill" : "calendar")
                        .font(.system(size: 9, weight: .bold))
                    Text(store.isCalendarMode ? text("Cards", "티저 카드") : text("Calendar", "개봉 캘린더"))
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                }
                .foregroundStyle(accentColor)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(accentColor.opacity(0.18))
                        .overlay(Capsule().strokeBorder(accentColor.opacity(0.45), lineWidth: 0.8))
                )
            }
            .buttonStyle(.plain)
            .help(text("Toggle between trailer cards and full calendar", "티저 카드와 개봉 캘린더 뷰 전환"))
        }
    }

    // MARK: - Spotlight Trailer Card & Mini Schedule

    private var spotlightAndScheduleRow: some View {
        HStack(spacing: 10) {
            // Left Pane: Featured Trailer Spotlight Card
            if let item = store.selectedItem ?? store.filteredReleases.first {
                spotlightTrailerCard(item: item)
                    .frame(maxWidth: .infinity)
            } else {
                emptyPlaceholderCard
                    .frame(maxWidth: .infinity)
            }

            // Right Pane: Mini Release Timeline
            miniScheduleColumn
                .frame(width: 250)
        }
        .frame(height: 156)
    }

    private func spotlightTrailerCard(item: CinemaReleaseItem) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Cinematic Gradient Backdrop
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: item.posterGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.8)
                )

            // Content Overlay
            VStack(alignment: .leading, spacing: 6) {
                // Top Tag Badges Row
                HStack(spacing: 5) {
                    // Platform Tag
                    HStack(spacing: 3.5) {
                        Image(systemName: item.platform.iconName)
                            .font(.system(size: 8.5, weight: .bold))
                        Text(item.platform.localizedName(isKorean: isKorean))
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(item.platform.accentColor, in: Capsule())

                    // D-Day Tag
                    Text(item.formattedDDay)
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundStyle(item.daysRemaining <= 7 && item.daysRemaining >= 0 ? Color.red : Color.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.black.opacity(0.6), in: Capsule())
                        .overlay(
                            Capsule().strokeBorder(
                                (item.daysRemaining <= 7 && item.daysRemaining >= 0 ? Color.red : Color.green).opacity(0.5),
                                lineWidth: 0.8
                            )
                        )

                    // Release Date
                    Text(item.formattedReleaseDate)
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))

                    Spacer()

                    // Rating Badge
                    Text(item.rating)
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                }

                // Title & Subtitle
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text("\(item.originalTitle) · \(item.genre)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                }

                // Synopsis
                Text(item.synopsis)
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(2)
                    .lineSpacing(1.5)

                Spacer(minLength: 0)

                // Action Buttons: Play Trailer | Add to Calendar
                HStack(spacing: 8) {
                    Button {
                        store.openTrailer(for: item)
                    } label: {
                        HStack(spacing: 4.5) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10.5, weight: .bold))
                            Text(text("Watch Trailer", "예고편 재생"))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background(
                            LinearGradient(
                                colors: [item.platform.accentColor, item.platform.accentColor.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            in: Capsule()
                        )
                        .shadow(color: item.platform.accentColor.opacity(0.4), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                    .help(text("Open official HD trailer", "공식 HD 예고편 보기"))

                    Button {
                        store.addToCalendar(for: item)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 10, weight: .semibold))
                            Text(text("Remind Me", "캘린더 등록"))
                                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.12), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 0.7))
                    }
                    .buttonStyle(.plain)
                    .help(text("Add release reminder to macOS Calendar", "macOS 캘린더에 개봉 알림 등록"))
                }
            }
            .padding(11)
        }
    }

    // MARK: - Mini Release Timeline Column

    private var miniScheduleColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "calendar.day.timeline.leading")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(accentColor)
                Text(text("Release Timeline", "개봉 타임라인"))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()

                Text("\(store.filteredReleases.count)" + text(" titles", "편"))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, 6)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(store.filteredReleases) { item in
                        let isSelected = store.selectedItem?.id == item.id
                        Button {
                            withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                                store.selectedItem = item
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(item.platform.accentColor)
                                    .frame(width: 5, height: 5)

                                Text(item.shortDateString)
                                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.85))

                                Text(item.title)
                                    .font(.system(size: 10.5, weight: isSelected ? .bold : .medium, design: .rounded))
                                    .foregroundStyle(isSelected ? .white : .white.opacity(0.8))
                                    .lineLimit(1)

                                Spacer()

                                Text(item.formattedDDay)
                                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                                    .foregroundStyle(isSelected ? item.platform.accentColor : .white.opacity(0.55))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4.5)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(isSelected ? item.platform.accentColor.opacity(0.22) : Color.white.opacity(0.04))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .strokeBorder(isSelected ? item.platform.accentColor.opacity(0.5) : Color.clear, lineWidth: 0.8)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.8)
                )
        )
    }

    // MARK: - Full Month Calendar View

    private var fullCalendarView: some View {
        VStack(spacing: 6) {
            // Month Header
            HStack {
                Text(text("Cinema & Netflix Release Schedule", "영화 & 넷플릭스 최신 개봉 일정"))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                if store.selectedDate != nil {
                    Button {
                        withAnimation { store.selectedDate = nil }
                    } label: {
                        Text(text("Show All Dates", "전체 날짜 보기"))
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .foregroundStyle(accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)

            // Timeline Schedule Rows
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 5) {
                    ForEach(store.filteredReleases) { item in
                        HStack(spacing: 10) {
                            // Date Column
                            VStack(spacing: 1) {
                                Text(item.formattedDDay)
                                    .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                                    .foregroundStyle(item.platform.accentColor)

                                Text(item.shortDateString)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 48)

                            // Title & Details
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 5) {
                                    Text(item.platform.localizedName(isKorean: isKorean))
                                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1.5)
                                        .background(item.platform.accentColor, in: Capsule())

                                    Text(item.title)
                                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)

                                    Text("(\(item.rating))")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.6))
                                }

                                Text("\(item.genre) · \(item.directorOrCast)")
                                    .font(.system(size: 9.5, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.68))
                                    .lineLimit(1)
                            }

                            Spacer()

                            // Watch Trailer Action Button
                            Button {
                                store.openTrailer(for: item)
                            } label: {
                                HStack(spacing: 3.5) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 9, weight: .bold))
                                    Text(text("Trailer", "예고편"))
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(item.platform.accentColor.opacity(0.85), in: Capsule())
                            }
                            .buttonStyle(.plain)

                            // Add to Calendar
                            Button {
                                store.addToCalendar(for: item)
                            } label: {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .frame(width: 24, height: 24)
                                    .background(Color.white.opacity(0.1), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .help(text("Add to Calendar", "캘린더에 등록"))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
                                )
                        )
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .frame(height: 156)
    }

    // MARK: - Bottom Horizontal Posters Carousel

    private var bottomPostersCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(store.filteredReleases) { item in
                    let isSelected = store.selectedItem?.id == item.id
                    Button {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                            store.selectedItem = item
                        }
                    } label: {
                        HStack(spacing: 6) {
                            // Mini Poster Gradient Icon
                            ZStack {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: item.posterGradient,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 28, height: 36)

                                Image(systemName: item.platform.iconName)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.9))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 3.5) {
                                    Text(item.formattedDDay)
                                        .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                                        .foregroundStyle(item.platform.accentColor)

                                    Text("· \(item.shortDateString)")
                                        .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.6))
                                }

                                Text(item.title)
                                    .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                                    .foregroundStyle(isSelected ? .white : .white.opacity(0.85))
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isSelected ? item.platform.accentColor.opacity(0.25) : Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(
                                            isSelected ? item.platform.accentColor.opacity(0.65) : Color.white.opacity(0.1),
                                            lineWidth: 0.8
                                        )
                                    )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
        .frame(height: 48)
    }

    private var emptyPlaceholderCard: some View {
        VStack(spacing: 6) {
            Image(systemName: "film")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
            Text(text("No upcoming releases found", "해당 조건의 개봉 예정작이 없습니다"))
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
                )
        )
    }
}
