import SwiftUI

struct AppPrivacyCoverView: View {
    @ObservedObject var controller: AppPrivacyController
    var body: some View {
        ZStack {
            // Keep the privacy surface opaque. Glass belongs to the controls above it.
            Color(red: 0.045, green: 0.05, blue: 0.065)
            VStack(spacing: 20) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 46, weight: .light))
                    .foregroundStyle(.white.opacity(0.9))
                    .accessibilityHidden(true)
                VStack(spacing: 10) {
                    Text(controller.shieldName).font(.system(size: 28, weight: .semibold)).multilineTextAlignment(.center)
                    Text(controller.message).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                if controller.authenticating { ProgressView().controlSize(.large) }
                if controller.previewing {
                    Button(privacyText("Back to settings", "설정으로 돌아가기")) { controller.goBack() }
                        .modifier(SettingsPrimaryAction()).controlSize(.large)
                        .keyboardShortcut(.defaultAction)
                } else {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Button(privacyText("Authenticate", "인증하기")) { controller.authenticate() }
                                .modifier(SettingsPrimaryAction())
                                .keyboardShortcut(.defaultAction)
                            Button(privacyText("Touch ID / Mac password", "Touch ID / Mac 암호")) { controller.authenticate(systemOnly: true) }
                                .modifier(SettingsSecondaryAction())
                        }.controlSize(.large).disabled(controller.authenticating)
                        Button(privacyText("Back to settings", "설정으로 돌아가기")) { controller.goBack() }
                            .buttonStyle(.borderless)
                    }
                    Text(privacyText("Going back keeps the app hidden.", "돌아가면 대상 앱은 숨긴 상태로 유지됩니다."))
                        .font(.callout).foregroundStyle(.secondary)
                }
            }.padding(48).frame(maxWidth: 620)
        }.foregroundStyle(.white).preferredColorScheme(.dark).ignoresSafeArea()
    }
}
