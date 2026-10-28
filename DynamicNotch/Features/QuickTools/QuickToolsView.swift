import SwiftUI
internal import AppKit
import AVFoundation
internal import EventKit
import UniformTypeIdentifiers

// MARK: - QuickToolsView (Settings & Notch Entry Point)

struct QuickToolsView: View {
    @ObservedObject var store: QuickToolsStore
    var inNotch = false
    @State private var showingTabCustomizer = false

    private var accentColor: Color {
        ApplicationSettingsStore.currentCustomAccentColor()
    }

    private func text(_ en: String, _ ko: String) -> String {
        privacyText(en, ko)
    }

    var body: some View {
        if inNotch {
            NotchiePanoramicHubView(
                store: store,
                nowPlayingViewModel: store.nowPlayingViewModel,
                mediaSettings: store.mediaSettings,
                applicationSettings: store.applicationSettings,
                onOpenPlaybackSource: {}
            )
        } else {
            settingsToolsBody
        }
    }

    private var settingsToolsBody: some View {
        VStack(spacing: 10) {
            notchNookTabBar
            customizableTabsCard
            QuickToolDetailSwitcherView(store: store)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Button("settings.tools.openNotch") {
                    NotificationCenter.default.post(name: .showQuickToolsInNotch, object: nil)
                }
                .accessibilityIdentifier("settings.tools.openNotch")
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(minHeight: 235)
    }

    private var notchNookTabBar: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(store.visibleTabs) { tab in
                        let isSelected = store.selectedTool == tab.id
                        Button {
                            withAnimation(.snappy(duration: 0.2)) {
                                store.selectedTool = tab.id
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: tab.systemImage)
                                    .font(.system(size: 11.5, weight: .semibold))
                                Text(LocalizedStringKey(tab.titleKey))
                                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(isSelected ? accentColor.opacity(0.24) : Color.primary.opacity(0.06))
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(isSelected ? accentColor.opacity(0.75) : Color.clear, lineWidth: 1)
                            )
                            .foregroundStyle(isSelected ? accentColor : .primary.opacity(0.82))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button {
                showingTabCustomizer.toggle()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .background(Color.primary.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .help(text("Customize visible tabs", "표시할 탭 설정"))
            .popover(isPresented: $showingTabCustomizer, arrowEdge: .bottom) {
                QuickToolTabCustomizerPopover(store: store)
            }
        }
    }

    private var customizableTabsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(text("Notch Hover Menu Tabs (Click to toggle)", "노치 호버 메뉴 탭 선택 (클릭하여 켜기/끄기)"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(text("Reset Default Tabs", "기본 탭으로 초기화")) {
                    store.resetEnabledTabs()
                }
                .font(.caption2)
                .buttonStyle(.link)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(QuickToolTab.allTabs) { tab in
                        let enabled = store.isTabEnabled(tab.id)
                        Button {
                            store.setTabEnabled(tab.id, enabled: !enabled)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: enabled ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 11))
                                    .foregroundStyle(enabled ? accentColor : .secondary)
                                Text(LocalizedStringKey(tab.titleKey))
                                    .font(.caption)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(enabled ? accentColor.opacity(0.14) : Color.primary.opacity(0.04))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct QuickToolDetailSwitcherView: View {
    @ObservedObject var store: QuickToolsStore

    var body: some View {
        Group {
            switch store.selectedTool {
            case "notes": QuickNotesView(store: store.notes)
            case "stopwatch": QuickStopwatchView(controller: store.stopwatch)
            case "awake": KeepAwakeView(controller: store.awake)
            case "focus": FocusSessionView(controller: store.focus)
            case "tasks": TodayTasksView()
            case "snippets": ClipboardSnippetsView()
            case "rules": AppPresentationRulesView()
            case "jobs": LocalJobView(runner: store.jobs)
            case "status": ResourceStatusView(store: store)
            case "calculator": CalculatorToolView()
            case "shortcuts": ShortcutsToolView()
            case "zip": ZipToolView()
            case "developer": DeveloperTextToolsView()
            case "reports": ReportCompareToolView()
            case "cases": SupportCaseLauncherView()
            default:
                VStack(spacing: 14) {
                    Text(store.sampledColor ?? "#------").font(.system(size: 30, design: .monospaced))
                    HStack {
                        Button("settings.tools.color.pick") { store.sampleColor() }
                        Button("settings.tools.color.copy") { store.copyColor() }.disabled(store.sampledColor == nil)
                    }
                    Text("settings.tools.color.desc").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct QuickToolTabCustomizerPopover: View {
    @ObservedObject var store: QuickToolsStore

    private func text(_ en: String, _ ko: String) -> String {
        privacyText(en, ko)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(text("Visible Notch Tabs", "노치 메뉴 표시 탭"))
                    .font(.callout.weight(.semibold))
                Spacer()
                Button(text("Reset", "초기화")) {
                    store.resetEnabledTabs()
                }
                .font(.caption)
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(QuickToolTab.allTabs) { tab in
                        Toggle(isOn: Binding(
                            get: { store.isTabEnabled(tab.id) },
                            set: { store.setTabEnabled(tab.id, enabled: $0) }
                        )) {
                            Label(LocalizedStringKey(tab.titleKey), systemImage: tab.systemImage)
                                .font(.caption)
                        }
                        .toggleStyle(.checkbox)
                    }
                }
            }
            .frame(maxHeight: 240)
        }
        .padding(12)
        .frame(width: 230)
    }
}

// MARK: - OS 27 Panoramic Notch Hub (NotchNook + macOS 27 Liquid Glass)

struct NotchiePanoramicHubView: View {
    @Environment(\.isNotchlessScreen) private var isNotchlessScreen
    @Environment(\.locale) private var locale

    @ObservedObject var store: QuickToolsStore
    var nowPlayingViewModel: NowPlayingViewModel?
    var mediaSettings: MediaAndFilesSettingsStore?
    var applicationSettings: ApplicationSettingsStore?
    var onOpenPlaybackSource: @MainActor () -> Void = {}

    @State private var showingTabCustomizer = false
    @State private var selectedDayOffset: Int = 0

    private var accentColor: Color {
        ApplicationSettingsStore.currentCustomAccentColor()
    }

    private func text(_ en: String, _ ko: String) -> String {
        privacyText(en, ko)
    }

    private var resolvedNowPlayingViewModel: NowPlayingViewModel? {
        nowPlayingViewModel ?? store.nowPlayingViewModel
    }

    private var resolvedMediaSettings: MediaAndFilesSettingsStore? {
        mediaSettings ?? store.mediaSettings
    }

    private var resolvedApplicationSettings: ApplicationSettingsStore? {
        applicationSettings ?? store.applicationSettings
    }

    var body: some View {
        VStack(spacing: 8) {
            topWingHeaderBar
                .frame(height: 30)

            Group {
                switch store.hubMode {
                case .nook:
                    nookThreeColumnDashboard
                case .tray:
                    NotchiePanoramicTraySection(
                        fileTrayViewModel: store.fileTrayViewModel,
                        mediaSettings: resolvedMediaSettings,
                        accentColor: accentColor
                    )
                case .clips:
                    panoramicToolContainer(title: text("Clipboard History", "클립보드 기록"), icon: "doc.on.clipboard.fill") {
                        ClipboardSnippetsView()
                    }
                case .notes:
                    panoramicToolContainer(title: text("Quick Notes", "빠른 메모"), icon: "note.text") {
                        QuickNotesView(store: store.notes)
                    }
                case .tools:
                    panoramicToolsBrowser
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, isNotchlessScreen ? 18 : 26)
        .padding(.top, isNotchlessScreen ? 6 : 4)
        .padding(.bottom, isNotchlessScreen ? 12 : 13)
        .environment(\.colorScheme, .dark)
        .onDisappear {
            if store.isMirrorCameraActive {
                store.isMirrorCameraActive = false
            }
        }
    }

    // MARK: - Top Header Bar (Flanking the Physical Camera Cutout)

    private var topWingHeaderBar: some View {
        HStack(spacing: 6) {
            // Left Wing: Mode Pills (Nook, Tray, Clips, Notes, Tools)
            HStack(spacing: 4) {
                ForEach(NotchHubMode.allCases) { mode in
                    modePillButton(for: mode)
                }
            }

            // Center Camera Cutout Safe Area
            Spacer(minLength: isNotchlessScreen ? 12 : 162)

            // Right Wing: Mini Now Playing Pill (when not on Nook tab) + Pin / Customize / Settings
            HStack(spacing: 5) {
                if store.hubMode != .nook, let vm = resolvedNowPlayingViewModel {
                    NotchieMiniNowPlayingHeaderPill(
                        nowPlayingViewModel: vm,
                        accentColor: accentColor
                    ) {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                            store.hubMode = .nook
                        }
                    }
                }

                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        store.isNotchHubPinned.toggle()
                    }
                } label: {
                    Image(systemName: store.isNotchHubPinned ? "pin.fill" : "pin")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(store.isNotchHubPinned ? accentColor : .white.opacity(0.68))
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(store.isNotchHubPinned ? accentColor.opacity(0.24) : Color.white.opacity(0.08))
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(store.isNotchHubPinned ? accentColor.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 0.8)
                        )
                }
                .buttonStyle(.plain)
                .help(store.isNotchHubPinned ? text("Pinned open", "노치 고정됨") : text("Pin notch open", "노치 열어두기 고정"))

                Button {
                    showingTabCustomizer.toggle()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.72))
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.08), in: Circle())
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.8))
                }
                .buttonStyle(.plain)
                .help(text("Customize tools", "도구 탭 설정"))
                .popover(isPresented: $showingTabCustomizer, arrowEdge: .bottom) {
                    QuickToolTabCustomizerPopover(store: store)
                }

                Button {
                    SettingsWindowController.shared.showWindow()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.76))
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.08), in: Circle())
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.8))
                }
                .buttonStyle(.plain)
                .help(text("Open Notchie Settings", "Notchie 설정 열기"))
            }
        }
    }

    private func modePillButton(for mode: NotchHubMode) -> some View {
        let isSelected = store.hubMode == mode
        let trayCount = store.fileTrayViewModel?.count ?? 0

        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                store.hubMode = mode
            }
        } label: {
            HStack(spacing: 4) {
                Text(modeTitle(for: mode))
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.46))

                if mode == .tray && trayCount > 0 {
                    Text("\(trayCount)")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 1)
                        .background(accentColor.opacity(0.85), in: Capsule())
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4.5)
            .background(
                ZStack {
                    if isSelected {
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.18),
                                        Color.white.opacity(0.09)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        Capsule(style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.32),
                                        accentColor.opacity(0.45)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.85
                            )
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }

    private func modeTitle(for mode: NotchHubMode) -> String {
        switch mode {
        case .nook: return "Nook"
        case .tray: return "Tray"
        case .clips: return text("Clips", "클립")
        case .notes: return text("Notes", "메모")
        case .tools: return text("Tools", "도구")
        }
    }

    // MARK: - 3-Column Nook Dashboard (Now Playing | 7-Day Calendar | Camera Mirror Pod)

    private var nookThreeColumnDashboard: some View {
        HStack(alignment: .center, spacing: 14) {
            // Column 1: Now Playing Studio
            NotchieNowPlayingStudioColumn(
                nowPlayingViewModel: resolvedNowPlayingViewModel,
                mediaSettings: resolvedMediaSettings,
                applicationSettings: resolvedApplicationSettings,
                accentColor: accentColor,
                onOpenPlaybackSource: onOpenPlaybackSource
            )
            .frame(width: 244)

            // Subtle OS 27 vertical glass divider
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.12), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 1)
                .padding(.vertical, 8)

            // Column 2: Month + 7-Day Week Strip & Schedule
            NotchieCalendarScheduleColumn(
                calendarViewModel: store.calendarViewModel,
                selectedDayOffset: $selectedDayOffset,
                accentColor: accentColor,
                onSwitchToTasks: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                        store.selectedTool = "tasks"
                        store.hubMode = .tools
                    }
                }
            )
            .frame(maxWidth: .infinity)

            // Subtle OS 27 vertical glass divider
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.12), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 1)
                .padding(.vertical, 8)

            // Column 3: Circular Camera Mirror & Focus Pod
            NotchieCameraMirrorPodColumn(
                store: store,
                accentColor: accentColor
            )
            .frame(width: 92)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Extended Mode Containers (Clips, Notes, Tools)

    private func panoramicToolContainer<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accentColor)
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                        store.hubMode = .nook
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 9.5, weight: .bold))
                        Text(text("Back to Nook", "Nook으로 돌아가기"))
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.62))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.8)
                )
        )
    }

    private var panoramicToolsBrowser: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(store.visibleTabs) { tab in
                        let isSelected = store.selectedTool == tab.id
                        Button {
                            withAnimation(.snappy(duration: 0.2)) {
                                store.selectedTool = tab.id
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: tab.systemImage)
                                    .font(.system(size: 11, weight: .semibold))
                                Text(LocalizedStringKey(tab.titleKey))
                                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4.5)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(isSelected ? accentColor.opacity(0.26) : Color.white.opacity(0.07))
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(isSelected ? accentColor.opacity(0.8) : Color.white.opacity(0.08), lineWidth: 0.85)
                            )
                            .foregroundStyle(isSelected ? accentColor : .white.opacity(0.78))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            QuickToolDetailSwitcherView(store: store)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.8)
                        )
                )
        }
    }
}

