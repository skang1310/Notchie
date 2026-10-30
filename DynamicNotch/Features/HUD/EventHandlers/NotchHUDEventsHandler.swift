import SwiftUI

@MainActor
final class NotchHUDEventsHandler {
    private let notchViewModel: NotchViewModel
    private let settingsViewModel: SettingsViewModel

    init(
        notchViewModel: NotchViewModel,
        settingsViewModel: SettingsViewModel
    ) {
        self.notchViewModel = notchViewModel
        self.settingsViewModel = settingsViewModel
    }

    func handleHud(_ event: HudEvent) {
        switch event {
        case .display(let level):
            guard settingsViewModel.isHUDEnabled(.brightness) else { return }
            notchViewModel.send(
                .showTemporaryNotification(
                    HudNotchContent(
                        kind: .brightness,
                        level: level,
                        style: settingsViewModel.hudStyle,
                        indicatorStyle: settingsViewModel.hudIndicatorStyle,
                        indicatorTintStyle: settingsViewModel.hudIndicatorTintStyle,
                        showsIndicatorGlow: settingsViewModel.isHUDIndicatorGlowEnabled,
                        usesColoredLevelStroke: settingsViewModel.isHUDColoredLevelStrokeEnabled,
                        applicationSettings: settingsViewModel.application
                    ),
                    duration: settingsViewModel.temporaryActivityDuration(for: .brightness)
                )
            )

        case .keyboard(let level):
            guard settingsViewModel.isHUDEnabled(.keyboard) else { return }
            notchViewModel.send(
                .showTemporaryNotification(
                    HudNotchContent(
                        kind: .keyboard,
                        level: level,
                        style: settingsViewModel.hudStyle,
                        indicatorStyle: settingsViewModel.hudIndicatorStyle,
                        indicatorTintStyle: settingsViewModel.hudIndicatorTintStyle,
                        showsIndicatorGlow: settingsViewModel.isHUDIndicatorGlowEnabled,
                        usesColoredLevelStroke: settingsViewModel.isHUDColoredLevelStrokeEnabled,
                        applicationSettings: settingsViewModel.application
                    ),
                    duration: settingsViewModel.temporaryActivityDuration(for: .keyboard)
                )
            )

        case .volume(let level, let deviceName):
            guard settingsViewModel.isHUDEnabled(.volume) else { return }
            // Do not display the Volume HUD Live Activity when adjusting volume via
            // Sound Mixer or when the Notch is expanded / Sound Mixer is active, preventing
            // layout oscillation and visual conflicts.
            guard !SoundMixerService.shared.isAdjustingVolume else { return }
            guard !notchViewModel.notchModel.isExpanded else { return }
            guard !notchViewModel.isDisplayingExpandedLiveActivity else { return }
            guard !QuickToolsStore.shared.isSoundMixerVisibleInCalendarSlot else { return }

            notchViewModel.send(
                .showTemporaryNotification(
                    HudNotchContent(
                        kind: .volume,
                        level: level,
                        style: settingsViewModel.hudStyle,
                        indicatorStyle: settingsViewModel.hudIndicatorStyle,
                        indicatorTintStyle: settingsViewModel.hudIndicatorTintStyle,
                        showsIndicatorGlow: settingsViewModel.isHUDIndicatorGlowEnabled,
                        usesColoredLevelStroke: settingsViewModel.isHUDColoredLevelStrokeEnabled,
                        deviceName: deviceName,
                        applicationSettings: settingsViewModel.application
                    ),
                    duration: settingsViewModel.temporaryActivityDuration(for: .volume)
                )
            )
        }
    }
}
