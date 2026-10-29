import Combine
import Foundation
internal import AppKit
import ServiceManagement
import SwiftUI

enum AppIconAppearanceStyle: String, CaseIterable, Identifiable, StoredSettingValue {
    case auto
    case light
    case dark

    var id: String { rawValue }

    static func resolved(_ rawValue: String?) -> AppIconAppearanceStyle {
        guard let rawValue, let style = AppIconAppearanceStyle(rawValue: rawValue) else {
            return .auto
        }
        return style
    }
}

extension SettingsAppearanceMode: StoredSettingValue {}
extension NotchBackgroundStyle: StoredSettingValue {}
extension NotchDisplayLocation: StoredSettingValue {}
extension DynamicNotchLanguage: StoredSettingValue {}
extension NotchAnimationPreset: StoredSettingValue {}
extension NotchExpandInteraction: StoredSettingValue {}
extension NotchCollapseInteraction: StoredSettingValue {}

@MainActor
final class ApplicationSettingsStore: SettingsStoreBase, NotchSettingsProviding {
    static let notchHoverExpandDelayRange: ClosedRange<Double> = 0.05...1.5
    static let notchPressHoldDurationRange: ClosedRange<Double> = 0.20...0.60
    static let notchPressHoldDurationStep: Double = 0.01
    static let defaultNotchPressHoldDuration: TimeInterval = 0.25
    static let notchStrokeWidthRange: ClosedRange<Double> = 1.0...3.0
    static let maxNotchStrokeOpacity: Double = 0.6
    static let notchStrokeOpacityRange: ClosedRange<Double> = 0.0...maxNotchStrokeOpacity

    @Published var isLaunchAtLoginEnabled: Bool {
        didSet {
            persist(isLaunchAtLoginEnabled, for: GeneralSettingsStorage.Keys.launchAtLogin)
            updateLaunchAtLogin()
        }
    }

    @StoredDefault(key: GeneralSettingsStorage.Keys.dockIcon, defaultValue: false)
    var isDockIconVisible: Bool

    @StoredDefault(key: GeneralSettingsStorage.Keys.appearanceMode, defaultValue: .system)
    var appearanceMode: SettingsAppearanceMode

    @StoredDefault(key: GeneralSettingsStorage.Keys.appIconAppearanceStyle, defaultValue: .auto)
    var appIconAppearanceStyle: AppIconAppearanceStyle

    @StoredDefault(key: GeneralSettingsStorage.Keys.isBlueNightMode, defaultValue: false)
    var isBlueNightMode: Bool

    @StoredDefault(key: GeneralSettingsStorage.Keys.customAccentColorHex, defaultValue: "#34C759")
    var customAccentColorHex: String

    @StoredDefault(key: GeneralSettingsStorage.Keys.idleNotchHoverMenuEnabled, defaultValue: true)
    var isIdleNotchHoverMenuEnabled: Bool

    @StoredDefault(key: GeneralSettingsStorage.Keys.startupPermissionCheckEnabled, defaultValue: true)
    var isStartupPermissionCheckEnabled: Bool

    @StoredDefault(key: GeneralSettingsStorage.Keys.notchBackgroundStyle, defaultValue: .black)
    var notchBackgroundStyle: NotchBackgroundStyle

    @StoredDefault(key: GeneralSettingsStorage.Keys.notchAnimationPreset, defaultValue: .fluid)
    var notchAnimationPreset: NotchAnimationPreset

    @Published var notchWidth: Int {
        didSet {
            let clamped = min(20, max(-20, notchWidth))
            if clamped != notchWidth {
                notchWidth = clamped
                return
            }
            guard oldValue != notchWidth else { return }
            persist(notchWidth, for: GeneralSettingsStorage.Keys.notchWidth)
            notchSizeEvent.send(.width)
        }
    }
    @Published var notchHeight: Int {
        didSet {
            let clamped = min(0, max(-4, notchHeight))
            if clamped != notchHeight {
                notchHeight = clamped
                return
            }
            guard oldValue != notchHeight else { return }
            persist(notchHeight, for: GeneralSettingsStorage.Keys.notchHeight)
            notchSizeEvent.send(.height)
        }
    }

