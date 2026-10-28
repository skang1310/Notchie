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

    @ObservedObject private var iconController = AppIconController.shared
    @ObservedObject private var messengerManager = NotchMessengerManager.shared
    @State private var showingTabCustomizer = false
    @State private var showingIconPicker = false
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
        VStack(spacing: 10) {
            topWingHeaderBar
                .frame(height: 28)

            Group {
                switch store.hubMode {
                case .nook:
                    nookThreeColumnDashboard
                case .tray, .shots:
                    trayAndShotsUnifiedContainer
                case .messages:
                    NotchieMessengerHubView(
                        manager: messengerManager,
                        accentColor: accentColor
                    )
                case .clips, .notes, .tools:
                    studioUnifiedContainer
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
                    title: "Tray",
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
                .frame(width: isNotchlessScreen ? 16 : 172)

            // Right Wing: 2 Primary Tabs (Talk | Studio) + Unified Glass Utility Rail
            HStack(spacing: 6) {
                primaryWingTabButton(
                    title: text("Talk", "톡"),
                    systemImage: "bubble.left.and.bubble.right.fill",
                    isSelected: store.hubMode == .messages,
                    badgeCount: messengerManager.unreadCount,
                    badgeIsAlert: true
                ) {
                    store.hubMode = .messages
                    messengerManager.markAllRead()
                }

                primaryWingTabButton(
                    title: text("Studio", "도구함"),
                    systemImage: "square.grid.2x2.fill",
                    isSelected: store.hubMode == .clips || store.hubMode == .notes || store.hubMode == .tools,
                    badgeCount: 0,
                    badgeIsAlert: false
                ) {
                    if store.hubMode != .clips && store.hubMode != .notes && store.hubMode != .tools {
                        store.hubMode = .clips
                    }
                }

                Spacer(minLength: 4)

                // Unified Apple Glass Utility Pill (Icon Theme · Pin · Settings)
                HStack(spacing: 2) {
                    Button {
                        showingIconPicker.toggle()
                    } label: {
                        Image(iconController.activeVariant == .light ? "NotchieIconLight" : "NotchieIconDark")
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: 15, height: 15)
                            .frame(width: 24, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(text("Switch App Icon (Light / Dark / Auto)", "앱 아이콘 선택 (라이트 / 다크 / 자동)"))
                    .popover(isPresented: $showingIconPicker, arrowEdge: .bottom) {
                        NotchieAppIconPopoverView(accentColor: accentColor)
                    }

                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 0.8, height: 12)

                    Button {
                        withAnimation(.snappy(duration: 0.18)) {
                            store.isNotchHubPinned.toggle()
                        }
                    } label: {
                        Image(systemName: store.isNotchHubPinned ? "pin.fill" : "pin")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(store.isNotchHubPinned ? accentColor : .white.opacity(0.72))
                            .frame(width: 24, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(store.isNotchHubPinned ? text("Pinned open", "노치 고정됨") : text("Pin notch open", "노치 열어두기 고정"))

                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 0.8, height: 12)

                    Button {
                        SettingsWindowController.shared.showWindow()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.75))
                            .frame(width: 24, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(text("Open Notchie Settings", "Notchie 설정 열기"))
                }
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
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(isSelected ? accentColor : .white.opacity(0.55))

                Text(title)
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.62))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(badgeIsAlert ? .black : .white)
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 1)
                        .background(
                            (badgeIsAlert ? Color(red: 0.99, green: 0.90, blue: 0.0) : accentColor.opacity(0.85)),
                            in: Capsule()
                        )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4.5)
            .background(
                ZStack {
                    if isSelected {
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.16),
                                        Color.white.opacity(0.08)
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
                    } else {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.035))
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

    // MARK: - Unified Studio Container (Clipboard · Notes · Tools)

    private var studioUnifiedContainer: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                subModeSegmentButton(
                    title: text("Clipboard", "클립보드"),
                    icon: "doc.on.clipboard.fill",
                    count: 0,
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

                subModeSegmentButton(
                    title: text("Tools", "생산성 도구"),
                    icon: "wrench.and.screwdriver.fill",
                    count: 0,
                    isSelected: store.hubMode == .tools
                ) {
                    store.hubMode = .tools
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) {
                        store.hubMode = .nook
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 9, weight: .bold))
                        Text("Nook")
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.68))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(Color.white.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            Group {
                if store.hubMode == .clips {
                    ClipboardSnippetsView()
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.045))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.8)
                                )
                        )
                } else if store.hubMode == .notes {
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
                } else {
                    panoramicToolsBrowser
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
                    .foregroundStyle(isSelected ? accentColor : .white.opacity(0.52))
                Text(title)
                    .font(.system(size: 10.5, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.62))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 0.5)
                        .background(accentColor.opacity(0.75), in: Capsule())
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.14) : Color.white.opacity(0.05))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(isSelected ? accentColor.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 0.75)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 3-Column Apple Liquid Glass Bento Dashboard (Now Playing | Calendar | Flip-Clock Weather)

    private var nookThreeColumnDashboard: some View {
        HStack(alignment: .top, spacing: 10) {
            // Bento Card 1: Now Playing Studio (210pt × 136pt)
            NotchieNowPlayingStudioColumn(
                nowPlayingViewModel: resolvedNowPlayingViewModel,
                mediaSettings: resolvedMediaSettings,
                applicationSettings: resolvedApplicationSettings,
                accentColor: accentColor,
                onOpenPlaybackSource: onOpenPlaybackSource
            )
            .frame(width: 210, height: 136)

            // Bento Card 2: 7-Day Calendar & Schedule (Flexible Center × 136pt)
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
            .frame(height: 136)

            // Bento Card 3: Flip-Clock & Weather Studio (222pt × 136pt)
            NotchieFlipClockWeatherColumn()
                .frame(width: 222, height: 136)
        }
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

            if let vm = nowPlayingViewModel {
                ObservedNowPlayingStudioBody(
                    nowPlayingViewModel: vm,
                    mediaSettings: mediaSettings,
                    applicationSettings: applicationSettings,
                    accentColor: accentColor,
                    onOpenPlaybackSource: onOpenPlaybackSource,
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
            ? locale.dn("notch.nowPlaying.nothingPlaying", fallback: "Not Playing")
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
    let onSwitchToTasks: () -> Void

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

        ZStack {
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

                // Bottom Row: Full-Width Event or Empty Schedule Pill (Never Squished)
                let dayEvents = events(on: selectedDate)
                if let primaryEvent = dayEvents.first ?? (selectedDayOffset == 0 ? calendarViewModel?.nextEvent : nil) {
                    eventDetailCard(for: primaryEvent)
                } else {
                    emptyScheduleBar
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
        }
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

    private var emptyScheduleBar: some View {
        Button {
            calendarViewModel?.openCalendarEvent()
        } label: {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.24))
                    .frame(width: 3, height: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text(text("No upcoming events today", "오늘 예정된 일정 없음"))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)

                    Text(text("Click to open Apple Calendar", "클릭하여 캘린더 열기"))
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.38))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.045))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.7)
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

