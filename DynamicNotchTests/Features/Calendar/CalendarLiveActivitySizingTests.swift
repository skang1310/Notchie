import XCTest
import EventKit
@testable import DynamicNotch

@MainActor
final class CalendarLiveActivitySizingTests: XCTestCase {

    func testCalendarNotchContentSizingForKoreanAndLongStrings() {
        let calendarVM = CalendarViewModel()
        let settingsVM = SettingsViewModel()
        let notchVM = NotchViewModel(settings: settingsVM)
        let content = CalendarNotchContent(calendarViewModel: calendarVM, notchViewModel: notchVM)
        
        let baseWidth: CGFloat = 200
        let baseHeight: CGFloat = 36
        
        // When there is no event, formattedNextEventTime is empty -> fallback 110
        let emptySize = content.compactSize(baseWidth: baseWidth, baseHeight: baseHeight)
        XCTAssertEqual(emptySize.width, baseWidth + 110)
        
        // Create an event
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = "디자인 리뷰 미팅"
        event.startDate = Date()
        event.endDate = Date().addingTimeInterval(3600)
        calendarVM.nextEvent = event
        
        // Even with standard time strings, requiredExtraWidth must be >= 200
        // ensuring right wing has >= 100pt, avoiding bezel overlap for Korean "오후 1:00"
        let compactSize = content.compactSize(baseWidth: baseWidth, baseHeight: baseHeight)
        XCTAssertGreaterThanOrEqual(compactSize.width, baseWidth + 200)
        
        // Measure right-wing available clearance
        let extraWidth = compactSize.width - baseWidth
        let rightWingAvailable = extraWidth / 2 - 14 // 14pt trailing padding
        
        let font = NSFont.systemFont(ofSize: 14)
        let sampleKoreanTime = "오후 1:00"
        let textWidth = (sampleKoreanTime as NSString).size(withAttributes: [.font: font]).width
        
        // Crucial invariant: right wing space must strictly exceed text width with at least 10pt safety gap
        XCTAssertGreaterThan(rightWingAvailable, textWidth + 10, "Korean text '오' must not be obscured under notch bezel")
    }

    func testTimerCompactSizingPreventsClipping() {
        let mockVM = TimerViewModel(monitor: InactiveClockTimerMonitor())
        let settingsVM = SettingsViewModel()
        let content = TimerNotchContent(timerViewModel: mockVM, settingsViewModel: settingsVM)
        
        // InactiveClockTimerMonitor formattedTime defaults to "0:00" containing ":"
        XCTAssertEqual(content.minimalTimerSize, 140, "Timer MM:SS format must provide 140pt extra width to avoid digit clipping")
        
        let compactSize = content.compactSize(baseWidth: 200, baseHeight: 36)
        XCTAssertEqual(compactSize.width, 340)
    }

    func testDownloadCompactSizingPreventsPercentClipping() {
        let downloadVM = DownloadViewModel(monitor: FakeFileDownloadMonitor())
        let settingsVM = SettingsViewModel()
        
        settingsVM.mediaAndFiles.downloadsProgressIndicatorStyle = .percent
        let percentContent = DownloadNotchContent(downloadViewModel: downloadVM, settingsViewModel: settingsVM)
        let percentSize = percentContent.compactSize(baseWidth: 200, baseHeight: 36)
        XCTAssertEqual(percentSize.width, 315, "Percent download indicator must have 115pt extra width for '100%'")
        
        settingsVM.mediaAndFiles.downloadsProgressIndicatorStyle = .circle
        let circleContent = DownloadNotchContent(downloadViewModel: downloadVM, settingsViewModel: settingsVM)
        let circleSize = circleContent.compactSize(baseWidth: 200, baseHeight: 36)
        XCTAssertEqual(circleSize.width, 285, "Circle download indicator must have 85pt extra width for thumbnail + ring")
    }

