import XCTest
import AppKit
import SwiftUI
@testable import DynamicNotch

@MainActor
final class AlcoveSettingsExtensionTests: XCTestCase {
    private func isolated(_ run: (UserDefaults) -> Void) {
        let name = "DynamicNotch.LocalSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        run(defaults)
    }
    func testInputTogglesPersistIndependently() {
        isolated { defaults in
            let store = ApplicationSettingsStore(defaults: defaults)
            store.isNotchMouseDragGesturesEnabled = false
            store.isNotchTrackpadSwipeGesturesEnabled = true
            store.isNotchSwipeDismissEnabled = false
            store.isNotchSwipeRestoreEnabled = true
            let restored = ApplicationSettingsStore(defaults: defaults)
            XCTAssertFalse(restored.isNotchMouseDragGesturesEnabled)
            XCTAssertTrue(restored.isNotchTrackpadSwipeGesturesEnabled)
            XCTAssertFalse(restored.isNotchSwipeDismissEnabled)
            XCTAssertTrue(restored.isNotchSwipeRestoreEnabled)
        }
    }
    func testHoverDelayIsSeparateFromHoldTiming() {
        isolated { defaults in
            let settings = SettingsViewModel(defaults: defaults)
            settings.notchPressHoldDuration = 0.4
            settings.notchHoverExpandDelay = 1.1
            let provider: any NotchSettingsProviding = settings
            XCTAssertEqual(provider.notchHoverExpandDelay, 1.1, accuracy: 0.001)
            XCTAssertEqual(provider.notchPressHoldDuration, 0.4, accuracy: 0.001)
            let restored = SettingsViewModel(defaults: defaults)
            XCTAssertEqual(restored.notchHoverExpandDelay, 1.1, accuracy: 0.001)
        }
    }
    func testHoverDelaySanitizesInvalidValues() {
        XCTAssertEqual(ApplicationSettingsStore.clampNotchHoverExpandDelay(-1), 0.05)
        XCTAssertEqual(ApplicationSettingsStore.clampNotchHoverExpandDelay(5), 1.5)
        XCTAssertEqual(ApplicationSettingsStore.clampNotchHoverExpandDelay(.nan), 0.25)
        XCTAssertEqual(ApplicationSettingsStore.clampNotchHoverExpandDelay(.infinity), 0.25)
    }
    func testResetGesturesRestoresAllInputPreferences() {
        isolated { defaults in
            let store = ApplicationSettingsStore(defaults: defaults)
            store.isNotchMouseDragGesturesEnabled = false
            store.isNotchTrackpadSwipeGesturesEnabled = false
            store.notchHoverExpandDelay = 1.4
            store.isIdleNotchHoverMenuEnabled = false
            store.resetGestures()
            XCTAssertTrue(store.isNotchMouseDragGesturesEnabled)
            XCTAssertTrue(store.isNotchTrackpadSwipeGesturesEnabled)
            XCTAssertTrue(store.isIdleNotchHoverMenuEnabled)
            XCTAssertEqual(store.notchHoverExpandDelay, 0.25, accuracy: 0.001)
        }
    }
    func testUnconfiguredLocalBuildDoesNotOptIntoLoginOrFaceUnlock() {
        isolated { defaults in
            XCTAssertFalse(ApplicationSettingsStore(defaults: defaults).isLaunchAtLoginEnabled)
            XCTAssertFalse(FaceIDSettingsStore(defaults: defaults).isFaceIDEnabled)
        }
    }
    func testDownloadAccessIsOptInAndInvalidBookmarkDoesNotResolve() {
        isolated { defaults in
            let store = MediaAndFilesSettingsStore(defaults: defaults)
            XCTAssertFalse(store.isDownloadsLiveActivityEnabled)
            XCTAssertTrue(store.downloadFolderBookmark.isEmpty)
            XCTAssertFalse(store.isBrowserDownloadMetadataEnabled)
            XCTAssertNil(DownloadFolderAuthorization.resolve(store.downloadFolderBookmark))
            XCTAssertNil(DownloadFolderAuthorization.resolve(Data("invalid bookmark".utf8)))
        }
    }
    func testAppBrandingAndIconCatalogUseNotchie() throws {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String, "Notchie")
        let iconURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("DynamicNotch/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json")
        let data = try Data(contentsOf: iconURL)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let images = try XCTUnwrap(json["images"] as? [[String: Any]])
        let filenames = images.compactMap { $0["filename"] as? String }
        XCTAssertEqual(filenames.count, 20)
        XCTAssertTrue(filenames.allSatisfy { $0.hasPrefix("Notchie-Light_") || $0.hasPrefix("Notchie-Dark_") })
    }
    func testCustomAccentColorAndIdleHoverMenuPersist() {
        isolated { defaults in
            let store = ApplicationSettingsStore(defaults: defaults)
            XCTAssertEqual(store.customAccentColorHex, "#34C759")
            XCTAssertTrue(store.isIdleNotchHoverMenuEnabled)

            store.customAccentColorHex = "#007AFF"
            store.isIdleNotchHoverMenuEnabled = false

            let restored = ApplicationSettingsStore(defaults: defaults)
            XCTAssertEqual(restored.customAccentColorHex, "#007AFF")
            XCTAssertFalse(restored.isIdleNotchHoverMenuEnabled)

            restored.resetAppearance()
            XCTAssertEqual(restored.customAccentColorHex, "#34C759")
        }
    }
    func testQuickToolsCustomizableTabsPersistAndMaintainAtLeastOneTab() {
        isolated { defaults in
            let store = QuickToolsStore(defaults: defaults)
            XCTAssertEqual(store.enabledTabIDs, QuickToolTab.defaultEnabledIDs)
            store.setTabEnabled("developer", enabled: true)
            XCTAssertTrue(store.isTabEnabled("developer"))

            let reloaded = QuickToolsStore(defaults: defaults)
            XCTAssertTrue(reloaded.isTabEnabled("developer"))

            for id in QuickToolTab.allTabs.map(\.id) {
                reloaded.setTabEnabled(id, enabled: false)
            }
            XCTAssertEqual(reloaded.enabledTabIDs.count, 1)

            reloaded.resetEnabledTabs()
            XCTAssertEqual(reloaded.enabledTabIDs, QuickToolTab.defaultEnabledIDs)
        }
    }
    func testFaceIDPresentationStyleOriginalAndMinimalPersistAndPreview() {
        isolated { defaults in
            let faceSettings = FaceIDSettingsStore(defaults: defaults)
            XCTAssertEqual(faceSettings.presentationStyle, .expanded)
            faceSettings.presentationStyle = .compact

            let reloaded = FaceIDSettingsStore(defaults: defaults)
            XCTAssertEqual(reloaded.presentationStyle, .compact)

            let originalContent = FaceIDNotchContent(service: .shared, style: .expanded)
            let minimalContent = FaceIDNotchContent(service: .shared, style: .compact)
            let originalSize = originalContent.compactSize(baseWidth: 180, baseHeight: 32)
            let minimalSize = minimalContent.compactSize(baseWidth: 180, baseHeight: 32)
            XCTAssertGreaterThan(originalSize.height, minimalSize.height)
            XCTAssertGreaterThan(minimalSize.width, originalSize.width)
        }
    }
    func testStartupPermissionCheckSettingAndMissingPermissionInspection() {
        isolated { defaults in
            let store = ApplicationSettingsStore(defaults: defaults)
            XCTAssertTrue(store.isStartupPermissionCheckEnabled)
            store.isStartupPermissionCheckEnabled = false

            let reloaded = ApplicationSettingsStore(defaults: defaults)
            XCTAssertFalse(reloaded.isStartupPermissionCheckEnabled)

            let permissionController = SettingsPermissionController()
            XCTAssertEqual(permissionController.permissionItems.count, 7)
            let missingCount = permissionController.missingPermissionItems.count
            XCTAssertEqual(permissionController.allPermissionsGranted, missingCount == 0)

            let alertContent = MissingPermissionsNotchContent(missingCount: 3)
            XCTAssertEqual(alertContent.id, "settings.permissions.missingAlert")
            XCTAssertEqual(alertContent.compactSize(baseWidth: 180, baseHeight: 32).width, 340)
        }
    }

    func testGenerateDocumentationScreenshotsIfRequested() throws {
        guard let outputDir = ProcessInfo.processInfo.environment["NOTCHIE_SCREENSHOT_DIR"],
              !outputDir.isEmpty else {
            return
        }
        let dirURL = URL(fileURLWithPath: outputDir, isDirectory: true)
        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)

        let defaults = UserDefaults(suiteName: "DynamicNotch.DocsScreenshots.\(UUID().uuidString)")!
        let appSettings = ApplicationSettingsStore(defaults: defaults)
        appSettings.appearanceMode = .dark
        appSettings.customAccentColorHex = "#34C759"
        let faceSettings = FaceIDSettingsStore(defaults: defaults)
        faceSettings.presentationStyle = .expanded
        let permController = SettingsPermissionController()

        func render<V: View>(_ view: V, name: String, width: CGFloat = 780, height: CGFloat = 580) throws {
            let wrapped = view
                .frame(width: width, height: height, alignment: .top)
                .background(Color(nsColor: .windowBackgroundColor))
                .environment(\.colorScheme, .dark)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.appearance = NSAppearance(named: .darkAqua)
            let hosting = NSHostingView(rootView: wrapped)
            hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
            window.contentView = hosting
            window.displayIfNeeded()
            hosting.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.08))

            guard let contentView = window.contentView,
                  let bitmap = contentView.bitmapImageRepForCachingDisplay(in: contentView.bounds) else {
                return
            }
            contentView.cacheDisplay(in: contentView.bounds, to: bitmap)
            if let png = bitmap.representation(using: .png, properties: [:]) {
                try png.write(to: dirURL.appendingPathComponent(name), options: .atomic)
            }
            window.orderOut(nil)
        }

        try render(
            NavigationStack {
                AboutAppSettingsView(applicationSettings: appSettings, onRequestInternetAccess: { true })
            },
            name: "about-settings.png",
            width: 780,
            height: 620
        )
        try render(
            FaceIDSettingsView(settings: faceSettings, applicationSettings: appSettings, notchViewModel: nil),
            name: "face-unlock-preview.png",
            width: 780,
            height: 680
        )
        try render(
            AppearanceSettingsView(applicationSettings: appSettings),
            name: "appearance-accent.png",
            width: 780,
            height: 540
        )
        try render(
            PermissionsSettingsView(permissionController: permController, applicationSettings: appSettings),
            name: "permissions-guard.png",
            width: 780,
            height: 640
        )

        let quickStore = QuickToolsStore(defaults: defaults)
        quickStore.selectedTool = "snippets"
        ProductivityStorage.shared.update { doc in
            if doc.snippets.isEmpty {
                doc.snippets = [
                    SavedSnippet(id: UUID(), text: "git push -u origin main --tags", date: Date().addingTimeInterval(-120)),
                    SavedSnippet(id: UUID(), text: "https://github.com/skang1310/Notchie", date: Date().addingTimeInterval(-480)),
                    SavedSnippet(id: UUID(), text: "Notchie — Custom macOS Notch Workspace (GPL-3.0)", date: Date().addingTimeInterval(-1800))
                ]
            }
        }
        try render(
            QuickToolsView(store: quickStore, inNotch: false),
            name: "quick-tools-clipboard.png",
            width: 780,
            height: 540
        )
    }
}
