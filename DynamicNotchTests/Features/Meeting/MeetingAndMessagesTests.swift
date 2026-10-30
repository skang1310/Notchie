//
//  MeetingAndMessagesTests.swift
//  DynamicNotchTests
//

import XCTest
import SwiftUI
@testable import DynamicNotch

private final class MockMeetingControlProvider: MeetingControlProviderProtocol, @unchecked Sendable {
    var volume: Int = 75
    var lastSentAction: MeetingShortcutAction?
    var lastSentPlatform: MeetingPlatform?
    var detectedMeeting: (platform: MeetingPlatform, pid: pid_t?, title: String?)?

    func getInputVolume() -> Int { volume }
    func setInputVolume(_ vol: Int) { volume = vol }
    func sendShortcut(platform: MeetingPlatform, action: MeetingShortcutAction, pid: pid_t?) {
        lastSentPlatform = platform
        lastSentAction = action
    }
    func detectActiveRunningMeeting() -> (platform: MeetingPlatform, pid: pid_t?, title: String?)? {
        detectedMeeting
    }
}

private final class MockMessagesProvider: MessagesProviderProtocol, @unchecked Sendable {
    var conversations: [MessageConversation] = []
    var sentMessages: [(text: String, chatId: String)] = []

    func fetchRecentConversations(limit: Int) -> [MessageConversation] {
        conversations
    }

    func sendMessage(text: String, toChatId: String) -> Bool {
        sentMessages.append((text, toChatId))
        return true
    }
}

@MainActor
final class MeetingAndMessagesTests: XCTestCase {

    func testElapsedTimerOnlyRunsWithVisibleConsumersAndUsesWallClock() {
        let service = MeetingControlService(provider: MockMeetingControlProvider())
        defer { service.stopDetection() }
        service.startMeetingSession(title: "Test", platform: .meet)
        XCTAssertFalse(service.isElapsedTimerRunning)
        let first = UUID(), second = UUID()
        service.acquirePresentation(first)
        service.acquirePresentation(second)
        XCTAssertTrue(service.isElapsedTimerRunning)
        service.updateElapsedTime(now: service.session.startTime!.addingTimeInterval(75))
        XCTAssertEqual(service.session.elapsedSeconds, 75)
        service.releasePresentation(first)
        XCTAssertTrue(service.isElapsedTimerRunning)
        service.releasePresentation(second)
        XCTAssertFalse(service.isElapsedTimerRunning)
        service.acquirePresentation(first)
        service.stopMeetingSession()
        XCTAssertFalse(service.isElapsedTimerRunning)
    }

    func testMeetingSessionStateFormatting() {
        var state = MeetingSessionState(
            isActive: true,
            platform: .zoom,
            title: "Sprint Standup",
            elapsedSeconds: 0
        )
        XCTAssertEqual(state.formattedDuration, "00:00")

        state.elapsedSeconds = 75
        XCTAssertEqual(state.formattedDuration, "01:15")

        state.elapsedSeconds = 3665
        XCTAssertEqual(state.formattedDuration, "01:01:05")

        XCTAssertEqual(MeetingPlatform.zoom.displayName, "Zoom")
        XCTAssertEqual(MeetingPlatform.meet.displayName, "Google Meet")
        XCTAssertEqual(MeetingPlatform.teams.displayName, "Microsoft Teams")
        XCTAssertEqual(MeetingPlatform.facetime.displayName, "FaceTime")
    }

    func testMeetingControlServiceMuteAndUnmute() {
        let mock = MockMeetingControlProvider()
        mock.volume = 70

        let service = MeetingControlService(provider: mock)
        XCTAssertFalse(service.session.isMuted)
        XCTAssertEqual(service.inputVolume, 70)

        // Toggle to Mute
        service.toggleMute()
        XCTAssertTrue(service.session.isMuted)
        XCTAssertEqual(service.inputVolume, 0)
        XCTAssertEqual(mock.volume, 0)
        XCTAssertEqual(mock.lastSentAction, .toggleMute)

        // Toggle to Unmute
        service.toggleMute()
        XCTAssertFalse(service.session.isMuted)
        XCTAssertEqual(service.inputVolume, 70)
        XCTAssertEqual(mock.volume, 70)
        XCTAssertEqual(mock.lastSentAction, .toggleMute)
    }

    func testMeetingControlServiceCameraAndLeave() {
        let mock = MockMeetingControlProvider()
        let service = MeetingControlService(provider: mock)

        XCTAssertTrue(service.session.isCameraOn)
        service.toggleCamera()
        XCTAssertFalse(service.session.isCameraOn)
        XCTAssertEqual(mock.lastSentAction, .toggleCamera)

        // Start session
        service.startMeetingSession(title: "Design Review", platform: .meet)
        XCTAssertTrue(service.session.isActive)
        XCTAssertEqual(service.session.title, "Design Review")
        XCTAssertEqual(service.session.platform, .meet)

        // Leave call
        service.leaveMeeting()
        XCTAssertFalse(service.session.isActive)
        XCTAssertEqual(mock.lastSentAction, .leaveCall)
    }

