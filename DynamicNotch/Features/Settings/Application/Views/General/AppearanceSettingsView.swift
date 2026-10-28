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
    
    var body: some View {
        SettingsPageScrollView {
            themeCard
            accentColorCard
        }
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

