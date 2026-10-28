import SwiftUI
internal import AppKit

struct DownloadsSettingsView: View {
    @ObservedObject var mediaSettings: MediaAndFilesSettingsStore
    @ObservedObject var appearanceSettings: ApplicationSettingsStore
    @State private var folderError: String?
    var body: some View {
        SettingsPageScrollView {
            SettingsCard(title: "settings.local.downloads.folder.title") {
                Text("settings.local.downloads.folder.desc").font(.callout).foregroundStyle(.secondary)
                if let folder = DownloadFolderAuthorization.resolve(mediaSettings.downloadFolderBookmark) {
                    Label(folder.lastPathComponent, systemImage: "folder.fill").font(.headline)
                } else { Text("settings.local.downloads.folder.none").foregroundStyle(.secondary) }
                Button("settings.local.downloads.folder.choose") { chooseFolder() }
                    .accessibilityIdentifier("settings.downloads.chooseFolder")
                if !mediaSettings.downloadFolderBookmark.isEmpty {
                    Button("settings.local.downloads.folder.remove") {
                        mediaSettings.isDownloadsLiveActivityEnabled = false
                        mediaSettings.downloadFolderBookmark = Data()
                    }
                }
                if let folderError { Text(folderError).font(.caption).foregroundStyle(.red) }
            }
            SettingsCard(title: "settings.downloads.card.activity") {
                SettingsToggleRow(
                    title: "settings.downloads.liveActivity.title", description: "settings.downloads.liveActivity.desc",
                    systemImage: "arrow.down.circle.fill", color: .blue,
                    isOn: $mediaSettings.isDownloadsLiveActivityEnabled,
                    accessibilityIdentifier: "settings.activities.live.downloads"
                ).disabled(mediaSettings.downloadFolderBookmark.isEmpty)
                Divider().opacity(0.6)
                SettingsToggleRow(
                    title: "settings.local.downloads.browser.title", description: "settings.local.downloads.browser.desc",
                    systemImage: "globe", color: .orange,
                    isOn: $mediaSettings.isBrowserDownloadMetadataEnabled,
                    accessibilityIdentifier: "settings.downloads.browserMetadata"
                )
            }
            SettingsCard(title: "settings.downloads.card.appearance") {
                SettingsMenuRow(
                    title: "settings.downloads.progressIndicator.title", description: "settings.downloads.progressIndicator.desc",
                    options: Array(DownloadProgressIndicatorStyle.allCases), optionTitle: { $0.title },
                    accessibilityIdentifier: "settings.activities.live.downloads.progressIndicator",
                    selection: $mediaSettings.downloadsProgressIndicatorStyle
                )
            }
        }
    }
    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let folder = panel.url else { return }
            do {
                mediaSettings.downloadFolderBookmark = try DownloadFolderAuthorization.bookmark(for: folder)
                mediaSettings.isDownloadsLiveActivityEnabled = true
                folderError = nil
            } catch { folderError = error.localizedDescription }
        }
    }
}
