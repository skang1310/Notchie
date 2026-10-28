import Foundation
import Combine
import HeyMacEngine

/// Existing notch presentation bridge. Legacy direct scanning stays disabled;
/// the opt-in HeyMac adapter supplies actual engine events.
@MainActor
final class FaceIDService: NSObject, ObservableObject {
    static let shared = FaceIDService()
    @Published private(set) var state: FaceIDState = .idle
    @Published private(set) var detectedFaceCount = 0
    @Published private(set) var areEyesOpen = false
    @Published private(set) var livenessScore = 0.0
    private var previewTask: Task<Void, Never>?

    func startScan(requireOpenEyes: Bool = true, livenessCheck: Bool = true, completion: ((Bool) -> Void)? = nil) {
        state = .failed(reason: "Password-based unlocking was removed. Use macOS Touch ID or login.")
        completion?(false)
    }

    func receive(_ event: EngineEvent) {
        previewTask?.cancel()
        previewTask = nil
        switch event {
        case .lockScreenScanning: state = .scanning(progress: 0.5)
        case .lockScreenUnlocked: state = .success
        case .lockScreenNoMatch, .lockScreenNoFace: state = .failed(reason: "Face not verified")
        case .lockScreenPasswordRejected: state = .failed(reason: "macOS rejected the saved password")
        case .lockScreenProblem(let reason): state = .failed(reason: reason)
        case .lockScreenScanEnded: state = .idle
        }
    }

    func playNotchPreview(style: FaceIDPresentationStyle, in notchViewModel: NotchViewModel?) {
        previewTask?.cancel()
        state = .scanning(progress: 0.5)
        notchViewModel?.send(.showTemporaryNotification(
            FaceIDNotchContent(service: self, style: style),
            duration: 3.3
        ))
        previewTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_550_000_000)
            guard let self, !Task.isCancelled else { return }
            self.state = .success
            notchViewModel?.send(.showTemporaryNotification(
                FaceIDNotchContent(service: self, style: style),
                duration: 1.5
            ))
            try? await Task.sleep(nanoseconds: 1_550_000_000)
            guard !Task.isCancelled else { return }
            self.state = .idle
        }
    }

    func cancelScan() {
        previewTask?.cancel()
        previewTask = nil
        state = .idle
    }
}