    @StoredDefault(key: GeneralSettingsStorage.Keys.menuBarIcon, defaultValue: true)
    var isMenuBarIconVisible: Bool

    @StoredDefault(key: GeneralSettingsStorage.Keys.notchStrokeEnabled, defaultValue: false)
    var isShowNotchStrokeEnabled: Bool

    @StoredDefault(
        key: GeneralSettingsStorage.Keys.notchStrokeWidth,
        defaultValue: 2.5,
        transform: ApplicationSettingsStore.clampNotchStrokeWidth
    )
    var notchStrokeWidth: Double

    @Published var notchStrokeOpacity: Double {
        didSet {
            let clamped = Self.clampNotchStrokeOpacity(notchStrokeOpacity)
            if clamped != notchStrokeOpacity {
                notchStrokeOpacity = clamped
                return
            }
            guard oldValue != notchStrokeOpacity else { return }
            persist(notchStrokeOpacity, for: GeneralSettingsStorage.Keys.notchStrokeOpacity)
            notchSizeEvent.send(.strokeOpacity)
        }
    }

    @Published var displayLocation: NotchDisplayLocation {
        didSet {
            persist(displayLocation.rawValue, for: GeneralSettingsStorage.Keys.displayLocation)

            if displayLocation == .specific {
                ensureSpecificDisplaySelection(previousLocation: oldValue)
            }
        }
    }

    @StoredDefault(key: GeneralSettingsStorage.Keys.preferredDisplayUUID, defaultValue: "")
    var preferredDisplayUUID: String

    @StoredDefault(key: GeneralSettingsStorage.Keys.preferredDisplayName, defaultValue: "")
    var preferredDisplayName: String

    @StoredDefault(key: GeneralSettingsStorage.Keys.displayAutoSwitchEnabled, defaultValue: true)
    var isDisplayAutoSwitchEnabled: Bool

    @StoredDefault(key: GeneralSettingsStorage.Keys.appLanguage, defaultValue: .system)
    var appLanguage: DynamicNotchLanguage

    @StoredDefault(key: GeneralSettingsStorage.Keys.notchLanguage, defaultValue: .system)
    var notchLanguage: DynamicNotchLanguage

    @StoredDefault(key: GeneralSettingsStorage.Keys.hideNotchInFullscreenEnabled, defaultValue: true)
    var isNotchHiddenInFullscreenEnabled: Bool

    @StoredDefault(key: GeneralSettingsStorage.Keys.hideDynamicIslandInFullscreenEnabled, defaultValue: true)
    var isDynamicIslandHiddenInFullscreenEnabled: Bool

    @StoredDefault(key: GeneralSettingsStorage.Keys.notchTapToExpandEnabled, defaultValue: true)
    var isNotchTapToExpandEnabled: Bool

    @StoredDefault(key: GeneralSettingsStorage.Keys.notchExpandInteraction, defaultValue: .hover)
    var notchExpandInteraction: NotchExpandInteraction

    @StoredDefault(key: GeneralSettingsStorage.Keys.notchCollapseInteraction, defaultValue: .hoverLeaves)
    var notchCollapseInteraction: NotchCollapseInteraction

    @StoredDefault(
        key: GeneralSettingsStorage.Keys.notchPressHoldDuration,
        defaultValue: 0.25,
        transform: ApplicationSettingsStore.clampNotchPressHoldDuration
    )
    var notchPressHoldDuration: TimeInterval

    @StoredDefault(key: GeneralSettingsStorage.Keys.notchHoverExpandDelay, defaultValue: 0.25,
                   transform: ApplicationSettingsStore.clampNotchHoverExpandDelay)
    var notchHoverExpandDelay: TimeInterval

    @StoredDefault(key: GeneralSettingsStorage.Keys.notchMouseDragGesturesEnabled, defaultValue: true)
    var isNotchMouseDragGesturesEnabled: Bool

    @StoredDefault(key: GeneralSettingsStorage.Keys.notchTrackpadSwipeGesturesEnabled, defaultValue: true)
    var isNotchTrackpadSwipeGesturesEnabled: Bool

