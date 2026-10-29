import SwiftUI

struct ShelfWidgetDashboard: View {
    @ObservedObject var store: QuickToolsStore
    let content: (ShelfWidget) -> AnyView
    var body: some View { ShelfWidgetRow(preferences: store.shelf, content: content) }
}

private struct ShelfWidgetRow: View {
    @ObservedObject var preferences: ShelfPreferences
    let content: (ShelfWidget) -> AnyView
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(preferences.widgets) { widget in
                content(widget)
                    .frame(maxWidth: .infinity)
                    .frame(height: 136)
                    .accessibilityIdentifier("shelf.widget.\(widget.rawValue)")
            }
        }
    }
}

struct ShelfWidgetEditor: View {
    @ObservedObject var preferences: ShelfPreferences
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(privacyText("Your shelf", "나만의 위젯 선반")).font(.headline)
                    Text(privacyText("Choose three widgets and their order.", "위젯 3개와 표시 순서를 선택하세요."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(privacyText("Reset", "초기화")) { preferences.reset() }.controlSize(.small)
            }
            ForEach(Array(preferences.widgets.enumerated()), id: \.element.id) { index, widget in
                HStack(spacing: 10) {
                    Image(systemName: widget.symbol).foregroundStyle(.mint)
                        .frame(width: 28, height: 28).background(.mint.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    Picker(privacyText("Slot", "위치") + " \(index + 1)", selection: Binding(
                        get: { widget }, set: { preferences.replace(at: index, with: $0) }
                    )) {
                        ForEach(ShelfWidget.allCases) { option in Text(option.title).tag(option) }
                    }.labelsHidden()
                    Button { preferences.move(widget, by: -1) } label: { Image(systemName: "chevron.up") }
                        .disabled(index == 0).help(privacyText("Move left", "왼쪽으로 이동"))
                    Button { preferences.move(widget, by: 1) } label: { Image(systemName: "chevron.down") }
                        .disabled(index == preferences.widgets.count - 1).help(privacyText("Move right", "오른쪽으로 이동"))
                }
                .padding(8).background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            }
        }.padding(16).frame(width: 330)
            .background(Color(red: 0.085, green: 0.09, blue: 0.105))
            .environment(\.colorScheme, .dark)
    }
}

struct ShelfUtilityWidget: View {
    let widget: ShelfWidget
    @ObservedObject var store: QuickToolsStore
    var body: some View {
        Group {
            switch widget {
            case .stats: ShelfSystemStatsView(compact: true)
            case .focus: ShelfFocusWidget(controller: store.focus)
            case .notes:
                Button {
                    store.selectedTool = "notes"; store.hubMode = .tools
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(privacyText("Quick Notes", "빠른 메모"), systemImage: "note.text").foregroundStyle(.yellow)
                        Text(privacyText("Capture a thought", "떠오른 생각을 기록하세요"))
                            .font(.system(size: 16, weight: .medium))
                        Label(privacyText("Open notes", "메모 열기"), systemImage: "arrow.up.right").font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading).padding(12)
                }.buttonStyle(.plain)
            default: EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [.white.opacity(0.075), .white.opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.1), lineWidth: 0.8))
    }
}

private struct ShelfFocusWidget: View {
    @ObservedObject var controller: FocusSessionController
    var body: some View {
        VStack(spacing: 8) {
            Label(privacyText("Focus", "집중"), systemImage: "timer").font(.caption).foregroundStyle(.orange)
            Text(controller.timer.isActive ? String(format: "%02d:%02d", Int(controller.timer.remainingTime) / 60, Int(controller.timer.remainingTime) % 60) : "25:00")
                .font(.system(size: 28, weight: .medium, design: .rounded)).monospacedDigit()
            HStack {
                if controller.timer.isActive {
                    Button { controller.pauseOrResume() } label: { Image(systemName: controller.timer.state == .running ? "pause.fill" : "play.fill") }
                    Button { controller.stop() } label: { Image(systemName: "stop.fill") }
                } else if controller.phase == .readyForBreak {
                    Button(privacyText("Start break", "휴식 시작")) { controller.startBreak() }
                } else {
                    Button(privacyText("Start focus", "집중 시작")) { controller.startFocus() }
                }
            }.controlSize(.small)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ShelfSystemStatsView: View {
    @StateObject private var stats = ShelfSystemStats()
    var compact = false
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 14) {
            HStack {
                meter("CPU", value: stats.cpu, color: .purple)
                Spacer()
                meter("RAM", value: stats.memory, color: .mint)
            }
            if compact {
                HStack {
                    Label(privacyText("Live", "실시간"), systemImage: "circle.fill").foregroundStyle(.mint)
                    Spacer()
                    Text(privacyText("CPU history", "최근 CPU"))
                }.font(.system(size: 8, weight: .medium)).foregroundStyle(.secondary)
            }
            Canvas { context, size in
                guard stats.history.count > 1 else { return }
                var path = Path()
                for (index, value) in stats.history.enumerated() {
                    let point = CGPoint(x: size.width * Double(index) / Double(stats.history.count - 1), y: size.height * (1 - value))
                    if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                var fill = path
                fill.addLine(to: CGPoint(x: size.width, y: size.height))
                fill.addLine(to: CGPoint(x: 0, y: size.height)); fill.closeSubpath()
                context.fill(fill, with: .linearGradient(Gradient(colors: [.purple.opacity(0.3), .purple.opacity(0.01)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                context.stroke(path, with: .color(.purple), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            }.frame(height: compact ? 28 : 60)
            if !compact {
                Text(privacyText("Local host statistics · 2-second samples while visible. RAM = active + wired + compressed memory. First CPU sample needs a baseline.", "로컬 시스템 통계 · 화면이 열려 있을 때 2초마다 갱신합니다. RAM은 활성·와이어드·압축 메모리의 합계입니다. CPU는 첫 샘플 이후 표시됩니다."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(compact ? 10 : 14)
        .task {
            while !Task.isCancelled {
                stats.sample()
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
            }
        }
    }
    private func meter(_ title: String, value: Double?, color: Color) -> some View {
        HStack(spacing: 5) {
            ZStack {
                Circle().stroke(color.opacity(0.16), lineWidth: 3)
                Circle().trim(from: 0, to: value ?? 0).stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round)).rotationEffect(.degrees(-90))
            }.frame(width: compact ? 24 : 36, height: compact ? 24 : 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
                Text(value.map { "\(Int(($0 * 100).rounded()))%" } ?? "—")
                    .font(.system(size: compact ? 13 : 20, weight: .semibold)).monospacedDigit()
            }
        }.accessibilityElement(children: .combine)
    }
}
