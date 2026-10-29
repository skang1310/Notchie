import Testing
@testable import HeyMacEngine

@Test func stoppedCameraRejectsConversionAlreadyInFlight() {
    var epoch = CameraFrameEpoch()
    epoch.begin()
    let sample = epoch.generation
    #expect(epoch.accepts(sample))
    epoch.end()
    #expect(!epoch.accepts(sample))
}

@Test func restartedCameraCannotPublishPreviousSessionsFrame() {
    var epoch = CameraFrameEpoch()
    epoch.begin()
    let old = epoch.generation
    epoch.end()
    epoch.begin()
    #expect(!epoch.accepts(old))
    #expect(epoch.accepts(epoch.generation))
}
