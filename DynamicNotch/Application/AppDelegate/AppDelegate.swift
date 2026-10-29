//
//  AppDelegate.swift
//  DynamicNotch
//
//  Created by Евгений Петрукович on 2/28/26.
//

import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let isRunningUITests: Bool
    let container: AppContainer

    var settingsViewModel: SettingsViewModel { container.settingsViewModel }
    var notchViewModel: NotchViewModel { container.notchViewModel }
    var notchEventCoordinator: NotchEventCoordinator { container.notchEventCoordinator }
    var hardwareHUDMonitor: HardwareHUDMonitor { container.hardwareHUDMonitor }
    var lockScreenPanelManager: LockScreenPanelManager { container.lockScreenPanelManager }
    var lockScreenLiveActivityWindowManager: LockScreenLiveActivityWindowManager { container.lockScreenLiveActivityWindowManager }
    var lockScreenFaceIDWindowManager: LockScreenFaceIDWindowManager { container.lockScreenFaceIDWindowManager }
    var airDropViewModel: AirDropNotchViewModel { container.airDropViewModel }
    var airDropController: NotchAirDropController { container.airDropController }
    var lockScreenManager: LockScreenManager { container.lockScreenManager }
    var nowPlayingViewModel: NowPlayingViewModel { container.nowPlayingViewModel }
    var downloadViewModel: DownloadViewModel { container.downloadViewModel }
    var timerViewModel: TimerViewModel { container.timerViewModel }
    var screenRecordingViewModel: ScreenRecordingViewModel { container.screenRecordingViewModel }
    var externalDrivesMonitor: ExternalDrivesMonitor { container.externalDrivesMonitor }
    var powerService: PowerService { container.powerService }
    var powerViewModel: PowerViewModel { container.powerViewModel }
    var bluetoothViewModel: BluetoothViewModel { container.bluetoothViewModel }
    var wifiViewModel: WifiViewModel { container.wifiViewModel }
    var vpnViewModel: VpnViewModel { container.vpnViewModel }
    var focusViewModel: FocusViewModel { container.focusViewModel }
    
    var window: OverlayPanelWindow!
    var localClickMonitor: Any?
    let globalClickMonitor = GlobalClickMonitor()
    var hideWindowWorkItem: DispatchWorkItem?
    var cancellables = Set<AnyCancellable>()
    private var quickToolsPresentation: AnyCancellable?
    private var quickToolsAutoDismissTask: Task<Void, Never>?
    var isPrimaryWindowSuspendedForLock = false
    var expansionTime: Date = .distantPast
    
    override init() {
        let isRunningUITests = AppEnvironment.isRunningUITests
        let isRunningTests = AppEnvironment.isRunningTests
        self.isRunningUITests = isRunningUITests
        self.container = AppContainer(isRunningTests: isRunningTests)
        super.init()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !AppEnvironment.isRunningUnitTests else {
            // Running as test host for unit tests: do not start UI, windows, monitors, or permission prompts.
            return
        }

        applyActivationPolicy(
            showsDockIcon: isRunningUITests || settingsViewModel.application.isDockIconVisible
        )
        observeDisplayLocationChanges()
        observeFullscreenVisibilityChanges()
        observeDockIconVisibilityChanges()
        observeHUDConfigurationChanges()
        observeFeatureMonitoringChanges()
        observeLockScreenWindowHandoff()
        
        SettingsWindowController.shared.setupDependencies(appDelegate: self)
        NotificationCenter.default.publisher(for: .showQuickToolsInNotch)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.quickToolsPresentation = self.notchViewModel.$notchModel
                    .receive(on: RunLoop.main)
                    .filter { $0.content?.id == "local.quickTools" }
                    .first()
                    .sink { [weak self] _ in self?.notchViewModel.expandActiveLiveActivity() }
                self.notchViewModel.send(.showLiveActivity(QuickToolsNotchContent(store: QuickToolsStore.shared, openedFromIdleHover: true)))

                self.quickToolsAutoDismissTask?.cancel()
                self.quickToolsAutoDismissTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 6_000_000_000)
                    guard !Task.isCancelled, let self else { return }
                    if let notchRect = self.activeNotchScreenRect, notchRect.contains(NSEvent.mouseLocation) {
                        return
                    }
                    if QuickToolsStore.shared.isNotchHubPinned {
                        return
                    }
                    self.notchViewModel.handleOutsideClick()
                }
            }.store(in: &cancellables)

        NotificationCenter.default.publisher(for: .closeQuickToolsInNotch)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.quickToolsAutoDismissTask?.cancel()
                self?.quickToolsPresentation?.cancel()
                self?.notchViewModel.send(.hideLiveActivity(id: "local.quickTools"))
            }.store(in: &cancellables)
        NotificationCenter.default.publisher(for: .presentationRuleChanged)
            .receive(on: RunLoop.main).sink { [weak self] _ in self?.updateWindowFrame() }.store(in: &cancellables)
        NotificationCenter.default.publisher(for: .pauseLocalMonitors)
            .receive(on: RunLoop.main).sink { [weak self] _ in
                guard let self else { return }
                self.settingsViewModel.mediaAndFiles.isDownloadsLiveActivityEnabled = false
                self.settingsViewModel.mediaAndFiles.isNowPlayingLiveActivityEnabled = false
                self.settingsViewModel.lockScreen.isLockScreenMediaPanelEnabled = false
                self.settingsViewModel.screenRecording.isScreenRecordingLiveActivityEnabled = false
                self.settingsViewModel.mediaAndFiles.isTimerLiveActivityEnabled = false
            }.store(in: &cancellables)
        NotificationCenter.default.publisher(for: .localJobCompleted)
            .receive(on: RunLoop.main).sink { _ in
                QuickToolsStore.shared.selectedTool = "jobs"
                NotificationCenter.default.post(name: .showQuickToolsInNotch, object: nil)
            }.store(in: &cancellables)
        NotificationCenter.default.publisher(for: .focusSessionCompleted)
            .receive(on: RunLoop.main).sink { _ in
                QuickToolsStore.shared.selectedTool = "focus"
                NotificationCenter.default.post(name: .showQuickToolsInNotch, object: nil)
            }.store(in: &cancellables)
        ProductivityCoordinator.shared.start()
        HeyMacFaceUnlockController.shared.resumeIfAuthorized()
        AppPrivacyController.shared.resume()

        if !isRunningUITests {
            createNotchWindow()
            observeOutsideClickDismissal()
            _ = lockScreenPanelManager
            _ = lockScreenLiveActivityWindowManager
            _ = lockScreenFaceIDWindowManager
            hardwareHUDMonitor.startMonitoring()
            container.notchlessWindowConstrainer.start()

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(updateWindowFrame),
                name: NSApplication.didChangeScreenParametersNotification,
                object: nil
            )
            observeWorkspaceChanges()

            DispatchQueue.main.async {
                for w in NSApp.windows {
                    if w !== self.window {
                        w.orderOut(nil)
                    }
                }
            }
        }

        if !isRunningUITests {
            notchEventCoordinator.checkFirstLaunch()
            SettingsPermissionController.shared.evaluateStartupPermissions(
                applicationSettings: settingsViewModel.application,
                notchViewModel: notchViewModel
            )
        }

        lockScreenManager.startMonitoring()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !AppEnvironment.isRunningTests else { return false }
        SettingsWindowController.shared.showWindow()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppPrivacyController.shared.shutdown()
        HeyMacFaceUnlockController.shared.shutdown()
        ProductivityCoordinator.shared.shutdown()
        QuickToolsStore.shared.shutdown()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        container.lockScreenManager.stopMonitoring()
        container.nowPlayingViewModel.stopMonitoring()
        container.downloadViewModel.stopMonitoring()
        container.timerViewModel.stopMonitoring()
        container.screenRecordingViewModel.stopMonitoring()
        container.hardwareHUDMonitor.stopMonitoring()
        container.notchlessWindowConstrainer.stop()
        if !isRunningUITests {
            container.lockScreenPanelManager.invalidate()
            container.lockScreenLiveActivityWindowManager.invalidate()
            container.lockScreenFaceIDWindowManager.invalidate()
        }
        stopOutsideClickMonitoring()
        hideWindowWorkItem?.cancel()
        hideWindowWorkItem = nil
        container.externalDrivesMonitor.stopMonitoring()
    }

    func applyActivationPolicy(showsDockIcon: Bool) {
        let targetPolicy: NSApplication.ActivationPolicy = showsDockIcon ? .regular : .accessory

        guard NSApp.activationPolicy() != targetPolicy else { return }

        NSApp.setActivationPolicy(targetPolicy)

        if showsDockIcon {
            NSApp.activate(ignoringOtherApps: false)
        }
    }
}
