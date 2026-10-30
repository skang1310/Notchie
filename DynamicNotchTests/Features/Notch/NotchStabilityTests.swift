import XCTest
import AppKit
@testable import DynamicNotch

@MainActor
final class NotchStabilityTests: XCTestCase {
    private func engine(delay: TimeInterval = 0.005) -> NotchEngine {
        NotchEngine(animations: { .preset(.fluid) }, hideDelay: delay, queueDelay: 0)
    }
    func testExpandedInteractionDefersOrdinaryAlertAndPriorityChange() async {
        let engine = engine()
        engine.send(.showLiveActivity(TestNotchContent(id: "working", priority: 5, isExpandable: true)))
        await assertEventually { await MainActor.run { engine.notchModel.liveActivityContent?.id == "working" } }
        engine.expand()
        engine.send(.showLiveActivity(TestNotchContent(id: "background", priority: 20)))
        engine.send(.showTemporaryNotification(TestNotchContent(id: "ordinary", priority: 10), duration: 1))
        try? await Task.sleep(for: .milliseconds(40))
        XCTAssertTrue(engine.notchModel.isExpanded)
        XCTAssertEqual(engine.notchModel.liveActivityContent?.id, "working")
        XCTAssertNil(engine.notchModel.temporaryNotificationContent)
        engine.collapse()
        await assertEventually { await MainActor.run { engine.notchModel.temporaryNotificationContent?.id == "ordinary" } }
        engine.hideTemporaryNotification()
        await assertEventually { await MainActor.run { engine.notchModel.temporaryNotificationContent == nil && engine.notchModel.liveActivityContent?.id == "background" } }
    }
    func testExpiredDeferredAlertDoesNotReplayAfterLongInteraction() async {
        let engine = engine()
        engine.send(.showLiveActivity(TestNotchContent(id: "working", priority: 5, isExpandable: true)))
        await assertEventually { await MainActor.run { engine.notchModel.liveActivityContent != nil } }
        engine.expand()
        engine.send(.showTemporaryNotification(TestNotchContent(id: "expired", priority: 10), duration: 0.02))
        try? await Task.sleep(for: .milliseconds(50))
        engine.collapse()
        await assertEventually { await MainActor.run { !engine.notchModel.isExpanded } }
        try? await Task.sleep(for: .milliseconds(30))
        XCTAssertNil(engine.notchModel.temporaryNotificationContent)
    }
    func testUrgentTimerInterruptsExpandedHubAndOrdinaryAlertCannotReplaceIt() async {
        let engine = engine()
        engine.send(.showLiveActivity(TestNotchContent(id: "working", priority: Int.max / 2, isExpandable: true)))
        await assertEventually { await MainActor.run { engine.notchModel.liveActivityContent != nil } }
        engine.expand()
        engine.send(.showTemporaryNotification(TimerFinishedNotchContent(), duration: 1))
        await assertEventually { await MainActor.run { engine.notchModel.temporaryNotificationContent?.id == NotchContentRegistry.Media.timerFinished.id } }
        engine.send(.showTemporaryNotification(TestNotchContent(id: "ordinary", priority: 20), duration: 0.02))
        try? await Task.sleep(for: .milliseconds(40))
        XCTAssertEqual(engine.notchModel.temporaryNotificationContent?.id, NotchContentRegistry.Media.timerFinished.id)
        engine.hideTemporaryNotification()
        await assertEventually { await MainActor.run { engine.notchModel.temporaryNotificationContent == nil && engine.notchModel.liveActivityContent?.id == "working" } }
    }
    func testSystemCriticalActivityOutranksManuallyOpenedHub() async {
        let engine = engine()
        engine.send(.showLiveActivity(TestNotchContent(id: "hub", priority: Int.max / 2, isExpandable: true)))
        await assertEventually { await MainActor.run { engine.notchModel.liveActivityContent != nil } }
        engine.expand()
        engine.send(.showLiveActivity(TestNotchContent(id: "lock", priority: NotchContentPriority.lockScreen)))
        await assertEventually { await MainActor.run { engine.notchModel.liveActivityContent?.id == "lock" } }
        XCTAssertFalse(engine.notchModel.isExpanded)
    }
    func testEndingExpandedActivityStillRevealsNextActivity() async {
        let engine = engine()
        engine.send(.showLiveActivity(TestNotchContent(id: "fallback", priority: 1)))
        engine.send(.showLiveActivity(TestNotchContent(id: "working", priority: 5, isExpandable: true)))
        await assertEventually { await MainActor.run { engine.notchModel.liveActivityContent?.id == "working" } }
        engine.expand()
        engine.send(.hideLiveActivity(id: "working"))
        await assertEventually { await MainActor.run { engine.notchModel.liveActivityContent?.id == "fallback" } }
        XCTAssertFalse(engine.notchModel.isExpanded)
    }
    func testEndedActivityIsNotResurrectedDuringTransitionDelay() async {
        let engine = engine(delay: 0.08)
        engine.send(.showLiveActivity(TestNotchContent(id: "first", priority: 1)))
        await assertEventually { await MainActor.run { engine.notchModel.liveActivityContent?.id == "first" } }
        engine.send(.showLiveActivity(TestNotchContent(id: "ended", priority: 10)))
        await assertEventually { await MainActor.run { engine.notchModel.liveActivityContent == nil } }
        engine.send(.hideLiveActivity(id: "ended"))
        await assertEventually { await MainActor.run { engine.notchModel.liveActivityContent?.id == "first" } }
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(engine.notchModel.liveActivityContent?.id, "first")
    }
    func testEqualPriorityArrivalDoesNotChurnVisibleActivity() async {
        let engine = engine()
        engine.send(.showLiveActivity(TestNotchContent(id: "z-visible", priority: 5)))
        await assertEventually { await MainActor.run { engine.notchModel.liveActivityContent?.id == "z-visible" } }
        engine.send(.showLiveActivity(TestNotchContent(id: "a-arrival", priority: 5)))
        try? await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(engine.notchModel.liveActivityContent?.id, "z-visible")
        engine.send(.hideLiveActivity(id: "z-visible"))
        await assertEventually { await MainActor.run { engine.notchModel.liveActivityContent?.id == "a-arrival" } }
    }
    func testCancelPendingExpansionAndMenuTrackingProtectInteraction() async {
        let model = NotchViewModel(settings: TestNotchSettings(), hideDelay: 0, queueDelay: 0,
            screenMetricsProvider: { _ in (1440, 0, nil) })
        model.send(.showLiveActivity(TestNotchContent(id: "working", priority: 5, isExpandable: true)))
        await assertEventually { await MainActor.run { model.notchModel.liveActivityContent != nil } }
        model.expandActiveLiveActivity()
        model.cancelPendingExpansion()
        try? await Task.sleep(for: .milliseconds(80))
        XCTAssertFalse(model.notchModel.isExpanded)
        model.expandActiveLiveActivity()
        await assertEventually { await MainActor.run { model.notchModel.isExpanded } }
        model.isMenuTracking = true
        model.handleOutsideClick()
        XCTAssertTrue(model.notchModel.isExpanded)
        model.isMenuTracking = false
        model.handleOutsideClick()
        await assertEventually { await MainActor.run { !model.notchModel.isExpanded } }
    }
    func testPointerInvalidationAndPortraitDisplayFit() async {
        let model = NotchViewModel(settings: TestNotchSettings(), hideDelay: 0, queueDelay: 0,
            screenMetricsProvider: { _ in (720, 0, nil) })
        model.send(.showLiveActivity(TestNotchContent(id: "large", priority: 5, isExpandable: true, expandedWidthOffset: 800)))
        await assertEventually { await MainActor.run { model.notchModel.liveActivityContent != nil } }
        model.expandActiveLiveActivity()
        await assertEventually { await MainActor.run { model.notchModel.isExpanded } }
        model.updatePresentationBounds(CGSize(width: 720, height: 1280))
        XCTAssertLessThanOrEqual(model.presentedNotchSize.width * model.presentationScale, 696)
        let revision = model.pointerInteractionRevision
        model.invalidatePointerInteraction()
        XCTAssertNotEqual(model.pointerInteractionRevision, revision)
        XCTAssertFalse(model.isPressed)
    }
    func testDisabledWindowMarginCreatesNoConstraintHooks() {
        let name = "Notchie.ConstraintTest.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = ApplicationSettingsStore(defaults: defaults)
        settings.isNotchlessWindowMarginEnabled = false
        let constrainer = NotchlessWindowConstrainer(settings: settings)
        constrainer.start()
        XCTAssertFalse(constrainer.hasActiveConstraintMonitors)
        constrainer.stop()
        XCTAssertFalse(constrainer.hasActiveConstraintMonitors)
    }
    func testDisplayLayoutHandlesNegativeOriginsAndSmallScreens() {
        let screen = CGRect(x: -720, y: -200, width: 720, height: 1280)
        let canvas = OverlayWindowLayout.canvasSize(for: screen.size)
        let frame = OverlayWindowLayout.topAnchoredFrame(screenFrame: screen, size: canvas)
        XCTAssertEqual(frame.midX, screen.midX)
        XCTAssertEqual(frame.maxY, screen.maxY + 1)
        XCTAssertLessThanOrEqual(frame.width, screen.width)
        XCTAssertEqual(OverlayWindowLayout.fitScale(content: CGSize(width: 780, height: 330), available: CGSize(width: 696, height: 1200)), 696.0 / 780, accuracy: 0.0001)
    }
    func testBuiltInAutoFallbackAndReconnectKeepStoredPreference() {
        let preferences = NotchScreenSelectionPreferences(displayLocation: .builtIn, preferredDisplayUUID: nil, allowsAutomaticDisplaySwitching: true)
        let external = NotchScreenSelectionCandidate(displayID: 42, displayUUID: "EXTERNAL", isBuiltIn: false)
        let builtIn = NotchScreenSelectionCandidate(displayID: 11, displayUUID: "BUILTIN", isBuiltIn: true)
        XCTAssertEqual(NotchScreenSelection.preferredDisplayID(for: preferences, candidates: [external], primaryDisplayID: 42), 42)
        XCTAssertEqual(NotchScreenSelection.preferredDisplayID(for: preferences, candidates: [external, builtIn], primaryDisplayID: 42), 11)
        XCTAssertNil(NotchScreenSelection.preferredDisplayID(for: preferences, candidates: [], primaryDisplayID: 42))
    }
}
