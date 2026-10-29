import SwiftUI
internal import AppKit
import AVFoundation
internal import EventKit
import UniformTypeIdentifiers
import ApplicationServices
import Combine

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
                    store.hubMode = .tools
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
                                Text(L10n.app(tab.titleKey))
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
                                Text(L10n.app(tab.titleKey))
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
            case "transform": ShelfTransformView()
            case "teleprompter": TeleprompterView(controller: store.teleprompter)
            case "emoji": ShelfEmojiView()
            case "stats": ShelfSystemStatsView()
            case "notes": QuickNotesView(store: store.notes)
            case "stopwatch": QuickStopwatchView(controller: store.stopwatch)
            case "awake": KeepAwakeView(controller: store.awake)
            case "focus": FocusSessionView(controller: store.focus)
            case "tasks": TodayTasksView()
            case "snippets": ClipboardSnippetsView(onOpenNotes: { store.selectedTool = "notes"; store.hubMode = .tools })
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
                            Label(L10n.app(tab.titleKey), systemImage: tab.systemImage)
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
    var onOpenPlaybackSource: @MainActor @Sendable () -> Void = {}

    @State private var showingTabCustomizer = false
    @State private var selectedDayOffset: Int = 0
    @State private var showingToolLibrary = false

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
        VStack(spacing: 10) {
            topWingHeaderBar
                .frame(height: 28)

            Group {
                switch store.hubMode {
                case .nook:
                    nookThreeColumnDashboard
                case .widgets:
                    nookThreeColumnDashboard
                case .tray, .shots:
                    trayAndShotsUnifiedContainer
                case .clips, .notes:
                    studioUnifiedContainer
                case .tools:
                    panoramicToolsBrowser
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, isNotchlessScreen ? 16 : 20)
        .padding(.top, isNotchlessScreen ? 6 : 5)
        .padding(.bottom, isNotchlessScreen ? 12 : 13)
        .environment(\.colorScheme, .dark)
        .onDisappear {
            if store.isMirrorCameraActive {
                store.isMirrorCameraActive = false
            }
        }
    }

    // MARK: - Top Header Bar (4 Balanced Primary Tabs Flanking the Camera Cutout)

    private var topWingHeaderBar: some View {
        HStack(spacing: 0) {
            // Left Wing: 2 Iconic Primary Tabs (Nook | Tray)
            HStack(spacing: 6) {
                primaryWingTabButton(
                    title: "Nook",
                    systemImage: "sparkles",
                    isSelected: store.hubMode == .nook,
                    badgeCount: 0,
                    badgeIsAlert: false
                ) {
                    store.hubMode = .nook
                }

                primaryWingTabButton(
                    title: text("Tray", "트레이"),
                    systemImage: "tray.full.fill",
                    isSelected: store.hubMode == .tray || store.hubMode == .shots,
                    badgeCount: (store.fileTrayViewModel?.count ?? 0) + (store.screenshotViewModel?.history.count ?? 0),
                    badgeIsAlert: false
                ) {
                    if store.hubMode != .tray && store.hubMode != .shots {
                        store.hubMode = .tray
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Center Camera Cutout Safe Area (Strictly Centered)
            Color.clear
                .frame(width: isNotchlessScreen ? 16 : 148)

            // Right Wing: Tools Tab Attached Directly Next to App Icon Utility Rail
            HStack(spacing: 5) {
                Spacer(minLength: 0)

                primaryWingTabButton(
                    title: text("Tools", "도구"),
                    systemImage: "wrench.and.screwdriver.fill",
                    isSelected: store.hubMode == .tools,
                    badgeCount: (store.focus.timer.isActive ? 1 : 0),
                    badgeIsAlert: store.focus.timer.isActive
                ) {
                    store.hubMode = .tools
                }

                // Apple Glass Settings Button
                Button {
                    SettingsWindowController.shared.showWindow()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 24, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(text("Open Notchie Settings", "Notchie 설정 열기"))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.07))
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                        )
                )
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func primaryWingTabButton(
        title: String,
        systemImage: String,
        isSelected: Bool,
        badgeCount: Int,
        badgeIsAlert: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) {
                action()
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? accentColor : .white.opacity(0.85))

                Text(title)
                    .font(.system(size: 11.5, weight: isSelected ? .bold : .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.92))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundStyle(badgeIsAlert ? .black : (isSelected ? .white : accentColor))
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 1)
                        .background(
                            (badgeIsAlert ? Color(red: 0.99, green: 0.90, blue: 0.0) : (isSelected ? accentColor : Color.white.opacity(0.12))),
                            in: Capsule()
                        )
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
                                        accentColor.opacity(0.35),
                                        accentColor.opacity(0.18)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        Capsule(style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        accentColor,
                                        accentColor.opacity(0.55)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.0
                            )
                            .shadow(color: accentColor.opacity(0.35), radius: 3, y: 1)
                    } else {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.09))
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.85)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Unified Tray + Screenshots Container

    private var trayAndShotsUnifiedContainer: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                subModeSegmentButton(
                    title: text("File Tray", "파일 트레이"),
                    icon: "tray.full.fill",
                    count: store.fileTrayViewModel?.count ?? 0,
                    isSelected: store.hubMode == .tray
                ) {
                    store.hubMode = .tray
                }

                subModeSegmentButton(
                    title: text("Captures", "스크린샷 기록"),
                    icon: "camera.viewfinder",
                    count: store.screenshotViewModel?.history.count ?? 0,
                    isSelected: store.hubMode == .shots
                ) {
                    store.hubMode = .shots
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) {
                        store.hubMode = .nook
                    }
                } label: {
                    HStack(spacing: 3.5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 9, weight: .bold))
                        Text(text("Back to Nook", "Nook으로 돌아가기"))
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.09), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 0.8))
                }
                .buttonStyle(.plain)
            }

            if store.hubMode == .shots {
                NotchieScreenshotHubView(
                    screenshotViewModel: store.screenshotViewModel,
                    fileTrayViewModel: store.fileTrayViewModel,
                    accentColor: accentColor
                )
            } else {
                NotchiePanoramicTraySection(
                    fileTrayViewModel: store.fileTrayViewModel,
                    mediaSettings: resolvedMediaSettings,
                    accentColor: accentColor
                )
            }
        }
    }

    // MARK: - Unified Studio Container (Clipboard · Notes)

    private var studioUnifiedContainer: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                subModeSegmentButton(
                    title: text("Clipboard", "클립보드"),
                    icon: "doc.on.clipboard.fill",
                    count: ProductivityStorage.shared.document.snippets.count,
                    isSelected: store.hubMode == .clips
                ) {
                    store.hubMode = .clips
                }

                subModeSegmentButton(
                    title: text("Quick Notes", "빠른 메모"),
                    icon: "note.text",
                    count: 0,
                    isSelected: store.hubMode == .notes
                ) {
                    store.hubMode = .notes
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) {
                        store.hubMode = .nook
                    }
                } label: {
                    HStack(spacing: 3.5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 9, weight: .bold))
                        Text(text("Back to Nook", "Nook으로 돌아가기"))
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.09), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 0.8))
                }
                .buttonStyle(.plain)
            }

            Group {
                if store.hubMode == .clips {
                    ClipboardSnippetsView(onOpenNotes: { store.selectedTool = "notes"; store.hubMode = .tools })
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.045))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.8)
                                )
                        )
                } else {
                    QuickNotesView(store: store.notes)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.045))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.8)
                                )
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func subModeSegmentButton(
        title: String,
        icon: String,
        count: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.18)) {
                action()
            }
        } label: {
            HStack(spacing: 4.5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isSelected ? accentColor : .white.opacity(0.82))
                Text(title)
                    .font(.system(size: 10.5, weight: isSelected ? .bold : .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.90))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.95))
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 0.5)
                        .background(accentColor.opacity(0.85), in: Capsule())
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(isSelected ? accentColor.opacity(0.8) : Color.white.opacity(0.14), lineWidth: 0.8)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Nook media and calendar

    private var nookThreeColumnDashboard: some View {
        HStack(alignment: .center, spacing: 12) {
            NotchieNowPlayingStudioColumn(
                nowPlayingViewModel: resolvedNowPlayingViewModel,
                mediaSettings: resolvedMediaSettings,
                applicationSettings: resolvedApplicationSettings,
                accentColor: accentColor,
                onOpenPlaybackSource: { onOpenPlaybackSource() },
                plainStyle: true
            )
            .frame(width: 230, height: 136)
            Rectangle().fill(.white.opacity(0.1)).frame(width: 1, height: 118)
            NotchieCalendarScheduleColumn(
                calendarViewModel: store.calendarViewModel,
                selectedDayOffset: $selectedDayOffset,
                accentColor: accentColor,
                onSwitchToTools: {},
                onSwitchToTasks: {},
                compactHome: true
            )
            .frame(maxWidth: .infinity).frame(height: 136)
        }
        .accessibilityIdentifier("nook.home.mediaCalendar")
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
            HStack(spacing: 6) {
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
                                    Text(L10n.app(tab.titleKey))
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

                Button { showingToolLibrary.toggle() } label: {
                    Label(text("All tools", "모든 도구"), systemImage: "square.grid.2x2")
                        .font(.system(size: 10.5, weight: .semibold))
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(accentColor.opacity(0.13), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("shelf.allTools")
                .popover(isPresented: $showingToolLibrary) {
                    ShelfToolLibrary(store: store) { showingToolLibrary = false }.preferredColorScheme(.dark)
                }

                Spacer(minLength: 4)

                Button {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) {
                        store.hubMode = .nook
                    }
                } label: {
                    HStack(spacing: 3.5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 9, weight: .bold))
                        Text(text("Back to Nook", "Nook으로 돌아가기"))
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.09), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 0.8))
                }
                .buttonStyle(.plain)
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
    let onOpenPlaybackSource: @MainActor @Sendable () -> Void

    var plainStyle = false

    @State private var scrubProgress: CGFloat?

    private var fallbackSnapshot: NowPlayingSnapshot {
        NowPlayingSnapshot(
            title: privacyText("Not Playing", "재생 대기 중"),
            artist: privacyText("Play music or video", "재생 중인 미디어 없음"),
            album: "Notchie Studio",
            duration: 0,
            elapsedTime: 0,
            playbackRate: 0,
            artworkData: nil,
            refreshedAt: .now
        )
    }

    var body: some View {
        ZStack {
            if !plainStyle {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.075),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.20),
                                    Color.white.opacity(0.06)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.85
                        )
                )

            }
            if let vm = nowPlayingViewModel {
                ObservedNowPlayingStudioBody(
                    nowPlayingViewModel: vm,
                    mediaSettings: mediaSettings,
                    applicationSettings: applicationSettings,
                    accentColor: accentColor,
                    onOpenPlaybackSource: { onOpenPlaybackSource() },
                    scrubProgress: $scrubProgress
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            } else {
                placeholderStudioCard
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
        }
    }

    private var placeholderStudioCard: some View {
        let snap = fallbackSnapshot
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.98, green: 0.24, blue: 0.38),
                                    Color(red: 0.72, green: 0.12, blue: 0.28)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.95))
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.8)
                        )
                        .shadow(color: .black.opacity(0.35), radius: 5, y: 2)

                    ZStack {
                        Circle()
                            .fill(Color(red: 0.12, green: 0.14, blue: 0.18))
                            .frame(width: 18, height: 18)
                        Circle()
                            .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.7)
                            .frame(width: 18, height: 18)
                        Image(systemName: "waveform")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(accentColor)
                    }
                    .offset(x: 3, y: 3)
                }

                VStack(alignment: .leading, spacing: 2.5) {
                    Text(snap.title)
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(snap.artist)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 6)

            // Balanced Scrubber Track
            VStack(spacing: 3) {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 3.5)

                HStack {
                    Text("0:00")
                    Spacer()
                    Text("-0:00")
                }
                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
            }

            Spacer(minLength: 4)

            // Centered Transport Bar
            HStack(spacing: 24) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 13.5, weight: .semibold))
                Image(systemName: "play.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white.opacity(0.82))
                Image(systemName: "forward.fill")
                    .font(.system(size: 13.5, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.52))
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
    let onOpenPlaybackSource: @MainActor @Sendable () -> Void
    @Binding var scrubProgress: CGFloat?

    private var resolvedSnapshot: NowPlayingSnapshot {
        nowPlayingViewModel.snapshot ?? NowPlayingSnapshot(
            title: privacyText("Not Playing", "재생 대기 중"),
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
                Circle()
                    .fill(Color(nsColor: nowPlayingViewModel.artworkPalette.equalizerHighlightColor).opacity(snapshot.isPlaying ? 0.20 : 0.08))
                    .frame(width: 84, height: 84)
                    .blur(radius: 24)
                    .offset(x: -8, y: -6)
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 10) {
                        Button {
                            openPlaybackSource()
                        } label: {
                            ZStack(alignment: .bottomTrailing) {
                                ArtworkView(
                                    nowPlayingViewModel: nowPlayingViewModel,
                                    width: 48,
                                    height: 48,
                                    cornerRadius: 12,
                                    usesFlipAnimation: mediaSettings?.nowPlayingAppearanceOptions.usesArtwork3DEffect ?? true
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
                                )
                                .shadow(color: .black.opacity(0.4), radius: 5, y: 2)

                                playbackSourceBadge(for: snapshot)
                                    .offset(x: 3, y: 3)
                            }
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 2.5) {
                            HStack(alignment: .center, spacing: 5) {
                                Text(displayTitle(for: snapshot))
                                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                LightweightNowPlayingEqualizerView(
                                    isPlaying: snapshot.isPlaying,
                                    colors: [
                                        nowPlayingViewModel.artworkPalette.equalizerHighlightColor,
                                        nowPlayingViewModel.artworkPalette.equalizerBaseColor
                                    ],
                                    barHeight: 14,
                                    barWidth: 2.1
                                )
                                .frame(width: 16, height: 14)
                            }

                            Text(displayArtist(for: snapshot))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.56))
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 6)

                    slimScrubber(snapshot: snapshot, displayedProgress: displayedProgress, elapsedTime: elapsedTime)

                    Spacer(minLength: 4)

                    HStack(spacing: 12) {
                        if mediaSettings?.nowPlayingAppearanceOptions.showsFavoriteButton ?? true {
                            FavoriteTrackButton(
                                nowPlayingViewModel: nowPlayingViewModel,
                                width: 22,
                                height: 22,
                                fontSize: 11.5
                            )
                        }

                        Spacer(minLength: 0)

                        PlayerControlButton(
                            systemImage: "backward.fill",
                            fontSize: 14,
                            width: 26,
                            height: 24,
                            feedbackStyle: .backward
                        ) {
                            nowPlayingViewModel.previousTrack()
                        }

                        PlayerControlButton(
                            systemImage: snapshot.isPlaying ? "pause.fill" : "play.fill",
                            fontSize: 18,
                            width: 30,
                            height: 26,
                            feedbackStyle: .playPause
                        ) {
                            nowPlayingViewModel.togglePlayPause()
                        }

                        PlayerControlButton(
                            systemImage: "forward.fill",
                            fontSize: 14,
                            width: 26,
                            height: 24,
                            feedbackStyle: .forward
                        ) {
                            nowPlayingViewModel.nextTrack()
                        }

                        Spacer(minLength: 0)

                        if mediaSettings?.nowPlayingAppearanceOptions.showsOutputDeviceButton ?? true {
                            AudioOutputRoutePickerButton(
                                nowPlayingViewModel: nowPlayingViewModel,
                                width: 22,
                                height: 22,
                                fontSize: 11.5
                            )
                        }
                    }
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
                .frame(width: 18, height: 18)
                .clipShape(Circle())
                .background(Circle().fill(Color.black.opacity(0.75)))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.7))
                .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
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
                    .frame(width: 18, height: 18)
                Image(systemName: "music.note")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
            }
            .overlay(Circle().strokeBorder(Color.black.opacity(0.55), lineWidth: 1.0))
            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
        }
    }

    private func slimScrubber(
        snapshot: NowPlayingSnapshot,
        displayedProgress: CGFloat,
        elapsedTime: TimeInterval
    ) -> some View {
        VStack(spacing: 2.5) {
            GeometryReader { geo in
                let width = max(1, geo.size.width)
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.14))
                        .frame(height: 3.5)

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
                        .frame(width: max(3.5, width * displayedProgress), height: 3.5)
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
            .frame(height: 5)

            HStack {
                Text(snapshot.duration > 0 ? shortTimeString(elapsedTime) : "0:00")
                Spacer()
                Text(snapshot.duration > 0 ? "-" + shortTimeString(max(0, snapshot.duration - elapsedTime)) : "-0:00")
            }
            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.38))
        }
    }

    private func displayTitle(for snapshot: NowPlayingSnapshot) -> String {
        snapshot.title.trimmed.isEmpty
            ? privacyText("Not Playing", "재생 대기 중")
            : snapshot.title
    }

    private func displayArtist(for snapshot: NowPlayingSnapshot) -> String {
        snapshot.artist.trimmed.isEmpty
            ? privacyText("Play music or video", "재생 중인 미디어 없음")
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

// MARK: - Column 2: Month + 7-Day Week Strip & Schedule Bento Card (Apple Liquid Glass)

private struct NotchieCalendarScheduleColumn: View {
    var calendarViewModel: CalendarViewModel?
    @Binding var selectedDayOffset: Int
    let accentColor: Color
    let onSwitchToTools: () -> Void
    let onSwitchToTasks: () -> Void
    var compactHome = false

    @ObservedObject private var productivityStorage = ProductivityStorage.shared

    private func text(_ en: String, _ ko: String) -> String {
        privacyText(en, ko)
    }

    private var selectedDate: Date {
        Calendar.current.date(byAdding: .day, value: selectedDayOffset, to: Date()) ?? Date()
    }

    private var monthHeaderTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = Locale.preferredLanguages.first?.hasPrefix("ko") == true ? "yyyy년 M월" : "MMMM yyyy"
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
        let pendingTask = productivityStorage.todayTasks.first(where: { !$0.done }) ?? productivityStorage.todayTasks.first

        if compactHome {
            nookCalendar
        } else {
        ZStack {
            if !compactHome {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.075),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.20),
                                    Color.white.opacity(0.06)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.85
                        )
                )

            }
            VStack(alignment: .leading, spacing: 6) {
                // Header Row: Month Title + Quick Task / Today Button
                HStack(alignment: .center, spacing: 6) {
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            selectedDayOffset = 0
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundStyle(accentColor)
                            Text(monthHeaderTitle)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    if !compactHome {
                    if let task = pendingTask {
                        Button {
                            productivityStorage.toggleTask(task.id)
                        } label: {
                            HStack(spacing: 3.5) {
                                Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundStyle(task.done ? accentColor : .white.opacity(0.6))
                                Text(task.text)
                                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .strikethrough(task.done)
                                    .lineLimit(1)
                                    .frame(maxWidth: 68, alignment: .leading)
                            }
                            .padding(.horizontal, 6.5)
                            .padding(.vertical, 2.5)
                            .background(Color.white.opacity(0.08), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: onSwitchToTasks) {
                            HStack(spacing: 3) {
                                Image(systemName: "plus")
                                    .font(.system(size: 8.5, weight: .bold))
                                    .foregroundStyle(accentColor)
                                Text(text("Task", "할 일"))
                                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.78))
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(Color.white.opacity(0.08), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    }
                }

                // Middle Row: Precision 7-Day Horizontal Strip (Single-Line Guaranteed)
                HStack(spacing: 2) {
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
                                    .font(.system(size: 7.5, weight: .bold, design: .rounded))
                                    .foregroundStyle(
                                        isSelected
                                            ? .white
                                            : (isToday ? accentColor : .white.opacity(0.45))
                                    )
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)

                                Text(item.dayNumber)
                                    .font(.system(size: 12, weight: isSelected ? .bold : .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(
                                        isSelected
                                            ? .white
                                            : .white.opacity(isToday ? 0.96 : 0.76)
                                    )
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)

                                Circle()
                                    .fill(item.hasEvents ? (isSelected ? .white : accentColor) : Color.clear)
                                    .frame(width: 3, height: 3)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(
                                        isSelected
                                            ? LinearGradient(
                                                colors: [
                                                    Color(red: 0.24, green: 0.56, blue: 1.0),
                                                    Color(red: 0.16, green: 0.42, blue: 0.92)
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                            : LinearGradient(
                                                colors: [Color.clear, Color.clear],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 0)

                // Bottom Row: Full-Width Event or High-Efficiency Productivity Hub
                let dayEvents = events(on: selectedDate)
                if let primaryEvent = dayEvents.first ?? (selectedDayOffset == 0 ? calendarViewModel?.nextEvent : nil) {
                    eventDetailCard(for: primaryEvent)
                } else if compactHome {
                    VStack(spacing: 4) {
                        Image(systemName: "calendar.badge.checkmark").font(.system(size: 14))
                        Text(calendarViewModel?.authorizationStatus == .fullAccess
                             ? text("Nothing for today", "선택한 날짜에 일정 없음")
                             : text("Calendar access is off", "캘린더 접근이 꺼져 있어요"))
                            .font(.system(size: 11, weight: .medium)).lineLimit(1)
                    }.foregroundStyle(.white.opacity(0.5)).frame(maxWidth: .infinity, minHeight: 36)
                } else {
                    quickProductivityActionRow
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
        }
        }
    }

    /// The home calendar stays open and airy: month + dates above, agenda below.
    private var nookCalendar: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { selectedDayOffset = 0 }
                } label: {
                    Text(selectedDate, format: .dateTime.month(.abbreviated))
                        .font(.system(size: 30, weight: .bold))
                        .tracking(-1)
                        .foregroundStyle(.white)
                        .fixedSize()
                }
                .buttonStyle(.plain)
                .help(text("Return to today", "오늘로 돌아가기"))

                HStack(spacing: 3) {
                    ForEach(weekDays, id: \.offset) { day in
                        let selected = day.offset == selectedDayOffset
                        let weekend = Calendar.current.isDateInWeekend(day.date)
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) { selectedDayOffset = day.offset }
                        } label: {
                            VStack(spacing: 3) {
                                Text(day.weekdayShort)
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.white.opacity(selected ? 0.7 : 0.32))
                                Text(day.dayNumber.count == 1 ? "0" + day.dayNumber : day.dayNumber)
                                    .font(.system(size: selected ? 23 : 18, weight: selected ? .bold : .semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(selected ? Color.blue : weekend ? Color.red.opacity(0.55) : Color.white.opacity(0.5))
                                Circle().fill(day.hasEvents ? Color.blue : .clear)
                                    .frame(width: 3, height: 3)
                            }
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(day.date.formatted(date: .complete, time: .omitted))
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
            Group {
                if let event = events(on: selectedDate).first {
                    eventDetailCard(for: event)
                } else {
                    VStack(spacing: 5) {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.system(size: 17, weight: .medium))
                        Text(calendarViewModel?.authorizationStatus == .fullAccess
                             ? (selectedDayOffset == 0 ? text("Nothing for today", "오늘 일정 없음") : text("Nothing for this day", "이 날의 일정 없음"))
                             : text("Calendar access is off", "캘린더 접근이 꺼져 있어요"))
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
    }

    private func eventDetailCard(for event: EKEvent) -> some View {
        let title = calendarViewModel?.displayTitle(for: event) ?? event.title ?? "Event"
        let meetingURL = MeetingLink.first(url: event.url, notes: event.notes, location: event.location)

        return HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 3, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(eventTimeRangeText(for: event))
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.56))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let meetingURL {
                Button {
                    NSWorkspace.shared.open(meetingURL)
                } label: {
                    HStack(spacing: 3.5) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text(text("Join", "참여"))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue, in: Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    calendarViewModel?.openCalendarEvent()
                } label: {
                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.7)
                )
        )
    }

    private var quickProductivityActionRow: some View {
        Button(action: onSwitchToTools) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 1.0, green: 0.78, blue: 0.32))
                    .frame(width: 3, height: 22)

                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.32))

                VStack(alignment: .leading, spacing: 1) {
                    Text(text("Quick Tools Hub", "생산성 도구함"))
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(text("Timer · Calculator · Quick Notes · Dev", "타이머 · 계산기 · 빠른 메모 · 개발 도구"))
                        .font(.system(size: 8.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.38))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.055))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.7)
                    )
            )
        }
        .buttonStyle(.plain)
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
        let extraHeight: CGFloat = store.shelfExtraHeight(isIsland: false)
        return CGSize(width: max(712, baseWidth + 512), height: baseHeight + extraHeight)
    }

    func expandedDynamicIslandSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        let extraHeight: CGFloat = store.shelfExtraHeight(isIsland: true)
        return CGSize(width: max(692, baseWidth + 492), height: baseHeight + extraHeight)
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
        HStack(spacing: 8) {
            // Left Wing: Core Pillars (Nook & File Tray)
            HStack(spacing: 7) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(store.hubMode == .nook ? accentColor : .white.opacity(0.85))

                Image(systemName: "tray.fill")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle((store.hubMode == .tray || store.hubMode == .shots) ? accentColor : .white.opacity(0.85))
            }

            Spacer()

            // Right Wing: Tools & Focus Session
            HStack(spacing: 7) {
                if store.focus.timer.isActive {
                    FocusCompactView(controller: store.focus)
                }

                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(store.hubMode == .tools ? accentColor : .white.opacity(0.85))
            }
        }
        .padding(.horizontal, 14)
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

