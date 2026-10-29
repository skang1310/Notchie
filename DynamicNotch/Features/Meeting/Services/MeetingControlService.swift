import Foundation
internal import AppKit
import SwiftUI
import Combine
import CoreAudio
import AudioToolbox

public enum MeetingShortcutAction: Sendable {
    case toggleMute
    case toggleCamera
    case leaveCall
}

public protocol MeetingControlProviderProtocol: Sendable {
    func getInputVolume() -> Int
    func setInputVolume(_ volume: Int)
    func sendShortcut(platform: MeetingPlatform, action: MeetingShortcutAction, pid: pid_t?)
    func detectActiveRunningMeeting() -> (platform: MeetingPlatform, pid: pid_t?, title: String?)?
}

public final class DefaultMeetingControlProvider: MeetingControlProviderProtocol, @unchecked Sendable {
    public init() {}

    public func getInputVolume() -> Int {
        var defaultInputDeviceID = AudioDeviceID(0)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
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
            &propertySize,
            &defaultInputDeviceID
        )

        if status == noErr && defaultInputDeviceID != 0 {
            var volume: Float32 = 0
            var volSize = UInt32(MemoryLayout<Float32>.size)
            var volAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )

            let volStatus = AudioObjectGetPropertyData(
                defaultInputDeviceID,
                &volAddress,
                0,
                nil,
                &volSize,
                &volume
            )
            if volStatus == noErr {
                return Int(round(volume * 100))
            }
        }
        return 60
    }

    public func setInputVolume(_ volume: Int) {
        let clamped = max(0, min(100, volume))
        let scalar = Float32(clamped) / 100.0

        var defaultInputDeviceID = AudioDeviceID(0)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
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
            &propertySize,
            &defaultInputDeviceID
        )

        if status == noErr && defaultInputDeviceID != 0 {
            var vol = scalar
            let volSize = UInt32(MemoryLayout<Float32>.size)
            var volAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )

            let setStatus = AudioObjectSetPropertyData(
                defaultInputDeviceID,
                &volAddress,
                0,
                nil,
                volSize,
                &vol
            )
            if setStatus == noErr {
                return
            }
        }

        // Detached background fallback if device scalar is unavailable
        Task.detached {
            let script = "set volume input volume \(clamped)"
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
            }
        }
    }

    public func sendShortcut(platform: MeetingPlatform, action: MeetingShortcutAction, pid: pid_t?) {
        let (keyCode, flags): (CGKeyCode, CGEventFlags)
        switch (platform, action) {
        case (.zoom, .toggleMute):
            keyCode = 0x00 // 'A'
            flags = [.maskCommand, .maskShift]
        case (.zoom, .toggleCamera):
            keyCode = 0x09 // 'V'
            flags = [.maskCommand, .maskShift]
        case (.zoom, .leaveCall):
            keyCode = 0x0D // 'W'
            flags = [.maskCommand]

        case (.meet, .toggleMute):
            keyCode = 0x02 // 'D'
            flags = [.maskCommand]
        case (.meet, .toggleCamera):
            keyCode = 0x0E // 'E'
            flags = [.maskCommand]
        case (.meet, .leaveCall):
            keyCode = 0x0D // 'W'
            flags = [.maskCommand]

        case (.teams, .toggleMute):
            keyCode = 0x2E // 'M'
            flags = [.maskCommand, .maskShift]
        case (.teams, .toggleCamera):
            keyCode = 0x1F // 'O'
            flags = [.maskCommand, .maskShift]
        case (.teams, .leaveCall):
            keyCode = 0x04 // 'H'
            flags = [.maskCommand, .maskShift]

        case (.facetime, .toggleMute):
            keyCode = 0x2E // 'M'
            flags = [.maskCommand, .maskShift]
        case (.facetime, .toggleCamera):
            keyCode = 0x09 // 'V'
            flags = [.maskCommand, .maskShift]
        case (.facetime, .leaveCall):
            keyCode = 0x0D // 'W'
            flags = [.maskCommand]

        case (.webex, .toggleMute):
            keyCode = 0x2E // 'M'
            flags = [.maskCommand]
        case (.webex, .toggleCamera):
            keyCode = 0x2D // 'N'
            flags = [.maskCommand]
        case (.webex, .leaveCall):
            keyCode = 0x0D // 'W'
            flags = [.maskCommand]

        default:
            return
        }

        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else { return }

        down.flags = flags
        up.flags = flags

        if let pid {
            down.postToPid(pid)
            up.postToPid(pid)
        } else {
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }

    public func detectActiveRunningMeeting() -> (platform: MeetingPlatform, pid: pid_t?, title: String?)? {
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            guard let bundleID = app.bundleIdentifier?.lowercased() else { continue }
            if bundleID.contains("zoom") {
                return (.zoom, app.processIdentifier, app.localizedName ?? "Zoom Meeting")
            }
            if bundleID.contains("teams") {
                return (.teams, app.processIdentifier, app.localizedName ?? "Microsoft Teams")
            }
            if bundleID.contains("facetime") {
                return (.facetime, app.processIdentifier, app.localizedName ?? "FaceTime")
            }
            if bundleID.contains("webex") {
                return (.webex, app.processIdentifier, app.localizedName ?? "Webex")
            }
        }
        return nil
    }
}

