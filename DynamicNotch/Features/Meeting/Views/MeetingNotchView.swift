import SwiftUI

public struct MeetingNotchView: View {
    @ObservedObject var service: MeetingControlService
    var accentColor: Color
    @State private var isPresentationVisible = false
    @State private var presentationID = UUID()

    public init(
        service: MeetingControlService = .shared,
        accentColor: Color = .blue
    ) {
        self.service = service
        self.accentColor = accentColor
    }

    private func text(_ en: String, _ ko: String) -> String {
        privacyText(en, ko)
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Left: Platform Logo & Live Duration Pill / Standby Badge
            HStack(spacing: 6) {
                Circle()
                    .fill(service.session.isMuted ? Color.red : Color.green)
                    .frame(width: 6, height: 6)

                let platform = service.session.platform == .unknown ? MeetingPlatform.meet : service.session.platform
                Image(systemName: platform.iconName)
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(platform.accentColor)

                Text(service.session.isActive ? service.session.formattedDuration : text("Meet Standby", "구글밋 대기 중"))
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8))
            )

            Spacer()

            // Center: Minimal Icon-Only Action Buttons (Mic | Camera | End Call)
            HStack(spacing: 10) {
                // 1. Mic Mute / Unmute (Hardware Input Mic Mute Toggle)
                Button {
                    service.toggleMute()
                } label: {
                    ZStack {
                        Circle()
                            .fill(service.session.isMuted ? Color.red.opacity(0.24) : Color.green.opacity(0.2))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle().strokeBorder(
                                    (service.session.isMuted ? Color.red : Color.green).opacity(0.45),
                                    lineWidth: 1
                                )
                            )

                        Image(systemName: service.session.isMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(service.session.isMuted ? Color.red : Color.green)
                    }
                }
                .contentShape(Circle())
                .buttonStyle(.plain)
                .help(service.session.isMuted ? text("Unmute Microphone", "마이크 음소거 해제") : text("Mute Microphone", "마이크 음소거"))

                // 2. Camera Toggle
                Button {
                    service.toggleCamera()
                } label: {
                    ZStack {
                        Circle()
                            .fill(service.session.isCameraOn ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle().strokeBorder(
                                    (service.session.isCameraOn ? accentColor.opacity(0.6) : Color.white.opacity(0.12)),
                                    lineWidth: 1
                                )
                            )

                        Image(systemName: service.session.isCameraOn ? "video.fill" : "video.slash.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(service.session.isCameraOn ? .white : .white.opacity(0.4))
                    }
                }
                .contentShape(Circle())
                .buttonStyle(.plain)
                .help(service.session.isCameraOn ? text("Turn Camera Off", "카메라 끄기") : text("Turn Camera On", "카메라 켜기"))

                // 3. Leave / End Call
                if service.session.isActive {
                    Button {
                        service.leaveMeeting()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.85))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.8)
                                )

                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .contentShape(Circle())
                    .buttonStyle(.plain)
                    .help(text("Leave Call", "통화 종료"))
                }
            }

            Spacer()

            // Right: Auxiliary App Controls (Open Google Meet / App Window / Copy Link)
            HStack(spacing: 6) {
                Button {
                    if let detectedPid = service.detectedPid, let app = NSRunningApplication(processIdentifier: detectedPid) {
                        app.activate(options: [.activateIgnoringOtherApps])
                    } else if let url = URL(string: "https://meet.google.com") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 11, weight: .semibold))
                        Text(text("Open Meet", "구글밋 열기"))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4.5)
                    .background(Color.white.opacity(0.1), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.7))
                }
                .buttonStyle(.plain)
                .help(text("Open Google Meet", "Google Meet 열기"))

                if service.session.meetingURL != nil {
                    Button {
                        service.copyMeetingLink()
                    } label: {
                        Image(systemName: "link")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .contentShape(Circle())
                    .buttonStyle(.plain)
                    .help(text("Copy Meeting Link", "미팅 링크 복사"))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PresentationVisibilityReader(isVisible: $isPresentationVisible).frame(width: 0, height: 0))
        .onChange(of: isPresentationVisible) { _, visible in
            if visible { service.acquirePresentation(presentationID) }
            else { service.releasePresentation(presentationID) }
        }
        .onDisappear { service.releasePresentation(presentationID) }
    }
}