// MARK: - Mini Now Playing Pill for Non-Nook Tabs

private struct NotchieMiniNowPlayingHeaderPill: View {
    @ObservedObject var nowPlayingViewModel: NowPlayingViewModel
    let accentColor: Color
    let onSelectNook: () -> Void

    var body: some View {
        let snapshot = nowPlayingViewModel.snapshot
        let title = (snapshot?.title.trimmed.isEmpty == false) ? snapshot!.title : "Notchie Audio"
        let isPlaying = snapshot?.isPlaying ?? false

        HStack(spacing: 6) {
            Button(action: onSelectNook) {
                HStack(spacing: 5) {
                    ArtworkView(
                        nowPlayingViewModel: nowPlayingViewModel,
                        width: 18,
                        height: 18,
                        cornerRadius: 5,
                        usesFlipAnimation: false
                    )
                    Text(title)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(1)
                        .frame(maxWidth: 78, alignment: .leading)
                }
            }
            .buttonStyle(.plain)

            Button {
                nowPlayingViewModel.togglePlayPause()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isPlaying ? accentColor : .white.opacity(0.8))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.09))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8)
                )
        )
    }
}

// MARK: - Column 1: Now Playing Studio (NotchNook + OS 27 Liquid Glass)

private struct NotchieNowPlayingStudioColumn: View {
    @Environment(\.locale) private var locale
    var nowPlayingViewModel: NowPlayingViewModel?
    var mediaSettings: MediaAndFilesSettingsStore?
    var applicationSettings: ApplicationSettingsStore?
    let accentColor: Color
    let onOpenPlaybackSource: @MainActor () -> Void

