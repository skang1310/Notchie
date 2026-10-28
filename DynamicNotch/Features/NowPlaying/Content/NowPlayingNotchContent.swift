import SwiftUI
internal import AppKit

enum NowPlayingEvent: Equatable {
    case started
    case stopped
    case playbackStateChanged(isPlaying: Bool)
}

struct NowPlayingNotchContent: NotchContentProtocol, DynamicIslandCustomizable {
    let id = NotchContentRegistry.Media.nowPlaying.id
    let nowPlayingViewModel: NowPlayingViewModel
    let settings: MediaAndFilesSettingsStore
    let applicationSettings: ApplicationSettingsStore
    let onOpenPlaybackSource: @MainActor () -> Void

    init(
        nowPlayingViewModel: NowPlayingViewModel,
        settings: MediaAndFilesSettingsStore,
        applicationSettings: ApplicationSettingsStore,
        onOpenPlaybackSource: @escaping @MainActor () -> Void = {}
    ) {
        self.nowPlayingViewModel = nowPlayingViewModel
        self.settings = settings
        self.applicationSettings = applicationSettings
        self.onOpenPlaybackSource = onOpenPlaybackSource
    }
    
    var priority: Int { NotchContentRegistry.Media.nowPlaying.priority }
    
    var isExpandable: Bool { true }

    var pinsExpandedInteraction: Bool {
        QuickToolsStore.shared.isNotchHubPinned
    }

    var windowLink: (@MainActor () -> Void)? {
        guard nowPlayingViewModel.canOpenPlaybackSource else { return nil }

        return {
            nowPlayingViewModel.openPlaybackSource()
        }
    }
    
    func compactSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        .init(width: baseWidth + 70, height: baseHeight)
    }
    
    func dynamicIslandSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        .init(width: baseWidth + 65, height: baseHeight)
    }
    
    func expandedSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        let extraHeight: CGFloat = QuickToolsStore.shared.hubMode.requiresExtendedHeight ? 210 : 154
        return .init(width: max(688, baseWidth + 488), height: baseHeight + extraHeight)
    }
    
    func expandedDynamicIslandSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        let extraHeight: CGFloat = QuickToolsStore.shared.hubMode.requiresExtendedHeight ? 200 : 146
        return .init(width: max(668, baseWidth + 468), height: baseHeight + extraHeight)
    }
    
    func expandedCornerRadius(baseRadius: CGFloat) -> (top: CGFloat, bottom: CGFloat) {
        (top: 19, bottom: 28)
    }

    func dynamicIslandCornerRadius(baseHeight: CGFloat) -> CGFloat {
        baseHeight * 0.5
    }

    func expandedDynamicIslandCornerRadius(baseHeight: CGFloat) -> CGFloat {
        baseHeight * 0.2
    }
    
    @MainActor
    func compactView() -> AnyView {
        AnyView(
            NowPlayingMinimalNotchView(
                nowPlayingViewModel: nowPlayingViewModel,
                settings: settings
            )
        )
    }
    
    @MainActor
    func expandedView() -> AnyView {
        AnyView(
            NowPlayingExpandedNotchView(
                nowPlayingViewModel: nowPlayingViewModel,
                settings: settings,
                applicationSettings: applicationSettings,
                onOpenPlaybackSource: onOpenPlaybackSource
            )
        )
    }
}