// MARK: - Column 3: Flip-Clock & Weather Studio Widget (Reference Image Design)

struct NotchieForecastDay: Identifiable, Equatable {
    let id: String
    let dayTitle: String
    let weatherCode: Int
    let highTempC: Double
    let lowTempC: Double

    var formattedHighLow: String {
        String(format: "%.1f°C / %.1f°C", highTempC, lowTempC)
    }
}

struct NotchieWeatherSnapshot: Equatable {
    var conditionLabel: String
    var currentTempC: Double
    var highTempC: Double
    var lowTempC: Double
    var weatherCode: Int
    var forecastDays: [NotchieForecastDay]
    var sunriseText: String
    var sunsetText: String
    var windText: String

    var formattedCurrentTemp: String {
        String(format: "%.1f °C", currentTempC)
    }

    var formattedHighLow: String {
        String(format: "%.1f° / %.1f°", highTempC, lowTempC)
    }

    static func defaultReferenceSnapshot(now: Date = .now) -> NotchieWeatherSnapshot {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE d"

        let sampleCodes = [0, 1, 2, 0]
        let sampleHighs = [23.8, 22.8, 17.8, 17.8]
        let sampleLows = [5.5, 6.1, 6.1, 6.1]

        let days: [NotchieForecastDay] = (0..<4).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: now) ?? now
            let title = formatter.string(from: date)
            return NotchieForecastDay(
                id: "day-\(offset)",
                dayTitle: title,
                weatherCode: sampleCodes[offset],
                highTempC: sampleHighs[offset],
                lowTempC: sampleLows[offset]
            )
        }

        return NotchieWeatherSnapshot(
            conditionLabel: "Dark Sky",
            currentTempC: 21.1,
            highTempC: 23.8,
            lowTempC: 5.5,
            weatherCode: 0,
            forecastDays: days,
            sunriseText: "6:47 AM",
            sunsetText: "7:59 PM",
            windText: "W 10.8 km/h"
        )
    }

    static func conditionName(for code: Int) -> String {
        switch code {
        case 0:
            return "Dark Sky"
        case 1, 2:
            return "Partly Cloudy"
        case 3:
            return "Overcast"
        case 45, 48:
            return "Misty Fog"
        case 51, 53, 55, 61, 63, 65, 80, 81, 82:
            return "Light Rain"
        case 71, 73, 75, 77, 85, 86:
            return "Snowfall"
        case 95, 96, 99:
            return "Thunderstorm"
        default:
            return "Dark Sky"
        }
    }

    static func compassDirection(for degrees: Double) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let normalized = ((degrees.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)
        let index = Int((normalized + 22.5) / 45.0) % 8
        return directions[index]
    }
}

@MainActor
final class NotchieWeatherStore: ObservableObject {
    static let shared = NotchieWeatherStore()

    @Published private(set) var snapshot: NotchieWeatherSnapshot = .defaultReferenceSnapshot()
    @Published private(set) var isRefreshing: Bool = false
    private var lastFetchDate: Date?

    private init() {}

    func refreshIfNeeded(force: Bool = false) {
        guard !AppEnvironment.isRunningTests else { return }
        if !force, let lastFetchDate, Date().timeIntervalSince(lastFetchDate) < 900 {
            return
        }
        guard !isRefreshing else { return }
        isRefreshing = true

        guard let url = URL(
            string: "https://api.open-meteo.com/v1/forecast?latitude=37.5665&longitude=126.9780&current=temperature_2m,weather_code,wind_speed_10m,wind_direction_10m&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset&timezone=auto&forecast_days=4"
        ) else {
            isRefreshing = false
            return
        }

        Task {
            defer { self.isRefreshing = false }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return }
                if let parsed = Self.parseOpenMeteoResponse(data: data) {
                    self.snapshot = parsed
                    self.lastFetchDate = Date()
                }
            } catch {
                // Keep existing snapshot when offline
            }
        }
    }

    nonisolated static func parseOpenMeteoResponse(data: Data) -> NotchieWeatherSnapshot? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let current = root["current"] as? [String: Any],
              let daily = root["daily"] as? [String: Any] else {
            return nil
        }

        let currentTemp = (current["temperature_2m"] as? NSNumber)?.doubleValue ?? 21.1
        let currentCode = (current["weather_code"] as? NSNumber)?.intValue ?? 0
        let windSpeed = (current["wind_speed_10m"] as? NSNumber)?.doubleValue ?? 10.8
        let windDirDeg = (current["wind_direction_10m"] as? NSNumber)?.doubleValue ?? 270.0

        let dailyTimes = daily["time"] as? [String] ?? []
        let dailyCodes = (daily["weather_code"] as? [NSNumber])?.map(\.intValue) ?? []
        let dailyHighs = (daily["temperature_2m_max"] as? [NSNumber])?.map(\.doubleValue) ?? []
        let dailyLows = (daily["temperature_2m_min"] as? [NSNumber])?.map(\.doubleValue) ?? []
        let sunrises = daily["sunrise"] as? [String] ?? []
        let sunsets = daily["sunset"] as? [String] ?? []

        let inDateFormatter = DateFormatter()
        inDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        inDateFormatter.dateFormat = "yyyy-MM-dd"

        let outDayFormatter = DateFormatter()
        outDayFormatter.locale = Locale(identifier: "en_US_POSIX")
        outDayFormatter.dateFormat = "EEE d"

        var forecastDays: [NotchieForecastDay] = []
        let count = min(4, min(dailyTimes.count, min(dailyHighs.count, dailyLows.count)))
        for idx in 0..<count {
            let dateObj = inDateFormatter.date(from: dailyTimes[idx]) ?? Date()
            let dayTitle = outDayFormatter.string(from: dateObj)
            let code = idx < dailyCodes.count ? dailyCodes[idx] : currentCode
            forecastDays.append(
                NotchieForecastDay(
                    id: dailyTimes[idx],
                    dayTitle: dayTitle,
                    weatherCode: code,
                    highTempC: dailyHighs[idx],
                    lowTempC: dailyLows[idx]
                )
            )
        }

        if forecastDays.isEmpty {
            forecastDays = NotchieWeatherSnapshot.defaultReferenceSnapshot().forecastDays
        }

        let high0 = dailyHighs.first ?? 23.8
        let low0 = dailyLows.first ?? 5.5
        let sunriseText = formatSunTime(sunrises.first) ?? "6:47 AM"
        let sunsetText = formatSunTime(sunsets.first) ?? "7:59 PM"
        let compass = NotchieWeatherSnapshot.compassDirection(for: windDirDeg)
        let windText = String(format: "%@ %.1f km/h", compass, windSpeed)

        return NotchieWeatherSnapshot(
            conditionLabel: NotchieWeatherSnapshot.conditionName(for: currentCode),
            currentTempC: currentTemp,
            highTempC: high0,
            lowTempC: low0,
            weatherCode: currentCode,
            forecastDays: forecastDays,
            sunriseText: sunriseText,
            sunsetText: sunsetText,
            windText: windText
        )
    }

    nonisolated private static func formatSunTime(_ isoString: String?) -> String? {
        guard let isoString else { return nil }
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd'T'HH:mm"
        guard let date = parser.date(from: isoString) else { return nil }
        let out = DateFormatter()
        out.locale = Locale(identifier: "en_US_POSIX")
        out.dateFormat = "h:mm a"
        return out.string(from: date)
    }
}