    @StoredDefault(key: GeneralSettingsStorage.Keys.notchSwipeDismissEnabled, defaultValue: true)
    var isNotchSwipeDismissEnabled: Bool

    @StoredDefault(key: GeneralSettingsStorage.Keys.notchSwipeRestoreEnabled, defaultValue: true)
    var isNotchSwipeRestoreEnabled: Bool

    @StoredDefault(key: GeneralSettingsStorage.Keys.notchHoverHapticEnabled, defaultValue: true)
    var isNotchHoverHapticEnabled: Bool

    @StoredDefault(key: GeneralSettingsStorage.Keys.closeAtFocusLiveActivityEnabled, defaultValue: false)
    var isCloseAtFocusLiveActivityEnabled: Bool

    @StoredDefault(key: GeneralSettingsStorage.Keys.notchlessWindowMarginEnabled, defaultValue: true)
    var isNotchlessWindowMarginEnabled: Bool

    @StoredDefault(
        key: GeneralSettingsStorage.Keys.notchlessWindowMarginOffset,
        defaultValue: 17,
        transform: ApplicationSettingsStore.clampNotchlessWindowMarginOffset
    )
    var notchlessWindowMarginOffset: Int

    @Published var notchContentPriorityOverrides: [String: Int] {
        didSet {
            let sanitizedOverrides = NotchContentPriority.sanitizedOverrides(notchContentPriorityOverrides)

            guard sanitizedOverrides == notchContentPriorityOverrides else {
                notchContentPriorityOverrides = sanitizedOverrides
                return
            }

            persist(
                notchContentPriorityOverrides,
                for: GeneralSettingsStorage.Keys.notchContentPriorityOverrides
            )
            NotificationCenter.default.post(name: .notchContentPrioritiesDidChange, object: self)
        }
    }

    @StoredDefault(key: GeneralSettingsStorage.Keys.notchSizeTemporaryActivityEnabled, defaultValue: true)
    var isNotchSizeTemporaryActivityEnabled: Bool

    @StoredDefault(
        key: GeneralSettingsStorage.Keys.notchSizeTemporaryActivityDuration,
        defaultValue: 2,
        transform: SettingsStoreBase.clampTemporaryActivityDuration
    )
    var notchSizeTemporaryActivityDuration: Int

    let notchSizeEvent = PassthroughSubject<NotchSizeEvent, Never>()

    var screenSelectionPreferences: NotchScreenSelectionPreferences {
        NotchScreenSelectionPreferences(
            displayLocation: displayLocation,
            preferredDisplayUUID: preferredDisplayUUID.isEmpty ? nil : preferredDisplayUUID,
            allowsAutomaticDisplaySwitching: isDisplayAutoSwitchEnabled
        )
    }

    override init(defaults: UserDefaults) {
        self.isLaunchAtLoginEnabled = defaults.bool(forKey: GeneralSettingsStorage.Keys.launchAtLogin)
        self.notchWidth = min(20, max(-20, defaults.integer(forKey: GeneralSettingsStorage.Keys.notchWidth)))
        self.notchHeight = min(0, max(-4, defaults.integer(forKey: GeneralSettingsStorage.Keys.notchHeight)))
        self.notchStrokeOpacity = Self.resolvedNotchStrokeOpacity(defaults: defaults)
        self.displayLocation = NotchDisplayLocation(
            rawValue: defaults.string(forKey: GeneralSettingsStorage.Keys.displayLocation) ?? NotchDisplayLocation.main.rawValue
        ) ?? .main
        self.notchContentPriorityOverrides = NotchContentPriority.overrideValues(defaults: defaults)

        super.init(defaults: defaults)
        persistSanitizedNotchStrokeSettingsIfNeeded()
        ensureSpecificDisplaySelection(previousLocation: .main)
        updateLaunchAtLogin()
        if defaults === UserDefaults.standard {
            AppIconController.shared.refreshIcon(using: defaults)
        }
    }

