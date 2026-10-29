import Foundation

protocol NotchSettingsProviding: AnyObject {
    var notchWidth: Int { get }
    var notchHeight: Int { get }
    var displayLocation: NotchDisplayLocation { get }
    var screenSelectionPreferences: NotchScreenSelectionPreferences { get }
    var isNotchTapToExpandEnabled: Bool { get }
    var notchExpandInteraction: NotchExpandInteraction { get }
    var notchCollapseInteraction: NotchCollapseInteraction { get }
    var notchHoverExpandDelay: TimeInterval { get }
    var notchPressHoldDuration: TimeInterval { get }
    var isNotchMouseDragGesturesEnabled: Bool { get }
    var isNotchTrackpadSwipeGesturesEnabled: Bool { get }
    var isNotchSwipeDismissEnabled: Bool { get }
    var isNotchSwipeRestoreEnabled: Bool { get }
    var isNotchHoverHapticEnabled: Bool { get }
    var isCloseAtFocusLiveActivityEnabled: Bool { get }
    var isIdleNotchHoverMenuEnabled: Bool { get }
    var notchAnimationPreset: NotchAnimationPreset { get }
}

// Existing providers retain their previous timing until they opt into a separate delay.
extension NotchSettingsProviding {
    var notchHoverExpandDelay: TimeInterval { notchPressHoldDuration }
    var isIdleNotchHoverMenuEnabled: Bool { false }
    var notchAnimationPreset: NotchAnimationPreset { .fluid }
}
