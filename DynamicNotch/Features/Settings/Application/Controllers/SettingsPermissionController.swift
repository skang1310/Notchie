import Combine
import CoreBluetooth
import Foundation
internal import AppKit
import SwiftUI
import AVFoundation
internal import EventKit

#if canImport(ApplicationServices)
import ApplicationServices
import CoreServices
#endif

enum Kind: String {
    case accessibility
    case bluetooth
    case mediaControls
    case camera
    case calendar
    case fullDiskAccess
    case automation
}

struct PermissionItem: Identifiable {
    let kind: Kind
    let titleKey: String
    let fallbackTitle: String
    let descriptionKey: String
    let fallbackDescription: String
    let assetImageName: String?
    let systemImage: String
    let tintColor: Color
    let iconColor: Color
    let isGranted: Bool
    let actionTitleKey: String?
    let fallbackActionTitle: String?
    let accessibilityIdentifier: String

    init(
        kind: Kind,
        titleKey: String,
        fallbackTitle: String,
        descriptionKey: String,
        fallbackDescription: String,
        assetImageName: String? = nil,
        systemImage: String,
        tintColor: Color,
        iconColor: Color = .white,
        isGranted: Bool,
        actionTitleKey: String?,
        fallbackActionTitle: String?,
        accessibilityIdentifier: String
    ) {
        self.kind = kind
        self.titleKey = titleKey
        self.fallbackTitle = fallbackTitle
        self.descriptionKey = descriptionKey
        self.fallbackDescription = fallbackDescription
        self.assetImageName = assetImageName
        self.systemImage = systemImage
        self.tintColor = tintColor
        self.iconColor = iconColor
        self.isGranted = isGranted
        self.actionTitleKey = actionTitleKey
        self.fallbackActionTitle = fallbackActionTitle
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    var id: String { kind.rawValue }
}

@MainActor
final class SettingsPermissionController: NSObject, ObservableObject, CBCentralManagerDelegate {
    static let shared = SettingsPermissionController()

    @Published private(set) var isAccessibilityTrusted: Bool
    @Published private(set) var bluetoothAuthorization: CBManagerAuthorization
    @Published private(set) var canPostMediaKeyEvents: Bool
    @Published private(set) var cameraAuthorization: AVAuthorizationStatus
    @Published private(set) var calendarAuthorization: EKAuthorizationStatus
    @Published private(set) var isFullDiskAccessGranted: Bool
    @Published private(set) var isAutomationAccessGranted: Bool

    private var didPromptForAccessibility = false
    private var didPromptForPostEventAccess = false
    private var didPromptForCameraAccess = false
    private var didPromptForCalendarAccess = false
    private var didPromptForAutomationAccess = false
    private var bluetoothPermissionRequester: CBCentralManager?
    private var cancellables = Set<AnyCancellable>()

