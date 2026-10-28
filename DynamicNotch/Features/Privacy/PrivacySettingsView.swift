import SwiftUI
struct PrivacySettingsView: View {
    @StateObject private var preferences = PrivacyPreferences()
    var body: some View {
        SettingsPageScrollView {
            SettingsCard(title: "settings.security.local.title") {
                Label("settings.security.local.desc", systemImage: "checkmark.shield")
                Text("settings.security.local.permissions").font(.caption).foregroundStyle(.secondary)
            }
            SettingsCard(title: "settings.security.network.title") {
                SettingsToggleRow(title: "settings.security.lyrics.title", description: "settings.security.lyrics.desc", systemImage: "text.quote", color: .pink, isOn: $preferences.onlineLyrics, accessibilityIdentifier: "settings.privacy.lyrics")
                Divider()
                SettingsToggleRow(title: "settings.security.ip.title", description: "settings.security.ip.desc", systemImage: "globe", color: .blue, isOn: $preferences.ipLookup, accessibilityIdentifier: "settings.privacy.ipLookup")
                Divider()
                SettingsToggleRow(title: "settings.security.remote.title", description: "settings.security.remote.desc", systemImage: "music.note", color: .red, isOn: $preferences.localMusicRemote, accessibilityIdentifier: "settings.privacy.localRemote")
            }
            SettingsCard(title: "settings.security.unlock.title") {
                Text("settings.security.unlock.desc").foregroundStyle(.secondary)
            }
        }
    }
}