    func testMessagesModelsAndInitials() {
        let conv1 = MessageConversation(id: "chat-1", displayName: "Dohan Kim", handle: "+18086661044")
        XCTAssertEqual(conv1.avatarInitials, "DK")

        let conv2 = MessageConversation(id: "chat-2", displayName: "꼬순", handle: "+821091769092")
        XCTAssertEqual(conv2.avatarInitials, "꼬순")

        let conv3 = MessageConversation(id: "chat-3", displayName: "Mom", handle: "Mom")
        XCTAssertEqual(conv3.avatarInitials, "MO")

        let msg = ChatMessageItem(text: "Hello from Notch", isFromMe: true, date: Date(), status: .sent)
        XCTAssertEqual(msg.text, "Hello from Notch")
        XCTAssertTrue(msg.isFromMe)
        XCTAssertEqual(msg.status, .sent)
    }

    func testMessagesServiceSendingAndReactions() async {
        let mock = MockMessagesProvider()
        let testConv = MessageConversation(id: "test-chat-1", displayName: "Alice", handle: "alice@test.com")
        mock.conversations = [testConv]

        let service = MessagesService(provider: mock)
        service.selectConversation(testConv)

        // Send a text message
        service.sendMessage(text: "Testing Droppy Quick Reply", to: testConv)
        let messages = service.messagesByChatId[testConv.id] ?? []
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages.first?.text, "Testing Droppy Quick Reply")
        XCTAssertEqual(messages.first?.status, .sent)

        // Send an emoji reaction
        service.sendReaction(emoji: "👍", to: testConv)
        let updatedMessages = service.messagesByChatId[testConv.id] ?? []
        XCTAssertEqual(updatedMessages.count, 2)
        XCTAssertEqual(updatedMessages.last?.text, "👍")
    }

    func testQuickToolsStoreIntegration() {
        let store = QuickToolsStore()

        XCTAssertTrue(QuickToolTab.allTabs.contains { $0.id == "meeting" })
        XCTAssertTrue(QuickToolTab.allTabs.contains { $0.id == "messages" })

        store.hubMode = .meeting
        XCTAssertEqual(store.shelfExtraHeight(isIsland: true), 54)

        store.hubMode = .messages
        XCTAssertEqual(store.shelfExtraHeight(isIsland: true), 280)
    }

    func testGoogleMeetDetectionAndPlatformProperties() {
        XCTAssertEqual(MeetingPlatform.meet.displayName, "Google Meet")
        XCTAssertEqual(MeetingPlatform.meet.iconName, "video.badge.checkmark")

        let mock = MockMeetingControlProvider()
        mock.detectedMeeting = (.meet, 12345, "Meet - team-sync-daily")

        let service = MeetingControlService(provider: mock)
        service.pollRunningMeeting()

        XCTAssertTrue(service.session.isActive)
        XCTAssertEqual(service.session.platform, .meet)
        XCTAssertEqual(service.session.title, "Meet - team-sync-daily")
        XCTAssertEqual(service.detectedPid, 12345)

        // Ending meeting cleans up session
        mock.detectedMeeting = nil
        service.pollRunningMeeting()
        XCTAssertFalse(service.session.isActive)
    }

    func testNotchIncomingMessageAndReplyContent() {
        let incoming = NotchIncomingMessage(
            sender: "Evyatar Ram",
            text: "Can you review the PR?",
            app: .slack
        )
        XCTAssertEqual(incoming.avatarInitials, "ER")
        XCTAssertEqual(incoming.app.displayName, "Slack")
        XCTAssertEqual(incoming.app.iconName, "number")

        var sentReply: String?
        var dismissed = false
        let content = NotchMessageReplyContent(
            message: incoming,
            onSend: { sentReply = $0 },
            onDismiss: { dismissed = true }
        )

        XCTAssertEqual(content.id, "message.reply." + incoming.id)
        XCTAssertTrue(content.isExpandable)
        XCTAssertTrue(content.expandsOnTap)
        XCTAssertTrue(content.pinsExpandedInteraction)
        XCTAssertEqual(content.priority, 950)

        let compact = content.compactSize(baseWidth: 100, baseHeight: 30)
        XCTAssertGreaterThan(compact.width, 100)

        let expanded = content.expandedSize(baseWidth: 100, baseHeight: 30)
        XCTAssertGreaterThan(expanded.width, compact.width)
        XCTAssertGreaterThan(expanded.height, compact.height)

        XCTAssertNotNil(content.compactView())
        XCTAssertNotNil(content.expandedView())
    }

    func testKoreanLanguageSystemResolution() {
        let lang = DynamicNotchLanguage.system
        XCTAssertEqual(lang.effectiveNotchLanguage, .korean)
        XCTAssertTrue(lang.bundleLanguageCandidates.contains("ko"))
        XCTAssertTrue(DynamicNotchLanguage.notchLanguages.contains(.korean))

        // Ensure legacy upstream "ru" default is rejected on non-Russian OS and resolves to system / Korean
        let resolvedRu = DynamicNotchLanguage.resolved("ru")
        XCTAssertEqual(resolvedRu, .system)
        XCTAssertEqual(resolvedRu.effectiveNotchLanguage, .korean)
    }

    func testGoogleMeetShortcutResolutionAndFallback() {
        let provider = DefaultMeetingControlProvider()
        // When platform is unknown or PID is nil, sendShortcut resolves running meeting or defaults to .meet
        // Ensures no fatal crash or silent drop
        provider.sendShortcut(platform: .unknown, action: .toggleMute, pid: nil)
        provider.sendShortcut(platform: .meet, action: .toggleCamera, pid: nil)
        provider.sendShortcut(platform: .meet, action: .leaveCall, pid: nil)
    }
}
