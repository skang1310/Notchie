import Foundation
import SwiftUI

public enum MeetingPlatform: String, CaseIterable, Identifiable, Codable, Sendable {
    case zoom
    case meet
    case teams
    case facetime
    case webex
    case slack
    case unknown

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .zoom: return "Zoom"
        case .meet: return "Google Meet"
        case .teams: return "Microsoft Teams"
        case .facetime: return "FaceTime"
        case .webex: return "Webex"
        case .slack: return "Slack Huddle"
        case .unknown: return "Online Meeting"
        }
    }

    public var iconName: String {
        switch self {
        case .zoom: return "video.fill"
        case .meet: return "video.badge.checkmark"
        case .teams: return "person.2.fill"
        case .facetime: return "video.fill"
        case .webex: return "waveform.circle.fill"
        case .slack: return "number"
        case .unknown: return "video"
        }
    }

    public var accentColor: Color {
        switch self {
        case .zoom: return Color(red: 0.18, green: 0.55, blue: 1.0)
        case .meet: return Color(red: 0.0, green: 0.65, blue: 0.42)
        case .teams: return Color(red: 0.38, green: 0.39, blue: 0.75)
        case .facetime: return Color(red: 0.20, green: 0.78, blue: 0.35)
        case .webex: return Color(red: 0.0, green: 0.72, blue: 0.83)
        case .slack: return Color(red: 0.88, green: 0.11, blue: 0.45)
        case .unknown: return Color.blue
        }
    }

    public var bundleIdentifiers: [String] {
        switch self {
        case .zoom: return ["us.zoom.xos", "zoom.us"]
        case .meet: return ["com.google.Chrome", "company.thebrowser.Browser", "com.apple.Safari"]
        case .teams: return ["com.microsoft.teams", "com.microsoft.teams2"]
        case .facetime: return ["com.apple.FaceTime"]
        case .webex: return ["com.cisco.webex.meetings", "Cisco-Systems.Spark"]
        case .slack: return ["com.tinyspeck.slackmacgap"]
        case .unknown: return []
        }
    }
}

public struct MeetingSessionState: Equatable, Sendable {
    public var isActive: Bool
    public var platform: MeetingPlatform
    public var title: String
    public var startTime: Date?
    public var isMuted: Bool
    public var isCameraOn: Bool
    public var meetingURL: URL?
    public var elapsedSeconds: TimeInterval

    public init(
        isActive: Bool = false,
        platform: MeetingPlatform = .unknown,
        title: String = "Online Meeting",
        startTime: Date? = nil,
        isMuted: Bool = false,
        isCameraOn: Bool = true,
        meetingURL: URL? = nil,
        elapsedSeconds: TimeInterval = 0
    ) {
        self.isActive = isActive
        self.platform = platform
        self.title = title
        self.startTime = startTime
        self.isMuted = isMuted
        self.isCameraOn = isCameraOn
        self.meetingURL = meetingURL
        self.elapsedSeconds = elapsedSeconds
    }

    public var formattedDuration: String {
        let total = Int(elapsedSeconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
