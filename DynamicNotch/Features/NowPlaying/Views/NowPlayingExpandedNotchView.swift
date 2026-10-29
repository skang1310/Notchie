import SwiftUI
internal import AppKit

struct NowPlayingExpandedNotchView: View {
    @ObservedObject var nowPlayingViewModel: NowPlayingViewModel
    @ObservedObject var settings: MediaAndFilesSettingsStore
    @ObservedObject var applicationSettings: ApplicationSettingsStore
    @ObservedObject private var quickToolsStore = QuickToolsStore.shared

    let onOpenPlaybackSource: @MainActor @Sendable () -> Void
    private let detailedPresentationSource = "nowPlaying.notch.expanded"

    var body: some View {
        NotchiePanoramicHubView(
            store: quickToolsStore,
            nowPlayingViewModel: nowPlayingViewModel,
            mediaSettings: settings,
            applicationSettings: applicationSettings,
            onOpenPlaybackSource: { onOpenPlaybackSource() }
        )
        .onAppear {
            nowPlayingViewModel.setDetailedPresentationActive(
                true,
                source: detailedPresentationSource
            )
        }
        .onDisappear {
            nowPlayingViewModel.setDetailedPresentationActive(
                false,
                source: detailedPresentationSource
            )
        }
    }
}
