//
//  SoundMixerService.swift
//  DynamicNotch
//

internal import AppKit
import Combine
import CoreAudio
import Foundation

struct AudioAppItem: Identifiable, Equatable {
    let id: String // bundle identifier
    let name: String
    let icon: NSImage?
    var volume: Double // 0.0 to 1.0
    var isPlaying: Bool

    static func == (lhs: AudioAppItem, rhs: AudioAppItem) -> Bool {
        lhs.id == rhs.id && lhs.volume == rhs.volume && lhs.isPlaying == rhs.isPlaying
    }
}

@MainActor
final class SoundMixerService: ObservableObject {
    static let shared = SoundMixerService()

    private static let appVolumesKey = "DynamicNotch.SoundMixer.appVolumes.v1"

    @Published private(set) var masterVolume: Double = 0.5
    @Published private(set) var isMasterMuted: Bool = false
    @Published private(set) var micVolume: Double = 0.5
    @Published private(set) var isMicMuted: Bool = false
    @Published private(set) var audioApps: [AudioAppItem] = []

    private let audioService = SystemAudioVolumeService()
    private let defaults: UserDefaults
    private var persistedAppVolumes: [String: Double] = [:]

    public private(set) var lastAdjustedAt: Date = .distantPast

    /// Indicates whether volume was recently adjusted through Sound Mixer controls (within last 1.5 seconds)
    public var isAdjustingVolume: Bool {
        Date().timeIntervalSince(lastAdjustedAt) < 1.5
    }

    public func touchAdjustment() {
        lastAdjustedAt = Date()
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.persistedAppVolumes = defaults.dictionary(forKey: Self.appVolumesKey) as? [String: Double] ?? [:]
        refreshSystemVolumes()
        refreshAudioApps()
    }

    // MARK: - Master Output Volume

    func refreshSystemVolumes() {
        masterVolume = Double(audioService.currentEffectiveVolume)
        isMasterMuted = audioService.isMuted
        micVolume = fetchDefaultInputVolume()
        isMicMuted = fetchDefaultInputMuted()
    }

    func setMasterVolume(_ volume: Double) {
        lastAdjustedAt = Date()
        let clamped = max(0.0, min(1.0, volume))
        masterVolume = clamped
        audioService.setVolume(Float(clamped))
        isMasterMuted = audioService.isMuted
    }

    func toggleMasterMute() {
        lastAdjustedAt = Date()
        let percent = audioService.toggleMute()
        isMasterMuted = audioService.isMuted
        masterVolume = isMasterMuted ? 0 : Double(percent) / 100.0
    }

    // MARK: - Microphone Input Volume

    private func defaultInputDeviceID() -> AudioDeviceID {
        var deviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        return status == noErr ? deviceID : kAudioObjectUnknown
    }

