import SwiftUI
internal import AppKit

struct NotchInteractiveBodyView: View {
    @ObservedObject var notchViewModel: NotchViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel
    @ObservedObject private var quickToolsStore = QuickToolsStore.shared
    @ObservedObject private var soundMixer = SoundMixerService.shared
    
    var body: some View {
        NotchSurfaceContainerView(
            notchViewModel: notchViewModel,
            settingsViewModel: settingsViewModel
        )
        .opacity(isVisiblyHiddenInFullscreen ? 0 : 1)
        .allowsHitTesting(!isVisiblyHiddenInFullscreen)
        .shadow(
            color: (notchViewModel.presentedNotchSize.height >= notchViewModel.notchModel.baseHeight + 30)
            ? .black.opacity(0.2) : .clear, radius: 20
        )
        .frame(
            width: notchViewModel.presentedNotchSize.width,
            height: notchViewModel.presentedNotchSize.height
        )
        .customNotchPressable(
            notchViewModel: notchViewModel,
            isPressed: $notchViewModel.isPressed,
            baseSize: notchViewModel.presentedNotchSize
        )
        .offset(y: notchViewModel.isDynamicIsland ? 9 : 1)
        .customNotchMouseSwipeable(
            notchViewModel: notchViewModel,
            isEnabled: shouldEnableNotchSwipeGestures
        )
        .customNotchSwipeDismissable(
            notchViewModel: notchViewModel,
            isEnabled: shouldEnableNotchSwipeGestures
        )
        .contextMenu {
            NotchContextMenu(settingsViewModel: settingsViewModel)
        }
        .environment(\.colorScheme, .dark)
        .animation(notchViewModel.animations.strokeVisibility, value: notchViewModel.shouldRenderStroke)
        .animation(notchViewModel.animations.strokeVisibility, value: settingsViewModel.isShowNotchStrokeEnabled)
    }
    
    private var isVisiblyHiddenInFullscreen: Bool {
        notchViewModel.isPrimarySurfaceHidden
    }
    
    private var shouldEnableNotchSwipeGestures: Bool {
        guard (!notchViewModel.isActivityPresentationHidden || notchViewModel.isLocked) || notchViewModel.notchModel.temporaryNotificationContent != nil else { return false }
        
        if quickToolsStore.isSoundMixerVisibleInCalendarSlot || soundMixer.isAdjustingVolume || quickToolsStore.isCalendarFullScheduleVisible {
            return false
        }
        
        return !(
            notchViewModel.isDisplayingExpandedLiveActivity &&
            notchViewModel.displayedContent?.id == NotchContentRegistry.DragAndDrop.trayActive.id
        )
    }
}
