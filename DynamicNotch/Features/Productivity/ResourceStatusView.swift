import SwiftUI
internal import AppKit
import AVFoundation
internal import EventKit
import ApplicationServices

struct ResourceStatusView: View {
    @ObservedObject var store: QuickToolsStore
    @ObservedObject private var privacy = PrivacyPreferences()
    @State private var revision = 0
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("productivity.status.description").font(.caption).foregroundStyle(.secondary)
                LabeledContent(L10n.app("productivity.status.camera"), value: AVCaptureDevice.authorizationStatus(for: .video) == .authorized ? L10n.app("productivity.allowed") : L10n.app("productivity.notAllowed"))
                LabeledContent(L10n.app("productivity.status.calendar"), value: EKEventStore.authorizationStatus(for: .event) == .fullAccess ? L10n.app("productivity.allowed") : L10n.app("productivity.notAllowed"))
                LabeledContent(L10n.app("productivity.status.accessibility"), value: AXIsProcessTrusted() ? L10n.app("productivity.allowed") : L10n.app("productivity.notAllowed"))
                Text("\(L10n.app("productivity.status.connections")): \(connectionCount)")
                Text(DownloadFolderAuthorization.resolve(UserDefaults.standard.data(forKey: DownloadFolderAuthorization.bookmarkKey) ?? Data())?.lastPathComponent ?? L10n.app("productivity.status.noFolder"))
                Text("\(L10n.app("productivity.tool.awake")): \(store.awake.until != nil || store.focus.awake.until != nil ? L10n.app("productivity.active") : L10n.app("productivity.inactive"))")
                Button("productivity.status.stopAwake") { store.awake.stop(); store.focus.awake.stop(); revision += 1 }
                Button("productivity.status.stopConnections") { privacy.onlineLyrics = false; privacy.ipLookup = false; privacy.localMusicRemote = false }
                Button("productivity.status.stopMonitors") { NotificationCenter.default.post(name: .pauseLocalMonitors, object: nil) }
                Button("productivity.status.refresh") { revision += 1 }
                if store.jobs.isRunning { Button("productivity.jobs.cancel") { store.jobs.cancel() } }
                Text("productivity.status.inFlight").font(.caption).foregroundStyle(.secondary)
            }.padding().id(revision)
        }
    }
    private var connectionCount: Int { [PrivacyPolicy.onlineLyricsKey, PrivacyPolicy.ipLookupKey, PrivacyPolicy.localMusicRemoteKey].filter { PrivacyPolicy.allows($0) }.count }
}
extension Notification.Name { static let pauseLocalMonitors = Notification.Name("DynamicNotch.PauseLocalMonitors") }