    func resetGeneral() {
        isLaunchAtLoginEnabled = defaultBool(for: GeneralSettingsStorage.Keys.launchAtLogin)
        isDockIconVisible = defaultBool(for: GeneralSettingsStorage.Keys.dockIcon)
        appearanceMode = SettingsAppearanceMode.resolved(
            defaultString(for: GeneralSettingsStorage.Keys.appearanceMode)
        )

        isBlueNightMode = defaultBool(for: GeneralSettingsStorage.Keys.isBlueNightMode)
        isMenuBarIconVisible = defaultBool(for: GeneralSettingsStorage.Keys.menuBarIcon)
        displayLocation = NotchDisplayLocation(
            rawValue: defaultString(for: GeneralSettingsStorage.Keys.displayLocation)
        ) ?? .main
        preferredDisplayUUID = defaultString(for: GeneralSettingsStorage.Keys.preferredDisplayUUID)
        preferredDisplayName = defaultString(for: GeneralSettingsStorage.Keys.preferredDisplayName)
        isDisplayAutoSwitchEnabled = defaultBool(
            for: GeneralSettingsStorage.Keys.displayAutoSwitchEnabled
        )
        appLanguage = DynamicNotchLanguage.resolved(
            defaultString(for: GeneralSettingsStorage.Keys.appLanguage)
        )
        notchLanguage = DynamicNotchLanguage.resolved(
            defaultString(for: GeneralSettingsStorage.Keys.notchLanguage)
        )
        isNotchHiddenInFullscreenEnabled = defaultBool(
            for: GeneralSettingsStorage.Keys.hideNotchInFullscreenEnabled
        )
        isDynamicIslandHiddenInFullscreenEnabled = defaultBool(
            for: GeneralSettingsStorage.Keys.hideDynamicIslandInFullscreenEnabled
        )
    }

    func resetAppearance() {
        appearanceMode = SettingsAppearanceMode.resolved(
            defaultString(for: GeneralSettingsStorage.Keys.appearanceMode)
        )
        appIconAppearanceStyle = AppIconAppearanceStyle.resolved(
            defaultString(for: GeneralSettingsStorage.Keys.appIconAppearanceStyle)
        )
        isBlueNightMode = defaultBool(for: GeneralSettingsStorage.Keys.isBlueNightMode)
        customAccentColorHex = defaultString(for: GeneralSettingsStorage.Keys.customAccentColorHex)
        if defaults === UserDefaults.standard {
            AppIconController.shared.refreshIcon(using: defaults)
        }
    }

    func resetDisplay() {
        displayLocation = NotchDisplayLocation(
            rawValue: defaultString(for: GeneralSettingsStorage.Keys.displayLocation)
        ) ?? .main
        preferredDisplayUUID = defaultString(for: GeneralSettingsStorage.Keys.preferredDisplayUUID)
        preferredDisplayName = defaultString(for: GeneralSettingsStorage.Keys.preferredDisplayName)
        isDisplayAutoSwitchEnabled = defaultBool(
            for: GeneralSettingsStorage.Keys.displayAutoSwitchEnabled
        )
        isNotchHiddenInFullscreenEnabled = defaultBool(
            for: GeneralSettingsStorage.Keys.hideNotchInFullscreenEnabled
        )
        isDynamicIslandHiddenInFullscreenEnabled = defaultBool(
            for: GeneralSettingsStorage.Keys.hideDynamicIslandInFullscreenEnabled
        )
        isNotchlessWindowMarginEnabled = defaultBool(
            for: GeneralSettingsStorage.Keys.notchlessWindowMarginEnabled
        )
        notchlessWindowMarginOffset = defaultInt(
            for: GeneralSettingsStorage.Keys.notchlessWindowMarginOffset
        )
    }

    func resetLanguage() {
        appLanguage = DynamicNotchLanguage.resolved(
            defaultString(for: GeneralSettingsStorage.Keys.appLanguage)
        )
        notchLanguage = DynamicNotchLanguage.resolved(
            defaultString(for: GeneralSettingsStorage.Keys.notchLanguage)
        )
    }