@MainActor
public final class MeetingControlService: ObservableObject {
    public static let shared = MeetingControlService()

    @Published public private(set) var session: MeetingSessionState
    @Published public private(set) var inputVolume: Int = 60
    @Published public private(set) var detectedPid: pid_t?

    private var lastSavedVolume: Int = 60
    private let provider: MeetingControlProviderProtocol
    private var timer: AnyCancellable?
    private var detectionTimer: AnyCancellable?

    public init(provider: MeetingControlProviderProtocol = DefaultMeetingControlProvider()) {
        self.provider = provider
        self.session = MeetingSessionState()
        let vol = provider.getInputVolume()
        self.inputVolume = vol
        self.lastSavedVolume = vol > 0 ? vol : 60
        self.session.isMuted = (vol == 0)

        startDetection()
    }

    public func refreshInputVolume() {
        let prov = provider
        Task.detached {
            let vol = prov.getInputVolume()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.inputVolume = vol
                if vol > 0 {
                    self.lastSavedVolume = vol
                }
                self.session.isMuted = (vol == 0)
            }
        }
    }

    public func startDetection() {
        detectionTimer = Timer.publish(every: 3.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.pollRunningMeeting()
            }
    }

    public func pollRunningMeeting() {
        if let detected = provider.detectActiveRunningMeeting() {
            detectedPid = detected.pid
            if !session.isActive {
                startMeetingSession(
                    title: detected.title ?? detected.platform.displayName,
                    platform: detected.platform
                )
            }
        } else if session.isActive && session.startTime != nil {
            // Check if user manually started it or if it should persist
        }
    }

    public func startMeetingSession(
        title: String = "Online Meeting",
        platform: MeetingPlatform = .unknown,
        url: URL? = nil
    ) {
        session.isActive = true
        session.title = title
        session.platform = platform
        session.meetingURL = url
        session.startTime = Date()
        session.elapsedSeconds = 0

        refreshInputVolume()

        timer?.cancel()
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if self.session.isActive {
                    self.session.elapsedSeconds += 1
                }
            }
    }

    public func stopMeetingSession() {
        session.isActive = false
        session.startTime = nil
        session.elapsedSeconds = 0
        timer?.cancel()
        timer = nil
    }

    public func toggleMute() {
        if session.isMuted {
            // Unmute
            let restoreVol = lastSavedVolume > 0 ? lastSavedVolume : 60
            provider.setInputVolume(restoreVol)
            inputVolume = restoreVol
            session.isMuted = false
        } else {
            // Mute
            let currentVol = inputVolume
            if currentVol > 0 {
                lastSavedVolume = currentVol
            }
            provider.setInputVolume(0)
            inputVolume = 0
            session.isMuted = true
        }

        // Also trigger app shortcut
        provider.sendShortcut(platform: session.platform, action: .toggleMute, pid: detectedPid)
    }

    public func toggleCamera() {
        session.isCameraOn.toggle()
        provider.sendShortcut(platform: session.platform, action: .toggleCamera, pid: detectedPid)
    }

    public func leaveMeeting() {
        provider.sendShortcut(platform: session.platform, action: .leaveCall, pid: detectedPid)
        stopMeetingSession()
    }

    public func copyMeetingLink() {
        guard let url = session.meetingURL else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
    }

    public func activateMeetingApp() {
        if let detectedPid, let app = NSRunningApplication(processIdentifier: detectedPid) {
            app.activate(options: [.activateIgnoringOtherApps])
        }
    }
}