    func testBluetoothCompactSizingPreventsIconAndPercentClipping() {
        let bluetoothVM = BluetoothViewModel()
        let connectivitySettings = ConnectivitySettingsStore(defaults: UserDefaults(suiteName: "BluetoothTests")!)
        let appSettings = ApplicationSettingsStore(defaults: UserDefaults(suiteName: "BluetoothTests")!)
        
        connectivitySettings.bluetoothAppearanceStyle = .compact
        connectivitySettings.bluetoothBatteryIndicatorStyle = .percent
        let percentContent = BluetoothConnectedNotchContent(bluetoothViewModel: bluetoothVM, settings: connectivitySettings, applicationSettings: appSettings)
        XCTAssertEqual(percentContent.compactSize(baseWidth: 200, baseHeight: 36).width, 315)
        
        connectivitySettings.bluetoothBatteryIndicatorStyle = .circle
        let circleContent = BluetoothConnectedNotchContent(bluetoothViewModel: bluetoothVM, settings: connectivitySettings, applicationSettings: appSettings)
        XCTAssertEqual(circleContent.compactSize(baseWidth: 200, baseHeight: 36).width, 285)
    }

    func testScreenRecordingCompactSizingPreventsDurationClipping() {
        let screenVM = ScreenRecordingViewModel(monitor: InactiveScreenRecordingMonitor())
        let settingsVM = SettingsViewModel()
        
        settingsVM.screenRecording.screenRecordingStyle = .detailed
        let detailedContent = ScreenRecordingContent(screenRecordingViewModel: screenVM, settingsViewModel: settingsVM)
        XCTAssertEqual(detailedContent.compactSize(baseWidth: 200, baseHeight: 36).width, 360, "Detailed recording requires 160pt for duration")
        
        settingsVM.screenRecording.screenRecordingStyle = .compact
        let compactContent = ScreenRecordingContent(screenRecordingViewModel: screenVM, settingsViewModel: settingsVM)
        XCTAssertEqual(compactContent.compactSize(baseWidth: 200, baseHeight: 36).width, 275)
    }

    func testVpnActiveCompactSizingPreventsDurationClipping() {
        let defaults = UserDefaults(suiteName: "VpnLiveActivitySizingTests")!
        let connectivitySettings = ConnectivitySettingsStore(defaults: defaults)
        let vpnVM = VpnViewModel(monitor: FakeWifiMonitor(), settings: connectivitySettings)
        let settingsVM = SettingsViewModel()
        let notchVM = NotchViewModel(settings: settingsVM)
        let content = VpnActiveNotchContent(vpnViewModel: vpnVM, notchViewModel: notchVM)
        XCTAssertEqual(content.compactSize(baseWidth: 200, baseHeight: 36).width, 330, "VPN requires 130pt extra width")
    }

    func testCalendarScheduleFullScheduleStateAndMutualExclusion() {
        let store = QuickToolsStore.shared
        store.isCalendarFullScheduleVisible = false
        store.isSoundMixerVisibleInCalendarSlot = false
        store.isLyricsVisibleInCalendarSlot = false

        XCTAssertFalse(store.isCalendarFullScheduleVisible)

        store.isCalendarFullScheduleVisible = true
        XCTAssertTrue(store.isCalendarFullScheduleVisible)

        // Opening Sound Mixer should reset calendar full schedule
        store.toggleSoundMixerInCalendarSlot()
        XCTAssertTrue(store.isSoundMixerVisibleInCalendarSlot)
        XCTAssertFalse(store.isCalendarFullScheduleVisible)

        // Opening full schedule again
        store.isCalendarFullScheduleVisible = true
        XCTAssertTrue(store.isCalendarFullScheduleVisible)

        // Opening Lyrics should reset calendar full schedule
        store.toggleLyricsInCalendarSlot()
        XCTAssertTrue(store.isLyricsVisibleInCalendarSlot)
        XCTAssertFalse(store.isCalendarFullScheduleVisible)

        // Cleanup
        store.isLyricsVisibleInCalendarSlot = false
        store.isSoundMixerVisibleInCalendarSlot = false
        store.isCalendarFullScheduleVisible = false
    }
}
