//
//  MenuBarMenu.swift
//  DynamicNotch
//
//  Created by Евгений Петрукович on 9/1/26.
//

import SwiftUI

struct MenuBarMenu: View {
    @AppStorage(GeneralSettingsStorage.Keys.appLanguage) private var appLanguageRaw: String = DynamicNotchLanguage.system.rawValue
    @AppStorage(GeneralSettingsStorage.Keys.appIconAppearanceStyle) private var appIconStyleRaw: String = AppIconAppearanceStyle.auto.rawValue

    private var locale: Locale {
        DynamicNotchLanguage.resolved(appLanguageRaw).locale
    }

    private var currentIconStyle: AppIconAppearanceStyle {
        AppIconAppearanceStyle.resolved(appIconStyleRaw)
    }

    private func menuIconPreview(named name: String) -> NSImage {
        let base = NSImage(named: name) ?? NSApp.applicationIconImage ?? NSImage()
        let copy = (base.copy() as? NSImage) ?? base
        copy.size = NSSize(width: 18, height: 18)
        copy.isTemplate = false
        return copy
    }
    
    var body: some View {
        Group {
            Menu {
                Button {
                    AppIconController.shared.selectStyle(.auto)
                } label: {
                    Image(nsImage: menuIconPreview(named: AppIconController.shared.activeVariant == .light ? "NotchieIconLight" : "NotchieIconDark"))
                    Text(currentIconStyle == .auto
                         ? privacyText("✓ Auto (Dark / Light Mode)", "✓ 자동 전환 (다크 / 라이트 모드)")
                         : privacyText("Auto (Dark / Light Mode)", "자동 전환 (다크 / 라이트 모드)"))
                }

                Button {
                    AppIconController.shared.selectStyle(.light)
                } label: {
                    Image(nsImage: menuIconPreview(named: "NotchieIconLight"))
                    Text(currentIconStyle == .light
                         ? privacyText("✓ Notchie Light Icon", "✓ 라이트 아이콘 (Light)")
                         : privacyText("Notchie Light Icon", "라이트 아이콘 (Light)"))
                }

                Button {
                    AppIconController.shared.selectStyle(.dark)
                } label: {
                    Image(nsImage: menuIconPreview(named: "NotchieIconDark"))
                    Text(currentIconStyle == .dark
                         ? privacyText("✓ Notchie Dark Icon", "✓ 다크 아이콘 (Dark)")
                         : privacyText("Notchie Dark Icon", "다크 아이콘 (Dark)"))
                }
            } label: {
                Image(nsImage: menuIconPreview(named: AppIconController.shared.activeVariant == .light ? "NotchieIconLight" : "NotchieIconDark"))
                Text(privacyText("App Icon (Light / Dark)", "앱 아이콘 선택 (라이트 / 다크)"))
            }

            Divider()

            Button {
                SettingsWindowController.shared.showWindow()
            } label: {
                Image(systemName: "gearshape")
                Text(locale.dn("menuBar.settings", fallback: "Settings"))
            }
            
            Divider()
            
            Button(action: { AppRelauncher.restartApp() }) {
                Image(systemName: "arrow.trianglehead.2.counterclockwise.rotate.90")
                Text(locale.dn("menuBar.restart", fallback: "Restart"))
            }
            
            Button(action: { NSApplication.shared.terminate(nil) }) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text(locale.dn("menuBar.quit", fallback: "Quit"))
            }
        }
    }
}
