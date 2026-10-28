import SwiftUI
internal import AppKit

struct FaceIDSettingsView: View {
    @ObservedObject var settings: FaceIDSettingsStore
    @ObservedObject var applicationSettings: ApplicationSettingsStore
    var notchViewModel: NotchViewModel?
    @ObservedObject private var unlock = HeyMacFaceUnlockController.shared
    @State private var section = "face"
    @State private var password = ""
    @State private var editingPassword = false
    @State private var confirmRemoval = false
    @State private var previewScanMedia: ScanMedia = .scanning
    @State private var previewUnlocked: Bool = false
    @State private var previewCycleToken = UUID()

    private func text(_ en: String, _ ko: String) -> String { privacyText(en, ko) }

    var body: some View {
        SettingsPageScrollView {
            Picker(text("Security feature", "보안 기능"), selection: $section) {
                Text(text("Face unlock", "얼굴 잠금 해제")).tag("face")
                Text(text("App privacy", "앱 프라이버시")).tag("apps")
            }
            .pickerStyle(.segmented).labelsHidden()
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
            if section == "apps" {
                AppPrivacySettingsView()
            } else {
                faceSettings
            }
        }
        .onAppear {
            startInlinePreviewCycle()
        }
        .onChange(of: section) { _, _ in password = ""; editingPassword = false; unlock.cancel() }
        .onDisappear { password = ""; unlock.cancel() }
        .confirmationDialog(text("Remove this app's saved face and password?", "이 앱에 저장된 얼굴과 암호를 삭제할까요?"), isPresented: $confirmRemoval) {
            Button(text("Remove", "삭제"), role: .destructive) { unlock.removeData() }
        }
    }

