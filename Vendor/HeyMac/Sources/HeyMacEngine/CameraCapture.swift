import AVFoundation
import CoreImage
import Foundation

public protocol FrameSource: AnyObject {
    func start() throws
    func stop()
    /// The newest available frame, if its sequence number is greater than `sequence`.
    func frame(newerThan sequence: Int) -> (image: CGImage, sequence: Int)?
}

public enum CameraCaptureError: Error {
    case noCameraDevice
    case inputCreationFailed
}

/// On-demand camera: runs only while a verification or enrollment needs frames, so the
/// camera light is off the rest of the time. Frames from the first `warmup` seconds are
/// dropped — a webcam's auto-exposure starts dark, and those frames made bad enrollments.
public final class CameraCapture: NSObject, FrameSource, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "heymac.camera")
    private let ciContext = CIContext()
    // Session lifecycle is serial; delegate frame storage has its own short lock.
    private let lifecycleQueue = DispatchQueue(label: "heymac.camera.lifecycle", qos: .userInitiated)
    private let frameLock = NSLock()
    private let commandLock = NSLock()
    private let warmup: TimeInterval
    private let minFrameInterval: TimeInterval = 1.0 / 30.0
    private var configured = false
    private var startedAt = Date.distantFuture
    private var lastConverted = Date.distantPast
    private var latest: (image: CGImage, sequence: Int)?
    private var sequence = 0
    private var epoch = CameraFrameEpoch()

    public init(warmup: TimeInterval = 0.05) {
        self.warmup = warmup
    }

    /// Build the session while capture is OFF, before a lock needs fast frames.
    public func prepare() throws {
        commandLock.lock()
        defer { commandLock.unlock() }
        try lifecycleQueue.sync { try configureIfNeeded() }
    }

    private func configureIfNeeded() throws {
        guard !configured else { return }
        guard let device = AVCaptureDevice.default(for: .video) else { throw CameraCaptureError.noCameraDevice }
        guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            throw CameraCaptureError.inputCreationFailed
        }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        if session.canSetSessionPreset(.hd1280x720) { session.sessionPreset = .hd1280x720 }
        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else {
            session.removeInput(input)
            throw CameraCaptureError.inputCreationFailed
        }
        session.addOutput(output)
        configured = true
    }

    public func start() throws {
        commandLock.lock()
        defer { commandLock.unlock() }
        try lifecycleQueue.sync {
            try configureIfNeeded()
            frameLock.withLock {
                epoch.begin()
                latest = nil
                lastConverted = .distantPast
                startedAt = Date()
            }
            if !session.isRunning { session.startRunning() }
        }
    }

    public func stop() {
        commandLock.lock()
        defer { commandLock.unlock() }
        // Reject frames immediately. Stop hardware off the authentication critical path.
        // A subsequent start is queued behind this stop, never racing it.
        frameLock.withLock {
            epoch.end()
            latest = nil
            startedAt = .distantFuture
        }
        lifecycleQueue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    public func frame(newerThan sequence: Int) -> (image: CGImage, sequence: Int)? {
        frameLock.withLock {
            guard let latest, latest.sequence > sequence else { return nil }
            return latest
        }
    }

    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = Date()
        let generation = frameLock.withLock { () -> UInt64? in
            guard epoch.active, now.timeIntervalSince(startedAt) >= warmup,
                  now.timeIntervalSince(lastConverted) >= minFrameInterval else { return nil }
            lastConverted = now
            return epoch.generation
        }
        guard let generation, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
        frameLock.withLock {
            guard epoch.accepts(generation) else { return }
            sequence += 1
            latest = (cgImage, sequence)
        }
    }
}

/// Invalidates conversions already in flight when capture stops or restarts.
struct CameraFrameEpoch {
    private(set) var generation: UInt64 = 0
    private(set) var active = false
    mutating func begin() { generation &+= 1; active = true }
    mutating func end() { generation &+= 1; active = false }
    func accepts(_ sample: UInt64) -> Bool { active && sample == generation }
}
