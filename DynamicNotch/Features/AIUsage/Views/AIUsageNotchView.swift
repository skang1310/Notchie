//
//  AIUsageNotchView.swift
//  DynamicNotch
//

import SwiftUI
internal import AppKit

public struct AIUsageNotchView: View {
    @StateObject private var service = AIUsageService.shared
    @State private var selectedFilter: ProviderFilter = .all

    private enum ProviderFilter: String, CaseIterable, Identifiable {
        case all = "all"
        case claude = "claude"
        case codex = "codex"
        case gemini = "gemini"

        var id: String { rawValue }

        func title(isKorean: Bool) -> String {
            switch self {
            case .all: return isKorean ? "전체 보기" : "All"
            case .claude: return "Claude"
            case .codex: return "Codex"
            case .gemini: return "Gemini"
            }
        }

        func provider() -> AIProviderType? {
            switch self {
            case .all: return nil
            case .claude: return .claudeCode
            case .codex: return .codex
            case .gemini: return .gemini
            }
        }
    }

    private var isKorean: Bool {
        let raw = UserDefaults.standard.string(forKey: GeneralSettingsStorage.Keys.appLanguage) ?? DynamicNotchLanguage.system.rawValue
        return DynamicNotchLanguage.resolved(raw).locale.language.languageCode?.identifier == "ko"
    }

    private func text(_ en: String, _ ko: String) -> String {
        privacyText(en, ko)
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            topControlBar

            cardsContainer
                .frame(maxWidth: .infinity)

            bottomStatusBar
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .onAppear {
            service.refresh()
        }
    }

    // MARK: - Top Control Bar

