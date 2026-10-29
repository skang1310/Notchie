//
//  AIUsageNotchView.swift
//  DynamicNotch
//

import SwiftUI
internal import AppKit

public struct AIUsageNotchView: View {
    @StateObject private var service = AIUsageService.shared
    @State private var selectedProvider: AIProviderType = .claudeCode
    @State private var hoveredEntryID: String?

    private var accentColor: Color {
        ApplicationSettingsStore.currentCustomAccentColor()
    }

    private func text(_ en: String, _ ko: String) -> String {
        privacyText(en, ko)
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            headerBar
            providerMetricsCard
            recentActivitySection
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .onAppear {
            service.refresh()
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 8) {
            // Provider Segmented Toggle
            HStack(spacing: 4) {
                ForEach(AIProviderType.allCases) { provider in
                    let isSelected = selectedProvider == provider
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            selectedProvider = provider
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: provider.iconName)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(
                                    isSelected
                                        ? (provider == .claudeCode ? Color.orange : Color.green)
                                        : Color.white.opacity(0.6)
                                )
                            Text(provider.displayName)
                                .font(.system(size: 11, weight: isSelected ? .semibold : .medium, design: .rounded))
                                .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.7))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isSelected ? Color.white.opacity(0.12) : Color.clear)
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

            // Live status & Refresh
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
                        .foregroundStyle(.white.opacity(0.75))
                        .rotationEffect(.degrees(service.isLoading ? 360 : 0))
                        .animation(service.isLoading ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: service.isLoading)
                }
                .buttonStyle(.plain)
                .help(text("Refresh AI stats", "AI 사용량 새로고침"))

                Button {
                    openCurrentDirectory()
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .buttonStyle(.plain)
                .help(text("Open directory in Finder", "Finder에서 폴더 열기"))
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
            return service.isClaudeInstalled && service.claudeStats != nil
        case .codex:
            return service.isCodexInstalled && !service.codexSessions.isEmpty
        }
    }

    private func openCurrentDirectory() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let target = selectedProvider == .claudeCode
            ? home.appendingPathComponent(".claude")
            : home.appendingPathComponent(".codex")
        NSWorkspace.shared.open(target)
    }

    // MARK: - Metrics Cards

    private var providerMetricsCard: some View {
        HStack(spacing: 8) {
            switch selectedProvider {
            case .claudeCode:
                claudeMetricsCards
            case .codex:
                codexMetricsCards
            }
        }
    }

    private var claudeMetricsCards: some View {
        Group {
            let stats = service.claudeStats
            let tokensStr = stats?.formattedTokens ?? "0"
            let messagesCount = stats?.totalMessages ?? 0
            let sessionsCount = stats?.totalSessions ?? 0
            let primaryModel = stats?.primaryModelName ?? "claude-3-7-sonnet"

            metricTile(
                title: text("Total Tokens", "총 토큰 수"),
                value: tokensStr,
                subtext: "In: \(stats?.aggregatedInputTokens ?? 0) · Out: \(stats?.aggregatedOutputTokens ?? 0)",
                icon: "sparkles",
                accent: .orange
            )

            metricTile(
                title: text("Activity", "대화 및 세션"),
                value: "\(messagesCount)",
                subtext: "\(sessionsCount) \(text("sessions", "세션"))",
                icon: "bubble.left.and.bubble.right.fill",
                accent: .yellow
            )

            metricTile(
                title: text("Active Model", "사용 모델"),
                value: shortModelName(primaryModel),
                subtext: stats?.lastComputedDate ?? text("Local stats", "로컬 집계"),
                icon: "cpu.fill",
                accent: .blue
            )
        }
    }

    private var codexMetricsCards: some View {
        Group {
            let config = service.codexConfig
            let totalSessions = service.codexSessions.count

            metricTile(
                title: text("Codex Model", "코덱스 모델"),
                value: shortModelName(config.model),
                subtext: "\(text("Effort", "추론")): \(config.reasoningEffort)",
                icon: "cpu.fill",
                accent: .green
            )

            metricTile(
                title: text("Total Sessions", "총 세션 수"),
                value: "\(totalSessions)",
                subtext: text("Active threads", "기록된 스레드"),
                icon: "list.bullet.rectangle.portrait.fill",
                accent: .mint
            )

            metricTile(
                title: text("Codex Client", "클라이언트"),
                value: "v\(config.clientVersion)",
                subtext: config.sandboxMode,
                icon: "terminal.fill",
                accent: .indigo
            )
        }
    }

    private func metricTile(
        title: String,
        value: String,
        subtext: String,
        icon: String,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(accent)
                Text(title)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Text(value)
                .font(.system(size: 14.5, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(subtext)
                .font(.system(size: 9, weight: .regular))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.8)
                )
        )
    }

    // MARK: - Recent Activity Section

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(selectedProvider == .claudeCode ? text("Recent Prompts & Sessions", "최근 프롬프트 및 세션") : text("Recent Codex Sessions", "최근 코덱스 작업 스레드"))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                Text(selectedProvider == .claudeCode ? "\(service.claudeHistory.count) items" : "\(service.codexSessions.count) sessions")
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 2)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 4) {
                    if selectedProvider == .claudeCode {
                        if service.claudeHistory.isEmpty {
                            emptyStateNotice(
                                icon: "sparkles",
                                title: text("No Claude Code history found", "Claude Code 기록을 찾을 수 없습니다"),
                                hint: text("Run `claude` in Terminal to start tracking", "터미널에서 `claude`를 실행하여 사용량을 기록하세요")
                            )
                        } else {
                            ForEach(service.claudeHistory.prefix(8)) { entry in
                                claudeHistoryRow(entry)
                            }
                        }
                    } else {
                        if service.codexSessions.isEmpty {
                            emptyStateNotice(
                                icon: "terminal",
                                title: text("No Codex sessions found", "Codex 세션 기록을 찾을 수 없습니다"),
                                hint: text("Run OpenAI Codex to start tracking sessions", "OpenAI Codex를 실행하여 세션을 기록하세요")
                            )
                        } else {
                            ForEach(service.codexSessions.prefix(8)) { session in
                                codexSessionRow(session)
                            }
                        }
                    }
                }
                .padding(.vertical, 1)
            }
            .frame(maxHeight: 120)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
                )
        )
    }

    private func claudeHistoryRow(_ entry: ClaudeHistoryEntry) -> some View {
        let isHovered = hoveredEntryID == entry.id
        return HStack(spacing: 6) {
            Image(systemName: "message.fill")
                .font(.system(size: 8.5))
                .foregroundStyle(Color.orange.opacity(0.85))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.display.replacingOccurrences(of: "\n", with: " "))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if !entry.projectName.isEmpty {
                        Text(entry.projectName)
                            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 3))
                    }

                    Text(entry.relativeTime)
                        .font(.system(size: 8.5))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            Spacer()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.display, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1.0 : 0.4)
            .help(text("Copy prompt", "프롬프트 복사"))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovered ? Color.white.opacity(0.08) : Color.white.opacity(0.02))
        )
        .onHover { isHovered in
            hoveredEntryID = isHovered ? entry.id : nil
        }
    }

    private func codexSessionRow(_ session: CodexSessionEntry) -> some View {
        let isHovered = hoveredEntryID == session.id
        return HStack(spacing: 6) {
            Image(systemName: "circle.circle.fill")
                .font(.system(size: 8.5))
                .foregroundStyle(Color.green.opacity(0.85))

            VStack(alignment: .leading, spacing: 2) {
                Text(session.threadName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)

                Text(session.relativeTime)
                    .font(.system(size: 8.5))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(session.threadName, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1.0 : 0.4)
            .help(text("Copy thread title", "세션 제목 복사"))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovered ? Color.white.opacity(0.08) : Color.white.opacity(0.02))
        )
        .onHover { isHovered in
            hoveredEntryID = isHovered ? session.id : nil
        }
    }

    private func emptyStateNotice(icon: String, title: String, hint: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.3))
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
            Text(hint)
                .font(.system(size: 8.5))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    private func shortModelName(_ model: String) -> String {
        model.replacingOccurrences(of: "claude-", with: "")
             .replacingOccurrences(of: "-latest", with: "")
    }
}