// MARK: - In-Notch Screenshot History & Fly-to-Notch Studio

struct NotchieScreenshotHubView: View {
    var screenshotViewModel: ScreenshotViewModel?
    var fileTrayViewModel: FileTrayViewModel?
    let accentColor: Color

    @State private var copiedToastID: UUID?

    private func text(_ en: String, _ ko: String) -> String {
        privacyText(en, ko)
    }

    var body: some View {
        if let vm = screenshotViewModel {
            NotchieScreenshotHubInnerView(
                viewModel: vm,
                fileTrayViewModel: fileTrayViewModel,
                accentColor: accentColor,
                copiedToastID: $copiedToastID
            )
        } else {
            Text(text("Screenshot service unavailable", "스크린샷 서비스를 불러올 수 없습니다."))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

private struct NotchieScreenshotHubInnerView: View {
    @ObservedObject var viewModel: ScreenshotViewModel
    var fileTrayViewModel: FileTrayViewModel?
    let accentColor: Color
    @Binding var copiedToastID: UUID?

    private func text(_ en: String, _ ko: String) -> String {
        privacyText(en, ko)
    }

    private var selectedScreenshot: ScreenshotModel? {
        if let id = viewModel.selectedHistoryItemID,
           let match = viewModel.history.first(where: { $0.id == id }) {
            return match
        }
        return viewModel.history.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            screenshotTopBar

            if viewModel.history.isEmpty {
                emptyHistoryPlaceholder
            } else {
                HStack(spacing: 10) {
                    if let selected = selectedScreenshot {
                        selectedScreenshotCard(selected)
                    }
                    historyFilmstrip
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
        )
    }

    private var screenshotTopBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(accentColor)
            Text(text("Screenshot History & Fly-to-Notch", "스크린샷 히스토리 · 노치 바로가기"))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))

            Text("\(viewModel.history.count)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 6)
                .padding(.vertical, 1.5)
                .background(Color.white.opacity(0.1), in: Capsule())

            Spacer()

            Button {
                viewModel.captureInteractiveScreenshot()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.viewfinder")
                        .font(.system(size: 10.5, weight: .bold))
                    Text(text("Area Capture", "영역 캡처"))
                        .font(.system(size: 10.5, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(accentColor.opacity(0.78), in: Capsule())
            }
            .buttonStyle(.plain)

            Button {
                viewModel.triggerDemoFlyToNotch()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10.5, weight: .bold))
                    Text(text("Fly-to-Notch Capture", "전체 캡처 (노치 애니메이션)"))
                        .font(.system(size: 10.5, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.12), in: Capsule())
                .overlay(Capsule().strokeBorder(accentColor.opacity(0.45), lineWidth: 0.8))
            }
            .buttonStyle(.plain)

            if !viewModel.history.isEmpty {
                Button {
                    viewModel.preloadRecentScreenshots()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .help(text("Refresh Screenshot Folder", "스크린샷 폴더 새로고침"))
            }
        }
    }

    private var emptyHistoryPlaceholder: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 68, height: 52)
                Image(systemName: "photo.badge.arrow.down.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(accentColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(text("Take a screenshot (⌘⇧3 / ⌘⇧4) to watch it fly straight into the notch!", "스크린샷(⌘⇧3 / ⌘⇧4)을 찍으면 노치로 날아 들어오며 여기에 기록됩니다."))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
                Text(text("Or click 'Fly-to-Notch Capture' above to capture your screen right now and preview the curved notch flight animation.", "상단의 '전체 캡처 (노치 애니메이션)' 버튼을 누르면 지금 바로 화면을 캡처해 노치 비행 애니메이션과 히스토리를 확인할 수 있습니다."))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        )
    }

