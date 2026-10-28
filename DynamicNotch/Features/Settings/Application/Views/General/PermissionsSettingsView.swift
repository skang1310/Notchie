import Combine
import SwiftUI

struct PermissionsSettingsView: View {
    @ObservedObject var permissionController: SettingsPermissionController
    @ObservedObject var applicationSettings: ApplicationSettingsStore
    @State private var imageAppear = false
    private let refreshTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    private func localized(_ key: String, fallback: String) -> String {
        applicationSettings.appLanguage.locale.dn(key, fallback: fallback)
    }

    private func text(_ en: String, _ ko: String) -> String {
        privacyText(en, ko)
    }

    var body: some View {
        SettingsPageScrollView {
            startupPermissionGuardCard
            permissionsCard
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                imageAppear = true
            }
            permissionController.refresh()
        }
        .onReceive(refreshTimer) { _ in
            permissionController.refresh()
        }
    }

    private var startupPermissionGuardCard: some View {
        let missing = permissionController.missingPermissionItems
        return SettingsCard(
            verbatimTitle: text("Startup Permission Check & Alert", "앱 시작 시 권한 확인 및 알림"),
            spacing: 12
        ) {
            HStack(spacing: 12) {
                Image(systemName: missing.isEmpty ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(missing.isEmpty ? .green : .orange)
                    .frame(width: 34, height: 34)
                    .background(
                        (missing.isEmpty ? Color.green : Color.orange).opacity(0.14),
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(
                        missing.isEmpty
                            ? text("All permissions are granted", "모든 권한이 허용되어 있습니다")
                            : text("\(missing.count) permission(s) currently need configuration", "현재 \(missing.count)개의 권한 설정이 필요합니다")
                    )
                    .font(.system(size: 13.5, weight: .semibold))

                    Text(
                        missing.isEmpty
                            ? text("Notchie has all required permissions to run every notch feature.", "모든 노치 기능을 제한 없이 사용할 수 있습니다.")
                            : text("Missing: \(permissionController.missingPermissionSummary)", "미설정 권한: \(permissionController.missingPermissionSummary)")
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                if !missing.isEmpty {
                    HStack(spacing: 6) {
                        Button(text("Fix Sync", "권한 인식 오류 해결")) {
                            permissionController.resetAndReRequestMissingPermissions()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help(text(
                            "Resets stale permission cache from older builds and re-requests permissions.",
                            "이전 빌드 서명으로 꼬인 macOS 권한 캐시를 초기화하고 다시 연결합니다."
                        ))
                        .accessibilityIdentifier("settings.permissions.fixSync")

                        Button(text("Request All Missing", "미설정 권한 모두 요청")) {
                            permissionController.requestUndeterminedPermissions()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .accessibilityIdentifier("settings.permissions.requestAll")
                    }
                }
            }

            if !missing.isEmpty {
                Text(text(
                    "Tip: If a permission is already turned ON in System Settings from an earlier build, click \"Fix Sync\" above or toggle its switch OFF and ON once in System Settings so macOS links it to the current certificate.",
                    "안내: 시스템 설정에서 이미 켜져 있는데도 '접근 필요'로 표시된다면, 위 [권한 인식 오류 해결] 버튼을 누르거나 시스템 설정에서 해당 스위치를 한 번 껐다가 다시 켜면 현재 인증서로 영구 연결됩니다."
                ))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Divider().opacity(0.6)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(text("Check & alert for missing permissions on app launch", "앱 시작 시 필수 권한 요청 및 미설정 알람 표시"))
                        .font(.system(size: 13, weight: .medium))
                    Text(text(
                        "Automatically asks for unconfigured permissions when Notchie starts and alerts you if any remain disabled.",
                        "Notchie를 시작할 때 필요한 권한을 자동으로 확인·요청하고, 설정되지 않은 권한이 있으면 알람으로 알려줍니다."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $applicationSettings.isStartupPermissionCheckEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .accessibilityIdentifier("settings.permissions.startupCheckToggle")
            }
        }
    }

    private var permissionsCard: some View {
        SettingsCard() {
            ForEach(Array(permissionController.permissionItems.enumerated()), id: \.element.id) { index, item in
                permissionRow(for: item)

                if index < permissionController.permissionItems.count - 1 {
                    Divider()
                        .opacity(0.6)
                        .padding(.leading, 43)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                }
            }
        }
    }

    @ViewBuilder
    private func permissionRow(for item: PermissionItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            if let assetImageName = item.assetImageName {
                SettingsIconBadge(
                    imageName: assetImageName,
                    tint: item.tintColor,
                    size: 30,
                    iconColor: item.iconColor,
                    iconSize: 14,
                    cornerRadius: 9
                )
            } else {
                SettingsIconBadge(
                    systemImage: item.systemImage,
                    tint: item.tintColor,
                    size: 30,
                    iconColor: item.iconColor,
                    iconSize: 14,
                    cornerRadius: 9
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    Text(localized(item.titleKey, fallback: item.fallbackTitle))

                    HStack(spacing: 5) {
                        Image(systemName: item.isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text(
                            localized(
                                item.isGranted ?
                                "settings.permissions.status.granted" :
                                "settings.permissions.status.needsAccess",
                                fallback: item.isGranted ? "Granted" : "Needs access"
                            )
                        )
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(item.isGranted ? .green : .orange)
                }

                Text(localized(item.descriptionKey, fallback: item.fallbackDescription))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            if let actionTitleKey = item.actionTitleKey,
               let fallbackActionTitle = item.fallbackActionTitle {
                Button(localized(actionTitleKey, fallback: fallbackActionTitle)) {
                    permissionController.performAction(for: item.kind)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityIdentifier("\(item.accessibilityIdentifier).action")
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
            }
        }
        .modifier(SettingsAccessibilityModifier(identifier: item.accessibilityIdentifier))
    }
}
