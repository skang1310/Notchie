import Foundation
import HeyMacEngine

/// Non-secret configuration + monotonic authentication sessions from HeyMac.
@MainActor
final class AppPrivacyState {
    static let faceKey = "DynamicNotch.HeyMac.appPrivacy.useFace"
    private let defaults: UserDefaults
    let store: LockedAppStore
    let sessions: SessionBook
    private let now: () -> TimeInterval
    private(set) var pauseDeadline: TimeInterval?

    init(defaults: UserDefaults = .standard, now: (() -> TimeInterval)? = nil) {
        self.defaults = defaults
        let clock = now ?? { ProcessInfo.processInfo.systemUptime }
        self.now = clock
        store = LockedAppStore(defaults: defaults)
        sessions = SessionBook(now: clock)
    }
    var useFace: Bool {
        get { defaults.bool(forKey: Self.faceKey) }
        set { defaults.set(newValue, forKey: Self.faceKey) }
    }
    var isPaused: Bool { (pauseDeadline ?? 0) > now() }
    var pauseSeconds: Int { max(0, Int(ceil((pauseDeadline ?? 0) - now()))) }
    var isActive: Bool { store.enabled && !isPaused }
    func enable(_ value: Bool) {
        store.enabled = value
        pauseDeadline = nil
        sessions.revokeAll()
    }
    @discardableResult
    func add(bundleID: String, name: String) -> Bool {
        guard !bundleID.isEmpty, !name.isEmpty,
              bundleID != "com.Jackson.DynamicNotch", bundleID != "com.Jackson.DynamicNotch.LocalTests" else { return false }
        return store.add(bundleID: bundleID, name: name, policy: .everyTime)
    }
    func remove(_ id: String) { sessions.revoke(id); store.remove(bundleID: id) }
    func setPolicy(_ policy: RelockPolicy, for id: String) {
        switch policy {
        case .afterMinutes(let minutes), .afterFocusLossMinutes(let minutes):
            guard [5, 15].contains(minutes) else { return }
        case .everyTime: break
        }
        store.setPolicy(policy, for: id)
        sessions.revoke(id)
    }
    func pause(minutes: Int) {
        guard [5, 15].contains(minutes) else { return }
        pauseDeadline = now() + Double(minutes * 60)
        sessions.revokeAll()
    }
    func relockAll() { pauseDeadline = nil; sessions.revokeAll() }
    func needsShield(_ id: String) -> Bool {
        isActive && store.isLocked(id) && !sessions.isUnlocked(id)
    }
}

/// Shared English/Korean strings honor the app's language selection.
func privacyText(_ english: String, _ korean: String) -> String {
    let raw = UserDefaults.standard.string(forKey: GeneralSettingsStorage.Keys.appLanguage) ?? DynamicNotchLanguage.system.rawValue
    let language = DynamicNotchLanguage.resolved(raw).locale.language.languageCode?.identifier
    return language == "ko" ? korean : english
}
