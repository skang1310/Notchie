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
            SettingsFeatureHeader(
                title: privacyText("Make Notchie yours", "나에게 맞는 Notchie"),
                subtitle: privacyText("Appearance, interaction and app preferences in one place.", "모양과 사용 방식, 앱 환경을 한곳에서 설정하세요."),
                symbol: "slider.horizontal.3", status: privacyText("Preferences", "환경설정"), active: true
            )
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
                title: "settings.section.about.title",
                description: "settings.section.about.subtitle",
                systemImage: "info.circle.fill",
                color: .gray,
                accessibilityIdentifier: "settings.general.about",
                position: .single,
                value: SettingsSubPage.about
            )
        }
    }
}