    @State private var scrubProgress: CGFloat?

    private var fallbackSnapshot: NowPlayingSnapshot {
        NowPlayingSnapshot(
            title: locale.dn("notch.nowPlaying.nothingPlaying", fallback: "Not Playing"),
            artist: privacyText("Play music or video to control live media", "음악·영상을 재생하면 여기에 표시됩니다"),
            album: "Notchie Studio",
            duration: 0,
            elapsedTime: 0,
            playbackRate: 0,
            artworkData: nil,
            refreshedAt: .now
        )
    }

    var body: some View {
        if let vm = nowPlayingViewModel {
            ObservedNowPlayingStudioBody(
                nowPlayingViewModel: vm,
                mediaSettings: mediaSettings,
                applicationSettings: applicationSettings,
                accentColor: accentColor,
                onOpenPlaybackSource: onOpenPlaybackSource,
                scrubProgress: $scrubProgress
            )
        } else {
            placeholderStudioCard
        }
    }

    private var placeholderStudioCard: some View {
        let snap = fallbackSnapshot
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.98, green: 0.22, blue: 0.36), Color(red: 0.72, green: 0.12, blue: 0.28)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 66, height: 66)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.92))
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
                        )

                    ZStack {
                        Circle()
                            .fill(Color(red: 0.14, green: 0.16, blue: 0.22))
                            .frame(width: 22, height: 22)
                        Circle()
                            .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.8)
                            .frame(width: 22, height: 22)
                        Image(systemName: "waveform")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(accentColor)
                    }
                    .offset(x: 4, y: 4)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(snap.title)
                        .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(snap.artist)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.54))
                        .lineLimit(2)
                }
            }
            HStack(spacing: 22) {
                Image(systemName: "backward.fill")
                Image(systemName: "play.fill")
                    .font(.system(size: 20, weight: .bold))
                Image(systemName: "forward.fill")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white.opacity(0.45))
            .frame(maxWidth: .infinity)
        }
    }
}

