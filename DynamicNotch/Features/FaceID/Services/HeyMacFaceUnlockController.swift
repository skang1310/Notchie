import Foundation
import Combine
import AVFoundation
import ApplicationServices
import HeyMacEngine
import HeyMacCore

/// Opt-in adapter. The vendored engine owns recognition, encryption and bounded
/// password injection. No enrollment, permission request or login launch at startup.
@MainActor
final class HeyMacFaceUnlockController: ObservableObject {
    static let shared = HeyMacFaceUnlockController()
    static let enabledKey = "DynamicNotch.HeyMac.enabled.v1"
    @Published private(set) var enabled = false
    @Published private(set) var busy = false
    @Published private(set) var enrolled = false
    @Published private(set) var hasPassword = false
    @Published private(set) var status = ""
    private let defaults: UserDefaults
    private let engineSettings: EngineSettings
    private var runtime: HeyMacRuntime?
    private var engine: EngineController?
    private var operation: FaceOperation?
    private let directory: URL

    init(defaults: UserDefaults = .standard, directory: URL? = nil) {
        self.defaults = defaults
        self.directory = directory ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/DynamicNotch/FaceUnlock", isDirectory: true)
        // Separate from HeyMac's preferences, credentials and registration.
        engineSettings = EngineSettings(defaults: defaults)
        refreshFiles()
        if engineSettings.lockScreenNeedsPassword {
            status = text("Saved password needs attention. Update it before enabling face unlock.", "저장된 암호를 확인해야 합니다. 암호를 다시 저장한 뒤 얼굴 잠금 해제를 켜세요.")
        }
    }
    var passwordNeedsUpdate: Bool { engineSettings.lockScreenNeedsPassword }