    private static let privacySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )
    private static let bluetoothPrivacySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth"
    )
    private static let cameraPrivacySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
    )
    private static let calendarPrivacySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
    )
    private static let fullDiskAccessPrivacySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
    )
    private static let automationPrivacySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
    )

    init(notificationCenter: NotificationCenter = .default) {
        self.bluetoothAuthorization = Self.currentBluetoothAuthorizationStatus()
        self.isAccessibilityTrusted = Self.currentAccessibilityTrustState()
        self.canPostMediaKeyEvents = Self.currentPostEventAccessState()
        self.cameraAuthorization = AVCaptureDevice.authorizationStatus(for: .video)
        self.calendarAuthorization = EKEventStore.authorizationStatus(for: .event)
        self.isFullDiskAccessGranted = FullDiskAccessAuthorization.hasPermission()
        self.isAutomationAccessGranted = Self.currentAutomationAccessState()

        super.init()

        notificationCenter.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
    }

    func refresh() {
        bluetoothAuthorization = Self.currentBluetoothAuthorizationStatus()
        isAccessibilityTrusted = Self.currentAccessibilityTrustState()
        canPostMediaKeyEvents = Self.currentPostEventAccessState()
        cameraAuthorization = AVCaptureDevice.authorizationStatus(for: .video)
        calendarAuthorization = EKEventStore.authorizationStatus(for: .event)
        isFullDiskAccessGranted = FullDiskAccessAuthorization.hasPermission()
        isAutomationAccessGranted = Self.currentAutomationAccessState()
    }

    var permissionItems: [PermissionItem] {
        [
            PermissionItem(
                kind: .accessibility,
                titleKey: "settings.permissions.accessibility.title",
                fallbackTitle: "Accessibility",
                descriptionKey: "settings.permissions.accessibility.description",
                fallbackDescription: "Allow Accessibility access to use custom volume and brightness HUD controls.",
                systemImage: "hand.raised.fill",
                tintColor: .orange,
                isGranted: isAccessibilityTrusted,
                actionTitleKey: isAccessibilityTrusted ? nil : (
                    didPromptForAccessibility ?
                    "settings.permissions.action.openPrivacySettings" :
                    "settings.permissions.action.grantAccess"
                ),
                fallbackActionTitle: isAccessibilityTrusted ? nil : (
                    didPromptForAccessibility ? "Open Privacy Settings" : "Grant Access"
                ),
                accessibilityIdentifier: "settings.permissions.accessibility"
            ),
            PermissionItem(
                kind: .bluetooth,
                titleKey: "settings.permissions.bluetooth.title",
                fallbackTitle: "Bluetooth",
                descriptionKey: "settings.permissions.bluetooth.description",
                fallbackDescription: "Allow Bluetooth access to read battery levels from supported accessories.",
                assetImageName: "bluetooth.white",
                systemImage: "dot.radiowaves.left.and.right",
                tintColor: .blue,
                isGranted: bluetoothAuthorization == .allowedAlways,
                actionTitleKey: bluetoothActionTitleKey,
                fallbackActionTitle: bluetoothFallbackActionTitle,
                accessibilityIdentifier: "settings.permissions.bluetooth"
            ),
            PermissionItem(
                kind: .camera,
                titleKey: "settings.permissions.camera.title",
                fallbackTitle: "Camera",
                descriptionKey: "settings.permissions.camera.description",
                fallbackDescription: "Allow Camera access to display a camera preview in the notch.",
                assetImageName: nil,
                systemImage: "camera.fill",
                tintColor: .gray,
                iconColor: .black,
                isGranted: cameraAuthorization == .authorized,
                actionTitleKey: cameraActionTitleKey,
                fallbackActionTitle: cameraFallbackActionTitle,
                accessibilityIdentifier: "settings.permissions.camera"
            ),
            PermissionItem(
                kind: .mediaControls,
                titleKey: "settings.permissions.mediaControls.title",
                fallbackTitle: "Media Controls",
                descriptionKey: "settings.permissions.mediaControls.description",
                fallbackDescription: "Allow media control event access so play, pause, and track buttons work from Now Playing.",
                systemImage: "music.note",
                tintColor: .red,
                isGranted: canPostMediaKeyEvents,
                actionTitleKey: canPostMediaKeyEvents ? nil : (
                    didPromptForPostEventAccess ?
                    "settings.permissions.action.openPrivacySettings" :
                    "settings.permissions.action.grantAccess"
                ),
                fallbackActionTitle: canPostMediaKeyEvents ? nil : (
                    didPromptForPostEventAccess ? "Open Privacy Settings" : "Grant Access"
                ),
                accessibilityIdentifier: "settings.permissions.mediaControls"
            ),
            PermissionItem(
                kind: .fullDiskAccess,
                titleKey: "settings.permissions.fullDiskAccess.title",
                fallbackTitle: "Full Disk Access",
                descriptionKey: "settings.permissions.fullDiskAccess.description",
                fallbackDescription: "Allow Full Disk Access to display real names and custom icons of Focus modes.",
                systemImage: "opticaldiscdrive.fill",
                tintColor: .gray,
                isGranted: isFullDiskAccessGranted,
                actionTitleKey: isFullDiskAccessGranted ? nil : "settings.permissions.action.openPrivacySettings",
                fallbackActionTitle: isFullDiskAccessGranted ? nil : "Open Privacy Settings",
                accessibilityIdentifier: "settings.permissions.fullDiskAccess"
            ),
            PermissionItem(
                kind: .calendar,
                titleKey: "settings.permissions.calendar.title",
                fallbackTitle: "Calendar",
                descriptionKey: "settings.permissions.calendar.description",
                fallbackDescription: "Allow Calendar access to display your upcoming events.",
                assetImageName: nil,
                systemImage: "calendar",
                tintColor: .blue,
                isGranted: Self.isCalendarAuthorized(calendarAuthorization),
                actionTitleKey: calendarActionTitleKey,
                fallbackActionTitle: calendarFallbackActionTitle,
                accessibilityIdentifier: "settings.permissions.calendar"
            ),
            PermissionItem(
                kind: .automation,
                titleKey: "settings.permissions.automation.title",
                fallbackTitle: "Automation (System Events)",
                descriptionKey: "settings.permissions.automation.description",
                fallbackDescription: "Allow control over System Events to center screen recording and screenshot preview windows.",
                assetImageName: nil,
                systemImage: "gearshape.2.fill",
                tintColor: .gray,
                isGranted: isAutomationAccessGranted,
                actionTitleKey: isAutomationAccessGranted ? nil : (
                    didPromptForAutomationAccess ?
                    "settings.permissions.action.openPrivacySettings" :
                    "settings.permissions.action.grantAccess"
                ),
                fallbackActionTitle: isAutomationAccessGranted ? nil : (
                    didPromptForAutomationAccess ? "Open Privacy Settings" : "Grant Access"
                ),
                accessibilityIdentifier: "settings.permissions.automation"
            )
        ]
    }

    var missingPermissionItems: [PermissionItem] {
        permissionItems.filter { !$0.isGranted }
    }

    var allPermissionsGranted: Bool {
        missingPermissionItems.isEmpty
    }

    var missingPermissionSummary: String {
        let locale = DynamicNotchLanguage.resolved(
            UserDefaults.standard.string(forKey: GeneralSettingsStorage.Keys.appLanguage)
        ).locale
        return missingPermissionItems
            .map { locale.dn($0.titleKey, fallback: $0.fallbackTitle) }
            .joined(separator: ", ")
    }

    static func isCalendarAuthorized(_ status: EKAuthorizationStatus) -> Bool {
        switch status {
        case .fullAccess, .writeOnly, .authorized:
            return true
        default:
            return false
        }
    }

    func requestUndeterminedPermissions() {
        guard !AppEnvironment.isRunningTests else { return }
        refresh()

        if !isAccessibilityTrusted {
            requestAccessibilityAccess()
        }
        if !canPostMediaKeyEvents {
            requestPostEventAccess()
        }
        if bluetoothAuthorization == .notDetermined {
            requestBluetoothAccess()
        }
        if cameraAuthorization == .notDetermined {
            requestCameraAccess()
        }
        if calendarAuthorization == .notDetermined {
            requestCalendarAccess()
        }
        if !isAutomationAccessGranted {
            requestAutomationAccess()
        }
        refresh()
    }

    func resetAndReRequestMissingPermissions() {
        guard !AppEnvironment.isRunningTests else { return }
        refresh()

        let bundleID = Bundle.main.bundleIdentifier ?? "com.Jackson.DynamicNotch"
        var servicesToReset: [String] = []

        if !isAccessibilityTrusted || !canPostMediaKeyEvents {
            servicesToReset.append("Accessibility")
            servicesToReset.append("PostEvent")
            didPromptForAccessibility = false
            didPromptForPostEventAccess = false
        }
        if cameraAuthorization != .authorized {
            servicesToReset.append("Camera")
            didPromptForCameraAccess = false
        }
        if !Self.isCalendarAuthorized(calendarAuthorization) {
            servicesToReset.append("Calendar")
            didPromptForCalendarAccess = false
        }
        if bluetoothAuthorization != .allowedAlways {
            servicesToReset.append("BluetoothAlways")
            bluetoothPermissionRequester = nil
        }
        if !isAutomationAccessGranted {
            servicesToReset.append("AppleEvents")
            didPromptForAutomationAccess = false
        }

        for service in servicesToReset {
            Self.runTCCReset(service: service, bundleIdentifier: bundleID)
        }

        refresh()
        requestUndeterminedPermissions()

        if !isFullDiskAccessGranted {
            Self.openFullDiskAccessPrivacySettings()
        } else if !isAccessibilityTrusted {
            Self.openPrivacySettings()
        }
    }

    private static func runTCCReset(service: String, bundleIdentifier: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", service, bundleIdentifier]
        try? process.run()
        process.waitUntilExit()
    }

    func evaluateStartupPermissions(
        applicationSettings: ApplicationSettingsStore,
        notchViewModel: NotchViewModel?,
        forceAlert: Bool = false
    ) {
        guard !AppEnvironment.isRunningTests else { return }
        guard forceAlert || applicationSettings.isStartupPermissionCheckEnabled else { return }

        requestUndeterminedPermissions()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
            guard let self else { return }
            self.refresh()
            let missing = self.missingPermissionItems
            guard !missing.isEmpty else { return }

            NSSound.beep()
            if let notchViewModel {
                let alertContent = MissingPermissionsNotchContent(missingCount: missing.count)
                notchViewModel.send(.showTemporaryNotification(alertContent, duration: 5.0))
            }
            self.presentMissingPermissionsAlert(
                missingItems: missing,
                applicationSettings: applicationSettings
            )
        }
    }

    func presentMissingPermissionsAlert(
        missingItems: [PermissionItem]? = nil,
        applicationSettings: ApplicationSettingsStore? = nil
    ) {
        guard !AppEnvironment.isRunningTests else { return }
        refresh()
        let items = missingItems ?? missingPermissionItems
        guard !items.isEmpty else { return }

        let locale = DynamicNotchLanguage.resolved(
            UserDefaults.standard.string(forKey: GeneralSettingsStorage.Keys.appLanguage)
        ).locale
        let bulletList = items.map { item in
            let title = locale.dn(item.titleKey, fallback: item.fallbackTitle)
            let desc = locale.dn(item.descriptionKey, fallback: item.fallbackDescription)
            return "• \(title): \(desc)"
        }.joined(separator: "\n")

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.icon = NSImage(named: "logo") ?? NSApp.applicationIconImage
        alert.messageText = privacyText(
            "Permissions Required for Notchie (\(items.count) missing)",
            "Notchie 권한 설정 필요 (\(items.count)개 미설정)"
        )
        alert.informativeText = privacyText(
            "Some permissions are not yet active:\n\n\(bulletList)\n\nTip: If a permission is already switched ON in System Settings from an earlier build, click \"Fix Permission Sync\" or toggle that switch OFF and ON once in System Settings.",
            "일부 권한이 아직 활성화되지 않았습니다:\n\n\(bulletList)\n\n참고: 시스템 설정에서 이미 켜져 있는데도 미설정으로 뜬다면(이전 빌드 서명 캐시), 아래 '권한 인식 오류 해결'을 누르거나 시스템 설정에서 스위치를 한 번 껐다가 다시 켜 주세요."
        )
        alert.addButton(withTitle: privacyText("Open Permissions Settings", "권한 설정 페이지 열기"))
        alert.addButton(withTitle: privacyText("Fix Permission Sync (Re-request)", "권한 인식 오류 해결 (재요청)"))
        alert.addButton(withTitle: privacyText("Remind Me Later", "나중에"))
        if applicationSettings != nil {
            alert.addButton(withTitle: privacyText("Don't Ask on Startup", "시작 시 다시 묻지 않기"))
        }

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            SettingsWindowController.shared.showWindow(selecting: .permissions)
        } else if response == .alertSecondButtonReturn {
            resetAndReRequestMissingPermissions()
            SettingsWindowController.shared.showWindow(selecting: .permissions)
        } else if response.rawValue == NSApplication.ModalResponse.alertThirdButtonReturn.rawValue + 1 {
            applicationSettings?.isStartupPermissionCheckEnabled = false
        }
    }

    func performAction(for kind: Kind) {
        switch kind {
        case .accessibility:
            requestAccessibilityAccess()
        case .bluetooth:
            requestBluetoothAccess()
        case .mediaControls:
            requestPostEventAccess()
        case .camera:
            requestCameraAccess()
        case .calendar:
            requestCalendarAccess()
        case .fullDiskAccess:
            Self.openFullDiskAccessPrivacySettings()
        case .automation:
            requestAutomationAccess()
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        refresh()
    }

    private func requestAccessibilityAccess() {
        guard !AppEnvironment.isRunningTests else { return }
        guard !Self.currentAccessibilityTrustState() else {
            refresh()
            return
        }

        if !didPromptForAccessibility {
            didPromptForAccessibility = true

            #if canImport(ApplicationServices)
            let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            let options = [promptKey: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            #endif
        } else {
            Self.openPrivacySettings()
        }

        refresh()
    }

    private func requestPostEventAccess() {
        guard !AppEnvironment.isRunningTests else { return }
        guard !Self.currentPostEventAccessState() else {
            refresh()
            return
        }

        if !didPromptForPostEventAccess {
            didPromptForPostEventAccess = true

            #if canImport(ApplicationServices)
            _ = CGRequestPostEventAccess()
            #endif
        } else {
            Self.openPrivacySettings()
        }

        refresh()
    }

    private var bluetoothActionTitleKey: String? {
        switch bluetoothAuthorization {
        case .allowedAlways:
            return nil
        case .notDetermined:
            return "settings.permissions.action.grantAccess"
        case .restricted, .denied:
            return "settings.permissions.action.openPrivacySettings"
        @unknown default:
            return "settings.permissions.action.openPrivacySettings"
        }
    }

    private var bluetoothFallbackActionTitle: String? {
        switch bluetoothAuthorization {
            case .allowedAlways:
                return nil
            case .notDetermined:
                return "Grant Access"
            case .restricted, .denied:
                return "Open Privacy Settings"
            @unknown default:
                return "Open Privacy Settings"
        }
    }

    private var cameraActionTitleKey: String? {
        switch cameraAuthorization {
        case .authorized:
            return nil
        case .notDetermined:
            return "settings.permissions.action.grantAccess"
        case .restricted, .denied:
            return "settings.permissions.action.openPrivacySettings"
        @unknown default:
            return "settings.permissions.action.openPrivacySettings"
        }
    }

    private var cameraFallbackActionTitle: String? {
        switch cameraAuthorization {
        case .authorized:
            return nil
        case .notDetermined:
            return "Grant Access"
        case .restricted, .denied:
            return "Open Privacy Settings"
        @unknown default:
            return "Open Privacy Settings"
        }
    }


    private var calendarActionTitleKey: String? {
        switch calendarAuthorization {
        case .fullAccess, .writeOnly, .authorized:
            return nil
        case .notDetermined:
            return "settings.permissions.action.grantAccess"
        case .restricted, .denied:
            return "settings.permissions.action.openPrivacySettings"
        @unknown default:
            return "settings.permissions.action.openPrivacySettings"
        }
    }

    private var calendarFallbackActionTitle: String? {
        switch calendarAuthorization {
        case .fullAccess, .writeOnly, .authorized:
            return nil
        case .notDetermined:
            return "Grant Access"
        case .restricted, .denied:
            return "Open Privacy Settings"
        @unknown default:
            return "Open Privacy Settings"
        }
    }

    private func requestCameraAccess() {
        guard !AppEnvironment.isRunningTests else { return }
        switch cameraAuthorization {
        case .authorized:
            refresh()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refresh()
                }
            }
        case .restricted, .denied:
            Self.openCameraPrivacySettings()
        @unknown default:
            Self.openCameraPrivacySettings()
        }
    }

    private func requestCalendarAccess() {
        guard !AppEnvironment.isRunningTests else { return }
        switch calendarAuthorization {
        case .fullAccess, .writeOnly:
            refresh()
        case .notDetermined:
            let store = EKEventStore()
            if #available(macOS 14.0, *) {
                store.requestFullAccessToEvents { [weak self] _, _ in
                    DispatchQueue.main.async {
                        self?.refresh()
                    }
                }
            } else {
                store.requestAccess(to: .event) { [weak self] _, _ in
                    DispatchQueue.main.async {
                        self?.refresh()
                    }
                }
            }
        case .restricted, .denied:
            Self.openCalendarPrivacySettings()
        @unknown default:
            Self.openCalendarPrivacySettings()
        }
    }

    private func requestBluetoothAccess() {
        guard !AppEnvironment.isRunningTests else { return }
        switch Self.currentBluetoothAuthorizationStatus() {
        case .allowedAlways:
            refresh()
        case .notDetermined:
            if bluetoothPermissionRequester == nil {
                bluetoothPermissionRequester = CBCentralManager(
                    delegate: self,
                    queue: nil,
                    options: [CBCentralManagerOptionShowPowerAlertKey: false]
                )
            }
        case .restricted, .denied:
            Self.openBluetoothPrivacySettings()
        @unknown default:
            Self.openBluetoothPrivacySettings()
        }
    }

    private static func openPrivacySettings() {
        guard let privacySettingsURL else { return }
        NSWorkspace.shared.open(privacySettingsURL)
    }

    private static func openBluetoothPrivacySettings() {
        guard let bluetoothPrivacySettingsURL else { return }
        NSWorkspace.shared.open(bluetoothPrivacySettingsURL)
    }


    private static func openCameraPrivacySettings() {
        guard let cameraPrivacySettingsURL else { return }
        NSWorkspace.shared.open(cameraPrivacySettingsURL)
    }

    private static func openCalendarPrivacySettings() {
        guard let calendarPrivacySettingsURL else { return }
        NSWorkspace.shared.open(calendarPrivacySettingsURL)
    }

    private static func openFullDiskAccessPrivacySettings() {
        guard let fullDiskAccessPrivacySettingsURL else { return }
        NSWorkspace.shared.open(fullDiskAccessPrivacySettingsURL)
    }

    private static func currentAccessibilityTrustState() -> Bool {
        #if canImport(ApplicationServices)
        AXIsProcessTrusted()
        #else
        true
        #endif
    }

    private static func currentPostEventAccessState() -> Bool {
        guard !AppEnvironment.isRunningTests else { return false }
        #if canImport(ApplicationServices)
        return CGPreflightPostEventAccess() || AXIsProcessTrusted()
        #else
        true
        #endif
    }

    private func requestAutomationAccess() {
        guard !AppEnvironment.isRunningTests else { return }
        guard !Self.currentAutomationAccessState() else {
            refresh()
            return
        }

        if !didPromptForAutomationAccess {
            didPromptForAutomationAccess = true
            let script = "tell application \"System Events\" to get name"
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                _ = appleScript.executeAndReturnError(&error)
            }
        } else {
            Self.openAutomationPrivacySettings()
        }

        refresh()
    }

    private static func openAutomationPrivacySettings() {
        guard let automationPrivacySettingsURL else { return }
        NSWorkspace.shared.open(automationPrivacySettingsURL)
    }

    private static func currentAutomationAccessState() -> Bool {
        guard !AppEnvironment.isRunningTests else { return false }
        let script = "tell application \"System Events\" to get name"
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            _ = appleScript.executeAndReturnError(&error)
            if let err = error, let errNum = err[NSAppleScript.errorNumber] as? Int, errNum == -1743 || errNum == -1744 {
                return false
            }
        }
        return true
    }

    private static func currentBluetoothAuthorizationStatus() -> CBManagerAuthorization {
        CBManager.authorization
    }
}

