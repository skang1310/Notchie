import Foundation
import ApplicationServices
internal import AppKit

/// Best-effort Music fallback using existing AX authorization and exact transport identifiers.
/// No app activation, global key event, unrelated button search or permission request.
nonisolated enum MusicAccessibilityPlayback {
    enum Action: Equatable { case press, alreadySatisfied, unsupported }
    static func action(for command: NowPlayingCommand, label: String) -> Action {
        let value = label.lowercased().replacingOccurrences(of: " ", with: "")
        let playing = value == "pause" || value == "일시정지"
        let paused = value == "play" || value == "재생"
        switch command {
        case .play: return playing ? .alreadySatisfied : (paused ? .press : .unsupported)
        case .pause: return paused ? .alreadySatisfied : (playing ? .press : .unsupported)
        case .togglePlayPause: return playing || paused ? .press : .unsupported
        case .nextTrack, .previousTrack: return .press
        default: return .unsupported
        }
    }
    static func send(_ command: NowPlayingCommand) -> Bool {
        guard AXIsProcessTrusted(),
              let pid = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").first?.processIdentifier else { return false }
        let identifier: String
        switch command {
        case .play, .pause, .togglePlayPause: identifier = "Music.miniPlayer.playbackTransportControl"
        case .nextTrack: identifier = "Music.miniPlayer.trailingTransportControl"
        case .previousTrack: identifier = "Music.miniPlayer.leadingTransportControl"
        default: return false
        }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.15)
        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else { return false }
        let deadline = Date().addingTimeInterval(1)
        var stack = Array(windows.prefix(3)), visited = 0
        while let element = stack.popLast(), visited < 800, Date() < deadline {
            visited += 1
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &value) == .success,
               value as? String == identifier {
                var label: CFTypeRef?
                AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &label)
                switch action(for: command, label: label as? String ?? "") {
                case .alreadySatisfied: return true
                case .press: return AXUIElementPerformAction(element, kAXPressAction as CFString) == .success
                case .unsupported: return false
                }
            }
            var childrenValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue) == .success,
               let children = childrenValue as? [AXUIElement] {
                stack.append(contentsOf: children.prefix(max(0, 800 - visited - stack.count)))
            }
        }
        return false
    }
}