    private func refreshFiles() {
        enrolled = FileManager.default.fileExists(atPath: directory.appendingPathComponent(StoredItems.faceCentroid).path)
        hasPassword = FileManager.default.fileExists(atPath: directory.appendingPathComponent(StoredItems.loginPassword).path)
    }
    private func loadRuntime() async throws -> HeyMacRuntime {
        if let runtime { return runtime }
        let directory = directory
        let loaded = try await Task.detached { try HeyMacRuntime(supportDirectory: directory) }.value
        runtime = loaded
        return loaded
    }
    func resumeIfAuthorized() {
        guard !AppEnvironment.isRunningTests, defaults.bool(forKey: Self.enabledKey) else { return }
        setEnabled(true)
    }
    func enroll() {
        guard !busy, !enabled, !AppEnvironment.isRunningTests else { return }
        busy = true
        let token = FaceOperation(); operation = token
        Task {
            defer { busy = false; operation = nil; refreshFiles() }
            let permission = AVCaptureDevice.authorizationStatus(for: .video)
            var allowed = permission == .authorized
            if permission == .notDetermined { allowed = await AVCaptureDevice.requestAccess(for: .video) }
            guard allowed, token.active else { status = text("Camera access is required.", "카메라 접근 권한이 필요합니다."); return }
            do {
                let runtime = try await loadRuntime()
                guard token.active else { return }
                let session = runtime.makeEnrollmentSession(strictness: .strict)
                status = text("Look at the camera in good lighting. Capturing 8 live samples…", "밝은 곳에서 카메라를 봐주세요. 얼굴 샘플 8개를 수집합니다…")
                let succeeded = await Task.detached {
                    session.enroller.run(shouldContinue: { token.active }, onProgress: { _ in })
                }.value
                guard succeeded, token.active else { status = text("Enrollment cancelled or failed. Try again in better lighting.", "등록이 취소되었거나 실패했습니다. 밝은 곳에서 다시 시도하세요."); return }
                status = text("Checking the new enrollment…", "새로 등록한 얼굴을 확인합니다…")
                let outcome = await Task.detached {
                    session.verifier.run(timeout: 12, requiredConsecutive: 3, keepGoing: { token.active })
                }.value
                guard outcome.matched, token.active else { status = text("Verification failed. Previous enrollment was preserved.", "얼굴 확인에 실패했습니다. 기존 등록은 유지됩니다."); return }
                try session.commit()
                status = text("Face registered and checked. Save your password next.", "얼굴 등록과 확인을 마쳤습니다. 다음으로 로그인 암호를 저장하세요.")
            } catch { status = error.localizedDescription }
        }
    }
    func savePassword(_ password: String) {
        guard !password.isEmpty, !busy, !enabled, enrolled, !AppEnvironment.isRunningTests else { return }
        busy = true
        Task {
            defer { busy = false; refreshFiles() }
            do {
                let runtime = try await loadRuntime()
                try runtime.saveLoginPassword(password)
                engineSettings.lockScreenNeedsPassword = false
                status = text("Encrypted password saved. It has not been verified against macOS.", "암호를 암호화해 저장했습니다. macOS 로그인 암호와 일치하는지는 아직 확인하지 않았습니다.")
            } catch { status = error.localizedDescription }
        }
    }
    func testFace() {
        guard !busy, !enabled, enrolled, !AppEnvironment.isRunningTests else { return }
        busy = true
        let token = FaceOperation(); operation = token
        Task {
            defer { busy = false; operation = nil }
            do {
                let runtime = try await loadRuntime()
                guard token.active, AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
                status = text("Look at the camera…", "카메라를 봐주세요…")
                FaceIDService.shared.receive(.lockScreenScanning)
                let outcome = await Task.detached {
                    runtime.verifier(interactive: true, strictness: .strict).run(timeout: 12, requiredConsecutive: 3, keepGoing: { token.active })
                }.value
                if outcome.matched && token.active {
                    FaceIDService.shared.receive(.lockScreenUnlocked(summary: "verified"))
                    status = text("Face matched. No password was typed.", "얼굴이 일치합니다. 암호는 입력하지 않았습니다.")
                } else {
                    FaceIDService.shared.receive(.lockScreenNoMatch(details: "no match"))
                    status = text("Face did not match or the check was cancelled.", "얼굴이 일치하지 않거나 확인이 취소되었습니다.")
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.8))
                    if !FaceIDService.shared.state.isActivelyEvaluating {
                        FaceIDService.shared.cancelScan()
                    }
                }
            } catch { status = error.localizedDescription }
        }
    }
    func setEnabled(_ value: Bool) {
        if !value {
            defaults.set(false, forKey: Self.enabledKey)
            engineSettings.lockScreenEnabled = false
            operation?.cancel()
            engine?.stop(); engine = nil; enabled = false
            FaceIDService.shared.cancelScan()
            return
        }
        guard !busy, !AppEnvironment.isRunningTests else { return }
        refreshFiles()
        guard enrolled, hasPassword, AXIsProcessTrusted(), AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            defaults.set(false, forKey: Self.enabledKey)
            status = text("Register your face, save a password and grant Camera and Accessibility access first.", "얼굴 등록·암호 저장 후 카메라 및 손쉬운 사용 권한을 직접 허용하세요.")
            return
        }
        busy = true
        let token = FaceOperation(); operation = token
        Task { [weak self] in
            guard let self else { return }
            defer { self.busy = false; self.operation = nil }
            do {
                let runtime = try await self.loadRuntime()
                guard token.active else { return }
                // Ensure background key access succeeds without a permission dialog.
                _ = try await Task.detached { try runtime.backgroundStore.load(StoredItems.faceCentroid) }.value
                guard token.active else { return }
                // A rejected password remains blocked across relaunch until explicitly saved again.
                guard !self.engineSettings.lockScreenNeedsPassword else {
                    self.status = self.text("macOS rejected the password. Save the correct password before enabling again.", "macOS가 암호를 거부했습니다. 올바른 암호를 다시 저장하세요."); return
                }
                self.engineSettings.setupComplete = true
                self.engineSettings.strictness = .strict
                self.engineSettings.paused = false
                self.engineSettings.launchAtLogin = false
                self.engineSettings.lockScreenEnabled = true
                let log = AppLog(url: self.directory.appendingPathComponent("events.log"), alsoStandardError: false)
                let controller = EngineController(runtime: runtime, settings: self.engineSettings, log: log) { [weak self] event in
                    Task { @MainActor [weak self] in self?.handle(event) }
                }
                try controller.start()
                self.engine = controller; self.enabled = true
                self.defaults.set(true, forKey: Self.enabledKey)
                self.status = self.text("Enabled while Notchie is running. Test on your next manual lock.", "Notchie 실행 중 활성화됩니다. 다음에 직접 화면을 잠가 확인하세요.")
            } catch { self.setEnabled(false); self.status = error.localizedDescription }
        }
    }
    private func handle(_ event: EngineEvent) {
        guard enabled else { return }
        switch event {
        case .lockScreenScanning: status = text("Checking your face…", "얼굴을 확인합니다…")
        case .lockScreenUnlocked: status = text("macOS unlocked.", "macOS 잠금이 해제되었습니다.")
        case .lockScreenPasswordRejected: status = text("macOS rejected the saved password. Face unlock is off; save the correct password before enabling again.", "macOS가 저장된 암호를 거부하여 기능을 껐습니다. 올바른 암호를 다시 저장한 후 활성화하세요.")
        case .lockScreenNoMatch: status = text("Face did not match.", "얼굴이 일치하지 않습니다.")
        case .lockScreenNoFace: status = text("No live face detected. Use the normal macOS login.", "실제 얼굴을 감지하지 못했습니다. 일반 macOS 로그인을 이용하세요.")
        case .lockScreenScanEnded: status = text("Camera check ended.", "카메라 확인을 마쳤습니다.")
        case .lockScreenProblem(let reason): status = text("Face unlock could not run. Check permissions and test your face from Settings.", "얼굴 잠금 해제를 실행하지 못했습니다. 권한을 확인하고 설정에서 얼굴 인식을 테스트하세요.") + "\n" + reason
        }
        FaceIDService.shared.receive(event)
        if event != .lockScreenScanning {
            Task {
                try? await Task.sleep(for: .seconds(3))
                if FaceIDService.shared.state.isActivelyEvaluating == false { FaceIDService.shared.cancelScan() }
            }
        }
        if event == .lockScreenPasswordRejected { setEnabled(false) }
    }
    /// App privacy needs no saved login password and never requests camera access.
    func appPrivacyFaceSource() async throws -> FaceAuthSource? {
        refreshFiles()
        guard enrolled, !busy, AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
              !AppEnvironment.isRunningTests else { return nil }
        let runtime = try await loadRuntime()
        return FaceVerifierAuthSource(matcher: runtime.verifier(interactive: true, strictness: .strict))
    }
    func retryOnLockScreen() {
        guard enabled, !busy, engine?.requestScan() == true else { return }
        status = text("Checking your face…", "얼굴을 확인합니다…")
    }

    func cancel() { operation?.cancel() }
    func shutdown() { cancel(); engine?.stop(); engine = nil }
    func removeData() {
        guard !busy, !AppEnvironment.isRunningTests else { return }
        setEnabled(false); busy = true
        Task {
            defer { busy = false; refreshFiles() }
            do {
                let runtime = try await loadRuntime()
                try runtime.removeAllData()
                status = text("Face and password data removed.", "얼굴 및 암호 데이터를 삭제했습니다.")
            } catch { status = error.localizedDescription }
        }
    }
    private func text(_ english: String, _ korean: String) -> String {
        Locale.preferredLanguages.first?.hasPrefix("ko") == true ? korean : english
    }
}
nonisolated private final class FaceOperation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    var active: Bool { lock.lock(); defer { lock.unlock() }; return !cancelled }
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
}