    private func selectedScreenshotCard(_ selected: ScreenshotModel) -> some View {
        let isCopied = copiedToastID == selected.id
        let copyIcon = isCopied ? "checkmark" : "doc.on.doc.fill"
        let copyLabel = isCopied ? text("Copied", "복사됨") : text("Copy", "복사")

        return HStack(spacing: 10) {
            Image(nsImage: selected.image)
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: 126, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
                )
                .onDrag {
                    viewModel.makeItemProvider(for: selected)
                }

            VStack(alignment: .leading, spacing: 5) {
                Text(selected.fileName)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(selected.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))

                if !selected.recognizedText.isEmpty {
                    Text(selected.recognizedText.replacingOccurrences(of: "\n", with: " "))
                        .font(.system(size: 9.5))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                selectedScreenshotActionButtons(selected, copyIcon: copyIcon, copyLabel: copyLabel)
            }
        }
        .padding(8)
        .frame(width: 326, height: 112)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.8)
        )
    }

    private func selectedScreenshotActionButtons(
        _ selected: ScreenshotModel,
        copyIcon: String,
        copyLabel: String
    ) -> some View {
        HStack(spacing: 5) {
            Button {
                viewModel.copyScreenshot(selected)
                copiedToastID = selected.id
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: copyIcon)
                        .font(.system(size: 9.5, weight: .bold))
                    Text(copyLabel)
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(accentColor.opacity(0.75), in: Capsule())
            }
            .buttonStyle(.plain)

            Button {
                if let url = viewModel.existingURL(for: selected) {
                    fileTrayViewModel?.add([url])
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 9.5, weight: .semibold))
                    Text("Tray")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.88))
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)

            Button {
                viewModel.openInPreview(selected)
            } label: {
                Image(systemName: "eye.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(width: 22, height: 22)
                    .background(Color.white.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)
            .help(text("Open in Preview", "미리보기에서 열기"))

            Button {
                viewModel.revealInFinder(selected)
            } label: {
                Image(systemName: "folder.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(width: 22, height: 22)
                    .background(Color.white.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)
            .help(text("Reveal in Finder", "Finder에서 보기"))

            Button {
                viewModel.deleteFromHistory(selected)
            } label: {
                Image(systemName: "trash.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.red.opacity(0.9))
                    .frame(width: 22, height: 22)
                    .background(Color.red.opacity(0.16), in: Circle())
            }
            .buttonStyle(.plain)
            .help(text("Delete Screenshot", "스크린샷 삭제"))
        }
    }

    private var historyFilmstrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.history) { item in
                    historyThumbnailButton(item)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func historyThumbnailButton(_ item: ScreenshotModel) -> some View {
        let isSelected = selectedScreenshot?.id == item.id
        return Button {
            withAnimation(.snappy(duration: 0.18)) {
                viewModel.selectedHistoryItemID = item.id
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Image(nsImage: item.image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: 82, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(isSelected ? accentColor : Color.white.opacity(0.14), lineWidth: isSelected ? 1.8 : 0.8)
                    )

                Text(item.timestamp, style: .time)
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isSelected ? accentColor : .white.opacity(0.6))
                    .lineLimit(1)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? accentColor.opacity(0.16) : Color.white.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
        .onDrag {
            viewModel.makeItemProvider(for: item)
        }
    }
}
