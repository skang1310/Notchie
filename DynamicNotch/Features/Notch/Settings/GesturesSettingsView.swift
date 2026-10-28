//
//  GesturesSettingsView.swift
//  DynamicNotch
//

import SwiftUI

struct GesturesSettingsView: View {
    @ObservedObject var applicationSettings: ApplicationSettingsStore

    var body: some View {
        SettingsPageScrollView {
            gesturesCard
            hoverTimingCard
            gestureToggleCard
        }
        .accessibilityIdentifier("settings.notch.gestures.root")
    }

    private var gesturesCard: some View {
        SettingsCard() {
            SettingsToggleRow(
                title: "settings.local.quick.idleHoverMenu.title",
                description: "settings.local.quick.idleHoverMenu.desc",
                systemImage: "menubar.dock.rectangle",
                color: .mint,
                isOn: $applicationSettings.isIdleNotchHoverMenuEnabled,
                accessibilityIdentifier: "settings.notch.idleHoverMenu"
            )

            Divider()
                .opacity(0.6)

            SettingsToggleRow(
                title: "settings.notch.gestures.expandActivity.title",
                description: "settings.notch.gestures.expandActivity.desc",
                systemImage: "hand.tap.fill",
                color: .blue,
                isOn: $applicationSettings.isNotchTapToExpandEnabled,
                accessibilityIdentifier: "settings.notch.tapToExpand"
            )
            
            Divider()
                .opacity(0.6)
            
            SettingsMenuRow(
                title: "settings.notch.gestures.expandGesture.title",
                description: "settings.notch.gestures.expandGesture.desc",
                options: Array(NotchExpandInteraction.allCases),
                optionTitle: { $0.title },
                accessibilityIdentifier: "settings.notch.expandInteraction",
                selection: $applicationSettings.notchExpandInteraction
            )
            
            Divider()
                .opacity(0.6)

            SettingsMenuRow(
                title: "settings.notch.gestures.collapseGesture.title",
                description: "settings.notch.gestures.collapseGesture.desc",
                options: Array(NotchCollapseInteraction.allCases),
                optionTitle: { $0.title },
                accessibilityIdentifier: "settings.notch.collapseInteraction",
                selection: $applicationSettings.notchCollapseInteraction
            )
            
            Divider()
                .opacity(0.6)
            
            SettingsSliderRow(
                title: "settings.notch.gestures.pressHoldTiming.title",
                description: "settings.notch.gestures.pressHoldTiming.desc",
                range: ApplicationSettingsStore.notchPressHoldDurationRange,
                step: ApplicationSettingsStore.notchPressHoldDurationStep,
                fractionLength: 2,
                suffix: "s",
                accessibilityIdentifier: "settings.notch.pressHoldDuration",
                value: $applicationSettings.notchPressHoldDuration
            )
            .disabled(applicationSettings.notchExpandInteraction == .click)
        }
    }
    
    private var hoverTimingCard: some View {
        SettingsCard(title: "settings.local.gestures.input.title") {
            SettingsSliderRow(
                title: "settings.local.gestures.hoverDelay.title",
                description: "settings.local.gestures.hoverDelay.desc",
                range: ApplicationSettingsStore.notchHoverExpandDelayRange,
                step: 0.05, fractionLength: 2, suffix: "s",
                accessibilityIdentifier: "settings.notch.hoverExpandDelay",
                value: $applicationSettings.notchHoverExpandDelay
            )
            .disabled(applicationSettings.notchExpandInteraction != .hover)
            Divider().opacity(0.6)
            SettingsToggleRow(
                title: "settings.local.gestures.mouse.title", description: "settings.local.gestures.mouse.desc",
                systemImage: "computermouse.fill", color: .blue,
                isOn: $applicationSettings.isNotchMouseDragGesturesEnabled,
                accessibilityIdentifier: "settings.notch.mouseDrag"
            )
            Divider().opacity(0.6)
            SettingsToggleRow(
                title: "settings.local.gestures.trackpad.title", description: "settings.local.gestures.trackpad.desc",
                systemImage: "hand.draw.fill", color: .purple,
                isOn: $applicationSettings.isNotchTrackpadSwipeGesturesEnabled,
                accessibilityIdentifier: "settings.notch.trackpadSwipe"
            )
        }
    }

    private var gestureToggleCard: some View {
        SettingsCard {
            SettingsToggleRow(
                title: "settings.notch.gestures.hoverHaptic.title",
                description: "settings.notch.gestures.hoverHaptic.desc",
                systemImage: "waveform",
                color: .red,
                isOn: $applicationSettings.isNotchHoverHapticEnabled,
                accessibilityIdentifier: "settings.notch.hoverHaptic"
            )
            
            Divider()
                .opacity(0.6)
                .padding(.leading, 43)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            
            SettingsToggleRow(
                title: "settings.notch.gestures.swipeDismissAndRestore.title",
                description: "settings.notch.gestures.swipeDismissAndRestore.subtitle",
                systemImage: "arrow.up.and.down.circle.fill",
                color: .red,
                isOn: Binding(
                    get: { applicationSettings.isNotchSwipeDismissEnabled && applicationSettings.isNotchSwipeRestoreEnabled },
                    set: { newValue in
                        applicationSettings.isNotchSwipeDismissEnabled = newValue
                        applicationSettings.isNotchSwipeRestoreEnabled = newValue
                    }
                ),
                accessibilityIdentifier: "settings.notch.swipeDismissAndRestore"
            )
            Divider().opacity(0.6)
            SettingsToggleRow(
                title: "settings.local.gestures.dismiss.title", description: "settings.local.gestures.dismiss.desc",
                systemImage: "arrow.up.circle", color: .red,
                isOn: $applicationSettings.isNotchSwipeDismissEnabled,
                accessibilityIdentifier: "settings.notch.swipeDismiss"
            )
            Divider().opacity(0.6)
            SettingsToggleRow(
                title: "settings.local.gestures.restore.title", description: "settings.local.gestures.restore.desc",
                systemImage: "arrow.down.circle", color: .green,
                isOn: $applicationSettings.isNotchSwipeRestoreEnabled,
                accessibilityIdentifier: "settings.notch.swipeRestore"
            )
        }
    }
}
