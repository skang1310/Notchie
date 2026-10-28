import SwiftUI

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
        VStack(spacing: 10) {
            notchNookTabBar

            if !inNotch {
                customizableTabsCard
            }

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
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !inNotch {
                HStack {
                    Button("settings.tools.openNotch") {
                        NotificationCenter.default.post(name: .showQuickToolsInNotch, object: nil)
                    }
                    .accessibilityIdentifier("settings.tools.openNotch")
                    Spacer()
                }
            }
        }
        .padding(.horizontal, inNotch ? 18 : 20)
        .padding(.top, inNotch ? 28 : 16)
        .padding(.bottom, inNotch ? 14 : 16)
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
                tabCustomizerPopover
            }

            if inNotch {
                Button {
                    store.isNotchHubPinned.toggle()
                } label: {
                    Image(systemName: store.isNotchHubPinned ? "pin.fill" : "pin")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(store.isNotchHubPinned ? accentColor : .secondary)
                        .frame(width: 26, height: 26)
                        .background(
                            (store.isNotchHubPinned ? accentColor.opacity(0.2) : Color.primary.opacity(0.08)),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .help(store.isNotchHubPinned ? text("Pinned open", "노치 메뉴 고정됨") : text("Pin menu open", "노치 메뉴 고정"))

                Button {
                    store.isNotchHubPinned = false
                    NotificationCenter.default.post(name: .closeQuickToolsInNotch, object: nil)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .background(Color.primary.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .help(L10n.app("productivity.returnAutomatic"))
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

    private var tabCustomizerPopover: some View {
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
        ApplicationSettingsStore.currentCustomAccentColor().opacity(0.42)
    }
    @MainActor func compactView() -> AnyView {
        AnyView(QuickToolsCompactView(store: store))
    }
    @MainActor func expandedView() -> AnyView { AnyView(QuickToolsView(store: store, inNotch: true)) }
    func compactSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize { CGSize(width: baseWidth + 90, height: baseHeight) }
    func expandedSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize { CGSize(width: max(540, baseWidth + 240), height: baseHeight + 370) }
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
