import SwiftUI

public struct MeetingNotchView: View {
    @ObservedObject var service: MeetingControlService
    var accentColor: Color

    public init(
        service: MeetingControlService = .shared,
        accentColor: Color = .blue
    ) {
        self.service = service
        self.accentColor = accentColor
    }

    private func text(_ en: String, _ ko: String) -> String {
        Locale.preferredLanguages.first?.hasPrefix("ko") == true ? ko : en
    }

    public var body: some View {
        VStack(spacing: 12) {
            headerBar

            if service.session.isActive {
                activeMeetingBentoGrid
            } else {
                idleMeetingBentoGrid
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 8) {
            // Platform Icon & Title
            HStack(spacing: 6) {
                Image(systemName: service.session.platform.iconName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(service.session.platform.accentColor)

                Text(service.session.isActive ? service.session.title : text("Meeting Control", "미팅 컨트롤"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Spacer()

            // Timer & Status Pill
            if service.session.isActive {
                HStack(spacing: 5) {
                    Circle()
                        .fill(service.session.isMuted ? Color.red : Color.green)
                        .frame(width: 7, height: 7)

                    Text(service.session.formattedDuration)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                        )
                )

                if service.session.meetingURL != nil {
                    Button {
                        service.copyMeetingLink()
                    } label: {
                        Image(systemName: "link")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help(text("Copy Meeting Link", "미팅 링크 복사"))
                }

                if service.detectedPid != nil {
                    Button {
                        service.activateMeetingApp()
                    } label: {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help(text("Open Meeting Window", "미팅 창 열기"))
                }
            } else {
                HStack(spacing: 5) {
                    Circle()
                        .fill(service.session.isMuted ? Color.red : Color.gray.opacity(0.6))
                        .frame(width: 7, height: 7)

                    Text(service.session.isMuted ? text("Muted", "음소거") : text("Ready", "대기 중"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.06)))
            }
        }
    }

    // MARK: - Active Meeting Bento Grid

    private var activeMeetingBentoGrid: some View {
        HStack(spacing: 10) {
            // 1. Mic Mute / Unmute Tile
            Button {
                service.toggleMute()
            } label: {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: service.session.isMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(service.session.isMuted ? .white : Color.green)

                        Spacer()

                        Text(service.session.isMuted ? text("MUTED", "음소거") : text("LIVE", "마이크 켜짐"))
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(service.session.isMuted ? .red : .green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill((service.session.isMuted ? Color.red : Color.green).opacity(0.18))
                            )
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 2) {
                        Text(service.session.isMuted ? text("Microphone Muted", "마이크 꺼짐") : text("Microphone On", "마이크 켜짐"))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)

                        Text(service.session.isMuted ? text("Tap to Unmute", "눌러서 음소거 해제") : text("Hardware Input 60%", "하드웨어 입력 활성"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(service.session.isMuted ? Color.red.opacity(0.15) : Color.green.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(
                                    (service.session.isMuted ? Color.red : Color.green).opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                )
            }
            .buttonStyle(.plain)

            // 2. Camera Toggle Tile
            Button {
                service.toggleCamera()
            } label: {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: service.session.isCameraOn ? "video.fill" : "video.slash.fill")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(service.session.isCameraOn ? accentColor : .white.opacity(0.5))

                        Spacer()

                        Text(service.session.isCameraOn ? text("ON", "켜짐") : text("OFF", "꺼짐"))
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(service.session.isCameraOn ? accentColor : .secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill((service.session.isCameraOn ? accentColor : Color.white.opacity(0.1)).opacity(0.18))
                            )
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 2) {
                        Text(service.session.isCameraOn ? text("Camera On", "카메라 켜짐") : text("Camera Off", "카메라 꺼짐"))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)

                        Text(text("Toggle Video", "비디오 전환"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(service.session.isCameraOn ? accentColor.opacity(0.12) : Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                        )
                )
            }
            .buttonStyle(.plain)

            // 3. Leave Call Tile
            Button {
                service.leaveMeeting()
            } label: {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)

                        Spacer()
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 2) {
                        Text(text("Leave Call", "통화 종료"))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)

                        Text(text("Disconnect", "미팅 나가기"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.red.opacity(0.75))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.8)
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .frame(height: 98)
    }

    // MARK: - Idle Meeting Bento Grid

    private var idleMeetingBentoGrid: some View {
        HStack(spacing: 10) {
            // 1. Universal Hardware Mic Mute Button (Droppy style)
            Button {
                service.toggleMute()
            } label: {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: service.session.isMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(service.session.isMuted ? .red : .green)

                        Spacer()

                        Text(service.session.isMuted ? text("MUTED", "음소거") : text("ACTIVE", "활성"))
                            .font(.system(size: 9.5, weight: .heavy))
                            .foregroundStyle(service.session.isMuted ? .red : .green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill((service.session.isMuted ? Color.red : Color.green).opacity(0.18))
                            )
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 2) {
                        Text(service.session.isMuted ? text("Mic Muted", "마이크 음소거") : text("System Mic On", "시스템 마이크 켜짐"))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)

                        Text(text("1-Click Hardware Mute", "클릭하여 즉시 음소거"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(service.session.isMuted ? Color.red.opacity(0.15) : Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(
                                    (service.session.isMuted ? Color.red.opacity(0.4) : Color.white.opacity(0.12)),
                                    lineWidth: 0.8
                                )
                        )
                )
            }
            .buttonStyle(.plain)

            // 2. Start Test Call / Quick Session
            Button {
                service.startMeetingSession(
                    title: text("Droppy Meeting Session", "Droppy 미팅 세션"),
                    platform: .meet
                )
            } label: {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.mint)

                        Spacer()
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 2) {
                        Text(text("Start Meeting Session", "미팅 세션 시작"))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)

                        Text(text("Track elapsed time & controls", "진행 시간 및 제어 추적"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                        )
                )
            }
            .buttonStyle(.plain)

            // 3. Quick Launch Meeting App Row
            VStack(spacing: 6) {
                Text(text("Quick Launch", "빠른 실행"))
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    quickLaunchButton(platform: .zoom, urlString: "zoommtg://")
                    quickLaunchButton(platform: .meet, urlString: "https://meet.google.com/new")
                    quickLaunchButton(platform: .teams, urlString: "msteams://")
                    quickLaunchButton(platform: .facetime, urlString: "facetime://")
                }
                .frame(maxWidth: .infinity)
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.8)
                    )
            )
        }
        .frame(height: 98)
    }

    private func quickLaunchButton(platform: MeetingPlatform, urlString: String) -> some View {
        Button {
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
                service.startMeetingSession(title: platform.displayName, platform: platform, url: url)
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: platform.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(platform.accentColor)

                Text(platform.displayName.components(separatedBy: " ").first ?? "")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
    }
}