    private var faceSettings: some View {
        Group {
            SettingsFeatureHeader(
                title: text("Unlock with a glance", "시선으로 잠금 해제"),
                subtitle: text("Uses your Mac's regular camera. Different from Apple Face ID.", "Mac의 일반 카메라를 사용합니다. Apple Face ID와는 다릅니다."),
                symbol: "faceid",
                status: unlock.enabled ? text("Face unlock is on", "얼굴 잠금 해제 켜짐") : text("Face unlock is off", "얼굴 잠금 해제 꺼짐"),
                active: unlock.enabled
            )
            SettingsCard {
                SettingsPreferenceRow(text("Face unlock", "얼굴 잠금 해제"), detail: text("Check your face when the Mac is locked.", "Mac이 잠겨 있을 때 등록된 얼굴을 확인합니다.")) {
                    Toggle(text("Enable face unlock", "얼굴 잠금 해제 켜기"), isOn: Binding(get: { unlock.enabled }, set: { unlock.setEnabled($0) }))
                        .labelsHidden().toggleStyle(.switch).disabled(unlock.busy)
                }
            }
            notchPresentationStyleCard
            SettingsCard(verbatimTitle: text("Set up this Mac", "이 Mac에서 설정"), spacing: 12) {
                SettingsPreferenceRow(text("Your face", "얼굴"), detail: unlock.enrolled ? text("Registered on this Mac", "이 Mac에 등록됨") : text("Register and verify your face to get started.", "얼굴을 등록하고 인식을 확인하세요.")) {
                    HStack(spacing: 8) {
                        if unlock.enrolled {
                            Button(text("Test", "인식 테스트")) { unlock.testFace() }
                                .modifier(SettingsPrimaryAction())
                            Button(text("Register again…", "다시 등록…")) { unlock.enroll() }
                        } else {
                            Button(text("Register…", "등록…")) { unlock.enroll() }
                                .modifier(SettingsPrimaryAction())
                        }
                    }.disabled(unlock.busy || unlock.enabled)
                }
                Divider()
                SettingsPreferenceRow(text("Login password", "로그인 암호"), detail: unlock.hasPassword ? text("Saved with encryption on this Mac", "이 Mac에 암호화하여 저장됨") : text("Used only after your face is verified.", "얼굴이 확인된 뒤에만 대신 입력합니다.")) {
                    if unlock.hasPassword && !editingPassword {
                        Button(text("Change…", "변경…")) { editingPassword = true }
                            .disabled(unlock.busy || unlock.enabled)
                    }
                }
                if !unlock.hasPassword || editingPassword {
                    HStack(spacing: 10) {
                        SecureField(text("Mac login password", "Mac 로그인 암호"), text: $password)
                            .textFieldStyle(.roundedBorder)
                            .disabled(unlock.busy || unlock.enabled)
                        Button(text("Save password", "암호 저장")) {
                            unlock.savePassword(password); password = ""; editingPassword = false
                        }
                        .disabled(password.isEmpty || !unlock.enrolled || unlock.busy || unlock.enabled)
                    }
                }
                Divider()
                SettingsPreferenceRow(text("Accessibility", "손쉬운 사용"), detail: text("Allow Notchie to type at the login screen.", "로그인 화면에 암호를 입력하려면 권한이 필요합니다.")) {
                    Button(text("Open Settings…", "설정 열기…")) {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") { NSWorkspace.shared.open(url) }
                    }
                }
            }
            if unlock.busy || !unlock.status.isEmpty {
                SettingsCard {
                    HStack(spacing: 12) {
                        if unlock.busy { ProgressView().controlSize(.small) }
                        if !unlock.status.isEmpty { Text(unlock.status).font(.callout).textSelection(.enabled) }
                        Spacer(minLength: 0)
                        if unlock.busy { Button(text("Cancel", "취소")) { unlock.cancel() } }
                    }.accessibilityElement(children: .contain)
                }
            }
            SettingsCard(verbatimTitle: text("About face unlock", "얼굴 잠금 해제에 관하여")) {
                DisclosureGroup(text("Security and how it works", "보안 및 작동 방식")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(text("A verified camera match types your encrypted, saved login password. Photo and screen rejection is not depth-sensor security.", "카메라로 얼굴이 확인되면 암호화해 저장한 로그인 암호를 대신 입력합니다. 사진·화면 감지는 깊이 센서 수준의 보안을 제공하지 않습니다."))
                        Text(text("Camera and Accessibility access are required. This cannot unlock FileVault after a restart. Login launch is not enabled automatically.", "카메라와 손쉬운 사용 권한이 필요합니다. 재시동 후 FileVault 잠금은 해제할 수 없으며, 로그인 시 실행은 자동으로 켜지지 않습니다."))
                        Link(text("HeyMac source and license", "HeyMac 소스 및 라이선스"), destination: URL(string: "https://github.com/iharshitmaurya/HeyMac")!)
                    }.font(.callout).foregroundStyle(.secondary).padding(.top, 10)
                }
                Divider()
                SettingsPreferenceRow(text("Saved data", "저장된 데이터"), detail: text("Remove this app's face registration and saved password.", "이 앱의 얼굴 등록과 저장된 암호를 삭제합니다.")) {
                    Button(text("Remove…", "삭제…"), role: .destructive) { confirmRemoval = true }
                        .disabled(unlock.busy || (!unlock.enrolled && !unlock.hasPassword))
                }
            }
        }
    }

    private var notchPresentationStyleCard: some View {
        SettingsCard(
            verbatimTitle: text("Notch Unlock Style & Preview", "노치 잠금 해제 스타일 및 미리보기"),
            spacing: 12
        ) {
            HStack {
                Text(text(
                    "Choose how the face scan animation appears in the notch and preview it directly at the top of your screen.",
                    "얼굴 인식 시 노치에 표시될 스캔 애니메이션 스타일(오리지널 배지 vs 미니멀)을 선택하고 실제 노치에서 바로 미리볼 수 있습니다."
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
                Spacer()
                Button {
                    startInlinePreviewCycle()
                } label: {
                    Label(text("Replay", "다시 재생"), systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            HStack(spacing: 12) {
                styleOptionCard(
                    style: .expanded,
                    title: text("Original", "오리지널 (Original)"),
                    subtitle: text("A full badge that plays the scan.", "전체 배지가 내려와 스캔 애니메이션을 재생합니다.")
                ) {
                    originalInlinePreview
                }

                styleOptionCard(
                    style: .compact,
                    title: text("Minimal", "미니멀 (Minimal)"),
                    subtitle: text("Compact lock icon and scan bar inside the notch.", "노치 좌우에 자물쇠와 스캔 아이콘을 미니멀하게 표시합니다.")
                ) {
                    minimalInlinePreview
                }
            }
        }
    }

    private func styleOptionCard<Preview: View>(
        style: FaceIDPresentationStyle,
        title: String,
        subtitle: String,
        @ViewBuilder preview: () -> Preview
    ) -> some View {
        let isSelected = settings.presentationStyle == style
        let accent = applicationSettings.customAccentColor
        return VStack(alignment: .leading, spacing: 10) {
            preview()
                .frame(maxWidth: .infinity)
                .frame(height: 128)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.11, green: 0.13, blue: 0.18),
                            Color(red: 0.06, green: 0.07, blue: 0.10)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(isSelected ? accent : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    settings.presentationStyle = style
                }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? accent : .secondary)
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                settings.presentationStyle = style
            }

            Button {
                settings.presentationStyle = style
                startInlinePreviewCycle()
                FaceIDService.shared.playNotchPreview(style: style, in: notchViewModel)
            } label: {
                Label(
                    text("Preview in Notch", "노치에서 미리보기"),
                    systemImage: "menubar.dock.rectangle"
                )
                .font(.caption.weight(.medium))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityIdentifier("settings.faceid.preview.\(style.rawValue)")
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(isSelected ? accent.opacity(0.08) : Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(isSelected ? accent.opacity(0.65) : Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var originalInlinePreview: some View {
        let accent = applicationSettings.customAccentColor
        return VStack(spacing: 0) {
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 18)

                VStack(spacing: 4) {
                    Capsule()
                        .fill(Color.white.opacity(0.16))
                        .frame(width: 44, height: 4)
                        .padding(.top, 5)

                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [accent.opacity(0.24), .clear],
                                    center: .center,
                                    startRadius: 2,
                                    endRadius: 34
                                )
                            )
                            .frame(width: 68, height: 68)

                        ScanAnimationView(media: previewScanMedia, tintColor: accent)
                            .frame(width: 58, height: 58)
                    }
                    .padding(.bottom, 8)
                }
                .frame(width: 132)
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 4,
                        bottomLeadingRadius: 26,
                        bottomTrailingRadius: 26,
                        topTrailingRadius: 4,
                        style: .continuous
                    )
                    .fill(Color.black)
                    .overlay(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 4,
                            bottomLeadingRadius: 26,
                            bottomTrailingRadius: 26,
                            topTrailingRadius: 4,
                            style: .continuous
                        )
                        .strokeBorder(accent.opacity(0.35), lineWidth: 1)
                    )
                )
            }
            Spacer(minLength: 0)
        }
    }

    private var minimalInlinePreview: some View {
        let accent = applicationSettings.customAccentColor
        return VStack(spacing: 0) {
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 18)

                HStack {
                    Image(systemName: previewUnlocked ? "lock.open.fill" : "lock.fill")
                        .contentTransition(.symbolEffect(.replace))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(previewUnlocked ? accent : .white)

                    Spacer()

                    Capsule()
                        .fill(Color.white.opacity(0.14))
                        .frame(width: 36, height: 4)

                    Spacer()

                    ScanAnimationView(media: previewScanMedia, tintColor: accent)
                        .frame(width: 22, height: 22)
                }
                .padding(.horizontal, 12)
                .frame(width: 168, height: 34)
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 4,
                        bottomLeadingRadius: 14,
                        bottomTrailingRadius: 14,
                        topTrailingRadius: 4,
                        style: .continuous
                    )
                    .fill(Color.black)
                    .overlay(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 4,
                            bottomLeadingRadius: 14,
                            bottomTrailingRadius: 14,
                            topTrailingRadius: 4,
                            style: .continuous
                        )
                        .strokeBorder(accent.opacity(0.35), lineWidth: 1)
                    )
                )
            }
            Spacer(minLength: 0)
            Text(previewUnlocked ? text("Unlocked", "잠금 해제됨") : text("Scanning…", "얼굴 스캔 중…"))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(previewUnlocked ? accent : .secondary)
                .padding(.bottom, 10)
        }
    }

    private func startInlinePreviewCycle() {
        let token = UUID()
        previewCycleToken = token
        previewScanMedia = .scanning
        previewUnlocked = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.65) {
            guard previewCycleToken == token else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                previewScanMedia = .success
                previewUnlocked = true
            }
        }
    }
}