    private func fetchDefaultInputVolume() -> Double {
        let deviceID = defaultInputDeviceID()
        guard deviceID != kAudioObjectUnknown else { return 0.5 }

        var volume: Float32 = 0.5
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)
        return status == noErr ? Double(max(0, min(1, volume))) : 0.5
    }

    private func fetchDefaultInputMuted() -> Bool {
        let deviceID = defaultInputDeviceID()
        guard deviceID != kAudioObjectUnknown else { return false }

        var isMuted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &isMuted)
        return status == noErr && isMuted != 0
    }

    func setMicVolume(_ volume: Double) {
        lastAdjustedAt = Date()
        let clamped = max(0.0, min(1.0, volume))
        micVolume = clamped
        let deviceID = defaultInputDeviceID()
        guard deviceID != kAudioObjectUnknown else { return }

        var scalar = Float32(clamped)
        let size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        _ = AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &scalar)
    }

    func toggleMicMute() {
        lastAdjustedAt = Date()
        let deviceID = defaultInputDeviceID()
        guard deviceID != kAudioObjectUnknown else { return }

        let nextMute: UInt32 = isMicMuted ? 0 : 1
        let size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var muteValue = nextMute
        let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &muteValue)
        if status == noErr {
            isMicMuted = nextMute != 0
        }
    }

    // MARK: - Per-App Volumes & Playing Indicator

    func refreshAudioApps(activePlayingBundleID: String? = nil, isPlaying: Bool = false) {
        let running = NSWorkspace.shared.runningApplications
        let ownBundleID = Bundle.main.bundleIdentifier ?? "com.Jackson.DynamicNotch"

        // Candidate media, browser, and communication apps
        let knownAudioBundles: [String: String] = [
            "com.google.Chrome": "Google Chrome",
            "com.apple.Music": "Music",
            "com.spotify.client": "Spotify",
            "com.apple.Safari": "Safari",
            "company.thebrowser.Browser": "Arc",
            "com.brave.Browser": "Brave",
            "org.mozilla.firefox": "Firefox",
            "com.microsoft.edgemac": "Microsoft Edge",
            "com.hnc.Discord": "Discord",
            "com.tinyspeck.slackmacgap": "Slack",
            "com.apple.QuickTimePlayerX": "QuickTime Player",
            "com.colliderli.iina": "IINA",
            "org.videolan.vlc": "VLC",
            "com.apple.Podcasts": "Podcasts",
            "com.apple.TV": "TV"
        ]

        var apps: [AudioAppItem] = []
        var seenBundleIDs = Set<String>()

        // 1. First prioritize actively playing app if known
        if let activeID = activePlayingBundleID, !activeID.isEmpty, activeID != ownBundleID {
            seenBundleIDs.insert(activeID)
            let name = knownAudioBundles[activeID] ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: activeID)?.deletingPathExtension().lastPathComponent ?? activeID
            let icon = NSWorkspace.shared.urlForApplication(withBundleIdentifier: activeID).map { NSWorkspace.shared.icon(forFile: $0.path) }
            let vol = persistedAppVolumes[activeID] ?? queryScriptableVolume(bundleID: activeID) ?? 1.0
            apps.append(AudioAppItem(id: activeID, name: name, icon: icon, volume: vol, isPlaying: isPlaying))
        }

        // 2. Discover running candidate applications
        for app in running {
            guard let bid = app.bundleIdentifier, bid != ownBundleID, !seenBundleIDs.contains(bid) else { continue }

            let isKnownAudio = knownAudioBundles.keys.contains(bid)
            let isRegularApp = app.activationPolicy == .regular

            if isKnownAudio || isRegularApp {
                let matchesCategory = isKnownAudio || bid.contains("audio") || bid.contains("music") || bid.contains("sound")
                if matchesCategory || isKnownAudio {
                    seenBundleIDs.insert(bid)
                    let name = app.localizedName ?? knownAudioBundles[bid] ?? bid
                    let icon = app.icon
                    let vol = persistedAppVolumes[bid] ?? queryScriptableVolume(bundleID: bid) ?? 1.0
                    let appIsPlaying = (bid == activePlayingBundleID && isPlaying)
                    apps.append(AudioAppItem(id: bid, name: name, icon: icon, volume: vol, isPlaying: appIsPlaying))
                }
            }
        }

        // 3. Always include Chrome, Music, Spotify if installed and not yet included (as shown in user UI)
        let defaultSampleList = ["com.google.Chrome", "com.apple.Music", "com.spotify.client"]
        for bid in defaultSampleList {
            if !seenBundleIDs.contains(bid), let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
                seenBundleIDs.insert(bid)
                let name = knownAudioBundles[bid] ?? url.deletingPathExtension().lastPathComponent
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                let vol = persistedAppVolumes[bid] ?? 1.0
                let appIsPlaying = (bid == activePlayingBundleID && isPlaying)
                apps.append(AudioAppItem(id: bid, name: name, icon: icon, volume: vol, isPlaying: appIsPlaying))
            }
        }

        self.audioApps = apps
    }

    func setAppVolume(bundleID: String, volume: Double) {
        lastAdjustedAt = Date()
        let clamped = max(0.0, min(1.0, volume))
        persistedAppVolumes[bundleID] = clamped
        defaults.set(persistedAppVolumes, forKey: Self.appVolumesKey)

        if let index = audioApps.firstIndex(where: { $0.id == bundleID }) {
            audioApps[index].volume = clamped
        }

        // Control scriptable players
        applyScriptableVolume(bundleID: bundleID, volume: clamped)
    }

    func resetAppVolume(bundleID: String) {
        lastAdjustedAt = Date()
        setAppVolume(bundleID: bundleID, volume: 1.0)
    }

    private func queryScriptableVolume(bundleID: String) -> Double? {
        if bundleID == "com.apple.Music" {
            let script = "tell application \"Music\" to if running then get sound volume"
            var error: NSDictionary?
            if let result = NSAppleScript(source: script)?.executeAndReturnError(&error).int32Value {
                return Double(result) / 100.0
            }
        } else if bundleID == "com.spotify.client" {
            let script = "tell application \"Spotify\" to if running then get sound volume"
            var error: NSDictionary?
            if let result = NSAppleScript(source: script)?.executeAndReturnError(&error).int32Value {
                return Double(result) / 100.0
            }
        }
        return nil
    }

    private func applyScriptableVolume(bundleID: String, volume: Double) {
        let intVol = Int(volume * 100)
        if bundleID == "com.apple.Music" {
            let script = "tell application \"Music\" to if running then set sound volume to \(intVol)"
            DispatchQueue.global(qos: .userInitiated).async {
                _ = NSAppleScript(source: script)?.executeAndReturnError(nil)
            }
        } else if bundleID == "com.spotify.client" {
            let script = "tell application \"Spotify\" to if running then set sound volume to \(intVol)"
            DispatchQueue.global(qos: .userInitiated).async {
                _ = NSAppleScript(source: script)?.executeAndReturnError(nil)
            }
        }
    }
}