    func resetGestures() {
        isNotchTapToExpandEnabled = defaultBool(for: GeneralSettingsStorage.Keys.notchTapToExpandEnabled)
        notchExpandInteraction = NotchExpandInteraction.resolved(
            defaultString(for: GeneralSettingsStorage.Keys.notchExpandInteraction)
        )
        notchCollapseInteraction = NotchCollapseInteraction.resolved(
            defaultString(for: GeneralSettingsStorage.Keys.notchCollapseInteraction)
        )
        notchPressHoldDuration = Self.clampNotchPressHoldDuration(
            defaultDouble(for: GeneralSettingsStorage.Keys.notchPressHoldDuration)
        )
        notchHoverExpandDelay = defaultDouble(for: GeneralSettingsStorage.Keys.notchHoverExpandDelay)
        isNotchMouseDragGesturesEnabled = defaultBool(for: GeneralSettingsStorage.Keys.notchMouseDragGesturesEnabled)
        isNotchTrackpadSwipeGesturesEnabled = defaultBool(for: GeneralSettingsStorage.Keys.notchTrackpadSwipeGesturesEnabled)
        isNotchSwipeDismissEnabled = defaultBool(for: GeneralSettingsStorage.Keys.notchSwipeDismissEnabled)
        isNotchSwipeRestoreEnabled = defaultBool(for: GeneralSettingsStorage.Keys.notchSwipeRestoreEnabled)
        isNotchHoverHapticEnabled = defaultBool(for: GeneralSettingsStorage.Keys.notchHoverHapticEnabled)
        isCloseAtFocusLiveActivityEnabled = defaultBool(for: GeneralSettingsStorage.Keys.closeAtFocusLiveActivityEnabled)
        isIdleNotchHoverMenuEnabled = defaultBool(for: GeneralSettingsStorage.Keys.idleNotchHoverMenuEnabled)
    }

    func resetNotch() {
        resetGestures()
        resetNotchContentPriorities()
        isShowNotchStrokeEnabled = defaultBool(for: GeneralSettingsStorage.Keys.notchStrokeEnabled)
        isNotchSizeTemporaryActivityEnabled = defaultBool(for: GeneralSettingsStorage.Keys.notchSizeTemporaryActivityEnabled)
        notchSizeTemporaryActivityDuration = Self.clampTemporaryActivityDuration(
            defaultInt(for: GeneralSettingsStorage.Keys.notchSizeTemporaryActivityDuration)
        )
        notchStrokeWidth = defaultDouble(for: GeneralSettingsStorage.Keys.notchStrokeWidth)
        notchStrokeOpacity = defaultDouble(for: GeneralSettingsStorage.Keys.notchStrokeOpacity)
        notchBackgroundStyle = NotchBackgroundStyle.resolved(
            defaultString(for: GeneralSettingsStorage.Keys.notchBackgroundStyle)
        )
        notchAnimationPreset = NotchAnimationPreset.resolved(
            defaultString(for: GeneralSettingsStorage.Keys.notchAnimationPreset)
        )
        notchWidth = defaultInt(for: GeneralSettingsStorage.Keys.notchWidth)
        notchHeight = defaultInt(for: GeneralSettingsStorage.Keys.notchHeight)
    }

    func reset() {
        resetGeneral()
        resetNotch()
    }

    func notchContentPriority(for key: NotchContentPriority.Key) -> Int {
        notchContentPriorityOverrides[key.rawValue] ?? key.defaultValue
    }

    func setNotchContentPriority(_ priority: Int, for key: NotchContentPriority.Key) {
        let clampedPriority = NotchContentPriority.clamped(priority)
        var overrides = notchContentPriorityOverrides

        if clampedPriority == key.defaultValue {
            overrides.removeValue(forKey: key.rawValue)
        } else {
            overrides[key.rawValue] = clampedPriority
        }

        notchContentPriorityOverrides = overrides
    }

    func resetNotchContentPriorities() {
        notchContentPriorityOverrides = [:]
    }

    private static func resolvedBool(defaults: UserDefaults, key: String) -> Bool {
        if let currentValue = defaults.object(forKey: key) as? Bool {
            return currentValue
        }

        return (GeneralSettingsStorage.defaultValues[key] as? Bool) ?? false
    }

