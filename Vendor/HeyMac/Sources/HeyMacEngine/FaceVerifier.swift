import CoreGraphics
import Foundation
import HeyMacCore

public struct VerificationOutcome: Equatable, Sendable {
    public var matched = false
    public var framesEvaluated = 0
    public var framesWithoutFace = 0
    public var bestSimilarity: Float = -1
    public var bestLiveness: Float = 0
    public var failure: String?
    public var mismatched = false
    public var wrongFaceFrames = 0
    public var longestWrongStreak = 0
    public var matchThreshold: Float = 0
    public var cameraStartSeconds: Double = 0
    public var firstFrameSeconds: Double = -1
    public var inferenceSeconds: Double = 0

    public init() {}

    public var debugSummary: String {
        String(format: "faceFrames=%d noFaceFrames=%d wrongFaceFrames=%d longestWrongStreak=%d/%d bestSimilarity=%.3f threshold=%.2f bestLiveness=%.3f",
               framesEvaluated, framesWithoutFace, wrongFaceFrames, longestWrongStreak, FaceVerifier.mismatchFrames,
               bestSimilarity, matchThreshold, bestLiveness)
    }

    public var summary: String {
        if let failure { return "FAIL (\(failure))" }
        let scores = String(format: "frames=%d noFace=%d bestSimilarity=%.3f bestLiveness=%.3f",
                            framesEvaluated, framesWithoutFace, bestSimilarity, bestLiveness)
        return (matched ? "OK " : "FAIL ") + scores + String(format: " cameraStart=%.3fs firstFrame=%.3fs inference=%.3fs", cameraStartSeconds, firstFrameSeconds, inferenceSeconds)
    }
}

public protocol FaceMatching: AnyObject {
    func run(timeout: TimeInterval, requiredConsecutive: Int, waitForTurn: TimeInterval,
             keepGoing: () -> Bool) -> VerificationOutcome
}

/// Runs a bounded verification window over live camera frames. A match needs
/// `requiredConsecutive` consecutive frames that are both live and above the similarity
/// threshold, so one lucky frame can't unlock. `sessionLock` is shared by everything that
/// uses the camera, so only one window or enrollment runs at a time.
public final class FaceVerifier: FaceMatching, @unchecked Sendable {
    private let camera: FrameSource
    private let pipeline: VerificationPipeline
    private let sessionLock: NSLock
    static let mismatchFrames = 6

    public init(camera: FrameSource, pipeline: VerificationPipeline, sessionLock: NSLock = NSLock()) {
        self.camera = camera
        self.pipeline = pipeline
        self.sessionLock = sessionLock
    }

    public func run(
        timeout: TimeInterval, requiredConsecutive: Int = 2, waitForTurn: TimeInterval = 0,
        keepGoing: () -> Bool = { true }
    ) -> VerificationOutcome {
        var outcome = VerificationOutcome()
        guard sessionLock.lock(before: Date().addingTimeInterval(waitForTurn)) else {
            outcome.failure = "camera busy with another verification"
            return outcome
        }
        defer { sessionLock.unlock() }

        // Load the enrollment before touching the camera: no enrollment or no key access
        // fails instantly, without flashing the camera light.
        let centroid: FaceEmbedding
        do {
            centroid = try pipeline.loadEnrolledCentroid()
        } catch KeychainKeyProviderError.interactionRequired {
            outcome.failure = "keychain access needs approval: open Hey Mac and run the face test"
            return outcome
        } catch SecureStoreError.notFound {
            outcome.failure = "not enrolled"
            return outcome
        } catch {
            outcome.failure = "enrollment unavailable: \(error)"
            return outcome
        }

        guard keepGoing() else { return outcome }
        let deadline = Date().addingTimeInterval(timeout)
        let started = ProcessInfo.processInfo.systemUptime
        do {
            try camera.start()
            outcome.cameraStartSeconds = ProcessInfo.processInfo.systemUptime - started
        } catch {
            outcome.failure = "camera unavailable: \(error)"
            return outcome
        }
        defer { camera.stop() }

        var lastSequence = 0
        outcome.matchThreshold = pipeline.config.matchThreshold
        var consecutive = 0
        var wrongStreak = 0
        while Date() < deadline, keepGoing() {
            guard let frame = camera.frame(newerThan: lastSequence) else {
                Thread.sleep(forTimeInterval: 0.005)
                continue
            }
            lastSequence = frame.sequence
            if outcome.firstFrameSeconds < 0 { outcome.firstFrameSeconds = ProcessInfo.processInfo.systemUptime - started }
            let inferenceStart = ProcessInfo.processInfo.systemUptime
            do {
                let evaluation = try pipeline.evaluate(image: frame.image, against: centroid)
                outcome.inferenceSeconds += ProcessInfo.processInfo.systemUptime - inferenceStart
                // Inference may finish after cancellation or a manual unlock.
                guard keepGoing() else { return outcome }
                outcome.framesEvaluated += 1
                outcome.bestSimilarity = max(outcome.bestSimilarity, evaluation.similarity)
                outcome.bestLiveness = max(outcome.bestLiveness, evaluation.liveness)
                consecutive = evaluation.accepted ? consecutive + 1 : 0
                wrongStreak = evaluation.isMatch ? 0 : wrongStreak + 1
                if !evaluation.isMatch { outcome.wrongFaceFrames += 1 }
                outcome.longestWrongStreak = max(outcome.longestWrongStreak, wrongStreak)

                // Face ID fast match: if user has confirmed eye attention (open eyes + facing camera)
                // and matches the enrolled identity, match instantly on the first frame!
                // For edge cases, require consecutive matching frames.
                let isInstantMatch = evaluation.accepted && evaluation.hasEyeAttention && evaluation.similarity >= pipeline.config.matchThreshold
                if isInstantMatch || consecutive >= requiredConsecutive {
                    outcome.matched = true
                    return outcome
                }
                if wrongStreak >= Self.mismatchFrames {
                    outcome.mismatched = true
                    return outcome
                }
            } catch {
                outcome.inferenceSeconds += ProcessInfo.processInfo.systemUptime - inferenceStart
                outcome.framesWithoutFace += 1
                consecutive = 0
                wrongStreak = 0
            }
        }
        return outcome
    }
}