private struct ObservedNowPlayingStudioBody: View {
    @Environment(\.locale) private var locale
    @ObservedObject var nowPlayingViewModel: NowPlayingViewModel
    var mediaSettings: MediaAndFilesSettingsStore?
    var applicationSettings: ApplicationSettingsStore?
    let accentColor: Color
    let onOpenPlaybackSource: @MainActor () -> Void
    @Binding var scrubProgress: CGFloat?

    private var resolvedSnapshot: NowPlayingSnapshot {
        nowPlayingViewModel.snapshot ?? NowPlayingSnapshot(
            title: locale.dn("notch.nowPlaying.nothingPlaying", fallback: "Not Playing"),
            artist: privacyText("Play music or video", "재생 중인 미디어 없음"),
            album: "",
            duration: 0,
            elapsedTime: 0,
            playbackRate: 0,
            artworkData: nil,
            refreshedAt: .now
        )
    }

    var body: some View {
        let snapshot = resolvedSnapshot
        TimelineView(.periodic(from: .now, by: snapshot.isPlaying ? 0.4 : 15.0)) { context in
            let elapsedTime = nowPlayingViewModel.snapshot != nil
                ? nowPlayingViewModel.elapsedTime(at: context.date)
                : snapshot.elapsedTime
            let progress = snapshot.duration > 0
                ? min(max(CGFloat(elapsedTime / snapshot.duration), 0), 1)
                : 0
            let displayedProgress = min(max(scrubProgress ?? progress, 0), 1)

            ZStack(alignment: .topLeading) {
                // Subtle ambient glow from album artwork palette
                Circle()
                    .fill(Color(nsColor: nowPlayingViewModel.artworkPalette.equalizerHighlightColor).opacity(snapshot.isPlaying ? 0.22 : 0.1))
                    .frame(width: 96, height: 96)
                    .blur(radius: 26)
                    .offset(x: -10, y: -6)
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 12) {
                        // Artwork + Floating Source App Badge (NotchNook style)
                        Button {
                            openPlaybackSource()
                        } label: {
                            ZStack(alignment: .bottomTrailing) {
                                ArtworkView(
                                    nowPlayingViewModel: nowPlayingViewModel,
                                    width: 66,
                                    height: 66,
                                    cornerRadius: 15,
                                    usesFlipAnimation: mediaSettings?.nowPlayingAppearanceOptions.usesArtwork3DEffect ?? true
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.8)
                                )
                                .shadow(color: .black.opacity(0.45), radius: 8, y: 3)

                                playbackSourceBadge(for: snapshot)
                                    .offset(x: 4, y: 4)
                            }
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(alignment: .center, spacing: 6) {
                                Text(displayTitle(for: snapshot))
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                LightweightNowPlayingEqualizerView(
                                    isPlaying: snapshot.isPlaying,
                                    colors: [
                                        nowPlayingViewModel.artworkPalette.equalizerHighlightColor,
                                        nowPlayingViewModel.artworkPalette.equalizerBaseColor
                                    ],
                                    barHeight: 16,
                                    barWidth: 2.3
                                )
                                .frame(width: 18, height: 15)
                            }

                            Text(displayArtist(for: snapshot))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.56))
                                .lineLimit(1)

                            // Compact interactive scrub bar
                            slimScrubber(snapshot: snapshot, displayedProgress: displayedProgress, elapsedTime: elapsedTime)
                                .padding(.top, 3)
                        }
                    }

                    // Transport Controls Row
                    HStack(spacing: 14) {
                        if mediaSettings?.nowPlayingAppearanceOptions.showsFavoriteButton ?? true {
                            FavoriteTrackButton(
                                nowPlayingViewModel: nowPlayingViewModel,
                                width: 26,
                                height: 26,
                                fontSize: 13
                            )
                        }

                        Spacer(minLength: 0)

                        PlayerControlButton(
                            systemImage: "backward.fill",
                            fontSize: 16,
                            width: 30,
                            height: 28,
                            feedbackStyle: .backward
                        ) {
                            nowPlayingViewModel.previousTrack()
                        }

                        PlayerControlButton(
                            systemImage: snapshot.isPlaying ? "pause.fill" : "play.fill",
                            fontSize: 21,
                            width: 34,
                            height: 30,
                            feedbackStyle: .playPause
                        ) {
                            nowPlayingViewModel.togglePlayPause()
                        }

                        PlayerControlButton(
                            systemImage: "forward.fill",
                            fontSize: 16,
                            width: 30,
                            height: 28,
                            feedbackStyle: .forward
                        ) {
                            nowPlayingViewModel.nextTrack()
                        }

                        Spacer(minLength: 0)

                        if mediaSettings?.nowPlayingAppearanceOptions.showsOutputDeviceButton ?? true {
                            AudioOutputRoutePickerButton(
                                nowPlayingViewModel: nowPlayingViewModel,
                                width: 26,
                                height: 26,
                                fontSize: 13
                            )
                        }
                    }
                    .padding(.leading, 4)
                }
            }
        }
    }

    @ViewBuilder
    private func playbackSourceBadge(for snapshot: NowPlayingSnapshot) -> some View {
        if let bundleID = snapshot.playbackSource?.preferredBundleIdentifier,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .clipShape(Circle())
                .background(Circle().fill(Color.black.opacity(0.75)))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.8))
                .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
        } else {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.98, green: 0.23, blue: 0.37),
                                Color(red: 0.84, green: 0.11, blue: 0.27)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 21, height: 21)
                Image(systemName: "music.note")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(.white)
            }
            .overlay(Circle().strokeBorder(Color.black.opacity(0.55), lineWidth: 1.2))
            .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
        }
    }

    private func slimScrubber(
        snapshot: NowPlayingSnapshot,
        displayedProgress: CGFloat,
        elapsedTime: TimeInterval
    ) -> some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                let width = max(1, geo.size.width)
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.14))
                        .frame(height: 4)

                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(nsColor: nowPlayingViewModel.artworkPalette.equalizerHighlightColor),
                                    accentColor
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(4, width * displayedProgress), height: 4)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard snapshot.duration > 0 else { return }
                            let ratio = min(max(value.location.x / width, 0), 1)
                            scrubProgress = ratio
                        }
                        .onEnded { value in
                            guard snapshot.duration > 0 else { return }
                            let ratio = min(max(value.location.x / width, 0), 1)
                            nowPlayingViewModel.seek(to: snapshot.duration * TimeInterval(ratio))
                            scrubProgress = nil
                        }
                )
            }
            .frame(height: 6)

            if snapshot.duration > 0 {
                HStack {
                    Text(shortTimeString(elapsedTime))
                    Spacer()
                    Text("-" + shortTimeString(max(0, snapshot.duration - elapsedTime)))
                }
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.42))
            }
        }
    }

    private func displayTitle(for snapshot: NowPlayingSnapshot) -> String {
        snapshot.title.trimmed.isEmpty
            ? locale.dn("notch.nowPlaying.nothingPlaying", fallback: "Not Playing")
            : snapshot.title
    }

    private func displayArtist(for snapshot: NowPlayingSnapshot) -> String {
        snapshot.artist.trimmed.isEmpty
            ? privacyText("Play music or video", "미디어 대기 중")
            : snapshot.artist
    }

    private func shortTimeString(_ time: TimeInterval) -> String {
        guard time.isFinite else { return "0:00" }
        let total = max(0, Int(time.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func openPlaybackSource() {
        if nowPlayingViewModel.canOpenPlaybackSource {
            nowPlayingViewModel.openPlaybackSource()
            if !(applicationSettings?.isCloseAtFocusLiveActivityEnabled ?? false) {
                onOpenPlaybackSource()
            }
        } else {
            _ = ApplicationActivator.shared.openOrActivate(bundleIdentifier: "com.apple.Music")
        }
    }
}

// MARK: - Column 2: Month + 7-Day Week Strip & Schedule (NotchNook + OS 27)

private struct NotchieCalendarScheduleColumn: View {
    var calendarViewModel: CalendarViewModel?
    @Binding var selectedDayOffset: Int
    let accentColor: Color
    let onSwitchToTasks: () -> Void

    @ObservedObject private var productivityStorage = ProductivityStorage.shared

    private func text(_ en: String, _ ko: String) -> String {
        privacyText(en, ko)
    }

    private var selectedDate: Date {
        Calendar.current.date(byAdding: .day, value: selectedDayOffset, to: Date()) ?? Date()
    }

    private var monthAbbreviation: String {
        let formatter = DateFormatter()
        formatter.dateFormat = Locale.preferredLanguages.first?.hasPrefix("ko") == true ? "M월" : "MMM"
        return formatter.string(from: selectedDate)
    }

    private var weekDays: [(offset: Int, date: Date, weekdayShort: String, dayNumber: String, hasEvents: Bool)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE"

        return (-2...4).compactMap { offset in
            guard let date = cal.date(byAdding: .day, value: offset, to: today) else { return nil }
            let dayNum = String(cal.component(.day, from: date))
            let wk = formatter.string(from: date).uppercased()
            let hasEvents = events(on: date).isEmpty == false
            return (offset, date, wk, dayNum, hasEvents)
        }
    }

    private func events(on date: Date) -> [EKEvent] {
        guard let events = calendarViewModel?.events else { return [] }
        let cal = Calendar.current
        return events.filter { event in
            cal.isDate(event.startDate, inSameDayAs: date) ||
            (event.startDate < cal.startOfDay(for: date).addingTimeInterval(86400) && event.endDate > cal.startOfDay(for: date))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top Row: Month Title + 7-Day Horizontal Strip (matches NotchNook screenshot)
            HStack(alignment: .center, spacing: 8) {
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        selectedDayOffset = 0
                    }
                } label: {
                    Text(monthAbbreviation)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                HStack(spacing: 4) {
                    ForEach(weekDays, id: \.offset) { item in
                        let isSelected = item.offset == selectedDayOffset
                        let isToday = item.offset == 0
                        Button {
                            withAnimation(.snappy(duration: 0.18)) {
                                selectedDayOffset = item.offset
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Text(item.weekdayShort)
                                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                                    .foregroundStyle(
                                        isSelected
                                            ? Color(red: 0.26, green: 0.62, blue: 1.0)
                                            : (isToday ? accentColor : .white.opacity(0.45))
                                    )

                                Text(item.dayNumber)
                                    .font(.system(size: 13, weight: isSelected ? .bold : .semibold, design: .rounded))
                                    .foregroundStyle(
                                        isSelected
                                            ? Color(red: 0.26, green: 0.62, blue: 1.0)
                                            : .white.opacity(isToday ? 0.95 : 0.72)
                                    )

                                Circle()
                                    .fill(item.hasEvents ? accentColor : Color.clear)
                                    .frame(width: 3.5, height: 3.5)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(isSelected ? Color(red: 0.2, green: 0.52, blue: 1.0).opacity(0.18) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Bottom Row: Selected Day's Event / Join Meeting OR "Nothing for today" + Today's Task Chip
            let dayEvents = events(on: selectedDate)
            if let primaryEvent = dayEvents.first ?? (selectedDayOffset == 0 ? calendarViewModel?.nextEvent : nil) {
                eventDetailCard(for: primaryEvent)
            } else {
                emptyScheduleView
            }
        }
    }

    private func eventDetailCard(for event: EKEvent) -> some View {
        let title = calendarViewModel?.displayTitle(for: event) ?? event.title ?? "Event"
        let meetingURL = MeetingLink.first(url: event.url, notes: event.notes, location: event.location)

        return HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 3.5, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(eventTimeRangeText(for: event))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.56))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let meetingURL {
                Button {
                    NSWorkspace.shared.open(meetingURL)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(text("Join", "참여"))
                            .font(.system(size: 10.5, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.blue, in: Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    calendarViewModel?.openCalendarEvent()
                } label: {
                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.8)
                )
        )
    }

    private var emptyScheduleView: some View {
        let pendingTask = productivityStorage.todayTasks.first(where: { !$0.done }) ?? productivityStorage.todayTasks.first

        return HStack(spacing: 10) {
            Button {
                calendarViewModel?.openCalendarEvent()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white.opacity(0.42))

                    VStack(alignment: .leading, spacing: 1.5) {
                        Text(text("Nothing for today", "오늘 예정된 일정 없음"))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                        Text(text("Tap to open Calendar", "클릭하여 캘린더 열기"))
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.34))
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 4)

            if let task = pendingTask {
                Button {
                    productivityStorage.toggleTask(task.id)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(task.done ? accentColor : .white.opacity(0.6))
                        Text(task.text)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.82))
                            .strikethrough(task.done)
                            .lineLimit(1)
                            .frame(maxWidth: 96, alignment: .leading)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.07), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.7))
                }
                .buttonStyle(.plain)
                .help(text("Toggle today's priority task", "오늘의 핵심 할 일 완료 토글"))
            } else {
                Button(action: onSwitchToTasks) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 10.5))
                            .foregroundStyle(accentColor)
                        Text(text("Add Task", "할 일 추가"))
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.07), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44)
    }

    private func eventTimeRangeText(for event: EKEvent) -> String {
        if event.isAllDay {
            return text("All Day", "종일")
        }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: event.startDate)) – \(formatter.string(from: event.endDate))"
    }
}

