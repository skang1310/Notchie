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
        XCTAssertEqual(store.shelfExtraHeight(isIsland: true), 220)

        store.hubMode = .messages
        XCTAssertEqual(store.shelfExtraHeight(isIsland: true), 280)
    }
}
