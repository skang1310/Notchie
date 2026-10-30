//
//  AIUsageNotchView.swift
//  DynamicNotch
//

import SwiftUI
internal import AppKit

public struct AIUsageNotchView: View {
    @StateObject private var service: AIUsageService
    @State private var isPresentationVisible = false
    @State private var liveConsumer = UUID()
    @ObservedObject private var preferences = AIUsagePreferences.shared
    @ObservedObject private var claudeTeam = ClaudeTeamConnection.shared
    private var isKorean: Bool {
        let raw = UserDefaults.standard.string(forKey: GeneralSettingsStorage.Keys.appLanguage) ?? DynamicNotchLanguage.system.rawValue
        return DynamicNotchLanguage.resolved(raw).locale.language.languageCode?.identifier == "ko"
    }

    private func text(_ en: String, _ ko: String) -> String {
        privacyText(en, ko)
    }

    public init() { _service = StateObject(wrappedValue: .shared) }
    init(service: AIUsageService) { _service = StateObject(wrappedValue: service) }

    public var body: some View {
        GeometryReader { geometry in
            let layout = AIUsagePanelMetrics(size: geometry.size)
            VStack(spacing: AIUsagePanelMetrics.spacing) {
                topControlBar.frame(height: AIUsagePanelMetrics.controlsHeight)
                TimelineView(.animation(minimumInterval: 30, paused: !isPresentationVisible)) { context in
                    cardsContainer(now: context.date, width: layout.cardWidth, height: layout.cardsHeight)
                }
                .frame(height: layout.cardsHeight)
                bottomStatusBar.frame(height: AIUsagePanelMetrics.footerHeight)
            }
            .padding(.horizontal, AIUsagePanelMetrics.horizontalPadding)
            .padding(.vertical, AIUsagePanelMetrics.verticalPadding)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        .background(Color.black.opacity(0.92), in: RoundedRectangle(cornerRadius: 12))
        .environment(\.colorScheme, .dark)
        .background(PresentationVisibilityReader(isVisible: $isPresentationVisible).frame(width: 0, height: 0))
        .onChange(of: claudeTeam.enabled) { _, _ in
            Task { await service.refreshQuotasAsync() }
        }
        .task(id: isPresentationVisible) {
            guard isPresentationVisible else { return }
            CodexLiveQuotaClient.shared.acquire(liveConsumer)
            defer { CodexLiveQuotaClient.shared.release(liveConsumer) }
            // Keep quota reads separate from the slower local activity scan.
            while !Task.isCancelled {
                await service.refreshIfNeeded(maxAge: 60)
                await service.refreshQuotasAsync()
                do { try await Task.sleep(for: .seconds(10)) } catch { return }
            }
        }
    }

    // MARK: - Top Control Bar

    private var topControlBar: some View {
        HStack(spacing: 8) {
            Label(text("AI Usage", "AI 사용량"), systemImage: "square.grid.2x2")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))

            Spacer()

            Menu {
                Toggle(text("Read my Claude Team usage page", "내 Claude Team 사용량 화면 읽기"), isOn: $claudeTeam.enabled)
                Button(text("Open Claude Team Usage", "Claude Team 사용량 열기")) {
                    NSWorkspace.shared.open(URL(string: "https://claude.ai/new#settings/usage")!)
                }
                Text(text("Reads only an open Team usage page in Chrome; uses existing Accessibility access. No cookies or tokens.", "Chrome에 열린 Team 사용량 화면만 읽습니다. 기존 손쉬운 사용 권한을 쓰며 쿠키·토큰은 읽지 않습니다."))
                Divider()
                Toggle(text("Usage warnings", "사용량 경고 알림"), isOn: $preferences.alertsEnabled)
                Picker(text("Warning threshold", "알림 기준"), selection: $preferences.threshold) {
                    ForEach([70, 80, 90, 95], id: \.self) { Text("\($0)%").tag($0) }
                }
                Toggle(text("Reset countdown", "초기화 카운트다운"), isOn: $preferences.countdownEnabled)
                Divider()
                Text(text("Only recorded provider quotas are shown", "서비스 한도 기록이 있을 때만 표시합니다"))
            } label: { Image(systemName: "slider.horizontal.3") }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(text("AI Usage Settings", "AI 사용량 설정"))

            // Actions: Refresh & Directory
            HStack(spacing: 6) {
                Button {
                    Task { await service.refreshAsync(); await service.refreshQuotasAsync() }
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

    private func cardsContainer(now: Date, width: CGFloat, height: CGFloat) -> some View {
        HStack(alignment: .top, spacing: AIUsagePanelMetrics.spacing) {
            ForEach(AIProviderType.allCases) { provider in
                ScrollView(.vertical, showsIndicators: true) {
                    if let summary = service.summary(for: provider) {
                        codenotchCard(summary: summary, now: now)
                            .frame(width: width, alignment: .topLeading)
                    } else {
                        ProgressView().frame(width: width, height: height)
                    }
                }
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("aiUsage.card." + provider.rawValue)
            }
        }
        .frame(height: height, alignment: .top)
    }

    // MARK: - Codenotch Card View (Exact Match to User UI Reference)

    private func codenotchCard(summary: AIProviderUsageSummary, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header Row: [Product Logo] Provider [TierBadge] ... TimeAgo
            HStack(spacing: 6) {
                // Official Product Logo
                AIProductLogoView(provider: summary.provider, size: 16)

                // Provider Name
                Text(summary.provider.shortDisplayName)
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
                if summary.provider != .gemini, let timeAgo = summary.localizedTimeAgo(isKorean: isKorean, now: now) {
                    Text(timeAgo)
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(.white.opacity(0.48))
                }
            }

            Text(summary.hasRecordedQuota
                ? (summary.provider == .claudeCode ? text("My Team quota", "Team 개인 한도") : (summary.provider == .gemini ? text("Antigravity local query", "Antigravity 로컬 조회") : (summary.isLiveAPI ? text("Server query", "서버 직접 조회") : text("Provider record", "서비스 한도 기록")))) + " · " + (summary.quotaRecordedAt ?? summary.lastUpdated).formatted(date: .omitted, time: .shortened)
                : text("Local activity only · quota unavailable", "로컬 활동만 확인 · 한도 정보 없음"))
                .font(.system(size: 8)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)

            if summary.provider == .codex && service.codexLiveQueryFailed {
                Text(text("Live query failed · check Codex login/network", "실시간 조회 실패 · Codex 로그인·네트워크 확인"))
                    .font(.system(size: 8)).foregroundStyle(.yellow)
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
                        Text(isKorean ? "최근 활동" : "Recent")
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

            if summary.hasRecordedQuota {
                quotaWindows(summary, now: now)
                if summary.provider == .gemini {
                    Text(text("Model quotas · scroll for more", "모델별 한도 · 스크롤로 더 보기"))
                        .font(.system(size: 8)).foregroundStyle(.white.opacity(0.5))
                }
                if !summary.isQuotaFresh(at: now) {
                    Text(summary.provider == .claudeCode
                        ? text("Open the Team Usage page in Chrome to update", "Chrome에서 Team 사용량 화면을 열면 갱신됩니다")
                        : text("Older record · retrying live query", "이전 기록 · 실시간 조회 재시도 중"))
                        .font(.system(size: 8)).foregroundStyle(.yellow)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(text("Quota unavailable", "한도 정보 없음")).font(.system(size: 12, weight: .semibold))
                    Text(summary.provider == .gemini
                        ? text("Open Antigravity and sign in to check its quota.", "Antigravity를 실행하고 로그인하면 한도를 확인합니다.")
                        : text("Session counts cannot determine quota or reset time.", "세션 수로 사용률·초기화 시각을 계산하지 않습니다."))
                        .font(.system(size: 9)).foregroundStyle(.white.opacity(0.5))
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 12)
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

    private func quotaWindows(_ summary: AIProviderUsageSummary, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach([summary.primaryWindow] + (summary.secondaryWindow.map { [$0] } ?? []) + summary.additionalWindows) { window in
                quotaBarSection(label: window.localizedTitle(isKorean: isKorean), utilization: window.utilization,
                    resetDetail: resetDetail(window, now: now), accentColor: .white.opacity(0.92))
            }
        }
    }

    private func resetDetail(_ window: AIQuotaWindow, now: Date) -> String {
        guard window.resetsAt > now else { return text("Reset time passed · awaiting new record", "초기화 시각 경과 · 새 기록 대기") }
        return window.formattedResetDetail(isKorean: isKorean, now: now, includeCountdown: preferences.countdownEnabled)
    }

    // MARK: - Quota Bar Section (Exact Codenotch Format)

    private func quotaBarSection(
        label: String,
        utilization: Double,
        resetDetail: String,
        accentColor: Color
    ) -> some View {
        let clampedUtil = max(0.0, min(100.0, utilization))
        let remaining = 100 - clampedUtil
        let isLimitReached = clampedUtil >= 98.0
        let barColor = isLimitReached ? Color.red.opacity(0.9) : accentColor

        return VStack(alignment: .leading, spacing: 3.5) {
            // Label & Percentage
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1).minimumScaleFactor(0.8)

                Spacer()

                HStack(spacing: 3) {
                    if isLimitReached {
                        Text(clampedUtil >= 100 ? text("Empty", "소진") : text("Low", "임박"))
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.red)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.red.opacity(0.15), in: Capsule())
                    }

                    Text(String(format: text("%.0f%% left", "%.0f%% 남음"), remaining))
                        .help(String(format: text("%.0f%% used", "%.0f%% 사용"), clampedUtil))
                        .accessibilityLabel(String(format: text("%.0f%% used, %.0f%% left", "%.0f%% 사용, %.0f%% 남음"), clampedUtil, remaining))
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
                            width: max(remaining > 0 ? 4.0 : 0.0, geo.size.width * CGFloat(remaining / 100.0)),
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
                .minimumScaleFactor(0.8)
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

                Text(text("Quota checks every 10s while visible", "화면 표시 중 10초 간격 한도 확인"))
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()

            if let lastRefreshed = service.lastRefreshed {
                Text("\(text("Activity scan", "활동 기록")): \(timeOnly(lastRefreshed))")
                    .font(.system(size: 8.5, weight: .regular))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 1)
    }

    private func openActiveDirectory() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        NSWorkspace.shared.open(home.appendingPathComponent(".claude"))
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
                Image(systemName: "a.circle.fill")
                    .resizable().scaledToFit().foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}