private struct NotchieFlipClockWeatherColumn: View {
    @ObservedObject private var weatherStore = NotchieWeatherStore.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let now = context.date
            ZStack {
                // Unified 136pt Apple Liquid Glass + Brushed Slate Bento Card
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.18, green: 0.20, blue: 0.24),
                                Color(red: 0.10, green: 0.11, blue: 0.14),
                                Color(red: 0.06, green: 0.07, blue: 0.09)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.24),
                                        Color.white.opacity(0.07)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.85
                            )
                    )

                VStack(spacing: 0) {
                    topFlipClockHeroSection(now: now)
                        .frame(height: 66)

                    Rectangle()
                        .fill(Color.white.opacity(0.09))
                        .frame(height: 0.7)
                        .padding(.horizontal, 8)

                    forecastFourDayStrip
                        .frame(height: 46)

                    Rectangle()
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 0.7)
                        .padding(.horizontal, 8)

                    bottomSunWindFooter
                        .frame(height: 22)
                }
            }
        }
        .onAppear {
            weatherStore.refreshIfNeeded()
        }
    }

    @ViewBuilder
    private func topFlipClockHeroSection(now: Date) -> some View {
        let hourText = Self.hourString(from: now)
        let minuteText = Self.minuteString(from: now)
        let dayHeader = Self.shortWeekdayDayString(from: now)

        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                // Twin Split Flip-Clock Cards (HH | MM)
                HStack(spacing: 5) {
                    NotchieFlipDigitCardView(digits: hourText)
                    NotchieFlipDigitCardView(digits: minuteText)
                }
                .padding(.top, 5)

                Spacer(minLength: 0)

                // Weather info row flanking the glowing center sun orb
                HStack(alignment: .bottom, spacing: 2) {
                    VStack(alignment: .leading, spacing: 0.5) {
                        Text(weatherStore.snapshot.conditionLabel)
                            .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.76))
                            .lineLimit(1)
                        Text(weatherStore.snapshot.formattedCurrentTemp)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }

                    Spacer(minLength: 36)

                    VStack(alignment: .trailing, spacing: 0.5) {
                        Text(dayHeader)
                            .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.76))
                            .lineLimit(1)
                        Text(weatherStore.snapshot.formattedHighLow)
                            .font(.system(size: 9.0, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 5)
            }

            // Center 3D Glowing Golden Sun / Weather Illustration
            NotchieGlowingWeatherOrbView(weatherCode: weatherStore.snapshot.weatherCode, size: 28)
                .offset(y: 34)
        }
    }

    private var forecastFourDayStrip: some View {
        HStack(spacing: 0) {
            ForEach(Array(weatherStore.snapshot.forecastDays.prefix(4).enumerated()), id: \.element.id) { index, day in
                VStack(spacing: 2) {
                    Text(day.dayTitle)
                        .font(.system(size: 7.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.84))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    NotchieGlowingWeatherOrbView(weatherCode: day.weatherCode, size: 12.5)

                    Text(String(format: "%.1f°/%.1f°", day.highTempC, day.lowTempC))
                        .font(.system(size: 7.0, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .frame(maxWidth: .infinity)

                if index < 3 {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.02),
                                    Color.white.opacity(0.18),
                                    Color.white.opacity(0.02)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 0.7, height: 30)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private var bottomSunWindFooter: some View {
        HStack(spacing: 6) {
            HStack(spacing: 2.5) {
                Image(systemName: "sunrise.fill")
                    .font(.system(size: 7.5))
                    .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.28))
                Text(weatherStore.snapshot.sunriseText)
                    .font(.system(size: 7.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            HStack(spacing: 2.5) {
                Image(systemName: "sunset.fill")
                    .font(.system(size: 7.5))
                    .foregroundStyle(Color(red: 1.0, green: 0.56, blue: 0.24))
                Text(weatherStore.snapshot.sunsetText)
                    .font(.system(size: 7.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            Spacer(minLength: 2)

            Button {
                weatherStore.refreshIfNeeded(force: true)
            } label: {
                HStack(spacing: 2.5) {
                    Image(systemName: "wind")
                        .font(.system(size: 7.5, weight: .semibold))
                        .foregroundStyle(Color(red: 0.58, green: 0.82, blue: 1.0))
                    Text(weatherStore.snapshot.windText)
                        .font(.system(size: 7.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.84))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .buttonStyle(.plain)
            .help("Refresh Weather")
        }
        .padding(.horizontal, 9)
    }

    private static func hourString(from date: Date) -> String {
        let comp = Calendar.current.component(.hour, from: date)
        return String(format: "%02d", comp)
    }

    private static func minuteString(from date: Date) -> String {
        let comp = Calendar.current.component(.minute, from: date)
        return String(format: "%02d", comp)
    }

    private static func shortWeekdayDayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE d"
        return formatter.string(from: date)
    }
}

private struct NotchieFlipDigitCardView: View {
    let digits: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.98),
                            Color(white: 0.88),
                            Color(white: 0.95)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.35), lineWidth: 0.7)
                )
                .shadow(color: .black.opacity(0.38), radius: 2.5, y: 1.5)

            Text(digits)
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(white: 0.08),
                            Color(white: 0.22)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .monospacedDigit()

            // Horizontal split flip seam + side hinge notches
            VStack(spacing: 0) {
                Spacer()
                ZStack {
                    Rectangle()
                        .fill(Color.black.opacity(0.26))
                        .frame(height: 0.85)
                    HStack {
                        Rectangle()
                            .fill(Color.black.opacity(0.45))
                            .frame(width: 2.0, height: 3.0)
                        Spacer()
                        Rectangle()
                            .fill(Color.black.opacity(0.45))
                            .frame(width: 2.0, height: 3.0)
                    }
                }
                Spacer()
            }
        }
        .frame(width: 44, height: 31)
    }
}

private struct NotchieGlowingWeatherOrbView: View {
    let weatherCode: Int
    let size: CGFloat

    var body: some View {
        ZStack {
            // Warm golden outer glow matching reference screenshot
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.84, blue: 0.28).opacity(0.75),
                            Color(red: 1.0, green: 0.58, blue: 0.12).opacity(0.28),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 1,
                        endRadius: size * 0.72
                    )
                )
                .frame(width: size * 1.35, height: size * 1.35)

            // Sun rays + glowing 3D golden sphere
            Image(systemName: symbolName)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: size * 0.78, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.95, blue: 0.55),
                            Color(red: 0.98, green: 0.68, blue: 0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color(red: 1.0, green: 0.72, blue: 0.18).opacity(0.85), radius: size * 0.22)
        }
        .frame(width: size, height: size)
    }

    private var symbolName: String {
        switch weatherCode {
        case 0:
            return "sun.max.fill"
        case 1, 2:
            return "cloud.sun.fill"
        case 3:
            return "cloud.fill"
        case 45, 48:
            return "cloud.fog.fill"
        case 51, 53, 55, 61, 63, 65, 80, 81, 82:
            return "cloud.sun.rain.fill"
        case 71, 73, 75, 77, 85, 86:
            return "cloud.snow.fill"
        case 95, 96, 99:
            return "cloud.bolt.rain.fill"
        default:
            return "sun.max.fill"
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
        let extraHeight: CGFloat = store.hubMode.requiresExtendedHeight ? 210 : 172
        return CGSize(width: max(712, baseWidth + 512), height: baseHeight + extraHeight)
    }

    func expandedDynamicIslandSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        let extraHeight: CGFloat = store.hubMode.requiresExtendedHeight ? 200 : 164
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

// MARK: - In-Notch Visual App Icon Selector Popover (Dark / Light / Auto)

struct NotchieAppIconPopoverView: View {
    let accentColor: Color
    @AppStorage(GeneralSettingsStorage.Keys.appIconAppearanceStyle) private var appIconStyleRaw: String = AppIconAppearanceStyle.auto.rawValue
    @ObservedObject private var iconController = AppIconController.shared

    private var currentStyle: AppIconAppearanceStyle {
        AppIconAppearanceStyle.resolved(appIconStyleRaw)
    }

    private func text(_ en: String, _ ko: String) -> String {
        privacyText(en, ko)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(text("Notchie App Icon", "앱 아이콘 스타일 선택"))
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                Spacer()
                Text(
                    iconController.activeVariant == .light
                        ? text("Active: Light", "현재: 라이트")
                        : text("Active: Dark", "현재: 다크")
                )
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                iconOptionButton(
                    style: .auto,
                    title: text("Auto", "자동 전환"),
                    subtitle: text("Dark / Light", "다크·라이트 연동")
                )
                iconOptionButton(
                    style: .light,
                    title: text("Light", "라이트"),
                    subtitle: text("Silver Glass", "실버 아이콘")
                )
                iconOptionButton(
                    style: .dark,
                    title: text("Dark", "다크"),
                    subtitle: text("Obsidian", "다크 아이콘")
                )
            }
        }
        .padding(12)
        .frame(width: 286)
    }

    private func iconOptionButton(
        style: AppIconAppearanceStyle,
        title: String,
        subtitle: String
    ) -> some View {
        let isSelected = currentStyle == style
        return Button {
            AppIconController.shared.selectStyle(style)
        } label: {
            VStack(spacing: 6) {
                if style == .auto {
                    HStack(spacing: -10) {
                        Image("NotchieIconLight")
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: 34, height: 34)
                        Image("NotchieIconDark")
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: 34, height: 34)
                    }
                    .frame(height: 38)
                } else {
                    Image(style == .light ? "NotchieIconLight" : "NotchieIconDark")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 38, height: 38)
                }

                VStack(spacing: 1) {
                    HStack(spacing: 3) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(isSelected ? accentColor : .secondary)
                        Text(title)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                    }
                    Text(subtitle)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? accentColor.opacity(0.16) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? accentColor.opacity(0.8) : Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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

