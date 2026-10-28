import SwiftUI
internal import AppKit

struct GeneralSettingsView: View {
    @ObservedObject var applicationSettings: ApplicationSettingsStore
    @ObservedObject var permissionController: SettingsPermissionController
    
    init(applicationSettings: ApplicationSettingsStore, permissionController: SettingsPermissionController) {
        self._applicationSettings = ObservedObject(wrappedValue: applicationSettings)
        self._permissionController = ObservedObject(wrappedValue: permissionController)
    }
    
    var body: some View {
        SettingsPageScrollView {
            quickControls
            firstCard
            secondCard
            thirdCard
        }
        .accessibilityIdentifier("settings.general.root")
    }
    
    private var quickControls: some View {
        SettingsCard(title: "settings.local.quick.title") {
            SettingsToggleRow(
                title: "settings.local.quick.idleHoverMenu.title",
                description: "settings.local.quick.idleHoverMenu.desc",
                systemImage: "menubar.dock.rectangle",
                color: .mint,
                isOn: Binding(
                    get: { applicationSettings.isIdleNotchHoverMenuEnabled },
                    set: { enabled in
                        applicationSettings.isIdleNotchHoverMenuEnabled = enabled
                        if enabled {
                            applicationSettings.isNotchTapToExpandEnabled = true
                            applicationSettings.notchExpandInteraction = .hover
                        }
                    }
                ),
                accessibilityIdentifier: "settings.general.idleHoverMenu"
            )
            Divider().opacity(0.6)
            SettingsToggleRow(
                title: "settings.local.quick.hover.title", description: "settings.local.quick.hover.desc",
                systemImage: "cursorarrow.rays", color: .blue,
                isOn: Binding(
                    get: { applicationSettings.isNotchTapToExpandEnabled && applicationSettings.notchExpandInteraction == .hover },
                    set: { enabled in
                        applicationSettings.isNotchTapToExpandEnabled = true
                        applicationSettings.notchExpandInteraction = enabled ? .hover : .click
                    }
                ),
                accessibilityIdentifier: "settings.general.quickHover"
            )
            Divider().opacity(0.6)
            SettingsToggleRow(
                title: "settings.notch.gestures.hoverHaptic.title", description: "settings.notch.gestures.hoverHaptic.desc",
                systemImage: "waveform", color: .red,
                isOn: $applicationSettings.isNotchHoverHapticEnabled,
                accessibilityIdentifier: "settings.general.quickHaptic"
            )
            Divider().opacity(0.6)
            SettingsToggleRow(
                title: "settings.local.quick.hideSource.title", description: "settings.local.quick.hideSource.desc",
                systemImage: "macwindow", color: .purple,
                isOn: $applicationSettings.isCloseAtFocusLiveActivityEnabled,
                accessibilityIdentifier: "settings.general.hideActiveMediaSource"
            )
        }
    }

    private var firstCard: some View {
        SettingsCard(spacing: 0, padding: 0) {
            SettingsNavigationRowView(
                title: "settings.general.system.title",
                description: "settings.general.system.subtitle",
                systemImage: "macbook.gen2",
                color: .gray,
                accessibilityIdentifier: "settings.general.system",
                position: .single,
                value: SettingsSubPage.system
            )
        }
    }
    
    private var secondCard: some View {
        SettingsCard(spacing: 0, padding: 0) {
            SettingsNavigationRowView(
                title: "settings.section.notch.title",
                description: "settings.section.notch.subtitle",
                systemImage: "rectangle.topthird.inset.filled",
                color: .black,
                stroke: true,
                accessibilityIdentifier: "settings.general.notch",
                position: .first,
                value: SettingsSubPage.notch
            )
            
            SettingsNavigationRowView(
                title: "settings.general.appearance.title",
                description: "settings.general.appearance.subtitle",
                systemImage: "paintbrush.fill",
                color: LinearGradient.greenGradient,
                accessibilityIdentifier: "settings.general.appearance",
                position: .middle,
                value: SettingsSubPage.appearance
            )
            
            SettingsNavigationRowView(
                title: "settings.section.language.title",
                description: "settings.section.language.subtitle",
                systemImage: "globe",
                color: .blue,
                accessibilityIdentifier: "settings.general.language",
                position: .last,
                value: SettingsSubPage.language
            )
        }
    }
    
    private var thirdCard: some View {
        SettingsCard(spacing: 0, padding: 0) {
            SettingsNavigationRowView(
                title: "settings.section.permissions.title",
                description: "settings.section.permissions.subtitle",
                systemImage: "checkmark.seal.fill",
                color: .green.opacity(0.9),
                accessibilityIdentifier: "settings.general.permissions",
                position: .first,
                value: SettingsSubPage.permissions
            )
            
            SettingsNavigationRowView(
                title: "settings.section.about.title",
                description: "settings.section.about.subtitle",
                systemImage: "info.circle.fill",
                color: .gray,
                accessibilityIdentifier: "settings.general.about",
                position: .last,
                value: SettingsSubPage.about
            )
        }
    }
}
