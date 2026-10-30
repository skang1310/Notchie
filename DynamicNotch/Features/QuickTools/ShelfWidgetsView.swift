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

struct ShelfSystemStatsView: View {
    @ObservedObject private var stats = ShelfSystemStats.shared
    var compact = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
            }.frame(height: compact ? 28 : 40)
            if !compact {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("↓ " + ShelfSystemStats.rate(stats.download))
                        Text("↑ " + ShelfSystemStats.rate(stats.upload))
                    }
                    Canvas { context, size in
                        guard stats.networkHistory.count > 1 else { return }
                        let peak = max(1, stats.networkHistory.max() ?? 1)
                        var path = Path()
                        for (index, value) in stats.networkHistory.enumerated() {
                            let point = CGPoint(x: size.width * Double(index) / Double(stats.networkHistory.count - 1), y: size.height * (1 - value / peak))
                            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                        }
                        context.stroke(path, with: .color(.mint), lineWidth: 1.5)
                    }.frame(height: 30).accessibilityLabel(privacyText("Recent download throughput", "최근 다운로드 전송량"))
                }.font(.system(size: 11, design: .monospaced))
                HStack {
                    Text(privacyText("Memory", "메모리") + " " + ShelfSystemStats.bytes(stats.usedMemoryBytes) + " / " + ShelfSystemStats.bytes(stats.totalMemoryBytes))
                    Spacer()
                    Text(privacyText("Swap", "스왑") + " " + ShelfSystemStats.bytes(stats.swapBytes))
                }.font(.system(size: 10))
                HStack {
                    Text(privacyText("Memory pressure", "메모리 압력") + ": " + pressureText)
                    Spacer()
                    Text(privacyText("Disk free", "디스크 여유") + " " + ShelfSystemStats.bytes(stats.freeDiskBytes.flatMap { $0 >= 0 ? UInt64($0) : nil }))
                }.font(.system(size: 10)).foregroundStyle(.secondary)
                Text(privacyText("2-second visible samples · RAM: active + wired + compressed. Network: active en* interfaces, excluding duplicate VPN/tunnel counters. First sample needs a baseline.", "화면 표시 중 2초 간격 · RAM: 활성+와이어드+압축. 네트워크: 활성 en* 인터페이스 합계, VPN·터널 중복 제외. 첫 샘플은 기준값 수집입니다."))
                    .font(.system(size: 8)).foregroundStyle(.secondary)
            }
        }
        .padding(compact ? 10 : 14)
        .modifier(SystemStatsSampling(stats: stats))
    }
    private var pressureText: String {
        switch stats.pressure {
        case 1: return privacyText("Normal", "정상")
        case 2: return privacyText("Warning", "주의")
        case 4: return privacyText("Critical", "높음")
        default: return "—"
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