    private static func resolvedNotchStrokeWidth(defaults: UserDefaults) -> Double {
        let key = GeneralSettingsStorage.Keys.notchStrokeWidth

        guard let currentValue = (defaults.object(forKey: key) as? NSNumber)?.doubleValue else {
            return defaultDoubleValue(for: key)
        }

        return clampNotchStrokeWidth(currentValue)
    }



    private static func defaultDoubleValue(for key: String) -> Double {
        (GeneralSettingsStorage.defaultValues[key] as? Double) ?? 0
    }

    static func clampNotchStrokeWidth(_ value: Double) -> Double {
        min(
            max(value, notchStrokeWidthRange.lowerBound),
            notchStrokeWidthRange.upperBound
        )
    }

    static func clampNotchStrokeOpacity(_ value: Double) -> Double {
        min(
            max(value, notchStrokeOpacityRange.lowerBound),
            notchStrokeOpacityRange.upperBound
        )
    }

    static func clampNotchlessWindowMarginOffset(_ value: Int) -> Int {
        min(50, max(0, value))
    }

    private static func resolvedNotchStrokeOpacity(defaults: UserDefaults) -> Double {
        let key = GeneralSettingsStorage.Keys.notchStrokeOpacity

        guard let currentValue = (defaults.object(forKey: key) as? NSNumber)?.doubleValue else {
            return defaultDoubleValue(for: key)
        }

        return clampNotchStrokeOpacity(currentValue)
    }



    private func persistSanitizedNotchStrokeSettingsIfNeeded() {
        let key = GeneralSettingsStorage.Keys.notchStrokeWidth
        if defaults.object(forKey: key) != nil {
            defaults.removeObject(forKey: key)
        }

        let opacityKey = GeneralSettingsStorage.Keys.notchStrokeOpacity
        if let storedOpacity = (defaults.object(forKey: opacityKey) as? NSNumber)?.doubleValue {
            let clampedOpacity = Self.clampNotchStrokeOpacity(storedOpacity)
            if clampedOpacity != storedOpacity {
                persist(clampedOpacity, for: opacityKey)
            }
        }


    }

    static func clampNotchPressHoldDuration(_ value: TimeInterval) -> TimeInterval {
        min(
            max(value, notchPressHoldDurationRange.lowerBound),
            notchPressHoldDurationRange.upperBound
        )
    }

    static func clampNotchHoverExpandDelay(_ value: TimeInterval) -> TimeInterval {
        guard value.isFinite else { return 0.25 }
        return min(max(value, notchHoverExpandDelayRange.lowerBound), notchHoverExpandDelayRange.upperBound)
    }

    private func updateLaunchAtLogin() {
        guard !AppEnvironment.isRunningTests else { return }
        let instance = SMAppService.mainApp

        do {
            if isLaunchAtLoginEnabled {
                try instance.register()
            } else {
                try instance.unregister()
            }
        } catch {
            print("Ошибка для \(instance.description): \(error)")
        }
    }

    func selectPreferredDisplay(_ display: NotchDisplayOption) {
        guard display.isAvailable else { return }

        preferredDisplayUUID = display.displayUUID
        preferredDisplayName = display.name
    }

    func syncPreferredDisplayMetadata() {
        guard !preferredDisplayUUID.isEmpty,
              let selectedDisplay = NSScreen.availableNotchDisplays().first(where: {
                  $0.displayUUID == preferredDisplayUUID
              })
        else {
            return
        }

        if preferredDisplayName != selectedDisplay.name {
            preferredDisplayName = selectedDisplay.name
        }
    }

    private func ensureSpecificDisplaySelection(previousLocation: NotchDisplayLocation) {
        guard displayLocation == .specific else { return }

        if !preferredDisplayUUID.isEmpty {
            syncPreferredDisplayMetadata()
            return
        }

        let previousPreferences = NotchScreenSelectionPreferences(
            displayLocation: previousLocation,
            preferredDisplayUUID: preferredDisplayUUID.isEmpty ? nil : preferredDisplayUUID,
            allowsAutomaticDisplaySwitching: isDisplayAutoSwitchEnabled
        )

        if let resolvedDisplay = NSScreen.preferredNotchDisplay(for: previousPreferences) ??
            NSScreen.availableNotchDisplays().first {
            selectPreferredDisplay(resolvedDisplay)
        }
    }

