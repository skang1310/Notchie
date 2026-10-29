import SwiftUI
internal import AppKit
@preconcurrency import AVFoundation

/// Invalidates a pending permission response when the mirror disappears or is cancelled.
struct MirrorActivationGate {
    private(set) var pending: UUID?
    mutating func begin() -> UUID { let id = UUID(); pending = id; return id }
    mutating func cancel() { pending = nil }
    mutating func complete(_ id: UUID, granted: Bool) -> Bool {
        guard pending == id else { return false }
        pending = nil
        return granted
    }
}

struct NookMirrorPod: View {
    @ObservedObject var store: QuickToolsStore
    @State private var gate = MirrorActivationGate()
    @State private var message: String?
    var body: some View {
        VStack(spacing: 7) {
            Button(action: toggle) {
                ZStack {
                    Circle().fill(LinearGradient(colors: [.white.opacity(0.12), .white.opacity(0.045)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    if store.isMirrorCameraActive {
                        MirrorCameraPreview(onFailure: { message = privacyText("Camera unavailable", "카메라를 사용할 수 없어요"); store.isMirrorCameraActive = false })
                            .clipShape(Circle())
                    } else {
                        VStack(spacing: 4) {
                            Image(systemName: "web.camera").font(.system(size: 27, weight: .regular))
                            Text(privacyText("Mirror", "미러")).font(.system(size: 11, weight: .semibold))
                        }.foregroundStyle(.white.opacity(0.55))
                    }
                    if gate.pending != nil { ProgressView().controlSize(.small) }
                }.frame(width: 92, height: 92)
                    .overlay(Circle().strokeBorder(.white.opacity(0.08), lineWidth: 0.8))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("nook.mirror")
            .accessibilityLabel(store.isMirrorCameraActive ? privacyText("Stop mirror", "미러 끄기") : privacyText("Open mirror", "미러 켜기"))
            .help(privacyText("Camera preview only. Click to start or stop.", "카메라 미리보기입니다. 클릭해서 켜거나 끄세요."))
            if let message { Text(message).font(.system(size: 9)).foregroundStyle(.secondary).multilineTextAlignment(.center).lineLimit(2) }
        }
        .onDisappear { gate.cancel(); store.isMirrorCameraActive = false }
    }
    private func toggle() {
        if store.isMirrorCameraActive || gate.pending != nil {
            gate.cancel(); store.isMirrorCameraActive = false; return
        }
        message = nil
        guard !AppEnvironment.isRunningTests else { return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: store.isMirrorCameraActive = true
        case .notDetermined:
            let request = gate.begin()
            Task { @MainActor in
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                if gate.complete(request, granted: granted) { store.isMirrorCameraActive = true }
            }
        default: message = privacyText("Allow Camera in System Settings", "시스템 설정에서 카메라 접근을 허용하세요")
        }
    }
}

private struct MirrorCameraPreview: NSViewRepresentable {
    var onFailure: @MainActor () -> Void
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> PreviewHost {
        let view = PreviewHost()
        let coordinator = context.coordinator
        view.preview.session = coordinator.session
        view.preview.videoGravity = .resizeAspectFill
        coordinator.start { success in
            Task { @MainActor in
                guard !view.isDetached else { return }
                if success {
                    if let connection = view.preview.connection, connection.isVideoMirroringSupported {
                        connection.automaticallyAdjustsVideoMirroring = false
                        connection.isVideoMirrored = true
                    }
                } else { onFailure() }
            }
        }
        return view
    }
    func updateNSView(_ view: PreviewHost, context: Context) {}
    static func dismantleNSView(_ view: PreviewHost, coordinator: Coordinator) {
        view.isDetached = true
        view.preview.session = nil
        coordinator.stop()
    }
    final class PreviewHost: NSView {
        let preview = AVCaptureVideoPreviewLayer()
        var isDetached = false
        override init(frame: NSRect) { super.init(frame: frame); wantsLayer = true; layer = preview }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func layout() { super.layout(); preview.frame = bounds }
    }
    final class Coordinator: @unchecked Sendable {
        let session = AVCaptureSession()
        private let queue = DispatchQueue(label: "DynamicNotch.Mirror.Preview", qos: .userInitiated)
        func start(completion: @escaping @Sendable (Bool) -> Void) {
            let session = session
            queue.async {
                session.beginConfiguration()
                session.sessionPreset = .medium
                guard let device = AVCaptureDevice.default(for: .video),
                      let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
                    session.commitConfiguration(); completion(false); return
                }
                session.addInput(input)
                session.commitConfiguration()
                session.startRunning()
                completion(session.isRunning)
            }
        }
        func stop() {
            let session = session
            queue.async {
                if session.isRunning { session.stopRunning() }
                session.inputs.forEach { session.removeInput($0) }
            }
        }
        deinit { stop() }
    }
}
