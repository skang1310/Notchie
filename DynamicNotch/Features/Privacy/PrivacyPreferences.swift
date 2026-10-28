import Foundation
import Combine

nonisolated enum PrivacyPolicy {
    // Legacy upstream detector/direct unlock remains disabled. HeyMac has a separate explicit opt-in.
    static let passwordUnlockSupported = false
    static let onlineLyricsKey = "privacy.onlineLyrics"
    static let ipLookupKey = "privacy.ipLocationLookup"
    static let localMusicRemoteKey = "privacy.localYouTubeMusicRemote"
    static func allows(_ key: String, defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: key) as? Bool == true
    }
}
@MainActor
final class PrivacyPreferences: ObservableObject {
    private let defaults: UserDefaults
    @Published var onlineLyrics: Bool { didSet { defaults.set(onlineLyrics, forKey: PrivacyPolicy.onlineLyricsKey) } }
    @Published var ipLookup: Bool { didSet { defaults.set(ipLookup, forKey: PrivacyPolicy.ipLookupKey) } }
    @Published var localMusicRemote: Bool { didSet { defaults.set(localMusicRemote, forKey: PrivacyPolicy.localMusicRemoteKey) } }
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        onlineLyrics = PrivacyPolicy.allows(PrivacyPolicy.onlineLyricsKey, defaults: defaults)
        ipLookup = PrivacyPolicy.allows(PrivacyPolicy.ipLookupKey, defaults: defaults)
        localMusicRemote = PrivacyPolicy.allows(PrivacyPolicy.localMusicRemoteKey, defaults: defaults)
    }
}