// MARK: - Column 3: Circular Camera Mirror & Focus Pod (NotchNook + OS 27)

private struct NotchieCameraMirrorPodColumn: View {
    @ObservedObject var store: QuickToolsStore
    @ObservedObject private var focusController: FocusSessionController
    @ObservedObject private var stopwatchController: StopwatchController
    let accentColor: Color

    init(store: QuickToolsStore, accentColor: Color) {
        self.store = store
        self._focusController = ObservedObject(wrappedValue: store.focus)
        self._stopwatchController = ObservedObject(wrappedValue: store.stopwatch)
        self.accentColor = accentColor
    }

    private func text(_ en: String, _ ko: String) -> String {
        privacyText(en, ko)
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        store.isMirrorCameraActive.toggle()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(0.15),
                                        Color.white.opacity(0.05),
                                        Color.black.opacity(0.65)
                                    ],
                                    center: .topLeading,
                                    startRadius: 4,
                                    endRadius: 56
                                )
                            )
                            .frame(width: 78, height: 78)

                        if store.isMirrorCameraActive {
                            NotchieMirrorCameraView()
                                .frame(width: 78, height: 78)
                                .clipShape(Circle())
                        } else if focusController.phase == .focus || focusController.phase == .rest {
                            VStack(spacing: 2) {
                                Image(systemName: "timer")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(accentColor)
                                Text(focusController.timer.formattedRemainingTime)
                                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                            }
                        } else if stopwatchController.state.isRunning {
                            TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                                VStack(spacing: 2) {
                                    Image(systemName: "stopwatch.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(accentColor)
                                    Text(StopwatchState.formatted(stopwatchController.state.elapsed(at: .now)))
                                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white)
                                }
                            }
                        } else {
                            // Sleek NotchNook-inspired mirrored portrait silhouette
                            VStack(spacing: 3) {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 32, weight: .light))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.white.opacity(0.75), .white.opacity(0.32)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                Text(text("Mirror", "미러"))
                                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                        }

                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.35),
                                        store.isMirrorCameraActive ? accentColor.opacity(0.85) : Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                            .frame(width: 78, height: 78)
                    }
                }
                .buttonStyle(.plain)
                .help(store.isMirrorCameraActive ? text("Stop Camera Mirror", "카메라 미러 끄기") : text("Start Live Camera Mirror", "실시간 카메라 미러 켜기"))

                // Floating bottom-right badge matching NotchNook screenshot
                Button {
                    if store.isMirrorCameraActive {
                        store.isMirrorCameraActive = false
                    } else {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                            store.selectedTool = "focus"
                            store.hubMode = .tools
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill( Color(red: 0.14, green: 0.16, blue: 0.22) )
                            .frame(width: 24, height: 24)
                        Circle()
                            .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.8)
                            .frame(width: 24, height: 24)
                        Image(systemName: store.isMirrorCameraActive ? "video.slash.fill" : "camera.fill")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(Color(red: 0.26, green: 0.62, blue: 1.0))
                    }
                    .shadow(color: .black.opacity(0.45), radius: 4, y: 1)
                }
                .buttonStyle(.plain)
                .offset(x: 2, y: 2)
            }
        }
    }
}