// MARK: - KakaoTalk & iMessage In-Notch Quick Reply Engine & Views

enum NotchMessengerService: String, Codable, CaseIterable, Identifiable {
    case kakaoTalk = "kakaotalk"
    case iMessage = "imessage"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kakaoTalk:
            return privacyText("KakaoTalk", "카카오톡")
        case .iMessage:
            return privacyText("iMessage", "아이메시지")
        }
    }

    var bundleIdentifier: String {
        switch self {
        case .kakaoTalk:
            return "com.kakao.KakaoTalkMac"
        case .iMessage:
            return "com.apple.MobileSMS"
        }
    }

    var brandColor: Color {
        switch self {
        case .kakaoTalk:
            return Color(red: 0.996, green: 0.898, blue: 0.0) // #FEE500 Kakao Yellow
        case .iMessage:
            return Color(red: 0.204, green: 0.780, blue: 0.349) // #34C759 iMessage Green
        }
    }

    var foregroundBadgeColor: Color {
        switch self {
        case .kakaoTalk:
            return Color(red: 0.22, green: 0.12, blue: 0.12)
        case .iMessage:
            return .white
        }
    }

    var iconName: String {
        switch self {
        case .kakaoTalk:
            return "bubble.left.and.bubble.right.fill"
        case .iMessage:
            return "message.fill"
        }
    }
}

