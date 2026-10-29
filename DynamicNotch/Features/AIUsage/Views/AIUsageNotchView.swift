//
//  AIUsageNotchView.swift
//  DynamicNotch
//

import SwiftUI
internal import AppKit

public struct AIUsageNotchView: View {
    @StateObject private var service = AIUsageService.shared
    @State private var selectedProvider: AIProviderType = .claudeCode

    private var isKorean: Bool {
        let raw = UserDefaults.standard.string(forKey: GeneralSettingsStorage.Keys.appLanguage) ?? DynamicNotchLanguage.system.rawValue
        return DynamicNotchLanguage.resolved(raw).locale.language.languageCode?.identifier == "ko"
    }

    private func text(_ en: String, _ ko: String) -> String {
        privacyText(en, ko)
    }

    private var currentSummary: AIProviderUsageSummary? {
        service.summary(for: selectedProvider)
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            headerBar

            if let summary = currentSummary {
                heroQuotaCard(summary: summary)
                breakdownTiers(summary: summary)
            } else {
                loadingOrEmptyCard
            }

            footerStatusBar
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .onAppear {
            service.refresh()
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 8) {
            // Provider Segmented Switcher (Claude Code / Codex / Gemini)
            HStack(spacing: 2.5) {
                ForEach(AIProviderType.allCases) { provider in
                    let isSelected = selectedProvider == provider
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            selectedProvider = provider
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: provider.iconName)
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(
                                    isSelected
                                        ? providerAccentColor(provider)
                                        : Color.white.opacity(0.6)
                                )
                            Text(provider.shortDisplayName)
                                .font(.system(size: 10.5, weight: isSelected ? .semibold : .medium, design: .rounded))
                                .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.7))
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
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.8)
                    )
            )

            Spacer()

            // Status indicator & Actions
            HStack(spacing: 6) {
                Circle()
                    .fill(isCurrentProviderActive ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)

                Text(isCurrentProviderActive ? text("Active", "연결됨") : text("Ready", "대기"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))

                Button {
                    service.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .rotationEffect(.degrees(service.isLoading ? 360 : 0))
                        .animation(service.isLoading ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: service.isLoading)
                }
                .buttonStyle(.plain)
                .help(text("Refresh Quota", "사용량 및 리셋 새로고침"))

                Button {
                    openCurrentDirectory()
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help(text("Open Directory in Finder", "Finder에서 폴더 열기"))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(Capsule(style: .continuous).strokeBorder(Color.white.opacity(0.1), lineWidth: 0.8))
            )
        }
    }

    private var isCurrentProviderActive: Bool {
        switch selectedProvider {
        case .claudeCode:
            return service.isClaudeInstalled
        case .codex:
            return service.isCodexInstalled
        case .gemini:
            return service.isGeminiInstalled
        }
    }

    private func openCurrentDirectory() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let target: URL
        switch selectedProvider {
        case .claudeCode:
            target = home.appendingPathComponent(".claude")
        case .codex:
            target = home.appendingPathComponent(".codex")
        case .gemini:
            target = home.appendingPathComponent(".gemini")
        }
        NSWorkspace.shared.open(target)
    }

    // MARK: - Hero Quota Card (Codenotch Style Ring Gauge + Reset Pill)

    private func heroQuotaCard(summary: AIProviderUsageSummary) -> some View {
        let primary = summary.primaryWindow
        let remainingPct = primary.remainingPercentage
        let usedPct = primary.utilization
        let health = primary.health

        return HStack(spacing: 14) {
            // Circular Ring Gauge (Codenotch signature)
            ZStack {
                // Background Track
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 7)

                // Progress Fill (Remaining Quota)
                Circle()
                    .trim(from: 0, to: CGFloat(remainingPct / 100.0))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: ringGradientColors(for: selectedProvider, health: health)),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: remainingPct)

                // Centered Label: Remaining %
                VStack(spacing: 1) {
                    Text(String(format: "%.0f%%", remainingPct))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(text("LEFT", "남음"))
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            .frame(width: 66, height: 66)
            .padding(.leading, 4)

            // Right Info: Window Title, Status, and Prominent Reset Timer
            VStack(alignment: .leading, spacing: 4) {
                // Window Title + Health Status Pill
                HStack(spacing: 6) {
                    Text(primary.localizedTitle(isKorean: isKorean))
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.95))

                    Spacer()

                    // Health Pill (Optimal / Warning / Limit Reached)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(health.color)
                            .frame(width: 5.5, height: 5.5)
                        Text(health.title(isKorean: isKorean))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(health.color)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(health.color.opacity(0.14))
                            .overlay(Capsule(style: .continuous).strokeBorder(health.color.opacity(0.3), lineWidth: 0.7))
                    )
                }

                // Prominent Reset Countdown Pill
                HStack(spacing: 5) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.yellow.opacity(0.9))

                    Text(primary.formattedCountdown(isKorean: isKorean))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("(\(primary.formattedExactTime(isKorean: isKorean)))")
                        .font(.system(size: 9.5, weight: .regular))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                        )
                )

                // Used Percentage Subtitle
                HStack(spacing: 4) {
                    Text(String(format: text("%.0f%% used", "%.0f%% 사용됨"), usedPct))
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))

                    if let desc = primary.totalLimitDesc {
                        Text("· \(desc)")
                            .font(.system(size: 9.5, weight: .regular))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.8)
                )
        )
    }

    // MARK: - Dual Tier Breakdown (5-Hour Session & 7-Day Weekly / Daily Limit)

    private func breakdownTiers(summary: AIProviderUsageSummary) -> some View {
        VStack(spacing: 6) {
            tierRow(
                window: summary.primaryWindow,
                icon: "clock.arrow.circlepath",
                accent: providerAccentColor(selectedProvider)
            )

            if let secondary = summary.secondaryWindow {
                tierRow(
                    window: secondary,
                    icon: "calendar.badge.clock",
                    accent: providerSecondaryAccentColor(selectedProvider)
                )
            }
        }
    }

    private func tierRow(window: AIQuotaWindow, icon: String, accent: Color) -> some View {
        let remainingPct = window.remainingPercentage
        let usedPct = window.utilization

        return VStack(spacing: 4) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(accent)

                    Text(window.localizedTitle(isKorean: isKorean))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }

                Spacer()

                HStack(spacing: 4) {
                    Text(String(format: text("%.0f%% left", "%.0f%% 남음"), remainingPct))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.95))

                    Text(String(format: text("(%.0f%% used)", "(%.0f%% 사용)"), usedPct))
                        .font(.system(size: 8.5, weight: .regular))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            // Capsule Progress Bar (Left: Remaining Quota, Right: Used)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 5.5)

                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent, accent.opacity(0.75)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(4, geo.size.width * CGFloat(remainingPct / 100.0)), height: 5.5)
                }
            }
            .frame(height: 5.5)

            // Reset time row
            HStack {
                Text(window.localizedSubtitle(isKorean: isKorean))
                    .font(.system(size: 8.5, weight: .regular))
                    .foregroundStyle(.white.opacity(0.4))

                Spacer()

                Text("\(text("Resets", "리셋")): \(window.formattedCountdown(isKorean: isKorean))")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.8)
                )
        )
    }

    // MARK: - Footer Status Bar

    private var footerStatusBar: some View {
        HStack {
            if let summary = currentSummary {
                HStack(spacing: 4) {
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 8.5))
                        .foregroundStyle(.white.opacity(0.5))

                    Text(shortModelName(summary.activeModel))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: summary.isLiveAPI ? "antenna.radiowaves.left.and.right" : "internaldrive.fill")
                        .font(.system(size: 8.5))
                        .foregroundStyle(.white.opacity(0.5))

                    Text(summary.isLiveAPI ? text("Live Quota", "실시간 연동") : text("Local Sync", "로컬 세션 동기화"))
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 1)
    }

    // MARK: - Loading / Empty Card

    private var loadingOrEmptyCard: some View {
        VStack(spacing: 8) {
            Image(systemName: selectedProvider.iconName)
                .font(.system(size: 22))
                .foregroundStyle(providerAccentColor(selectedProvider).opacity(0.7))

            Text(text("Reading local AI usage...", "로컬 AI 사용량을 읽는 중..."))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))

            Text(text("Run `claude`, `codex`, or `gemini` to start tracking quota", "터미널에서 `claude`, `codex`, 또는 `gemini`를 실행하면 사용량이 기록됩니다"))
                .font(.system(size: 9, weight: .regular))
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
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

    // MARK: - Helpers

    private func providerAccentColor(_ provider: AIProviderType) -> Color {
        switch provider {
        case .claudeCode: return Color.orange
        case .codex: return Color.green
        case .gemini: return Color.cyan
        }
    }

    private func providerSecondaryAccentColor(_ provider: AIProviderType) -> Color {
        switch provider {
        case .claudeCode: return Color.yellow
        case .codex: return Color.mint
        case .gemini: return Color.blue
        }
    }

    private func ringGradientColors(for provider: AIProviderType, health: AIQuotaHealth) -> [Color] {
        switch health {
        case .optimal:
            switch provider {
            case .claudeCode:
                return [Color.orange, Color.yellow, Color.orange]
            case .codex:
                return [Color.green, Color.mint, Color.green]
            case .gemini:
                return [Color.blue, Color.cyan, Color.blue]
            }
        case .warning:
            return [Color.yellow, Color.orange, Color.yellow]
        case .critical:
            return [Color.red, Color.orange, Color.red]
        }
    }

    private func shortModelName(_ model: String) -> String {
        model.replacingOccurrences(of: "claude-", with: "")
             .replacingOccurrences(of: "-latest", with: "")
    }
}