// MARK: - Live Front-Camera Mirror Preview (Opt-in on Click, Auto-Stop on Close)

private struct NotchieMirrorCameraView: NSViewRepresentable {
    func makeNSView(context: Context) -> NotchieMirrorPreviewNSView {
        let view = NotchieMirrorPreviewNSView()
        view.startMirrorIfAuthorized()
        return view
    }

    func updateNSView(_ nsView: NotchieMirrorPreviewNSView, context: Context) {}

    static func dismantleNSView(_ nsView: NotchieMirrorPreviewNSView, coordinator: ()) {
        nsView.stopMirror()
    }
}

private final class NotchieMirrorPreviewNSView: NSView {
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.notchie.mirror.camera.queue")
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func layout() {
        super.layout()
        previewLayer?.frame = bounds
    }

    func startMirrorIfAuthorized() {
        guard !AppEnvironment.isRunningTests else { return }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .authorized {
            configureAndStart()
        } else if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard granted else { return }
                DispatchQueue.main.async {
                    self?.configureAndStart()
                }
            }
        }
    }

    private func configureAndStart() {
        if previewLayer == nil {
            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            layer.frame = bounds
            layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            if let connection = layer.connection, connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
            }
            self.layer?.addSublayer(layer)
            self.previewLayer = layer
        }

        let captureSession = self.session
        sessionQueue.async { [weak self] in
            guard !captureSession.isRunning else { return }
            captureSession.beginConfiguration()
            captureSession.sessionPreset = .medium
            if captureSession.inputs.isEmpty,
               let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) ?? AVCaptureDevice.default(for: .video),
               let input = try? AVCaptureDeviceInput(device: camera),
               captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            captureSession.commitConfiguration()
            captureSession.startRunning()
            DispatchQueue.main.async {
                if let connection = self?.previewLayer?.connection, connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = true
                }
            }
        }
    }

    func stopMirror() {
        let captureSession = self.session
        sessionQueue.async {
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
        }
    }

    deinit {
        let captureSession = self.session
        sessionQueue.async {
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
        }
    }
}

