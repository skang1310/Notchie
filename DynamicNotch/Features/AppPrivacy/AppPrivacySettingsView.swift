import SwiftUI
import HeyMacEngine

struct AppPrivacySettingsView: View {
    @ObservedObject private var privacy = AppPrivacyController.shared
    @State private var selectedApp = ""
    @State private var query = ""
    private var candidates: [InstalledApp] {
        privacy.availableApps.filter { app in
            !privacy.apps.contains(where: { $0.bundleID == app.bundleID }) &&
            (query.isEmpty || app.name.localizedCaseInsensitiveContains(query))
        }
    }
    private var status: String {
        if !privacy.enabled { return privacyText("App privacy is off", "앱 프라이버시 꺼짐") }
        if privacy.pausedSeconds > 0 {
            return privacyText("Resumes in ", "다시 시작까지 ") + "\((privacy.pausedSeconds + 59) / 60)" + privacyText(" min", "분")
        }
        return privacyText("App privacy is on", "앱 프라이버시 켜짐")
    }
    var body: some View {
        SettingsFeatureHeader(
            title: privacyText("App privacy", "앱 프라이버시"),
            subtitle: privacyText("Hide selected apps until you authenticate. Works while Notchie is running.", "선택한 앱을 가리고 인증 후 표시합니다. Notchie 실행 중에만 작동합니다."),
            symbol: "lock.shield", status: status,
            active: privacy.enabled && privacy.pausedSeconds == 0
        )
        SettingsCard {
            SettingsPreferenceRow(privacyText("App privacy", "앱 프라이버시"), detail: privacyText("Require authentication for the apps you choose.", "선택한 앱을 사용하기 전에 인증합니다.")) {
                Toggle(privacyText("Enable app privacy", "앱 프라이버시 켜기"), isOn: Binding(get: { privacy.enabled }, set: { privacy.setEnabled($0) }))
                    .labelsHidden().toggleStyle(.switch)
            }
            Divider()
            SettingsPreferenceRow(privacyText("Use your registered face", "등록된 얼굴 사용"), detail: privacyText("Try face recognition before Touch ID or Mac password.", "Touch ID·Mac 암호 인증 전에 얼굴을 확인합니다.")) {
                Toggle(privacyText("Use registered face", "등록된 얼굴로 인증"), isOn: Binding(get: { privacy.useFace }, set: { privacy.setUseFace($0) }))
                    .labelsHidden().toggleStyle(.switch)
            }
        }
        SettingsCard(verbatimTitle: privacyText("Protected apps", "보호할 앱"), spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary).accessibilityHidden(true)
                TextField(privacyText("Find an installed app", "설치된 앱 검색"), text: $query).textFieldStyle(.roundedBorder)
                Button { privacy.refreshAvailableApps() } label: { Image(systemName: "arrow.clockwise") }
                    .help(privacyText("Refresh installed apps", "설치된 앱 새로고침"))
                    .accessibilityLabel(privacyText("Refresh installed apps", "설치된 앱 새로고침"))
                    .disabled(privacy.scanningApps)
            }
            HStack(spacing: 12) {
                Picker(privacyText("App", "앱"), selection: $selectedApp) {
                    Text(privacyText("Choose an app…", "앱 선택…")).tag("")
                    ForEach(candidates) { app in Text(app.name).tag(app.bundleID) }
                }.frame(maxWidth: .infinity)
                Button(privacyText("Add app", "앱 추가")) {
                    if let app = candidates.first(where: { $0.bundleID == selectedApp }) { privacy.add(app) }
                    selectedApp = ""
                }
                .disabled(!candidates.contains(where: { $0.bundleID == selectedApp }))
            }
            if privacy.scanningApps { ProgressView().controlSize(.small) }
            if privacy.apps.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "app.dashed").font(.system(size: 26, weight: .light)).foregroundStyle(.secondary)
                    Text(privacyText("Your apps, your choice", "보호할 앱을 추가하세요")).font(.body.weight(.medium))
                    Text(privacyText("Nothing is locked until you add apps and turn on App privacy.", "앱을 추가하고 앱 프라이버시를 켜기 전에는 잠기는 앱이 없습니다."))
                        .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity).padding(.vertical, 20)
            }
            ForEach(privacy.apps) { app in
                Divider()
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "app.fill").font(.title2).foregroundStyle(.secondary).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(app.name).font(.body.weight(.medium))
                            Spacer()
                            Button { privacy.remove(app.bundleID) } label: { Image(systemName: "minus.circle") }
                                .buttonStyle(.borderless)
                                .help(privacyText("Remove ", "제거: ") + app.name)
                                .accessibilityLabel(privacyText("Remove ", "제거: ") + app.name)
                        }
                        Picker(privacyText("Authenticate again", "다시 인증"), selection: Binding(get: { policyCode(app.policy) }, set: { privacy.setPolicy(policy($0), for: app.bundleID) })) {
                            Text(privacyText("After every app switch", "앱을 전환할 때마다")).tag(0)
                            Text(privacyText("5 minutes after unlock", "잠금 해제 후 5분")).tag(5)
                            Text(privacyText("15 minutes after unlock", "잠금 해제 후 15분")).tag(15)
                            Text(privacyText("5 minutes after leaving", "앱에서 벗어난 후 5분")).tag(105)
                            Text(privacyText("15 minutes after leaving", "앱에서 벗어난 후 15분")).tag(115)
                        }
                    }
                }.padding(.vertical, 4)
            }
            Text(privacyText("Recovery tools such as Finder, System Settings and Terminal are excluded.", "Finder·시스템 설정·터미널 등 복구에 필요한 앱은 제외됩니다."))
                .font(.caption).foregroundStyle(.secondary)
        }
        .onAppear { privacy.refreshAvailableApps() }
        SettingsCard(verbatimTitle: privacyText("Quick actions", "빠른 동작")) {
            SettingsPreferenceRow(privacyText("Check your privacy screen", "가림 화면 확인"), detail: privacyText("Preview the cover without locking an app.", "앱을 잠그지 않고 가림 화면을 살펴봅니다.")) {
                Button(privacyText("Preview", "미리보기")) { privacy.preview() }.modifier(SettingsSecondaryAction())
            }
            Divider()
            HStack(spacing: 12) {
                Button(privacyText("Relock all now", "모두 다시 잠금")) { privacy.relockAll() }
                Menu(privacyText("Pause…", "일시 정지…")) {
                    Button(privacyText("5 minutes", "5분")) { privacy.pause(minutes: 5) }
                    Button(privacyText("15 minutes", "15분")) { privacy.pause(minutes: 15) }
                }
                Spacer(minLength: 0)
            }.disabled(!privacy.enabled).padding(.vertical, 5)
            if !privacy.message.isEmpty { Text(privacy.message).font(.callout).foregroundStyle(.secondary) }
        }
        SettingsCard {
            DisclosureGroup(privacyText("Authentication and privacy", "인증 및 개인정보 안내")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(privacyText("Touch ID or Mac password works without face enrollment or saving a password in this app. Camera is used only after you press Authenticate and only if already authorized.", "얼굴 등록이나 이 앱에 암호를 저장하지 않아도 Touch ID·Mac 암호를 사용할 수 있습니다. 카메라는 이미 권한이 있을 때 인증하기를 누른 뒤에만 사용합니다."))
                    Text(privacyText("This cover does not encrypt app data or replace macOS access controls.", "이 가림 화면은 앱 데이터를 암호화하거나 macOS 접근 제어를 대체하지 않습니다."))
                }.font(.callout).foregroundStyle(.secondary).padding(.top, 10)
            }
        }
    }
    private func policyCode(_ policy: RelockPolicy) -> Int {
        switch policy {
        case .everyTime: return 0
        case .afterMinutes(let minutes): return minutes
        case .afterFocusLossMinutes(let minutes): return 100 + minutes
        }
    }
    private func policy(_ code: Int) -> RelockPolicy {
        switch code {
        case 5, 15: return .afterMinutes(code)
        case 105, 115: return .afterFocusLossMinutes(code - 100)
        default: return .everyTime
        }
    }
}
