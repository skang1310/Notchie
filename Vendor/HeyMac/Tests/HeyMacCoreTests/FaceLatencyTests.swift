import Testing
import Foundation
import ImageIO
@testable import HeyMacCore

@Test func reportFixtureInferenceLatency() throws {
    let url = Bundle.module.url(forResource: "image_T1", withExtension: "jpg", subdirectory: "Fixtures")!
    let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
    let detector = VisionFaceDetector()
    let embedder = try FaceEmbedder()
    let classifier = try AntiSpoofClassifier()
    for index in 0..<5 {
        let start = ProcessInfo.processInfo.systemUptime
        let face = try detector.detectLargestFace(in: image)
        let detected = ProcessInfo.processInfo.systemUptime
        let frame = RGBAImage(cgImage: image)!
        let live = try classifier.liveness(for: face, in: frame)
        let classified = ProcessInfo.processInfo.systemUptime
        let embedding = try embedder.embedding(for: face, in: frame)
        let ended = ProcessInfo.processInfo.systemUptime
        #expect(!embedding.vector.isEmpty)
        #expect(live.isLive)
        print(String(format: "LATENCY sample=%d detect=%.4f live=%.4f embed=%.4f total=%.4f", index, detected-start, classified-detected, ended-classified, ended-start))
    }
}
