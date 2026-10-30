//
//  NotchieSoundMixerView.swift
//  DynamicNotch
//

internal import AppKit
import SwiftUI

struct NotchieSoundMixerView: View {
    var nowPlayingViewModel: NowPlayingViewModel?
    let accentColor: Color
    var onDismiss: () -> Void

    @StateObject private var mixer = SoundMixerService.shared

    private enum SoundHoverTarget: Equatable {
        case master
        case mic
        case app(String)
    }

    @State private var hoveredTarget: SoundHoverTarget? = nil
    @State private var scrollMonitor: Any? = nil

    init(
        nowPlayingViewModel: NowPlayingViewModel?,
        accentColor: Color,
        onDismiss: @escaping () -> Void
    ) {
        self.nowPlayingViewModel = nowPlayingViewModel
        self.accentColor = accentColor
        self.onDismiss = onDismiss
    }

    private var currentRouteName: String {
        nowPlayingViewModel?.currentAudioOutputRoute?.name
            ?? nowPlayingViewModel?.audioOutputRoutes.first(where: \.isCurrent)?.name
            ?? "MacBook Pro Speakers"
    }

    private var activePlayingBundleID: String? {
        nowPlayingViewModel?.snapshot?.playbackSource?.preferredBundleIdentifier
    }

    private var isActivelyPlaying: Bool {
        nowPlayingViewModel?.snapshot?.isPlaying == true
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Top Bar: Output Device Pill & Settings / Calendar Return
            HStack(spacing: 8) {
                outputDeviceMenuPill

                Spacer()

                // Settings Gear Button
                Button {
                    openSoundSettings()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .help(privacyText("Open Sound Settings", "사운드 설정 열기"))

                // Switch back to Calendar Schedule Button
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .help(privacyText("Return to Calendar", "캘린더로 돌아가기"))
            }

            // Sliders Row: Master | Mic | App 1 | App 2 | ...
            HStack(spacing: 12) {
                // Master Volume Column
                let isMasterHovered = hoveredTarget == .master
                VStack(spacing: 6) {
                    Button {
                        mixer.toggleMasterMute()
                    } label: {
                        Image(systemName: mixer.isMasterMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(mixer.isMasterMuted ? Color.gray : Color.white)
                            .frame(width: 28, height: 24)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)

                    VerticalCapsuleSlider(
                        value: Binding(
                            get: { mixer.masterVolume },
                            set: { mixer.setMasterVolume($0) }
                        )
                    )

                    Text("\(Int(mixer.masterVolume * 100))%")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 3)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isMasterHovered ? Color.white.opacity(0.08) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(isMasterHovered ? Color.white.opacity(0.18) : Color.clear, lineWidth: 0.8)
                )
                .contentShape(Rectangle())
                .onHover { isHovered in
                    handleHover(isHovered ? .master : nil)
                }
                .help(privacyText("Hover and scroll to adjust Master volume", "마우스를 올리고 스크롤하여 마스터 볼륨 조절"))
                .frame(width: 38)

                // Mic Volume Column
                let isMicHovered = hoveredTarget == .mic
                VStack(spacing: 6) {
                    Button {
                        mixer.toggleMicMute()
                    } label: {
                        Image(systemName: mixer.isMicMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(mixer.isMicMuted ? Color.gray : Color.white)
                            .frame(width: 28, height: 24)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)

                    VerticalCapsuleSlider(
                        value: Binding(
                            get: { mixer.micVolume },
                            set: { mixer.setMicVolume($0) }
                        )
                    )

                    Text("Mic")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.horizontal, 3)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isMicHovered ? Color.white.opacity(0.08) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(isMicHovered ? Color.white.opacity(0.18) : Color.clear, lineWidth: 0.8)
                )
                .contentShape(Rectangle())
                .onHover { isHovered in
                    handleHover(isHovered ? .mic : nil)
                }
                .help(privacyText("Hover and scroll to adjust Mic volume", "마우스를 올리고 스크롤하여 마이크 볼륨 조절"))
                .frame(width: 38)

                // Divider Line
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 1, height: 96)

                // Per-App Volume Sliders
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(mixer.audioApps) { app in
                            appVolumeColumn(app)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .onAppear {
            mixer.touchAdjustment()
            mixer.refreshSystemVolumes()
            mixer.refreshAudioApps(activePlayingBundleID: activePlayingBundleID, isPlaying: isActivelyPlaying)
        }
        .onDisappear {
            hoveredTarget = nil
            removeScrollMonitor()
        }
        .onHover { isHovering in
            if isHovering {
                mixer.touchAdjustment()
            }
        }
        .onChange(of: activePlayingBundleID) { _, newID in
            mixer.refreshAudioApps(activePlayingBundleID: newID, isPlaying: isActivelyPlaying)
        }
        .onChange(of: isActivelyPlaying) { _, playing in
            mixer.refreshAudioApps(activePlayingBundleID: activePlayingBundleID, isPlaying: playing)
        }
    }

    // MARK: - Hover & Scroll Wheel Volume Handler

    private func handleHover(_ target: SoundHoverTarget?) {
        hoveredTarget = target
        if target != nil {
            installScrollMonitorIfNeeded()
        } else {
            DispatchQueue.main.async {
                if self.hoveredTarget == nil {
                    self.removeScrollMonitor()
                }
            }
        }
    }

    private func installScrollMonitorIfNeeded() {
        guard scrollMonitor == nil else { return }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak mixer] event in
            guard let mixer = mixer else { return event }
            let deltaY = event.scrollingDeltaY
            let deltaX = event.scrollingDeltaX

            // If horizontal gesture is dominant, pass through to horizontal ScrollView
            if abs(deltaX) > abs(deltaY) {
                return event
            }

            guard abs(deltaY) > 0.05 else { return event }

            // Determine delta step based on trackpad vs discrete mouse wheel
            let step: Double
            if event.hasPreciseScrollingDeltas {
                step = Double(deltaY) * 0.005
            } else {
                step = Double(deltaY > 0 ? 0.04 : -0.04)
            }

            switch self.hoveredTarget {
            case .master:
                mixer.touchAdjustment()
                let newVol = min(max(mixer.masterVolume + step, 0.0), 1.0)
                mixer.setMasterVolume(newVol)
            case .mic:
                mixer.touchAdjustment()
                let newVol = min(max(mixer.micVolume + step, 0.0), 1.0)
                mixer.setMicVolume(newVol)
            case .app(let bundleID):
                mixer.touchAdjustment()
                let current = mixer.audioApps.first(where: { $0.id == bundleID })?.volume ?? 1.0
                let newVol = min(max(current + step, 0.0), 1.0)
                mixer.setAppVolume(bundleID: bundleID, volume: newVol)
            case .none:
                return event
            }

            return nil // Handled & consumed
        }
    }