struct SentNotchReply: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let timestamp: Date
    let deliveryNote: String
}

struct IncomingNotchMessage: Identifiable, Equatable {
    let id: UUID
    let service: NotchMessengerService
    let sender: String
    let roomOrSubtitle: String
    let body: String
    let timestamp: Date
    var chatIdentifier: String?
    var isUnread: Bool
    var isSimulated: Bool
    var sentReplies: [SentNotchReply]

    init(
        id: UUID = UUID(),
        service: NotchMessengerService,
        sender: String,
        roomOrSubtitle: String = "",
        body: String,
        timestamp: Date = Date(),
        chatIdentifier: String? = nil,
        isUnread: Bool = true,
        isSimulated: Bool = false,
        sentReplies: [SentNotchReply] = []
    ) {
        self.id = id
        self.service = service
        self.sender = sender
        self.roomOrSubtitle = roomOrSubtitle
        self.body = body
        self.timestamp = timestamp
        self.chatIdentifier = chatIdentifier
        self.isUnread = isUnread
        self.isSimulated = isSimulated
        self.sentReplies = sentReplies
    }
}

@MainActor
final class NotchMessengerManager: ObservableObject {
    static let shared = NotchMessengerManager()

    @Published private(set) var messages: [IncomingNotchMessage] = []
    @Published var selectedMessageID: UUID?
    @Published var activeBannerMessage: IncomingNotchMessage?
    @Published var draftReplyText: String = ""
    @Published var lastStatusMessage: String?

    weak var notchViewModel: NotchViewModel?
    private var monitorTimer: Timer?
    private var seenFingerprints = Set<String>()
    private var lastIMessageRowID: Int64?

    var unreadCount: Int {
        messages.filter(\.isUnread).count
    }

    private init() {
        seedWelcomePreviewMessagesIfNeeded()
    }

    func bind(notchViewModel: NotchViewModel) {
        self.notchViewModel = notchViewModel
        startMonitoringIfNeeded()
    }

    private func seedWelcomePreviewMessagesIfNeeded() {
        guard messages.isEmpty else { return }
        let kakaoSample = IncomingNotchMessage(
            service: .kakaoTalk,
            sender: privacyText("Minji Kim", "김민지"),
            roomOrSubtitle: privacyText("KakaoTalk · Direct", "카카오톡 · 1:1 채팅"),
            body: privacyText("Did you check the new Notchie OS 27 design? Reply right from the notch!", "오늘 회의 자료 확인하셨나요? 노치에서 바로 답장 테스트해보세요!"),
            timestamp: Date().addingTimeInterval(-180),
            isUnread: false,
            isSimulated: true
        )
        let imessageSample = IncomingNotchMessage(
            service: .iMessage,
            sender: privacyText("Alex Park", "박현우"),
            roomOrSubtitle: "iMessage",
            body: privacyText("On my way! Let me know when you're ready.", "지금 출발했어요! 도착하기 전에 카톡이나 아이메시지 주세요."),
            timestamp: Date().addingTimeInterval(-540),
            chatIdentifier: nil,
            isUnread: false,
            isSimulated: true
        )
        messages = [kakaoSample, imessageSample]
        selectedMessageID = kakaoSample.id
    }

