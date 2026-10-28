import SwiftUI

/// Use glass for prominent actions; content surfaces stay quiet and opaque.
struct SettingsPrimaryAction: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *), !reduceTransparency, contrast != .increased {
            content.buttonStyle(.glassProminent)
        } else {
            content.buttonStyle(.borderedProminent)
        }
    }
}
struct SettingsSecondaryAction: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *), !reduceTransparency, contrast != .increased {
            content.buttonStyle(.glass)
        } else {
            content.buttonStyle(.bordered)
        }
    }
}
struct SettingsFeatureHeader: View {
    let title: String
    let subtitle: String
    let symbol: String
    let status: String
    let active: Bool
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 54, height: 54)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.title2.weight(.semibold))
                Text(subtitle).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Label(status, systemImage: active ? "checkmark.circle.fill" : "circle.dotted")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(active ? Color.green : Color.secondary)
            }
            Spacer(minLength: 0)
        }.padding(.horizontal, 10).padding(.vertical, 6)
    }
}
struct SettingsPreferenceRow<Control: View>: View {
    let title: String
    let detail: String
    private let control: Control
    init(_ title: String, detail: String, @ViewBuilder control: () -> Control) {
        self.title = title; self.detail = detail; self.control = control()
    }
    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.body.weight(.medium))
                if !detail.isEmpty {
                    Text(detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            control.fixedSize(horizontal: true, vertical: false)
        }.padding(.vertical, 5)
    }
}