    private func removeScrollMonitor() {
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
    }

    // MARK: - Output Device Menu Pill

    private var outputDeviceMenuPill: some View {
        Menu {
            if let routes = nowPlayingViewModel?.audioOutputRoutes, !routes.isEmpty {
                ForEach(routes) { route in
                    Button {
                        nowPlayingViewModel?.switchAudioOutput(to: route)
                    } label: {
                        HStack {
                            Image(systemName: route.systemImageName)
                            Text(route.name)
                            if route.isCurrent {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } else {
                Text("No audio outputs available")
            }
            Divider()
            Button(privacyText("Sound Settings…", "사운드 설정…")) {
                openSoundSettings()
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 9.5, weight: .semibold))
                Text(currentRouteName)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.1), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 0.8))
        }
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
    }

    // MARK: - Per-App Column View

    private func appVolumeColumn(_ app: AudioAppItem) -> some View {
        let isHovered = hoveredTarget == .app(app.id)
        return VStack(spacing: 6) {
            // App Icon with Green Dot Indicator if Actively Playing
            ZStack(alignment: .bottomTrailing) {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 22, height: 22)
                        .overlay(
                            Image(systemName: "app.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.8))
                        )
                }

                if app.isPlaying {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                        .overlay(Circle().strokeBorder(Color.black.opacity(0.8), lineWidth: 0.8))
                        .offset(x: 2, y: 2)
                }
            }
            .frame(width: 28, height: 24)

            // Vertical Capsule Slider
            VerticalCapsuleSlider(
                value: Binding(
                    get: { app.volume },
                    set: { mixer.setAppVolume(bundleID: app.id, volume: $0) }
                )
            )

            // Bottom Label: ↺ 40% 🔊
            HStack(spacing: 2) {
                if app.volume < 0.99 {
                    Button {
                        mixer.resetAppVolume(bundleID: app.id)
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }

                Text("\(Int(app.volume * 100))%")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Image(systemName: "speaker.wave.1.fill")
                    .font(.system(size: 6.5))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovered ? Color.white.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isHovered ? Color.white.opacity(0.18) : Color.clear, lineWidth: 0.8)
        )
        .contentShape(Rectangle())
        .onHover { isHovered in
            handleHover(isHovered ? .app(app.id) : nil)
        }
        .help(privacyText("Hover and scroll to adjust volume", "마우스를 올리고 스크롤하여 볼륨 조절"))
        .frame(width: 44)
    }

    private func openSoundSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension") {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        }
    }
}

// MARK: - Vertical Capsule Slider Component

public struct VerticalCapsuleSlider: View {
    @Binding var value: Double // 0.0 ... 1.0

    private let sliderWidth: CGFloat = 26
    private let sliderHeight: CGFloat = 66

    public var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let filledHeight = max(0, min(height, CGFloat(value) * height))

            ZStack(alignment: .bottom) {
                // Background Track
                Capsule()
                    .fill(Color(white: 0.16))

                // Filled Lower Portion
                Capsule()
                    .fill(Color.white)
                    .frame(height: filledHeight)
            }
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        SoundMixerService.shared.touchAdjustment()
                        let locationY = gesture.location.y
                        let progress = 1.0 - (locationY / height)
                        value = max(0.0, min(1.0, Double(progress)))
                    }
                    .onEnded { _ in
                        SoundMixerService.shared.touchAdjustment()
                    }
            )
        }
        .frame(width: sliderWidth, height: sliderHeight)
    }
}
