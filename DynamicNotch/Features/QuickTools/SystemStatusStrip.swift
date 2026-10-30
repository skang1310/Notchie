import SwiftUI

struct SystemStatsSampling: ViewModifier {
    @ObservedObject var stats: ShelfSystemStats
    @State private var consumer = UUID()
    @State private var visible = false
    func body(content: Content) -> some View {
        content.background(PresentationVisibilityReader(isVisible: $visible).frame(width: 0, height: 0))
            .onChange(of: visible) { _, value in
                if value { stats.acquire(consumer) } else { stats.release(consumer) }
            }
            .onDisappear { stats.release(consumer) }
    }
}

struct SystemStatusStrip: View {
    @ObservedObject private var stats = ShelfSystemStats.shared
    let onOpen: () -> Void
    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 10) {
                Image(systemName: "waveform.path.ecg").foregroundStyle(.mint)
                Text("CPU " + (stats.cpu.map { String(format: "%.0f%%", $0 * 100) } ?? "—"))
                Divider().frame(height: 10)
                Text("RAM " + ShelfSystemStats.bytes(stats.usedMemoryBytes) + " / " + ShelfSystemStats.bytes(stats.totalMemoryBytes))
                Spacer(minLength: 2)
                Text("↓ " + ShelfSystemStats.rate(stats.download))
                Text("↑ " + ShelfSystemStats.rate(stats.upload))
                Image(systemName: "chevron.right").font(.system(size: 8, weight: .semibold))
            }
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain)
            .accessibilityLabel(privacyText("System usage. Open CPU, memory and network details", "시스템 사용량. CPU·메모리·네트워크 상세 열기"))
            .help(privacyText("System Usage", "시스템 사용량"))
            .modifier(SystemStatsSampling(stats: stats))
    }
}
