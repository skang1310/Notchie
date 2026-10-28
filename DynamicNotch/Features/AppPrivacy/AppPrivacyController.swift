import SwiftUI
import Combine
internal import AppKit
import LocalAuthentication
import HeyMacEngine

@MainActor
final class AppPrivacyController: ObservableObject {
    static let shared = AppPrivacyController()
    let state: AppPrivacyState
    @Published private(set) var enabled: Bool
    @Published private(set) var apps: [LockedApp]
    @Published private(set) var useFace: Bool
    @Published private(set) var pausedSeconds = 0
    @Published private(set) var availableApps: [InstalledApp] = []
    @Published private(set) var scanningApps = false
    @Published private(set) var shieldName = ""
    @Published private(set) var authenticating = false
    @Published private(set) var message = ""
    @Published private(set) var previewing = false
    private var target: NSRunningApplication?
    private var panels: [NSPanel] = []
    private var observers: [NSObjectProtocol] = []
    private var screenObserver: NSObjectProtocol?
    private var lockObserver: NSObjectProtocol?
    private var timer: Timer?
    private var authentication: Task<Void, Never>?
    private var attempt = UUID()
    private var running = false

    init(defaults: UserDefaults = .standard) {
        let model = AppPrivacyState(defaults: defaults)
        state = model
        enabled = model.store.enabled
        apps = model.store.apps
        useFace = model.useFace
    }
    func resume() {
        guard !AppEnvironment.isRunningTests, enabled else { return }
        startMonitoring()
    }
    func setEnabled(_ value: Bool) {
        if value {
            let context = LAContext()
            var error: NSError?
            guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
                message = privacyText("System authentication is unavailable. Set up a Mac login password first.", "시스템 인증을 사용할 수 없습니다. 먼저 Mac 로그인 암호를 설정하세요.")
                return
            }
        }
        state.enable(value); enabled = value; pausedSeconds = 0
        if value { resume() } else { stopMonitoring() }
    }
    func setUseFace(_ value: Bool) { state.useFace = value; useFace = value }
    func refreshAvailableApps() {
        guard !scanningApps else { return }
        scanningApps = true
        Task {
            availableApps = await Task.detached { InstalledApps.scan() }.value
                .filter { $0.bundleID != "com.Jackson.DynamicNotch" && $0.bundleID != "com.Jackson.DynamicNotch.LocalTests" }
            scanningApps = false
        }
    }
    func add(_ app: InstalledApp) {
        if state.add(bundleID: app.bundleID, name: app.name) { apps = state.store.apps; reconcile() }
    }
    func remove(_ id: String) {
        state.remove(id); apps = state.store.apps
        if target?.bundleIdentifier == id { dismissShield() }
    }
    func setPolicy(_ policy: RelockPolicy, for id: String) {
        state.setPolicy(policy, for: id); apps = state.store.apps; reconcile()
    }
    func pause(minutes: Int) {
        state.pause(minutes: minutes); pausedSeconds = state.pauseSeconds; dismissShield()
    }
    func relockAll() {
        state.relockAll(); pausedSeconds = 0; dismissShield(); reconcile()
    }
    func preview() {
        guard target == nil else { return }
        previewing = true
        shieldName = privacyText("Privacy screen preview", "프라이버시 화면 미리보기")
        message = privacyText("No app is locked by this preview.", "미리보기에서는 앱을 잠그지 않습니다.")
        showPanels()
    }
    private func startMonitoring() {
        guard !running, !AppEnvironment.isRunningTests else { return }
        running = true
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didUnhideApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
                MainActor.assumeIsolated { self?.activated(app) }
            })
        }
        observers.append(center.addObserver(forName: NSWorkspace.didDeactivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let id = app.bundleIdentifier else { return }
            MainActor.assumeIsolated { self?.state.sessions.focusLost(id) }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            MainActor.assumeIsolated {
                if let id = app.bundleIdentifier { self?.state.sessions.revoke(id) }
                if self?.target?.processIdentifier == app.processIdentifier { self?.dismissShield() }
            }
        })
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.state.sessions.revokeAll(); self?.dismissShield() }
            })
        }
        lockObserver = DistributedNotificationCenter.default().addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.state.sessions.revokeAll(); self?.dismissShield() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.reconcile() }
        }
        timer?.tolerance = 0.4
        reconcile()
    }
    private func activated(_ app: NSRunningApplication) {
        guard let id = app.bundleIdentifier, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        if let target {
            if target.processIdentifier == app.processIdentifier { app.hide(); return }
            // SecurityAgent can activate while macOS authenticates. Do not cancel its prompt.
            if authenticating { return }
            dismissShield()
        }
        state.sessions.focusGained(id)
        consider(app)
    }
    private func reconcile() {
        pausedSeconds = state.pauseSeconds
        guard running, target == nil, !previewing, let front = NSWorkspace.shared.frontmostApplication else { return }
        consider(front)
    }
    private func consider(_ app: NSRunningApplication) {
        guard running, let id = app.bundleIdentifier, state.needsShield(id),
              !AppLockBlacklist.isProtected(id), app.activationPolicy == .regular, !app.isTerminated,
              target == nil, !previewing else { return }
        target = app
        shieldName = app.localizedName ?? state.store.app(id)?.name ?? id
        message = privacyText("Authenticate to return to this app.", "이 앱으로 돌아가려면 인증하세요.")
        // Hide the app before lowering covers for the system auth dialog.
        app.hide()
        showPanels()
    }
    private func showPanels() {
        panels.forEach { $0.orderOut(nil) }; panels.removeAll()
        guard !AppEnvironment.isRunningTests else { return }
        for screen in NSScreen.screens {
            let panel = PrivacyCoverPanel(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            panel.level = .mainMenu + 2
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.isOpaque = true; panel.backgroundColor = .black; panel.hasShadow = false
            panel.isReleasedWhenClosed = false
            panel.contentView = NSHostingView(rootView: AppPrivacyCoverView(controller: self))
            panels.append(panel); panel.orderFrontRegardless()
        }
        NSApp.activate(ignoringOtherApps: true)
        panels.first?.makeKey()
        if screenObserver == nil {
            screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, !self.panels.isEmpty else { return }
                    self.showPanels()
                    if self.authenticating { self.panels.forEach { $0.level = .normal } }
                }
            }
        }
    }
    func authenticate(systemOnly: Bool = false) {
        guard !authenticating, !previewing, let app = target, let id = app.bundleIdentifier else { return }
        let ticket = UUID(); attempt = ticket; authenticating = true
        message = privacyText("Authenticating…", "인증 중입니다…")
        authentication = Task { [weak self] in
            guard let self else { return }
            var face: FaceAuthSource?
            if useFace && !systemOnly { face = try? await HeyMacFaceUnlockController.shared.appPrivacyFaceSource() }
            guard !Task.isCancelled, attempt == ticket else { return }
            let coordinator = AuthCoordinator(face: face, system: LocalSystemAuth(), onSystemAuthentication: { @MainActor [weak self] in
                guard let self, self.attempt == ticket, !Task.isCancelled else { return }
                // Target is hidden. Let macOS's trusted dialog appear above the cover.
                self.panels.forEach { $0.level = .normal }
            })
            let result = await coordinator.run(reason: privacyText("Unlock ", "잠금 해제: ") + shieldName)
            guard !Task.isCancelled, attempt == ticket, enabled, state.isActive,
                  target?.processIdentifier == app.processIdentifier, !app.isTerminated,
                  let entry = state.store.app(id) else { return }
            authenticating = false; authentication = nil
            switch result {
            case .unlocked:
                state.sessions.unlock(id, policy: entry.policy)
                dismissShield()
                app.unhide(); app.activate(options: [])
            case .cancelled, .denied:
                panels.forEach { $0.level = .mainMenu + 2 }
                message = privacyText("Authentication was cancelled or failed. You can try again or go back.", "인증이 취소되었거나 실패했습니다. 다시 시도하거나 돌아갈 수 있습니다.")
            }
        }
    }
    func goBack() {
        target?.hide()
        dismissShield()
        SettingsWindowController.shared.showWindow()
    }
    private func dismissShield() {
        attempt = UUID(); authentication?.cancel(); authentication = nil; authenticating = false
        panels.forEach { $0.orderOut(nil) }; panels.removeAll()
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }; screenObserver = nil
        target = nil; previewing = false; shieldName = ""
    }
    private func stopMonitoring() {
        running = false; timer?.invalidate(); timer = nil
        let center = NSWorkspace.shared.notificationCenter
        observers.forEach { center.removeObserver($0) }; observers.removeAll()
        if let lockObserver { DistributedNotificationCenter.default().removeObserver(lockObserver) }; lockObserver = nil
        state.sessions.revokeAll(); dismissShield()
    }
    func shutdown() { stopMonitoring() }
}
private final class PrivacyCoverPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
