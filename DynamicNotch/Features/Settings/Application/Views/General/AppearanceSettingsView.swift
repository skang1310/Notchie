//
//  AppearanceSettingsView.swift
//  DynamicNotch
//
//  Created by Евгений Петрукович on 7/13/26.
//

import SwiftUI

struct AppearanceSettingsView: View {
    @ObservedObject var applicationSettings: ApplicationSettingsStore
    @Environment(\.colorScheme) private var colorScheme
    
    private let accentPresets: [(name: String, hex: String)] = [
        ("Green", "#34C759"),
        ("Mint", "#00C7BE"),
        ("Blue", "#007AFF"),
        ("Indigo", "#5856D6"),
        ("Purple", "#AF52DE"),
        ("Pink", "#FF2D55"),
        ("Orange", "#FF9500"),
        ("Gold", "#FFCC00")
    ]
    
    private func text(_ en: String, _ ko: String) -> String {
        privacyText(en, ko)
    }
    
    @ObservedObject private var iconController = AppIconController.shared

    var body: some View {
        SettingsPageScrollView {
            shelfFinishCard
            themeCard
            appIconStyleCard
            accentColorCard
        }
    }

    private var shelfFinishCard: some View {
        SettingsCard(verbatimTitle: text("Shelf finish", "선반 표면"), spacing: 12) {
            Picker(text("Material", "재질"), selection: $applicationSettings.notchBackgroundStyle) {
                ForEach(NotchBackgroundStyle.allCases, id: \.self) { style in
                    Label(style.title, systemImage: style.symbolName).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("shelf.finish")
            Text(text("Dynamic Glass blends the black camera area into glass. Liquid Glass stays translucent. Reduce Transparency uses a solid surface.", "다이내믹 글래스는 검은 카메라 영역에서 유리로 이어집니다. 리퀴드 글래스는 반투명하게 표시되며, 투명도 줄이기를 켜면 불투명 표면을 사용합니다."))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var appIconStyleCard: some View {
        SettingsCard(verbatimTitle: text("App Icon Style (Dark & Light Mode)", "앱 아이콘 스타일 (다크 / 라이트 모드 연동)"), spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(text("Dynamic App Icon", "다크/라이트 모드에 따라 앱 아이콘 변경"))
                        .font(.system(size: 13.5, weight: .semibold))
                    Text(text("Automatically switches between Notchie Light and Dark icons based on system/app appearance, or pins your preferred icon.", "시스템/앱의 다크·라이트 테마에 맞춰 앱 아이콘을 자동으로 바꾸거나 원하는 아이콘으로 고정할 수 있습니다."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 5) {
                    Circle()
                        .fill(applicationSettings.customAccentColor)
                        .frame(width: 7, height: 7)
                    Text(
                        iconController.activeVariant == .light
                            ? text("Active: Light", "현재 적용: 라이트 아이콘")
                            : text("Active: Dark", "현재 적용: 다크 아이콘")
                    )
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.06), in: Capsule())
            }

            HStack(spacing: 12) {
                appIconOptionCard(
                    style: .auto,
                    title: text("Auto (Dark / Light)", "자동 (다크/라이트 연동)"),
                    subtitle: text("Follows theme automatically", "테마에 따라 자동 전환")
                )
                appIconOptionCard(
                    style: .light,
                    title: text("Notchie Light", "라이트 아이콘"),
                    subtitle: text("Bright silver-glass icon", "밝은 실버 글래스 아이콘")
                )
                appIconOptionCard(
                    style: .dark,
                    title: text("Notchie Dark", "다크 아이콘"),
                    subtitle: text("Obsidian carbon icon", "옵시디언 다크 아이콘")
                )
            }
        }
    }

    private func appIconOptionCard(
        style: AppIconAppearanceStyle,
        title: String,
        subtitle: String
    ) -> some View {
        let isSelected = applicationSettings.appIconAppearanceStyle == style
        let accent = applicationSettings.customAccentColor
        return Button {
            withAnimation(.snappy(duration: 0.22)) {
                applicationSettings.appIconAppearanceStyle = style
                AppIconController.shared.refreshIcon()
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    if style == .auto {
                        HStack(spacing: -14) {
                            Image("NotchieIconLight")
                                .resizable()
                                .interpolation(.high)
                                .scaledToFit()
                                .frame(width: 48, height: 48)
                            Image("NotchieIconDark")
                                .resizable()
                                .interpolation(.high)
                                .scaledToFit()
                                .frame(width: 48, height: 48)
                        }
                        .frame(height: 54)
                    } else {
                        Image(style == .light ? "NotchieIconLight" : "NotchieIconDark")
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: 54, height: 54)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 6)

                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(isSelected ? accent : .secondary)
                        Text(title)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                    }
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? accent.opacity(0.14) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? accent.opacity(0.85) : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.appearance.appIcon.\(style.rawValue)")
    }
    
    private var accentColorCard: some View {
        SettingsCard(verbatimTitle: text("Accent Color & Notch Tint", "강조 색상 (Accent Color) 및 노치 틴트"), spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(text("Custom Accent Color", "맞춤 강조 색상"))
                        .font(.system(size: 13.5, weight: .semibold))
                    Text(text("Applied to the Notch Hover Hub tabs, Face Unlock scan animation, and active indicators.", "노치 호버 메뉴 탭, 얼굴 잠금 해제 스캔 애니메이션 및 활성 배지에 적용됩니다."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(applicationSettings.customAccentColorHex)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                ColorPicker(
                    text("Custom Color", "직접 선택"),
                    selection: Binding(
                        get: { applicationSettings.customAccentColor },
                        set: { applicationSettings.customAccentColor = $0 }
                    ),
                    supportsOpacity: false
                )
                .labelsHidden()
                .accessibilityIdentifier("settings.appearance.customAccentPicker")
            }
            
            Divider().opacity(0.6)
            
            HStack(spacing: 10) {
                ForEach(accentPresets, id: \.hex) { preset in
                    let isSelected = applicationSettings.customAccentColorHex.caseInsensitiveCompare(preset.hex) == .orderedSame
                    let color = ApplicationSettingsStore.color(fromHex: preset.hex) ?? .green
                    Button {
                        applicationSettings.customAccentColorHex = preset.hex
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 24, height: 24)
                            .overlay {
                                Circle()
                                    .strokeBorder(Color.white.opacity(isSelected ? 0.95 : 0.2), lineWidth: isSelected ? 2.5 : 1)
                            }
                            .shadow(color: color.opacity(isSelected ? 0.55 : 0.0), radius: 4)
                    }
                    .buttonStyle(.plain)
                    .help(preset.name)
                }
                Spacer()
            }
        }
    }
    
    private var themeCard: some View {
        SettingsCard() {
            CustomPicker(
                selection: $applicationSettings.appearanceMode,
                options: Array(SettingsAppearanceMode.allCases),
                title: { $0.title },
                headerTitle: "settings.appearance.theme.headerTitle",
                headerDescription: "settings.appearance.theme.headerDesc",
                itemHeight: 110,
                lightBackgroundImage: Image("backgroundLight"),
                darkBackgroundImage: Image("backgroundDark")
            ) { mode, isSelected in
                ThemeAppearancePickerContent(mode: mode, isSelected: isSelected)
            }
            .accessibilityIdentifier("settings.general.appearanceMode")
            
            if isCurrentlyDark {
                Divider().opacity(0.6)
                
                SettingsToggleRow(
                    title: "settings.general.blueNightMode.title",
                    description: "settings.general.blueNightMode.description",
                    systemImage: "powersleep",
                    color: LinearGradient.darkBlueGradient,
                    iconBadge: false,
                    isOn: $applicationSettings.isBlueNightMode,
                    accessibilityIdentifier: "settings.general.blueNightMode"
                )
            }
        }
    }
    
    private var isCurrentlyDark: Bool {
        switch applicationSettings.appearanceMode {
        case .dark:
            return true
        case .system:
            return colorScheme == .dark
        case .light:
            return false
        }
    }
}

private struct ThemeAppearancePickerContent: View {
    let mode: SettingsAppearanceMode
    let isSelected: Bool
    
    var body: some View {
        themePreview
    }
    
    @ViewBuilder
    private var themePreview: some View {
        switch mode {
        case .system:
            ZStack {
                ThemeMiniWindow(style: .light)
                    .frame(width: 100, height: 80)
                    .offset(x: -15)
                
                ThemeMiniWindow(style: .dark)
                    .frame(width: 100, height: 80)
                    .offset(x: 15)
            }
            
        case .light:
            ThemeMiniWindow(style: .light)
                .frame(width: 110, height: 80)
            
        case .dark:
            ThemeMiniWindow(style: .dark)
                .frame(width: 110, height: 80)
        }
    }
}

private struct ThemeMiniWindow: View {
    enum Style {
        case light
        case dark
        
        var background: Color {
            switch self {
            case .light:
                return Color(red: 0.985, green: 0.988, blue: 0.995)
            case .dark:
                return Color(red: 0.087, green: 0.098, blue: 0.118)
            }
        }
        
        var chrome: Color {
            switch self {
            case .light:
                return Color(red: 0.94, green: 0.95, blue: 0.972)
            case .dark:
                return Color(red: 0.118, green: 0.129, blue: 0.157)
            }
        }
        
        var sidebar: Color {
            switch self {
            case .light:
                return Color(red: 0.925, green: 0.937, blue: 0.962)
            case .dark:
                return Color(red: 0.102, green: 0.113, blue: 0.139)
            }
        }
        
        var surface: Color {
            switch self {
            case .light:
                return Color.gray.opacity(0.2)
            case .dark:
                return Color(red: 0.145, green: 0.161, blue: 0.196)
            }
        }
        
        var accent: Color {
            switch self {
            case .light:
                return Color(red: 0.29, green: 0.54, blue: 0.98)
            case .dark:
                return Color(red: 0.37, green: 0.67, blue: 1.0)
            }
        }
        
        var primary: Color {
            switch self {
            case .light:
                return Color.black.opacity(0.72)
            case .dark:
                return Color.white.opacity(0.84)
            }
        }
        
        var secondary: Color {
            switch self {
            case .light:
                return Color.black.opacity(0.26)
            case .dark:
                return Color.white.opacity(0.24)
            }
        }
        
        var stroke: Color {
            switch self {
            case .light:
                return Color.black.opacity(0.08)
            case .dark:
                return Color.white.opacity(0.08)
            }
        }
        
        var shadow: Color {
            switch self {
            case .light:
                return Color.black.opacity(0.08)
            case .dark:
                return Color.black.opacity(0.32)
            }
        }
    }
    
    let style: Style
    
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        
        shape
            .fill(style.background)
            .overlay {
                VStack(spacing: 0) {
                    chromeBar
                    
                    HStack(spacing: 0) {
                        sidebar
                        content
                    }
                }
                .clipShape(shape)
            }
            .overlay {
                shape.stroke(style.stroke, lineWidth: 1)
            }
            .shadow(color: style.shadow, radius: 10, y: 4)
    }
    
    private var chromeBar: some View {
        HStack(alignment: .center) {
            HStack(spacing: 3) {
                Circle().fill(Color.red.opacity(style == .light ? 0.9 : 0.75))
                Circle().fill(Color.orange.opacity(style == .light ? 0.9 : 0.75))
                Circle().fill(Color.green.opacity(style == .light ? 0.9 : 0.75))
            }
            .frame(width: 20, height: 6)
            
            Spacer()
        }
        .padding(.horizontal, 6)
        .frame(height: 14)
        .background(style.chrome)
    }
    
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 5) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(style.secondary)
                .frame(width: 14, height: 4)
            
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(style.accent.opacity(0.8))
                .frame(width: 14, height: 4)
            
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(style.secondary)
                .frame(width: 14, height: 4)
            
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(style.secondary)
                .frame(width: 14, height: 4)
            
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(style.secondary)
                .frame(width: 14, height: 4)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 7)
        .frame(width: 26)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(style.sidebar)
    }
    
    private var content: some View {
        VStack(alignment: .leading, spacing: 5) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(style.primary.opacity(0.76))
                .frame(width: 24, height: 5)
            
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(style.accent.opacity(style == .light ? 0.14 : 0.22))
                .overlay(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(style.accent)
                        .frame(width: 14, height: 6)
                        .padding(4)
                }
                .frame(height: 20)
            
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(style.surface)
                
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(style.surface)
            }
            .frame(height: 13)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(style.background)
    }
}

