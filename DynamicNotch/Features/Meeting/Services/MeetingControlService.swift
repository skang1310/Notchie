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
    nonisolated func detectActiveRunningMeeting() -> (platform: MeetingPlatform, pid: pid_t?, title: String?)?
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

    private func getElementCenter(_ element: AXUIElement) -> CGPoint? {
        var posRef: CFTypeRef?, sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posValue = posRef, CFGetTypeID(posValue) == AXValueGetTypeID(),
              let sizeValue = sizeRef, CFGetTypeID(sizeValue) == AXValueGetTypeID() else {
            return nil
        }
        var point = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posValue as! AXValue, .cgPoint, &point)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        guard size.width > 4 && size.height > 4 else { return nil }
        return CGPoint(x: point.x + size.width / 2, y: point.y + size.height / 2)
    }

    private func postSyntheticClick(at point: CGPoint) {
        let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
        let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
        down?.post(tap: .cghidEventTap)
        usleep(20_000)
        up?.post(tap: .cghidEventTap)
    }

    private func findWebAreas(in element: AXUIElement, depth: Int = 0) -> [AXUIElement] {
        if depth > 8 { return [] }
        var results: [AXUIElement] = []
        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        let role = roleRef as? String ?? ""
        if role == "AXWebArea" {
            results.append(element)
            return results
        }
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                results.append(contentsOf: findWebAreas(in: child, depth: depth + 1))
            }
        }
        return results
    }

    private func ensureMeetTabActive(bundleId: String) -> Bool {
        guard bundleId.contains("Chrome") || bundleId.contains("brave") || bundleId.contains("edge") || bundleId.contains("Safari") || bundleId.contains("Browser") else {
            return false
        }
        let script: String
        if bundleId.contains("Safari") {
            script = """
            tell application "Safari"
                repeat with w in windows
                    repeat with i from 1 to count of tabs of w
                        set t to item i of tabs of w
                        if URL of t contains "meet.google.com" then
                            set current tab of w to t
                            set index of w to 1
                            return true
                        end if
                    end repeat
                end repeat
                return false
            end tell
            """
        } else {
            script = """
            tell application id "\(bundleId)"
                repeat with w in windows
                    set tabList to tabs of w
                    repeat with i from 1 to count of tabList
                        set t to item i of tabList
                        if URL of t contains "meet.google.com" then
                            set active tab index of w to i
                            set index of w to 1
                            return true
                        end if
                    end repeat
                end repeat
                return false
            end tell
            """
        }
        var error: NSDictionary?
        let res = NSAppleScript(source: script)?.executeAndReturnError(&error)
        return res?.booleanValue ?? false
    }

    public func sendShortcut(platform: MeetingPlatform, action: MeetingShortcutAction, pid: pid_t?) {
        var effectivePlatform = platform
        var effectivePid = pid

        if effectivePlatform == .unknown || effectivePid == nil {
            if let detected = detectActiveRunningMeeting() {
                if effectivePlatform == .unknown { effectivePlatform = detected.platform }
                if effectivePid == nil { effectivePid = detected.pid }
            }
        }

        if effectivePid == nil && (effectivePlatform == .meet || effectivePlatform == .unknown) {
            for bId in ["com.google.Chrome", "company.thebrowser.Browser", "com.brave.Browser", "com.microsoft.edgemac", "com.apple.Safari"] {
                if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bId).first {
                    effectivePid = app.processIdentifier
                    if effectivePlatform == .unknown { effectivePlatform = .meet }
                    break
                }
            }
        }

        // 1. Google Meet & browser meetings: AX press / coordinate click first, then activate + keystroke fallback
        if effectivePlatform == .meet {
            // Tier 1: Direct AX press / click on current active tab
            if let effectivePid, performMeetAccessibilityAction(action: action, pid: effectivePid) {
                return
            }

            // Tier 2: Switch to Meet tab if in background, then retry AX press
            let bundleId = NSRunningApplication(processIdentifier: effectivePid ?? 0)?.bundleIdentifier ?? "com.google.Chrome"
            if ensureMeetTabActive(bundleId: bundleId) {
                usleep(80_000) // 80ms for accessibility DOM attach
                if let effectivePid, performMeetAccessibilityAction(action: action, pid: effectivePid) {
                    return
                }
            }

            // Tier 3: Focused hardware keycode dispatch fallback
            sendBrowserMeetShortcut(action: action, pid: effectivePid)
            return
        }

        // 2. Native meeting applications (Zoom, Teams, FaceTime, Webex, Slack)
        sendNativeAppShortcut(platform: effectivePlatform, action: action, pid: effectivePid)
    }

    private func performMeetAccessibilityAction(action: MeetingShortcutAction, pid: pid_t?) -> Bool {
        guard let pid, AXIsProcessTrusted() else { return false }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else { return false }

        let keywords: [String]
        switch action {
        case .toggleMute:
            keywords = ["마이크", "microphone", "mic", "음소거"]
        case .toggleCamera:
            keywords = ["카메라", "camera", "video", "비디오", "영상"]
        case .leaveCall:
            keywords = ["통화에서 나가기", "통화 나가기", "통화 종료", "회의 나가기", "회의에서 나가기", "전화 끊기", "leave call", "leave", "end call", "통화 퇴장", "통화"]
        }

        for window in windows {
            let webAreas = findWebAreas(in: window)
            for webArea in webAreas {
                var urlRef: CFTypeRef?
                AXUIElementCopyAttributeValue(webArea, "AXURL" as CFString, &urlRef)
                var titleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
                var webAreaTitleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(webArea, kAXTitleAttribute as CFString, &webAreaTitleRef)

                let urlStr = ((urlRef as? URL)?.absoluteString ?? (urlRef as? String) ?? "").lowercased()
                let windowTitle = (titleRef as? String ?? "").lowercased()
                let webAreaTitle = (webAreaTitleRef as? String ?? "").lowercased()

                let isMeet = urlStr.contains("meet.google.com") ||
                             windowTitle.contains("meet") ||
                             windowTitle.contains("회의") ||
                             webAreaTitle.contains("meet") ||
                             webAreaTitle.contains("회의")

                guard isMeet else { continue }

                // Search for the button inside this Google Meet webArea
                // Appending in natural order so popLast() visits the bottom toolbar first!
                var stack = [webArea]
                var visited = 0
                let deadline = ProcessInfo.processInfo.systemUptime + 1.5

                while let element = stack.popLast(), visited < 4000, ProcessInfo.processInfo.systemUptime < deadline {
                    visited += 1

                    var roleRef: CFTypeRef?
                    AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
                    let role = roleRef as? String ?? ""

                    var roleDescRef: CFTypeRef?
                    AXUIElementCopyAttributeValue(element, kAXRoleDescriptionAttribute as CFString, &roleDescRef)
                    let roleDesc = (roleDescRef as? String ?? "").lowercased()

                    let isClickable = role == "AXButton" || role == "AXCheckBox" || role == "AXRadioButton" ||
                                      role == "AXPopUpButton" || roleDesc.contains("button") || roleDesc.contains("toggle") ||
                                      roleDesc.contains("버튼")

                    if isClickable {
                        var descRef: CFTypeRef?, btnTitleRef: CFTypeRef?, helpRef: CFTypeRef?
                        AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef)
                        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &btnTitleRef)
                        AXUIElementCopyAttributeValue(element, kAXHelpAttribute as CFString, &helpRef)

                        let label = "\((descRef as? String) ?? "") \((btnTitleRef as? String) ?? "") \((helpRef as? String) ?? "")".lowercased()

                        if keywords.contains(where: { label.contains($0) }) {
                            let isDropdown = label.contains("설정") || label.contains("settings") || label.contains("options") || label.contains("더보기")
                            if !isDropdown {
                                // 1. Try AXPress
                                if AXUIElementPerformAction(element, kAXPressAction as CFString) == .success {
                                    return true
                                }
                                // 2. Try direct coordinate click on button center
                                if let center = getElementCenter(element) {
                                    postSyntheticClick(at: center)
                                    return true
                                }
                            }
                        }
                    }

                    var childrenRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
                       let children = childrenRef as? [AXUIElement] {
                        stack.append(contentsOf: children)
                    }
                }

                // Focus the webArea for keyboard shortcut fallback
                AXUIElementSetAttributeValue(webArea, kAXFocusedAttribute as CFString, kCFBooleanTrue)
            }
        }
        return false
    }

    private func sendBrowserMeetShortcut(action: MeetingShortcutAction, pid: pid_t?) {
        // Hardware key codes:
        // 2 = 'D' (physical D key on Mac)
        // 14 = 'E' (physical E key on Mac)
        // 13 = 'W' (physical W key on Mac)
        let keyCode: Int
        switch action {
        case .toggleMute: keyCode = 2
        case .toggleCamera: keyCode = 14
        case .leaveCall: keyCode = 13
        }

        let bundleId: String = {
            if let pid, let bId = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier {
                return bId
            }
            return "com.google.Chrome"
        }()

        Task.detached {
            let script: String
            if bundleId.contains("Chrome") || bundleId.contains("brave") || bundleId.contains("edge") {
                script = """
                tell application id "\(bundleId)"
                    set found to false
                    repeat with w in windows
                        set tabList to tabs of w
                        repeat with i from 1 to count of tabList
                            set t to item i of tabList
                            if URL of t contains "meet.google.com" then
                                set active tab index of w to i
                                set index of w to 1
                                activate
                                set found to true
                                exit repeat
                            end if
                        end repeat
                        if found then exit repeat
                    end repeat
                end tell
                delay 0.12
                tell application "System Events"
                    key code \(keyCode) using command down
                end tell
                """
            } else {
                script = """
                tell application id "\(bundleId)"
                    activate
                end tell
                delay 0.12
                tell application "System Events"
                    key code \(keyCode) using command down
                end tell
                """
            }

            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
            }
        }
    }

    private func sendNativeAppShortcut(platform: MeetingPlatform, action: MeetingShortcutAction, pid: pid_t?) {
        let keyChar: String
        let modifiers: String
        let appName: String

        switch (platform, action) {
        case (.zoom, .toggleMute):
            (keyChar, modifiers, appName) = ("a", "{command down, shift down}", "zoom.us")
        case (.zoom, .toggleCamera):
            (keyChar, modifiers, appName) = ("v", "{command down, shift down}", "zoom.us")
        case (.zoom, .leaveCall):
            (keyChar, modifiers, appName) = ("w", "command down", "zoom.us")

        case (.teams, .toggleMute):
            (keyChar, modifiers, appName) = ("m", "{command down, shift down}", "Microsoft Teams")
        case (.teams, .toggleCamera):
            (keyChar, modifiers, appName) = ("o", "{command down, shift down}", "Microsoft Teams")
        case (.teams, .leaveCall):
            (keyChar, modifiers, appName) = ("h", "{command down, shift down}", "Microsoft Teams")

        case (.facetime, .toggleMute):
            (keyChar, modifiers, appName) = ("m", "{command down, shift down}", "FaceTime")
        case (.facetime, .toggleCamera):
            (keyChar, modifiers, appName) = ("v", "{command down, shift down}", "FaceTime")
        case (.facetime, .leaveCall):
            (keyChar, modifiers, appName) = ("w", "command down", "FaceTime")

        case (.webex, .toggleMute):
            (keyChar, modifiers, appName) = ("m", "command down", "Webex")
        case (.webex, .toggleCamera):
            (keyChar, modifiers, appName) = ("n", "command down", "Webex")
        case (.webex, .leaveCall):
            (keyChar, modifiers, appName) = ("w", "command down", "Webex")

        default:
            return
        }

        Task.detached {
            let script = """
            tell application "\(appName)" to activate
            tell application "System Events"
                keystroke "\(keyChar)" using \(modifiers)
            end tell
            """
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
            }
        }
    }

    nonisolated public func detectActiveRunningMeeting() -> (platform: MeetingPlatform, pid: pid_t?, title: String?)? {
        // 1. Detect browser-based Google Meet and Slack Huddle calls via window list
        if let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] {
            for win in windowList {
                guard let owner = win[kCGWindowOwnerName as String] as? String,
                      let name = win[kCGWindowName as String] as? String,
                      !name.isEmpty else { continue }
                let lowerOwner = owner.lowercased()
                let lowerName = name.lowercased()

                let isBrowser = lowerOwner.contains("chrome") || lowerOwner.contains("safari") ||
                                lowerOwner.contains("arc") || lowerOwner.contains("brave") ||
                                lowerOwner.contains("edge") || lowerOwner.contains("chromium") ||
                                lowerOwner.contains("meet")

                // Detect Google Meet active tab or window
                if isBrowser && (name.contains("Meet -") || name.contains("Meet –") || name.contains("Meet: ") ||
                                 lowerName.contains("google meet") || lowerName.contains("meet.google.com") ||
                                 (name.contains("회의") && (lowerOwner.contains("chrome") || lowerOwner.contains("meet")))) {
                    let pid = (win[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value
                    let cleanTitle = name
                        .replacingOccurrences(of: " - Google Chrome", with: "")
                        .replacingOccurrences(of: " - Chrome", with: "")
                        .replacingOccurrences(of: " - Arc", with: "")
                        .replacingOccurrences(of: " - Safari", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    return (.meet, pid, cleanTitle.isEmpty ? "Google Meet" : cleanTitle)
                }

                // Detect Slack Huddle
                if lowerOwner.contains("slack") && (lowerName.contains("huddle") || lowerName.contains("허들")) {
                    let pid = (win[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value
                    return (.slack, pid, name)
                }
            }
        }

        // 2. Check running browsers for meet.google.com tab if window list didn't identify it (e.g. background tab or non-standard title)
        for bId in ["com.google.Chrome", "company.thebrowser.Browser", "com.brave.Browser", "com.microsoft.edgemac"] {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bId).first {
                let script = """
                tell application id "\(bId)"
                    repeat with w in windows
                        repeat with t in tabs of w
                            if URL of t contains "meet.google.com" then
                                return title of t
                            end if
                        end repeat
                    end repeat
                    return ""
                end tell
                """
                var error: NSDictionary?
                if let res = NSAppleScript(source: script)?.executeAndReturnError(&error),
                   let tabTitle = res.stringValue, !tabTitle.isEmpty {
                    return (.meet, app.processIdentifier, tabTitle)
                }
            }
        }

        // 3. Native meeting applications
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
    private var detectionTask: Task<Void, Never>?
    private var detectionObservers = Set<AnyCancellable>()
    private var detectionInterval: TimeInterval?
    private var presentationConsumers = Set<UUID>()
    var isElapsedTimerRunning: Bool { timer != nil }

    public init(provider: MeetingControlProviderProtocol? = nil) {
        self.provider = provider ?? DefaultMeetingControlProvider()
        self.session = MeetingSessionState()
        let vol = self.provider.getInputVolume()
        self.inputVolume = vol
        self.lastSavedVolume = vol > 0 ? vol : 60
        self.session.isMuted = (vol == 0)

        startDetection()
    }

    public func refreshInputVolume() {
        let vol = self.provider.getInputVolume()
        self.inputVolume = vol
        if vol > 0 {
            self.lastSavedVolume = vol
        }
        self.session.isMuted = (vol == 0)
    }

    public func startDetection() {
        guard detectionTimer == nil, !AppEnvironment.isRunningTests else { return }
        configureDetectionTimer()
        let center = NSWorkspace.shared.notificationCenter
        Publishers.Merge3(center.publisher(for: NSWorkspace.didActivateApplicationNotification),
            center.publisher(for: NSWorkspace.didLaunchApplicationNotification),
            center.publisher(for: NSWorkspace.didTerminateApplicationNotification))
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.requestMeetingDetection() }
            .store(in: &detectionObservers)
        requestMeetingDetection()
    }

    private func configureDetectionTimer() {
        let interval: TimeInterval = session.isActive ? 3 : 15
        guard detectionInterval != interval else { return }
        detectionTimer?.cancel()
        detectionInterval = interval
        detectionTimer = Timer.publish(every: interval, tolerance: session.isActive ? 0.5 : 2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.requestMeetingDetection()
            }
    }

    /// At most one serialized discovery; expensive browser scripts never block the main UI queue.
    private func requestMeetingDetection() {
        guard detectionTask == nil else { return }
        let provider = provider
        detectionTask = Task { @MainActor [weak self] in
            let detected = await Task.detached(priority: .utility) { provider.detectActiveRunningMeeting() }.value
            guard !Task.isCancelled, let self else { return }
            self.applyDetectedMeeting(detected)
            self.detectionTask = nil
        }
    }

    public func pollRunningMeeting() {
        applyDetectedMeeting(provider.detectActiveRunningMeeting())
    }

    private func applyDetectedMeeting(_ detected: (platform: MeetingPlatform, pid: pid_t?, title: String?)?) {
        if let detected {
            detectedPid = detected.pid
            if !session.isActive {
                startMeetingSession(
                    title: detected.title ?? detected.platform.displayName,
                    platform: detected.platform
                )
            }
        } else if session.isActive && detectedPid != nil {
            // Previously detected meeting is no longer running -> clean exit
            stopMeetingSession()
        }
        if detectionTimer != nil { configureDetectionTimer() }
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

        updateElapsedTimer()
    }

    func acquirePresentation(_ id: UUID) {
        presentationConsumers.insert(id)
        updateElapsedTimer()
    }

    func releasePresentation(_ id: UUID) {
        presentationConsumers.remove(id)
        updateElapsedTimer()
    }

    private func updateElapsedTimer() {
        timer?.cancel(); timer = nil
        guard session.isActive, !presentationConsumers.isEmpty else { return }
        updateElapsedTime()
        timer = Timer.publish(every: 1.0, tolerance: 0.2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.updateElapsedTime()
            }
    }

    func updateElapsedTime(now: Date = .now) {
        guard session.isActive, let start = session.startTime else { return }
        let elapsed = max(0, now.timeIntervalSince(start).rounded(.down))
        if session.elapsedSeconds != elapsed { session.elapsedSeconds = elapsed }
    }

    public func stopDetection() {
        detectionTimer?.cancel(); detectionTimer = nil
        detectionInterval = nil
        detectionTask?.cancel(); detectionTask = nil
        detectionObservers.removeAll()
        timer?.cancel(); timer = nil
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