struct MissingPermissionsNotchContent: NotchContentProtocol, DynamicIslandCustomizable {
    let id = "settings.permissions.missingAlert"
    let missingCount: Int

    var priority: Int { 92 }

    var strokeColor: Color { .orange.opacity(0.6) }

    func compactSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        .init(width: baseWidth + 160, height: baseHeight)
    }

    func dynamicIslandSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        .init(width: baseWidth + 140, height: baseHeight)
    }

    var windowLink: (@MainActor () -> Void)? {
        return {
            SettingsWindowController.shared.showWindow(selecting: .permissions)
        }
    }

    @MainActor
    func compactView() -> AnyView {
        AnyView(MissingPermissionsNotchView(missingCount: missingCount))
    }
}

struct MissingPermissionsNotchView: View {
    @Environment(\.isNotchlessScreen) private var isNotchlessScreen
    @Environment(\.notchScale) private var scale
    let missingCount: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.orange)

            Spacer()

            Text(
                privacyText(
                    "Permissions needed (\(missingCount))",
                    "권한 설정 필요 (\(missingCount))"
                )
            )
            .font(.system(size: isNotchlessScreen ? 12 : 13, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
        }
        .padding(.leading, isNotchlessScreen ? 8.scaled(by: scale) : 14.scaled(by: scale))
        .padding(.trailing, isNotchlessScreen ? 8.scaled(by: scale) : 14.scaled(by: scale))
    }
}