    private var topControlBar: some View {
        HStack(spacing: 8) {
            // Filter Pills (All / Claude / Codex / Gemini)
            HStack(spacing: 2.5) {
                ForEach(ProviderFilter.allCases) { filter in
                    let isSelected = selectedFilter == filter
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            selectedFilter = filter
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if let prov = filter.provider() {
                                AIProductLogoView(provider: prov, size: 12)
                            } else {
                                Image(systemName: "square.grid.2x2")
                                    .font(.system(size: 8.5, weight: .semibold))
                                    .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.6))
                            }

                            Text(filter.title(isKorean: isKorean))
                                .font(.system(size: 10, weight: isSelected ? .semibold : .medium, design: .rounded))
                                .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.65))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isSelected ? Color.white.opacity(0.14) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.8)
                    )
            )

            Spacer()

            // Actions: Refresh & Directory
            HStack(spacing: 6) {
                Button {
                    service.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .rotationEffect(.degrees(service.isLoading ? 360 : 0))
                        .animation(service.isLoading ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: service.isLoading)
                }
                .buttonStyle(.plain)
                .help(text("Refresh AI Quotas & Sessions", "사용량 및 활성 세션 새로고침"))

                Button {
                    openActiveDirectory()
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help(text("Open Directory in Finder", "Finder에서 폴더 열기"))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(Capsule(style: .continuous).strokeBorder(Color.white.opacity(0.09), lineWidth: 0.8))
            )
        }
    }

    // MARK: - Cards Container

    private var cardsContainer: some View {
        Group {
            switch selectedFilter {
            case .all:
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if let claude = service.claudeSummary {
                            codenotchCard(summary: claude)
                                .frame(width: 236)
                        }
                        if let codex = service.codexSummary {
                            codenotchCard(summary: codex)
                                .frame(width: 236)
                        }
                        if let gemini = service.geminiSummary {
                            codenotchCard(summary: gemini)
                                .frame(width: 236)
                        }
                    }
                    .padding(.horizontal, 2)
                }

            case .claude:
                if let claude = service.claudeSummary {
                    codenotchCard(summary: claude)
                } else {
                    emptyProviderView(for: .claudeCode)
                }

            case .codex:
                if let codex = service.codexSummary {
                    codenotchCard(summary: codex)
                } else {
                    emptyProviderView(for: .codex)
                }

            case .gemini:
                if let gemini = service.geminiSummary {
                    codenotchCard(summary: gemini)
                } else {
                    emptyProviderView(for: .gemini)
                }
            }
        }
    }

    // MARK: - Codenotch Card View (Exact Match to User UI Reference)

    private func codenotchCard(summary: AIProviderUsageSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header Row: [Product Logo] Provider [TierBadge] ... TimeAgo
            HStack(spacing: 6) {
                // Official Product Logo
                AIProductLogoView(provider: summary.provider, size: 16)

                // Provider Name
                Text(summary.provider.displayName)
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                // Tier / Model Badge (e.g. Max 5x, Plus, Advanced)
                Text(summary.tierBadge)
                    .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Color.white.opacity(0.12), in: Capsule())

                Spacer()

                // Relative Time Ago
                if let timeAgo = summary.localizedTimeAgo(isKorean: isKorean) {
                    Text(timeAgo)
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(.white.opacity(0.48))
                }
            }

            // Active Session Row: ● DynamicNotch [Running]
            HStack(spacing: 5) {
                Circle()
                    .fill(summary.isSessionActive ? Color.green : Color.white.opacity(0.3))
                    .frame(width: 5, height: 5)

                if let title = summary.activeSessionTitle, !title.isEmpty {
                    Text(title)
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(summary.isSessionActive ? 0.95 : 0.65))
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Text(isKorean ? "활성 세션 대기 중" : "No active session")
                        .font(.system(size: 9.5, weight: .regular))
                        .foregroundStyle(.white.opacity(0.4))
                }

                Spacer()

                if summary.isSessionActive {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 3.5, height: 3.5)
                        Text(isKorean ? "실행 중" : "Active")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.green)
                    }
                    .padding(.horizontal, 4.5)
                    .padding(.vertical, 1.5)
                    .background(Color.green.opacity(0.15), in: Capsule())
                }
            }
            .padding(.horizontal, 6.5)
            .padding(.vertical, 3.5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.045))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.6)
                    )
            )

            // Primary Window: 5 hours (Util %)
            quotaBarSection(
                label: isKorean ? "5시간 세션" : "5 hours",
                utilization: summary.primaryWindow.utilization,
                resetDetail: summary.primaryWindow.formattedResetDetail(isKorean: isKorean, includeCountdown: true),
                accentColor: Color.white.opacity(0.92)
            )

            // Secondary Window: This week / Daily Quota
            if let secondary = summary.secondaryWindow {
                quotaBarSection(
                    label: isKorean ? "이번 주" : "This week",
                    utilization: secondary.utilization,
                    resetDetail: secondary.formattedResetDetail(isKorean: isKorean, includeCountdown: false),
                    accentColor: Color.white.opacity(0.92)
                )
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(summary.primaryWindow.utilization >= 98.0 ? Color.red.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 0.8)
                )
        )
    }

    // MARK: - Quota Bar Section (Exact Codenotch Format)

    private func quotaBarSection(
        label: String,
        utilization: Double,
        resetDetail: String,
        accentColor: Color
    ) -> some View {
        let clampedUtil = max(0.0, min(100.0, utilization))
        let isLimitReached = clampedUtil >= 98.0
        let barColor = isLimitReached ? Color.red.opacity(0.9) : accentColor

        return VStack(alignment: .leading, spacing: 3.5) {
            // Label & Percentage
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))

                Spacer()

                HStack(spacing: 3) {
                    if isLimitReached {
                        Text(isKorean ? "소진" : "Max")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.red)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.red.opacity(0.15), in: Capsule())
                    }

                    Text(String(format: "%.0f%%", clampedUtil))
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundStyle(isLimitReached ? Color.red : Color.white)
                }
            }

            // Horizontal Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 4.5)

                    Capsule(style: .continuous)
                        .fill(barColor)
                        .frame(
                            width: max(clampedUtil > 0 ? 4.0 : 0.0, geo.size.width * CGFloat(clampedUtil / 100.0)),
                            height: 4.5
                        )
                }
            }
            .frame(height: 4.5)

            // Reset Subtext: e.g. "Resets 11:01 AM · in 1 hr 29 min"
            Text(resetDetail)
                .font(.system(size: 8.5, weight: .regular))
                .foregroundStyle(isLimitReached ? Color.yellow.opacity(0.8) : Color.white.opacity(0.48))
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    // MARK: - Bottom Status Bar

    private var bottomStatusBar: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 8.5))
                    .foregroundStyle(.white.opacity(0.45))

                Text(text("Live local session tracking", "실시간 로컬 세션 감지"))
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()

            if let lastRefreshed = service.lastRefreshed {
                Text("\(text("Updated", "업데이트")): \(timeOnly(lastRefreshed))")
                    .font(.system(size: 8.5, weight: .regular))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 1)
    }

    // MARK: - Empty Provider View

    private func emptyProviderView(for provider: AIProviderType) -> some View {
        VStack(spacing: 8) {
            AIProductLogoView(provider: provider, size: 28)

            Text(String(format: text("%@ not detected", "%@가 감지되지 않았습니다"), provider.displayName))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))

            Text(text("Run it in terminal to start tracking quota", "터미널에서 실행하면 사용량이 기록됩니다"))
                .font(.system(size: 9, weight: .regular))
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
                )
        )
    }

    private func openActiveDirectory() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let target: URL
        switch selectedFilter {
        case .all, .claude:
            target = home.appendingPathComponent(".claude")
        case .codex:
            target = home.appendingPathComponent(".codex")
        case .gemini:
            target = home.appendingPathComponent(".gemini")
        }
        NSWorkspace.shared.open(target)
    }

    private func timeOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isKorean ? "ko_KR" : "en_US")
        formatter.dateFormat = isKorean ? "a h:mm" : "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Official AI Product Logo View

public struct AIProductLogoView: View {
    public let provider: AIProviderType
    public let size: CGFloat

    public init(provider: AIProviderType, size: CGFloat = 16) {
        self.provider = provider
        self.size = size
    }

    public var body: some View {
        Group {
            switch provider {
            case .claudeCode:
                if let nsImage = NSImage(named: "claudeLogo") {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: size * 0.75, weight: .semibold))
                        .foregroundStyle(Color.orange)
                }
            case .codex:
                if let nsImage = NSImage(named: "codexLogo") {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: size * 0.75, weight: .semibold))
                        .foregroundStyle(Color.green)
                }
            case .gemini:
                if let nsImage = NSImage(named: "geminiLogo") {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: size * 0.75, weight: .semibold))
                        .foregroundStyle(Color.cyan)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}
