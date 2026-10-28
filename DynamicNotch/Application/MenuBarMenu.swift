//
//  MenuBarMenu.swift
//  DynamicNotch
//
//  Created by Евгений Петрукович on 9/1/26.
//

import SwiftUI

struct MenuBarMenu: View {
    @ObservedObject private var privacy = AppPrivacyController.shared
    @AppStorage(GeneralSettingsStorage.Keys.appLanguage) private var appLanguageRaw: String = DynamicNotchLanguage.system.rawValue

    private var locale: Locale {
        DynamicNotchLanguage.resolved(appLanguageRaw).locale
    }

    private var localizedVersionText: String {
        locale.dnFormat(
            "menuBar.version",
            fallback: "Version: %@",
            AppVersionText.appVersionText
        )
    }
    
    var body: some View {
        Group {
            Text(verbatim: localizedVersionText)
            
            Divider()
            
            Button {
                SettingsWindowController.shared.showWindow()
            } label: {
                Image(systemName: "gearshape")
                Text(locale.dn("menuBar.settings", fallback: "Settings"))
            }
            
            Button { NotificationCenter.default.post(name: .showQuickToolsInNotch, object: nil) } label: {
                Label("settings.tools.title", systemImage: "square.grid.2x2")
            }
            Button("support.board.title") { SupportDeskCoordinator.shared.show() }
            Button("productivity.palette") { ProductivityCoordinator.shared.showPalette() }
            Divider()
            
            if privacy.enabled {
                Button(privacyText("Relock private apps", "보호 앱 모두 다시 잠금")) { privacy.relockAll() }
                Button(privacyText("Pause app privacy for 5 minutes", "앱 프라이버시 5분 일시 정지")) { privacy.pause(minutes: 5) }
                Divider()
            }
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