// MARK: - Panoramic Tray Section (File Shelf + AirDrop Drop Zone)

private struct NotchiePanoramicTraySection: View {
    var fileTrayViewModel: FileTrayViewModel?
    var mediaSettings: MediaAndFilesSettingsStore?
    let accentColor: Color

    private func text(_ en: String, _ ko: String) -> String {
        privacyText(en, ko)
    }

    var body: some View {
        if let trayVM = fileTrayViewModel {
            ObservedPanoramicTrayBody(
                fileTrayViewModel: trayVM,
                mediaSettings: mediaSettings,
                accentColor: accentColor
            )
        } else {
            emptyTrayPlaceholder(onAddFiles: {})
        }
    }

    private func emptyTrayPlaceholder(onAddFiles: @escaping () -> Void) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Label(text("Notchie File Tray & AirDrop", "Notchie 파일 트레이 & AirDrop"), systemImage: "tray.and.arrow.down.fill")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(text("Drag files onto the notch to pin them here or share via AirDrop.", "파일을 노치로 드래그하여 보관하거나 AirDrop으로 즉시 공유하세요."))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            Button(action: onAddFiles) {
                Label(text("Add Files", "파일 추가"), systemImage: "plus.circle.fill")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(accentColor.opacity(0.82), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        .foregroundStyle(Color.white.opacity(0.18))
                )
        )
    }
}

private struct ObservedPanoramicTrayBody: View {
    @ObservedObject var fileTrayViewModel: FileTrayViewModel
    var mediaSettings: MediaAndFilesSettingsStore?
    let accentColor: Color

    private func text(_ en: String, _ ko: String) -> String {
        privacyText(en, ko)
    }

