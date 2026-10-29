//
//  NotchSettingsView.swift
//  DynamicNotch
//

import SwiftUI
internal import AppKit

struct NotchSettingsView: View {
    @ObservedObject var powerService: PowerService
    @ObservedObject var applicationSettings: ApplicationSettingsStore
    @Binding var availableDisplays: [NotchDisplayOption]

    var body: some View {
        SettingsPageScrollView {
            animationCard
            appearanceCard
            otherSettings
        }
        .accessibilityIdentifier("settings.notch.root")
        .onAppear(perform: refreshAvailableDisplays)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            refreshAvailableDisplays()
        }
    }
    
    private var animationCard: some View {
        SettingsCard(verbatimTitle: privacyText("Motion & Dynamic Island Physics", "모션 및 다이내믹 아일랜드 물리 애니메이션"), spacing: 12) {
            Picker(privacyText("Animation Style", "애니메이션 스타일"), selection: $applicationSettings.notchAnimationPreset) {
                ForEach(NotchAnimationPreset.allCases) { preset in
                    Label(preset.title, systemImage: preset.symbolName).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("settings.notch.animationPreset")

            Text(applicationSettings.notchAnimationPreset.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var appearanceCard: some View {
        SettingsCard() {

            SettingsToggleRow(
                title: "settings.notch.showStroke.title",
                description: "settings.notch.showStroke.desc",
                systemImage: "inset.filled.capsule",
                color: .black,
                stroke: true,
                isOn: $applicationSettings.isShowNotchStrokeEnabled,
                accessibilityIdentifier: "settings.general.showNotchStroke"
            )
            
            Divider().opacity(0.6)
            
            SettingsSliderRow(
                title: "settings.notch.strokeOpacity.title",
                description: "settings.notch.strokeOpacity.desc",
                range: 0...100,
                step: 5,
                fractionLength: 0,
                suffix: "%",
                accessibilityIdentifier: "settings.general.notchStrokeOpacity",
                value: Binding(
                    get: { ((applicationSettings.notchStrokeOpacity / ApplicationSettingsStore.maxNotchStrokeOpacity) * 100).rounded() },
                    set: { applicationSettings.notchStrokeOpacity = ($0 / 100) * ApplicationSettingsStore.maxNotchStrokeOpacity }
                )
            )
            
            Divider().opacity(0.6)
            
            SettingsSliderRow(
                title: "settings.notch.width.title",
                description: "settings.notch.width.desc",
                range: -10...20,
                step: 1,
                fractionLength: 0,
                suffix: "px",
                accessibilityIdentifier: "settings.general.notchWidth",
                value: Binding(
                    get: { Double(applicationSettings.notchWidth) },
                    set: { applicationSettings.notchWidth = Int($0.rounded()) }
                )
            )
            
            Divider().opacity(0.6)
            
            SettingsSliderRow(
                title: "settings.notch.height.title",
                description: "settings.notch.height.desc",
                range: -4...0,
                step: 1,
                fractionLength: 0,
                suffix: "px",
                accessibilityIdentifier: "settings.general.notchHeight",
                value: Binding(
                    get: { Double(applicationSettings.notchHeight) },
                    set: { applicationSettings.notchHeight = Int($0.rounded()) }
                )
            )
        }
    }
    
    private var otherSettings: some View {
        SettingsCard(spacing: 0, padding: 0) {
            SettingsNavigationRowView(
                title: "settings.notch.priorities.title",
                description: "settings.notch.priorities.subtitle",
                systemImage: "list.bullet",
                color: .red,
                accessibilityIdentifier: "settings.notch.priorities",
                position: .first,
                value: SettingsSubPage.activityPriorities
            )
            
            SettingsNavigationRowView(
                title: "settings.notch.display.title",
                description: "settings.notch.display.subtitle",
                systemImage: "display.2",
                color: .black,
                stroke: true,
                accessibilityIdentifier: "settings.notch.display",
                position: .middle,
                value: SettingsSubPage.notchDisplay
            )
            
            SettingsNavigationRowView(
                title: "settings.notch.gestures.navTitle",
                description: "settings.notch.gestures.subtitle",
                systemImage: "hand.draw.badge.ellipsis.fill",
                color: LinearGradient.orangeGradient,
                accessibilityIdentifier: "settings.notch.gestures",
                position: .last,
                value: SettingsSubPage.gestures
            )
        }
    }
    
    private func refreshAvailableDisplays() {
        availableDisplays = NSScreen.availableNotchDisplays()
        applicationSettings.syncPreferredDisplayMetadata()
    }
}