    var customAccentColor: Color {
        get { Self.color(fromHex: customAccentColorHex) ?? Color.green }
        set {
            if let hex = Self.hexString(from: newValue) {
                customAccentColorHex = hex
            }
        }
    }

    static func currentCustomAccentColor(defaults: UserDefaults = .standard) -> Color {
        let hex = defaults.string(forKey: GeneralSettingsStorage.Keys.customAccentColorHex) ?? "#34C759"
        return color(fromHex: hex) ?? .green
    }

    nonisolated static func color(fromHex hex: String) -> Color? {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }

    static func hexString(from color: Color) -> String? {
        guard let srgb = NSColor(color).usingColorSpace(.sRGB) else { return nil }
        let r = Int((min(1, max(0, srgb.redComponent)) * 255).rounded())
        let g = Int((min(1, max(0, srgb.greenComponent)) * 255).rounded())
        let b = Int((min(1, max(0, srgb.blueComponent)) * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

@MainActor
final class AppIconController: ObservableObject {
    static let shared = AppIconController()

    @Published private(set) var activeVariant: AppIconAppearanceStyle = .dark
    private var cancellables = Set<AnyCancellable>()

    private init() {
        DistributedNotificationCenter.default()
            .publisher(for: Notification.Name("AppleInterfaceThemeChangedNotification"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshIcon()
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshIcon()
            }
            .store(in: &cancellables)

        refreshIcon()
    }

    static func isSystemInDarkMode() -> Bool {
        if let app = NSApp {
            let match = app.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
            if let match {
                return match == .darkAqua
            }
        }
        let globalStyle = UserDefaults.standard.string(forKey: "AppleInterfaceStyle")
        return globalStyle?.caseInsensitiveCompare("Dark") == .orderedSame
    }

    static func resolvedVariant(
        style: AppIconAppearanceStyle,
        appearanceMode: SettingsAppearanceMode,
        systemDark: Bool? = nil
    ) -> AppIconAppearanceStyle {
        let isDark = systemDark ?? isSystemInDarkMode()
        switch style {
        case .light:
            return .light
        case .dark:
            return .dark
        case .auto:
            switch appearanceMode {
            case .light:
                return .light
            case .dark:
                return .dark
            case .system:
                return isDark ? .dark : .light
            }
        }
    }

    func iconImage(for variant: AppIconAppearanceStyle) -> NSImage? {
        switch variant {
        case .light:
            return NSImage(named: "NotchieIconLight") ?? NSImage(named: "AppIcon")
        case .dark, .auto:
            return NSImage(named: "NotchieIconDark") ?? NSImage(named: "AppIcon")
        }
    }

    func selectStyle(_ style: AppIconAppearanceStyle, defaults: UserDefaults = .standard) {
        defaults.set(style.rawValue, forKey: GeneralSettingsStorage.Keys.appIconAppearanceStyle)
        refreshIcon(using: defaults)
    }

    func refreshIcon(using defaults: UserDefaults = .standard) {
        let style = AppIconAppearanceStyle.resolved(
            defaults.string(forKey: GeneralSettingsStorage.Keys.appIconAppearanceStyle)
        )
        let appearanceMode = SettingsAppearanceMode.resolved(
            defaults.string(forKey: GeneralSettingsStorage.Keys.appearanceMode) ?? SettingsAppearanceMode.system.rawValue
        )
        let resolved = Self.resolvedVariant(style: style, appearanceMode: appearanceMode)
        if activeVariant != resolved {
            activeVariant = resolved
        }

        guard !AppEnvironment.isRunningTests else { return }
        guard let icon = iconImage(for: resolved) else { return }
        NSApp?.applicationIconImage = icon

        // Keep the signed bundle immutable. Finder's setIcon writes FinderInfo /
        // resource forks into the .app and invalidates strict signature validation.
        // Finder uses the bundled appearance variants; Dock uses applicationIconImage.

    }
}