    var body: some View {
        if fileTrayViewModel.items.isEmpty {
            HStack(spacing: 16) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(accentColor)
                    .frame(width: 48, height: 48)
                    .background(accentColor.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(text("File Shelf & AirDrop Tray", "파일 보관함 & AirDrop 트레이"))
                        .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(text("Drop any files, images, or folders here for temporary holding or quick AirDrop.", "파일·이미지·폴더를 노치에 드롭하여 임시 보관하거나 AirDrop으로 공유하세요."))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(2)
                }

                Spacer()

                Button {
                    pickFilesForTray()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus.circle.fill")
                        Text(text("Add Files…", "파일 추가…"))
                    }
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(accentColor.opacity(0.8), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.045))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                            .foregroundStyle(Color.white.opacity(0.18))
                    )
            )
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleFileDrop(providers)
            }
        } else if let settings = mediaSettings {
            TrayExpandedActiveNotchView(
                fileTrayViewModel: fileTrayViewModel,
                mediaSettings: settings
            )
        }
    }

    private func pickFilesForTray() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            fileTrayViewModel.add(panel.urls)
        }
    }

    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let resolvedURL: URL?
                if let data = item as? Data {
                    resolvedURL = URL(dataRepresentation: data, relativeTo: nil)
                } else if let url = item as? URL {
                    resolvedURL = url
                } else {
                    resolvedURL = nil
                }
                if let url = resolvedURL {
                    Task { @MainActor in
                        fileTrayViewModel.add([url])
                    }
                }
            }
        }
        return true
    }
}

// MARK: - Stopwatch & KeepAwake Views

struct QuickStopwatchView: View {
    @ObservedObject var controller: StopwatchController
    var body: some View {
        VStack(spacing: 16) {
            if controller.state.isRunning {
                TimelineView(.periodic(from: .now, by: 0.2)) { _ in time(StopwatchState.formatted(controller.state.elapsed(at: .now))) }
            } else { time(StopwatchState.formatted(controller.state.accumulated)) }
            HStack(spacing: 20) {
                Button(LocalizedStringKey(controller.state.isRunning ? "settings.tools.pause" : "settings.tools.start")) {
                    if controller.state.isRunning { controller.pause() } else { controller.start() }
                }
                Button("settings.tools.reset") { controller.reset() }
            }
            Text("settings.tools.stopwatch.desc").font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private func time(_ value: String) -> some View { Text(value).font(.system(size: 34, weight: .light, design: .monospaced)).monospacedDigit() }
}

struct KeepAwakeView: View {
    @ObservedObject var controller: KeepAwakeController
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: controller.until == nil ? "cup.and.saucer" : "cup.and.saucer.fill").font(.title)
            if let until = controller.until {
                Text(until, style: .timer).monospacedDigit()
                Button("settings.tools.stop") { controller.stop() }
            } else {
                HStack { ForEach([15, 30, 60], id: \.self) { minutes in Button("\(minutes) min") { controller.start(seconds: Double(minutes * 60)) } } }
            }
            if let error = controller.error { Text(error).foregroundStyle(.red).font(.caption) }
            Text("settings.tools.awake.desc").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - QuickToolsNotchContent (Panoramic Geometry & Corner Radius)

struct QuickToolsNotchContent: NotchContentProtocol {
    let id = "local.quickTools"
    let store: QuickToolsStore
    var openedFromIdleHover: Bool = false

    var priority: Int { Int.max / 2 }
    var isExpandable: Bool { true }
    var pinsExpandedInteraction: Bool {
        openedFromIdleHover ? store.isNotchHubPinned : true
    }
    var strokeColor: Color {
        ApplicationSettingsStore.currentCustomAccentColor().opacity(0.45)
    }

    @MainActor func compactView() -> AnyView {
        AnyView(QuickToolsCompactView(store: store))
    }

    @MainActor func expandedView() -> AnyView {
        AnyView(QuickToolsView(store: store, inNotch: true))
    }

    func compactSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        CGSize(width: baseWidth + 90, height: baseHeight)
    }

    func expandedSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        let extraHeight: CGFloat = store.hubMode.requiresExtendedHeight ? 210 : 154
        return CGSize(width: max(688, baseWidth + 488), height: baseHeight + extraHeight)
    }

    func expandedDynamicIslandSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        let extraHeight: CGFloat = store.hubMode.requiresExtendedHeight ? 200 : 146
        return CGSize(width: max(668, baseWidth + 468), height: baseHeight + extraHeight)
    }

    func expandedCornerRadius(baseRadius: CGFloat) -> (top: CGFloat, bottom: CGFloat) {
        (top: 19, bottom: 28)
    }
}

struct QuickToolsCompactView: View {
    @ObservedObject var store: QuickToolsStore
    private var accentColor: Color {
        ApplicationSettingsStore.currentCustomAccentColor()
    }
    var body: some View {
        HStack {
            Image(systemName: "square.grid.2x2").foregroundStyle(accentColor)
            Spacer()
            if store.selectedTool == "focus" { FocusCompactView(controller: store.focus) }
            else { Image(systemName: "pencil.and.outline").foregroundStyle(accentColor) }
        }.padding(.horizontal, 14)
    }
}

struct FocusCompactView: View {
    @ObservedObject var controller: FocusSessionController
    var body: some View {
        Text(controller.timer.formattedRemainingTime)
            .monospacedDigit()
            .font(.caption)
            .foregroundStyle(ApplicationSettingsStore.currentCustomAccentColor())
    }
}