    func startMonitoringIfNeeded() {
        guard !AppEnvironment.isRunningTests, monitorTimer == nil else { return }
        primeIMessageBaseline()
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pollNotificationCenterBanners()
                self?.pollIMessageDatabaseIfAuthorized()
            }
        }
    }

    func markAllRead() {
        for idx in messages.indices {
            messages[idx].isUnread = false
        }
    }

    func simulateIncomingMessage(service: NotchMessengerService) {
        let message: IncomingNotchMessage
        switch service {
        case .kakaoTalk:
            message = IncomingNotchMessage(
                service: .kakaoTalk,
                sender: privacyText("Jisoo Lee", "이지수"),
                roomOrSubtitle: privacyText("KakaoTalk · Project Team", "카카오톡 · 프로젝트 단톡방"),
                body: privacyText("Can we review the screenshot history & notch reply at 3 PM?", "노치에서 바로 카톡 답장 보내기 잘 되나요? 확인 부탁드려요! 😊"),
                timestamp: Date(),
                isUnread: true,
                isSimulated: true
            )
        case .iMessage:
            message = IncomingNotchMessage(
                service: .iMessage,
                sender: privacyText("Daniel Kang", "강다니엘"),
                roomOrSubtitle: "iMessage",
                body: privacyText("Hey! Just sent the build over AirDrop. Reply here!", "방금 파일 보냈어요! 노치에서 바로 아이메시지 답장 남겨주세요."),
                timestamp: Date(),
                chatIdentifier: nil,
                isUnread: true,
                isSimulated: true
            )
        }
        receiveIncomingMessage(message)
    }

    func receiveIncomingMessage(_ message: IncomingNotchMessage) {
        let fingerprint = "\(message.service.rawValue)|\(message.sender)|\(message.body)"
        if !message.isSimulated {
            guard !seenFingerprints.contains(fingerprint) else { return }
            seenFingerprints.insert(fingerprint)
        }

        messages.insert(message, at: 0)
        if messages.count > 30 {
            messages.removeLast(messages.count - 30)
        }
        selectedMessageID = message.id
        activeBannerMessage = message
        draftReplyText = ""

        if let notchViewModel {
            notchViewModel.pulseNotch()
            let content = MessageReplyNotchContent(manager: self, message: message)
            notchViewModel.send(.showTemporaryNotification(content, duration: 12.0))
        }
    }

    func dismissBanner() {
        activeBannerMessage = nil
        notchViewModel?.hideTemporaryNotification()
    }

    func focusNotchPanelForTyping() {
        NSApp.activate(ignoringOtherApps: true)
        if let overlayWindow = NSApp.windows.first(where: { $0 is OverlayPanelWindow }) {
            overlayWindow.makeKeyAndOrderFront(nil)
        }
    }

    func sendReply(to messageID: UUID, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let idx = messages.firstIndex(where: { $0.id == messageID }) else { return }

        let target = messages[idx]
        var deliveryNote = privacyText("Sent from Notch", "노치에서 답장 전송 완료")

        if target.isSimulated {
            deliveryNote = privacyText("Delivered (Preview Mode)", "노치 즉시 답장 완료 (미리보기)")
        } else if trySendViaNotificationCenterBanner(replyText: trimmed, service: target.service) {
            deliveryNote = privacyText("Sent via Notification Banner", "알림 배너 인라인 답장 전송 완료")
        } else if target.service == .iMessage,
                  let handle = target.chatIdentifier,
                  !handle.isEmpty,
                  trySendIMessageViaAppleScript(handle: handle, body: trimmed) {
            deliveryNote = privacyText("Sent via Messages.app", "iMessage 직접 전송 완료")
        } else {
            deliveryNote = sendViaAppActivationOrPasteboard(service: target.service, replyText: trimmed)
        }

        let reply = SentNotchReply(text: trimmed, timestamp: Date(), deliveryNote: deliveryNote)
        messages[idx].sentReplies.append(reply)
        messages[idx].isUnread = false
        if activeBannerMessage?.id == messageID {
            activeBannerMessage = messages[idx]
        }
        draftReplyText = ""
        lastStatusMessage = deliveryNote

        if activeBannerMessage?.id == messageID {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
                if self?.activeBannerMessage?.id == messageID {
                    self?.dismissBanner()
                }
            }
        }
    }

    // MARK: - Live Notification Center Inspection & Inline Reply

    private func pollNotificationCenterBanners() {
        guard AXIsProcessTrusted() else { return }
        guard let ncApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.notificationcenterui").first else {
            return
        }
        let appElement = AXUIElementCreateApplication(ncApp.processIdentifier)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else { return }

        for window in windows {
            var strings: [String] = []
            collectStrings(from: window, into: &strings, depth: 0)
            guard !strings.isEmpty else { continue }
            let joined = strings.joined(separator: " ").lowercased()

            let detectedService: NotchMessengerService?
            if joined.contains("kakaotalk") || joined.contains("카카오톡") || joined.contains("카톡") {
                detectedService = .kakaoTalk
            } else if joined.contains("messages") || joined.contains("imessage") || joined.contains("메시지") {
                detectedService = .iMessage
            } else {
                detectedService = nil
            }

            guard let service = detectedService else { continue }
            let filtered = strings.filter { str in
                let lower = str.lowercased()
                return lower != "kakaotalk" && lower != "카카오톡" && lower != "messages" && lower != "메시지" && lower != "now" && lower != "지금"
            }
            guard filtered.count >= 2 else { continue }
            let sender = filtered[0]
            let body = filtered.dropFirst().joined(separator: " ")
            let msg = IncomingNotchMessage(
                service: service,
                sender: sender,
                roomOrSubtitle: service.displayName,
                body: body,
                timestamp: Date(),
                isUnread: true,
                isSimulated: false
            )
            receiveIncomingMessage(msg)
        }
    }

    private func collectStrings(from element: AXUIElement, into results: inout [String], depth: Int) {
        guard depth < 7 else { return }
        for attr in [kAXTitleAttribute, kAXValueAttribute, kAXDescriptionAttribute] {
            var valRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, attr as CFString, &valRef) == .success,
               let str = valRef as? String {
                let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty, trimmed.count < 240, !results.contains(trimmed) {
                    results.append(trimmed)
                }
            }
        }
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                collectStrings(from: child, into: &results, depth: depth + 1)
            }
        }
    }

    private func trySendViaNotificationCenterBanner(replyText: String, service: NotchMessengerService) -> Bool {
        guard AXIsProcessTrusted(),
              let ncApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.notificationcenterui").first else {
            return false
        }
        let appElement = AXUIElementCreateApplication(ncApp.processIdentifier)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement],
              !windows.isEmpty else { return false }

        for window in windows {
            if let textField = findElement(in: window, role: kAXTextFieldRole as String, depth: 0) ??
                findElement(in: window, role: kAXTextAreaRole as String, depth: 0) {
                AXUIElementSetAttributeValue(textField, kAXFocusedAttribute as CFString, kCFBooleanTrue)
                AXUIElementSetAttributeValue(textField, kAXValueAttribute as CFString, replyText as CFTypeRef)
                AXUIElementPerformAction(textField, kAXConfirmAction as CFString)
                return true
            }
        }
        return false
    }

    private func findElement(in root: AXUIElement, role: String, depth: Int) -> AXUIElement? {
        guard depth < 8 else { return nil }
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(root, kAXRoleAttribute as CFString, &roleRef) == .success,
           let currentRole = roleRef as? String,
           currentRole == role {
            return root
        }
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(root, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                if let match = findElement(in: child, role: role, depth: depth + 1) {
                    return match
                }
            }
        }
        return nil
    }

    // MARK: - iMessage Read-Only SQLite Polling & AppleScript Reply

    private func primeIMessageBaseline() {
        let dbPath = (NSHomeDirectory() as NSString).appendingPathComponent("Library/Messages/chat.db")
        guard FileManager.default.isReadableFile(atPath: dbPath) else { return }
        if let maxID = queryLatestIMessageRowID(dbPath: dbPath) {
            lastIMessageRowID = maxID
        }
    }

    private func pollIMessageDatabaseIfAuthorized() {
        let dbPath = (NSHomeDirectory() as NSString).appendingPathComponent("Library/Messages/chat.db")
        guard FileManager.default.isReadableFile(atPath: dbPath) else { return }
        guard let baseline = lastIMessageRowID else {
            lastIMessageRowID = queryLatestIMessageRowID(dbPath: dbPath)
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        let sql = "SELECT m.ROWID, IFNULL(h.id, 'iMessage'), REPLACE(IFNULL(m.text, ''), char(10), ' ') FROM message m LEFT JOIN handle h ON m.handle_id = h.ROWID WHERE m.is_from_me = 0 AND m.ROWID > \(baseline) AND m.text IS NOT NULL AND m.text != '' ORDER BY m.ROWID ASC LIMIT 3;"
        process.arguments = ["-readonly", "-separator", "\t", dbPath, sql]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8), !output.isEmpty else { return }
            for line in output.split(separator: "\n") {
                let cols = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
                guard cols.count >= 3, let rowID = Int64(cols[0]) else { continue }
                lastIMessageRowID = max(lastIMessageRowID ?? rowID, rowID)
                let handle = cols[1]
                let text = cols[2]
                let msg = IncomingNotchMessage(
                    service: .iMessage,
                    sender: handle,
                    roomOrSubtitle: "iMessage",
                    body: text,
                    timestamp: Date(),
                    chatIdentifier: handle,
                    isUnread: true,
                    isSimulated: false
                )
                receiveIncomingMessage(msg)
            }
        } catch {}
    }

    private func queryLatestIMessageRowID(dbPath: String) -> Int64? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = ["-readonly", dbPath, "SELECT IFNULL(MAX(ROWID), 0) FROM message;"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return Int64(str)
        } catch {
            return nil
        }
    }

    private func trySendIMessageViaAppleScript(handle: String, body: String) -> Bool {
        let escapedHandle = handle.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedBody = body.replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        tell application "Messages"
            set targetService to 1st account whose service type = iMessage
            set targetBuddy to participant "\(escapedHandle)" of targetService
            send "\(escapedBody)" to targetBuddy
        end tell
        """
        guard let script = NSAppleScript(source: source) else { return false }
        var error: NSDictionary?
        _ = script.executeAndReturnError(&error)
        return error == nil
    }

    private func sendViaAppActivationOrPasteboard(service: NotchMessengerService, replyText: String) -> String {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(replyText, forType: .string)

        if let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: service.bundleIdentifier).first {
            runningApp.activate()
            if AXIsProcessTrusted() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                    Self.postPasteAndReturnKeystrokes()
                }
                return privacyText("Sent to \(service.displayName) chat window", "\(service.displayName) 대화창으로 즉시 전송 완료")
            }
            return privacyText("Copied & opened \(service.displayName) (⌘V to send)", "답장 복사 및 \(service.displayName) 열기 완료 (⌘V)")
        } else if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: service.bundleIdentifier) {
            NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
            return privacyText("Copied & launched \(service.displayName)", "답장 복사 및 \(service.displayName) 실행 완료")
        }
        return privacyText("Reply copied to clipboard", "답장이 클립보드에 복사되었습니다")
    }

    private static func postPasteAndReturnKeystrokes() {
        let src = CGEventSource(stateID: .combinedSessionState)
        // Cmd + V (keyCode 9)
        if let vDown = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: true),
           let vUp = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: false) {
            vDown.flags = .maskCommand
            vUp.flags = .maskCommand
            vDown.post(tap: .cghidEventTap)
            vUp.post(tap: .cghidEventTap)
        }
        // Return (keyCode 36)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            if let retDown = CGEvent(keyboardEventSource: src, virtualKey: 36, keyDown: true),
               let retUp = CGEvent(keyboardEventSource: src, virtualKey: 36, keyDown: false) {
                retDown.post(tap: .cghidEventTap)
                retUp.post(tap: .cghidEventTap)
            }
        }
    }
}

// MARK: - Live Notch Content for Incoming KakaoTalk / iMessage Quick Reply

struct MessageReplyNotchContent: NotchContentProtocol {
    let id = "local.messenger.quickReply"
    let manager: NotchMessengerManager
    let message: IncomingNotchMessage

    var priority: Int { 92 }
    var isExpandable: Bool { true }
    var shouldAutoExpandOnAppear: Bool { true }
    var pinsExpandedInteraction: Bool { true }
    var strokeColor: Color {
        message.service.brandColor.opacity(0.55)
    }

    func compactSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        CGSize(width: baseWidth + 240, height: baseHeight + 98)
    }

    func expandedSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        CGSize(width: max(520, baseWidth + 320), height: baseHeight + 128)
    }

    func compactCornerRadius(baseRadius: CGFloat) -> (top: CGFloat, bottom: CGFloat) {
        (top: 19, bottom: 26)
    }

    func expandedCornerRadius(baseRadius: CGFloat) -> (top: CGFloat, bottom: CGFloat) {
        (top: 19, bottom: 26)
    }

    @MainActor
    func compactView() -> AnyView {
        AnyView(MessageReplyNotchBannerView(manager: manager, message: message))
    }

    @MainActor
    func expandedView() -> AnyView {
        AnyView(MessageReplyNotchBannerView(manager: manager, message: message))
    }
}

struct MessageReplyNotchBannerView: View {
    @ObservedObject var manager: NotchMessengerManager
    let message: IncomingNotchMessage
    @State private var replyText: String = ""
    @FocusState private var isReplyFocused: Bool

    private func text(_ en: String, _ ko: String) -> String {
        privacyText(en, ko)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer(minLength: 24)

            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(message.service.brandColor)
                        .frame(width: 34, height: 34)
                    Image(systemName: message.service.iconName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(message.service.foregroundBadgeColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(message.sender)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                        Text(message.service.displayName)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(message.service.foregroundBadgeColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(message.service.brandColor, in: Capsule())
                        Spacer()
                        Button {
                            manager.dismissBanner()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        .buttonStyle(.plain)
                    }

                    Text(message.body)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(1)
                }
            }

            HStack(spacing: 6) {
                TextField(
                    text("Reply directly from notch…", "노치에서 바로 답장 입력… (Enter 전송)"),
                    text: $replyText
                )
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .focused($isReplyFocused)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.1), in: Capsule())
                .overlay(Capsule().strokeBorder(message.service.brandColor.opacity(0.65), lineWidth: 1))
                .onTapGesture {
                    manager.focusNotchPanelForTyping()
                    isReplyFocused = true
                }
                .onSubmit {
                    guard !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    manager.sendReply(to: message.id, text: replyText)
                    replyText = ""
                }

                ForEach([text("Got it 👍", "확인했어요 👍"), text("One sec!", "잠시만요!")], id: \.self) { chip in
                    Button {
                        manager.sendReply(to: message.id, text: chip)
                    } label: {
                        Text(chip)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.1), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    manager.sendReply(to: message.id, text: replyText)
                    replyText = ""
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 10.5, weight: .bold))
                        Text(text("Send", "전송"))
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(message.service.foregroundBadgeColor)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(message.service.brandColor, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 12)
        .onAppear {
            manager.focusNotchPanelForTyping()
        }
    }
}

// MARK: - In-Notch KakaoTalk & iMessage Quick Reply Studio (Talk Tab)

struct NotchieMessengerHubView: View {
    @ObservedObject var manager: NotchMessengerManager
    let accentColor: Color
    @FocusState private var isInputFocused: Bool

    private func text(_ en: String, _ ko: String) -> String {
        privacyText(en, ko)
    }

    private var selectedMessage: IncomingNotchMessage? {
        if let id = manager.selectedMessageID,
           let found = manager.messages.first(where: { $0.id == id }) {
            return found
        }
        return manager.messages.first
    }

    private var quickReplyChips: [String] {
        [
            text("Got it 👍", "확인했어요 👍"),
            text("One moment!", "잠시만요!"),
            text("In a meeting, will text soon", "회의 중이라 곧 연락드릴게요"),
            text("Thank you!", "감사합니다 😊")
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            // Top bar
            HStack(spacing: 8) {
                Image(systemName: "message.badge.filled.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 0.996, green: 0.898, blue: 0.0))
                Text(text("KakaoTalk & iMessage Quick Reply", "카카오톡 · 아이메시지 노치 즉시 답장"))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))

                if let status = manager.lastStatusMessage {
                    Text(status)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(accentColor.opacity(0.16), in: Capsule())
                }

                Spacer()

                Button {
                    manager.simulateIncomingMessage(service: .kakaoTalk)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(text("Test KakaoTalk Banner", "카톡 도착 테스트"))
                            .font(.system(size: 10.5, weight: .bold))
                    }
                    .foregroundStyle(Color(red: 0.22, green: 0.12, blue: 0.12))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.996, green: 0.898, blue: 0.0), in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    manager.simulateIncomingMessage(service: .iMessage)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(text("Test iMessage Banner", "iMessage 도착 테스트"))
                            .font(.system(size: 10.5, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.204, green: 0.780, blue: 0.349), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                // Left column: Recent KakaoTalk / iMessage list
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 5) {
                        ForEach(manager.messages) { msg in
                            let isSelected = selectedMessage?.id == msg.id
                            Button {
                                manager.selectedMessageID = msg.id
                                manager.focusNotchPanelForTyping()
                            } label: {
                                HStack(spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(msg.service.brandColor)
                                            .frame(width: 24, height: 24)
                                        Image(systemName: msg.service.iconName)
                                            .font(.system(size: 10.5, weight: .bold))
                                            .foregroundStyle(msg.service.foregroundBadgeColor)
                                    }

                                    VStack(alignment: .leading, spacing: 1.5) {
                                        HStack {
                                            Text(msg.sender)
                                                .font(.system(size: 11.5, weight: .bold))
                                                .foregroundStyle(.white)
                                                .lineLimit(1)
                                            Spacer()
                                            Text(msg.timestamp, style: .time)
                                                .font(.system(size: 9, design: .monospaced))
                                                .foregroundStyle(.white.opacity(0.45))
                                        }
                                        Text(msg.body)
                                            .font(.system(size: 10.5))
                                            .foregroundStyle(.white.opacity(0.68))
                                            .lineLimit(1)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(isSelected ? Color.white.opacity(0.14) : Color.white.opacity(0.04))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(isSelected ? msg.service.brandColor.opacity(0.75) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(width: 215)

                // Right column: Selected conversation + inline reply input
                if let current = selectedMessage {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text(current.sender)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                            Text(current.roomOrSubtitle.isEmpty ? current.service.displayName : current.roomOrSubtitle)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(current.service.foregroundBadgeColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1.5)
                                .background(current.service.brandColor, in: Capsule())
                            Spacer()
                        }

                        Text(current.body)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(2)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                        if let lastReply = current.sentReplies.last {
                            HStack(spacing: 5) {
                                Image(systemName: "arrowshape.turn.up.left.fill")
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(accentColor)
                                Text("\(text("Replied:", "내 답장:")) \(lastReply.text)")
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .foregroundStyle(accentColor)
                                    .lineLimit(1)
                                Spacer()
                                Text(lastReply.deliveryNote)
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(.white.opacity(0.45))
                                    .lineLimit(1)
                            }
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 5) {
                                    ForEach(quickReplyChips, id: \.self) { chip in
                                        Button {
                                            manager.sendReply(to: current.id, text: chip)
                                        } label: {
                                            Text(chip)
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundStyle(.white.opacity(0.86))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3.5)
                                                .background(Color.white.opacity(0.08), in: Capsule())
                                                .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.7))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        Spacer(minLength: 0)

                        HStack(spacing: 6) {
                            TextField(
                                text("Type a reply to send from the notch…", "\(current.sender)님에게 노치에서 바로 답장 입력…"),
                                text: $manager.draftReplyText
                            )
                            .textFieldStyle(.plain)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.white)
                            .focused($isInputFocused)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5.5)
                            .background(Color.white.opacity(0.09), in: Capsule())
                            .overlay(Capsule().strokeBorder(current.service.brandColor.opacity(0.6), lineWidth: 0.9))
                            .onTapGesture {
                                manager.focusNotchPanelForTyping()
                                isInputFocused = true
                            }
                            .onSubmit {
                                guard !manager.draftReplyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                                manager.sendReply(to: current.id, text: manager.draftReplyText)
                            }

                            Button {
                                manager.sendReply(to: current.id, text: manager.draftReplyText)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 10, weight: .bold))
                                    Text(text("Send", "답장 전송"))
                                        .font(.system(size: 10.5, weight: .bold))
                                }
                                .foregroundStyle(current.service.foregroundBadgeColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5.5)
                                .background(current.service.brandColor, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(manager.draftReplyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.8)
                    )
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
}
