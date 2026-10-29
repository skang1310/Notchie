# Notchie custom edition features — 2026-10-28 / 2026-10-29

1. **Multi-Directory Screenshot Capture & Preload Modernization (2026-10-29 v31)**:
   - Fixed screenshot history not recording/displaying: `ScreenshotMonitorService` now reads modern macOS `location-screenshot`, `location-last`, and `location` keys from `com.apple.screencapture` domain.
   - Added `candidateScreenshotDirectories()` and `candidateScreenRecordingDirectories()` scanning across system screencapture paths, user custom settings path, `~/Documents`, `~/Desktop`, `~/Pictures` (and `Pictures/Screenshots`), and `~/Downloads`.
   - Expanded multilingual screenshot filename detection (`isScreenshotFilename`) to support Korean (both NFD and NFC `스크린샷`, `화면 캡처`, `캡처`), Japanese, Chinese, German, French, Spanish, Russian, and third-party tools (CleanShot, Shottr, Snagit).
   - Upgraded real-time scanner timer with `.common` run loop mode and safe path-based deduplication to prevent dropping rapid captures.
   - Fixed `processNewScreenshot` so non-staging files already on disk (e.g. in `~/Documents`) are marked `isSavedToDisk = true`, preserving user original files without redundant moving.
   - Added `.onAppear { preloadRecentScreenshots(); scanNow() }` and always-visible reload button in `NotchieScreenshotHubView`.
   - Added automated regression tests in `ScreenshotViewModelTests.swift` (`testScreenshotCandidateDirectoriesAndMultiFolderScanning` and `testScreenshotFilenameDetectionMultilingual`).
2. **Notch Clipboard 10-Item Limit & Full Settings History (2026-10-29 v30)**:
   - Limited clipboard snippet display inside the Notch (`trayAndShotsUnifiedContainer` and `studioUnifiedContainer`) to the most recent 10 items (`maxItems: 10`).
   - Added an interactive overflow affordance at the bottom of the list when additional items exist (`"외 N개 항목은 앱 설정에서 보기…"` / `"+N more in App Settings…"`) with `arrow.up.forward.app` icon, opening `SettingsWindowController.shared.showWindow()` on click.
   - Preserved unlimited full clipboard history (`maxItems: nil`) in App Settings (`Tray Settings` -> `Clipboard` tab / `trayClipboardSettingsCard`), supporting search, type filtering, preview, favorites, and clearing.
   - Added regression coverage in `ClipboardExperienceTests.swift` (`testClipboardRecentTenItemsLimitAndSettingsFullHistory`).
2. **Notch Tray Auto-Dismiss & Outside-Click Collapse (2026-10-29 v29)**:
   - Fixed "Open Tray in Notch" persistent open issue by passing `openedFromIdleHover: true`, allowing outside-click and hover-leaves auto-dismissal.
   - Added 6-second inactivity auto-dismiss timer when opened from Settings and an explicit `✕` close button in the Notch header bar.
3. **Tray & Tools Unification into 4-Segment Tray Hub (2026-10-29 v28)**:
   - Eliminated redundant "Tools" tab; merged File Transform and Clipboard History into Tray with 4 submodes: Files, Captures, Transform, Clipboard.
   - Renamed "Quick Tools Settings" to "Tray Settings" with dedicated settings tabs and direct notch tray launcher.
4. **Weather & Golden Hour removal and Notch Hover Menu tab reordering (2026-10-29 v27)**:
   - Completely removed legacy weather and golden hour code: deleted `NotchieWeather.swift`, removed `.weather` widget from `ShelfPreferences.swift`, and cleaned up test fixtures.
   - Added user-customizable tab ordering and positioning in the Notch Hover Menu: `QuickToolsStore.enabledTabIDs` now preserves user sequence order; `QuickToolsStore.moveTab(_:by:)` and `moveTab(fromOffsets:toOffset:)` enable shifting tab positions left/right.
   - Redesigned `customizableTabsCard` and `QuickToolTabCustomizerPopover` in `QuickToolsView.swift` with interactive ◀ / ▶ movement buttons and dynamic tab addition/hiding.
   - Added automated regression tests in `AlcoveSettingsExtensionTests.swift` (`testQuickToolsCustomizableTabsReorderingAndPersistence`).
2. **About page & removal of Support / Software Update pages**:
   - Removed the Support (`후원`) and Software Update (`소프트웨어 업데이트`) navigation rows from `GeneralSettingsView`, removed `Check for Updates` from `MenuBarMenu`, and removed the update badge from `SettingsRootView`.
   - Redesigned `AboutAppSettingsView` (`일반 - 정보`) as **Notchie Custom Edition**, showcasing the user's added features, local build revision (`Notchie-20261028-v2`), and open-source attributions (`DynamicNotch` GPL-3.0 and `HeyMac` MIT) without the upstream author's personal Telegram, email, or donation links.
2. **NotchNook-style Idle Notch Hover Menu & Customizable Tabs**:
   - Added persisted `isIdleNotchHoverMenuEnabled` (default `true`) in `ApplicationSettingsStore` (`GeneralSettingsStorage.Keys.idleNotchHoverMenuEnabled`), exposed in General Quick Controls and Gestures settings.
   - Extended `NotchViewModel` and `NotchEngine` (`presentIdleHoverContent`) so hovering over (or clicking) the idle notch expands the Notch Hub (`QuickToolsNotchContent`) with a top horizontal icon-tab bar (`QuickToolsView`), pin toggle (`isNotchHubPinned`), and automatic collapse back to the idle notch when the cursor leaves or on outside click.
   - Added customizable tab visibility (`QuickToolTab` / `QuickToolsStore.enabledTabIDs`) persisted in `UserDefaults`.
3. **Clipboard History Search, One-Click Re-copy & Opt-in Auto-Capture**:
   - Upgraded `ClipboardSnippetsView` and `ProductivityStorage` with real-time search filtering (`filteredSnippets(query:)`), one-click row/button re-copy with visual `"Copied!"` feedback, and an opt-in `"Auto-save copied items while running"` toggle (`isAutoCaptureClipboardEnabled`, default `false`, excluding concealed/transient pasteboard types).
4. **Custom Accent Color Picker**:
   - Added `customAccentColorHex` (default `"#34C759"`) and `customAccentColor` in `ApplicationSettingsStore` and `AppearanceSettingsView` with preset color swatches + native macOS `ColorPicker`, applied across the Notch Hub tabs, active indicators, and Face Unlock scan animations.
5. **Face Unlock Original (Full Badge Scan) vs. Minimal Style & Live Notch Preview**:
   - Added the **Notch Unlock Style & Preview (`노치 잠금 해제 스타일 및 미리보기`)** card in `FaceIDSettingsView` with side-by-side live visual previews for **Original (`FaceIDPresentationStyle.expanded` — full badge that plays the scan)** and **Minimal (`FaceIDPresentationStyle.compact` — compact lock + scan bar)** using `ScanAnimationView` (`idleanimation.mp4` / `unlockanimation.mp4`), plus **"Preview in Notch (`노치에서 미리보기`)"** buttons (`FaceIDService.playNotchPreview`) that animate the chosen style directly in the top notch.
6. **Startup Permission Check & Missing-Permission Alert (`Notchie-20261028-v3`)**:
   - Added persisted `isStartupPermissionCheckEnabled` (default `true`) in `ApplicationSettingsStore` (`GeneralSettingsStorage.Keys.startupPermissionCheckEnabled`) and exposed the **Startup Permission Check & Alert (`앱 시작 시 권한 확인 및 알림`)** card in `PermissionsSettingsView`.
   - On interactive app launch (`!AppEnvironment.isRunningTests && !isRunningUITests`), `SettingsPermissionController.shared.evaluateStartupPermissions` requests undetermined permissions and, if any required permissions remain ungranted, presents both a temporary Notch warning banner (`MissingPermissionsNotchContent`) and a native `NSAlert` listing the missing permissions with a direct button to open `SettingsSubPage.permissions`.
7. **Code Review, Optimization & Documentation Webpage (`docs/index.html`)**:
   - Cleaned up unused `SettingsSubPage.support` / `SettingsSubPage.softwareUpdate` routes, removed redundant Sparkle observer in `AppDelegate`, unified `privacyText(_:_:)` localization across custom views, shared `SettingsPermissionController.shared`, and removed staging icon archives.
   - Simplified `MenuBarMenu.swift` (`Notchie-20261028-v4`) so the menu bar item contains only **Settings (`설정`)**, **Restart (`재시작`)**, and **Quit (`종료`)**.
   - Created `docs/index.html` and updated `README.md` with rendered screenshots (`docs/screenshots/*.png`) and open-source attributions.

# Notchie branding and icon replacement — 2026-10-28 / 2026-10-29

Renamed user-facing app display/bundle name to `Notchie` (`Info.plist`, `InfoPlist.xcstrings`, `Localizable.xcstrings`, `AboutAppSettingsView`, `SoftwareUpdateSettingsView`, `AppVersionText`, and FaceID/AppPrivacy strings) while retaining internal module/executable/bundle ID `com.Jackson.DynamicNotch` and `/Applications/DynamicNotch.app` bundle path to preserve existing settings, Keychain items, and TCC permissions. Removed legacy `AppIcon`, `logo`, and `simplifiedLogo` PNGs and replaced them with the Light and Dark icon sets from `Notchie-macOS-Icons`.

On 2026-10-29, standardized all 20 app icon assets (`AppIcon.appiconset`, `NotchieIconDark`, `NotchieIconLight`, `logo`, `simplifiedLogo`, and `docs/assets`) to follow Apple's macOS Human Interface Guidelines (macOS Big Sur+):
- 824×824 pt centered squircle on a 1024×1024 pt canvas (0.805 ratio) with 100 pt margins.
- Dual native drop shadows: key shadow blur 30px, y -18px, opacity 0.25; ambient shadow blur 14px, y -4px, opacity 0.16.
- Resolves oversized Dock / Finder / Launchpad icon appearance compared to other standard macOS apps (Safari, Notes, Calendar, Slack, ChatGPT).
- Preserved master full-bleed 1024x1024 artwork under `Design/AppIconOriginal-FullBleed/`.
- Removed redundant SwiftUI `.shadow(...)` modifiers in `AppearanceSettingsView.swift` to eliminate double-shadowing.
- Added automated regression tests in `AlcoveSettingsExtensionTests.swift` enforcing 824px body width (815...835) and 100px margins.

# HeyMac app privacy extension — 2026-10-28

Added opt-in app privacy cover using existing vendored HeyMac app store/session/auth/system fallback engines. Per-app every-switch and 5/15 minute total/focus-loss relock policies, explicit registered-face preference, native Touch ID/password fallback without saving credentials, lock-all, bounded pause, recovery exclusions, native app picker and cover preview. No extra protected permission, launch agent or automatic enabling. Opaque native covers hide the target app and cancel stale auth results; sleep/lock/termination revoke sessions. Reused existing settings page via two segments and menu controls. Also corrected stale Privacy login-password text.

During development a LocalTests bootstrap EXC_BAD_ACCESS occurred repeatedly with stale incremental app artifacts; initializer cleanup + clean build passed all 265 app tests. Exact compiler/runtime cause remains unproven. Added a quiet unit-test menu path and scripts/test-app.sh (clean, one worker, distinct display name, no debug dylib). The production installed build was a different process. See TEST_REPORT.md for final evidence.

# HeyMac face unlock extension — 2026-10-28

User requested persistent /Applications delivery, Alcove-like behavior and HeyMac face unlock. Existing Alcove settings, activities, gestures and tools retained. Added explicit opt-in camera registration, live confirmation, face-only test, encrypted password saving, permission settings link, enable/disable and confirmed removal. HeyMac core/engine/models are vendored at 8cfbe360dc1cccd5cae42f44727da68685e549dc with MIT/model notices; separate Keychain, preferences and support directory. No automatic enrollment, permission request, login launch or activation. No Face ID/TrueDepth security claim. Engine events feed the existing notch presentation. Private lock-state API remains documented in Vendor/HeyMac/LOCAL_INTEGRATION.md. New post-match cancellation gate prevents typing after stop/disable.

# DynamicNotch local extension

Base: https://github.com/jackson-storm/DynamicNotch
Revision: ec927e198550fd6c731b9135c159736c8ab0e0cf
Upstream app version: 1.6.3. License: GPL-3.0; original notices retained.
Installed target: /Applications/DynamicNotch.app (local ad-hoc signature; not Developer ID notarized).

## Alcove-inspired changes

Observed reference: installed Alcove 1.7.7 build 199, General/Sound/Now Playing/Lock Screen settings and official tryalcove.com demo. Observation record: ../Documentation/ALCOVE_OBSERVATIONS.md. No Alcove executable or assets copied.

- Reopening the installed app opens Settings; a standard Command-comma Settings command is available.
- General Quick controls: hover/click expansion, hover haptics and hiding media when its source is frontmost. Bindings reuse the existing settings and engine.
- Independent hover expansion delay, 0.05–1.50 seconds, separated from press-and-hold timing, sanitized and persisted.
- Mouse drag and trackpad swipe preferences now persist and affect the engine; upstream accessors previously always returned true and ignored writes.
- Separate swipe-dismiss and swipe-restore controls, retaining the existing combined shortcut.
- Hide-when-source-active is also exposed on the Now Playing page; its pre-existing implementation is reused.
- English and Korean text for new controls, retaining upstream localization structure.
- Login launch and FaceID are not enabled for fresh local installs. Test construction no longer changes login registration.
- Local-build marker disables Sparkle checks/downloads so upstream updates cannot silently replace this extension; update settings explain the local build.
- Repaired a stale upstream transition test calling a removed compactScaleX parameter.

## Existing upstream capabilities preserved

Media, artwork, audio outputs/visualization, calendar, downloads, tray/AirDrop, timers, HUDs, battery/connectivity/focus, priorities, display selection, gesture/physics engine, fullscreen handling, lock-screen and localization settings are reused. Their presence is not a claim of physical end-to-end verification. Upstream uses private/system-specific integration techniques (including its MediaRemote adapter); this patch adds no new private framework.

## Remaining Alcove differences / validation gates

No claim of complete Alcove parity. Automatic Quick Peek on track change, arbitrary idle None/Playing/Calendar/Duo selection, hide-in-Mission-Control/game policies and lock-screen weather are not added by this patch. Do not expose unsupported toggles merely to resemble the reference. FaceID/password enrollment is not authorized or configured. Hardware HUD, real playback/source-hiding and physical gestures require runtime/hardware verification with user-authorized permissions.

## Rebuild / update / uninstall

Build Release with Xcode; scripts/install-local.sh copies it into Applications and verifies an ad-hoc signature. Existing locally installed versions are backed up under ../build/installed-backups.noindex/. No Gatekeeper/quarantine/security settings are weakened. Local modified sources remain here under GPL-3.0. To uninstall: quit, disable login launch if enabled by the user, then remove the app; settings remain unless explicitly removed. No shell/Codex configuration changes.

Build/test/runtime evidence will be recorded in ../TEST_REPORT.md and local logs under ../build/checkpoints/.

## Repeated folder-permission fix

The upstream default download monitor scanned Downloads, Desktop, Documents, Movies, Music and Pictures automatically. This local build starts with no monitored locations and downloads monitoring off. Downloads settings let the user choose exactly one folder using NSOpenPanel; a security-scoped bookmark persists that choice. Folder changes stop and restart the existing monitor and release scoped access when stopped. Browser-profile metadata lookup is separately opt-in and off by default. Full Disk Access status is not guessed by opening protected TCC/Focus databases. Accessibility prompts are triggered only by the explicit permission action, not background HUD startup. Test-host detection includes modern XCTest injection markers; verification app instances are not left running beside the installed app.

## Security review and useful local tools — 2026-10-28

No confirmed malware/exfiltration was identified in the reviewed source. This is not a guarantee about precompiled upstream dependencies. See Documentation/DYNAMICNOTCH_SECURITY_REVIEW.md and Documentation/NOTCH_APP_COMPARISON_20261028.md (also retained in the parent workspace).

- Removed password-based Face Unlock, credential collection/storage service, simulated face success and lock-screen password injection. The compatibility scan always fails; settings explain removal. Existing saved Keychain items are neither read nor deleted by this change.
- Added Privacy & Security with off-by-default network consent for online lyrics, public-IP country lookup and localhost YouTube Music remote. Network recipients/data are described.
- Added real Quick Tools in Settings/menu bar/the existing notch engine: local notes with atomic persistence/pin/search/corruption protection; monotonic stopwatch; 15/30/60-minute Keep Awake with expiry/stop/quit release; system color picker with explicit HEX copy.
- Local notes reuse our own previously tested utility implementation with a separate DynamicNotch storage location. Standalone NookFlow remains cancelled and is not installed.
- Added regression tests for security defaults, disabled credential unlock, denied IP lookup, notes persistence, stopwatch, assertion lifecycle and color formatting.
- The user's existing /Users/davidkang/DynamicNotch Xcode project team settings are preserved when syncing this patch.

## Approved productivity extensions — 2026-10-28

1. Explicit Quick Tools session takes precedence over other ongoing activities. Temporary system alerts still preempt; Return to automatic removes only the tools session. Expansion waits for selected content instead of expanding the previous activity.
2. Searchable tool/saved-note palette, menu entry, Command-Shift-K while app is active and Control-Option-Space global registration with its own hotkey ID. Timer shortcut is preserved. App launch uses a user-selected application, never a shell command. Unsaved note drafts are not overwritten by palette selection.
3. Focus/break sessions reuse LocalTimerViewModel and KeepAwakeController; optional display-awake defaults off, pause/stop releases it, completed-focus history persists. App termination ends active sessions; it does not pretend to resume them.
4. Existing calendar join UI now extracts HTTPS links from event URL/notes/location, matches supported service hosts safely, and displays relative start time. No auto-join or new calendar permission grant.
5. Local day-based top-three priorities, completion and explicit removal.
6. Existing tray context menu exports PNG copies or JPEG copies resized to at most 1600 px. Save dialog; original path rejected; JPEG transparency flattened white. Static images only; no cloud upload.
7. Clipboard snippets captured only by explicit button, no polling. Concealed password-manager items excluded. Local 0600 JSON is not encrypted; 100 items and 100 KB/item maximum; explicit copy/removal.
8. Local exact-bundle-ID display hide rules, using existing window presenter and public workspace activation notifications. Own app excluded; removing a rule restores automatic display.
9. Explicitly selected project/scheme Xcode build or file SHA-256 process, no shell. Actual exit code/duration and bounded local output; completion opens results, cancellation requests process interrupt. Project build scripts are disclosed in UI.
10. Permission/optional-connection/folder/Keep Awake state and controls to disable optional connections, release assertions and stop media/download/recording/timer monitors. Read-only permission checks never request grants.

Additional safety repair: upstream automatic screenshot interception scanned Desktop, redirected macOS screenshot output, changed floating-thumbnail preference and restarted SystemUIServer. It is disabled for local builds and all test hosts, visibly explained in screen capture settings; screen recording activity detection is separate. No attempt is made to guess or overwrite pre-existing system capture preferences.

Tests: focus/storage, URL lookalike rejection, app rules, real image output dimensions, and actual SHA-256/nonzero process results are covered. Full build/test/installed verification remains separately documented in TEST_REPORT.md and parent source-of-truth trackers.

Test infrastructure: use a separate PRODUCT_BUNDLE_IDENTIFIER=com.Jackson.DynamicNotch.LocalTests, DYNAMICNOTCH_TEST_HOST=YES and per-process temporary tray storage. Real screenshot interception is excluded from test hosts. Download publication callbacks are invalidated on stop/restart; test expectations accept one qualifying notification. Lock-screen integration test explicitly enables its prerequisite instead of depending on user preferences. Earlier legacy tests changed app-language preferences; the observed Korean Settings preference was restored through the installed UI.

Canonical app is /Applications/DynamicNotch.app. On 2026-10-28 duplicate app registrations were removed and old installed backups preserved under build/installed-backups.noindex in the original workspace. Development outputs remain; opening them can register them again.

## Support-20261028 — local support workflow
- Manual Quick Tools pin expanded interaction until explicit dismissal; About shows local revision and bundle path.
- Existing timer publisher uses one-second updates (two in Low Power Mode); serial thumbnail decoder and bounded cache. CPU/battery improvement is not yet measured.
- Offline calculator/units; explicit Apple Shortcuts list/run; ZIP creation and ZIP32 extraction with path/link/encryption checks, full bounded deflate/CRC validation and extraction from an immutable private copy.
- JSON formatting/minification/structural diff, query decoding, pattern-based secret masking and local Singular payload structure hints. Masking is a review aid, not a guarantee.
- CSV A/B group reconciliation with exact Decimal sums, explicit keys/metric, missing-row distinction, duplicate counts and no automatic timezone/currency conversion.
- Local screenshot case board: selected imports/paste, SHA-256 dedup, session-only selected-folder watcher, thumbnails, two-image compare, captions, on-demand local OCR, opaque redaction and evidence folder export. Export reencodes images and excludes OCR text/original image metadata. Original images remain preserved locally.
- No customer content fetched, uploaded, or sent. No permission granted automatically. Alcove assets/executable are not copied.

## Notchie-20261028-v6 — OS 27 Liquid Glass Panoramic Notch Hub & Hover Expansion
- **Hover-to-Expand on Active Now Playing & Idle Notch (`NotchViewModel`, `GeneralSettingsStorage`, `ApplicationSettingsStore`)**:
  - Updated default `notchExpandInteraction` to `.hover` and `notchCollapseInteraction` to `.hoverLeaves`.
  - Updated `NotchViewModel.shouldExpandActiveContentOnHover` and `shouldCollapseActiveContentOnHoverLeaves` so hovering over the notch **while Now Playing (`자동 재생`) is active** (as well as when idle) expands smoothly on hover and collapses when the cursor leaves unless pinned (`QuickToolsStore.shared.isNotchHubPinned`).
- **OS 27 Liquid Glass Panoramic Notch Hub (`NotchiePanoramicHubView`, `NowPlayingExpandedNotchView`, `QuickToolsView`, `NotchBackgroundSurface`)**:
  - Redesigned the expanded notch into a sleek, widescreen `688pt` horizontal dashboard (`cornerRadius: (top: 19, bottom: 28)`) inspired by NotchNook (`https://getnotchnook.com`) and 2026 macOS notch apps with macOS 27 (OS 27) Liquid Glass aesthetics:
    1. **Top Wing Header Bar (flanking the physical camera cutout)**: Left mode pills (`Nook`, `Tray` with item count badge, `Clips`, `Notes`, `Tools`), a clear center camera cutout safe gap, and right-side live Mini-Player pill (on non-`Nook` tabs) + `Pin`, `Customize Tabs`, and `Settings` (`gearshape.fill`) buttons.
    2. **Left Column — Now Playing Studio**: `66×66` rounded album artwork with ambient palette glow + floating bottom-right source app icon badge, track title/artist, live equalizer, interactive slim scrubber, and transport controls (`backward.fill`, `play.fill`/`pause.fill`, `forward.fill`, favorite, audio output route).
    3. **Center Column — Month + 7-Day Week Strip & Schedule**: Bold month header + interactive 7-day strip (`SUN..SAT` + day numbers with selected/today highlight and event indicator dots), upcoming event card with 1-click **Join Meeting** button OR `"Nothing for today"` (`"오늘 예정된 일정 없음"`) + Today's Task quick toggle chip.
    4. **Right Column — Circular Camera Mirror & Focus Pod**: `78×78` circular OS 27 Liquid Glass pod with bottom-right `camera.fill` badge that toggles an opt-in live mirrored front-camera preview (`NotchieMirrorCameraView`, auto-stopping on close) or shows active Focus/Stopwatch progress.

## Notchie-20261028-v5 — Custom Edition & Permission Sync Fixes
- Rebranded user-facing app name and icons to `Notchie` (`Notchie-macOS-Icons`), customized `AboutAppSettingsView`, removed Support & Software Update pages, and simplified `MenuBarMenu` to Settings, Restart, and Quit.
- Added NotchNook-style idle notch hover menu (`isIdleNotchHoverMenuEnabled`), customizable Notch Hub tabs (`QuickToolsStore.enabledTabIDs`), clipboard search + one-click re-copy + opt-in auto-capture, custom accent color picker (`customAccentColorHex`), and Face Unlock Original (Full Badge Scan) vs. Minimal selector + live notch preview.
- Fixed permission detection bugs:
  1. Removed the hardcoded `DynamicNotchLocalBuild == true` short-circuit in `FullDiskAccessAuthorization.hasPermission()` that forced Full Disk Access to always return `false` even when enabled in System Settings.
  2. Unified Media Controls (`canPostEventAccessState`) with `AXIsProcessTrusted()` and updated Calendar `isGranted` to accept `.fullAccess`, `.writeOnly`, and `.authorized`.
  3. Updated `scripts/install-local.sh` to sign `/Applications/DynamicNotch.app` with the local `Apple Development` certificate + `DynamicNotch.entitlements` (instead of an ad-hoc `--sign -` signature whose changing `CDHash` invalidated macOS TCC permissions on every rebuild) and unregister build/DerivedData app copies from LaunchServices.
  4. Added live 1.5s permission status refresh while `PermissionsSettingsView` is visible and a "Fix Sync (`권한 인식 오류 해결`)" action (`resetAndReRequestMissingPermissions()`) to clear stale ad-hoc TCC entries and re-link permissions.

## Notchie-Droppy-20261029-v16 — public-reference shelf extension

Public Droppy references informed an independent extension; no Droppy source/assets are in the app. Existing Nook, tray, media, clipboard, weather, notes, Focus, privacy/authentication and user preferences are retained. Complete feature-by-feature scope, including gaps, is in `Documentation/DROPPY_FEATURE_COMPARISON_20261029.md`.

- Shared solid / Dynamic Glass / Liquid Glass expanded surfaces, opaque compact region and Reduce Transparency fallback; existing appearance store persists selection.
- Home / Tray / Widgets lower navigation; Tools remains beside the app-icon rail. Expanded media and Quick Tools share the extra navigation height.
- Three persistent replaceable/reorderable widget slots reuse current media/calendar/weather/focus/notes engines. New local host CPU/RAM widget polls only while visible, has a bounded CPU history and explicitly missing first CPU value.
- Local teleprompter script/speed persistence, monotonic progress, explicit read/edit/pause/reset and sleep-gap handling. Closing the view pauses; no recording or speech access.
- Korean/English common emoji search and explicit copy. New tools also appear in the existing command palette and the shelf's All Tools menu without resetting chosen tabs.
- Text clipboard favorites migrate existing version-one data, sort first and survive recapture; existing optional capture behavior unchanged.
- Native Transform uses CoreGraphics/Vision and existing OCR: selected image/PDF combination, foreground cutout PNG, Korean/English image OCR. Bounded inputs, explicit Save and original-path protection. No cloud, new API key or model download.
- New Mac system Dynamic Island is treated as design context, not a verified public API or hardware compatibility claim. No login launch, face enrollment, permissions or external accounts enabled.

Delivery integrity repair: the pre-existing icon controller used `NSWorkspace.setIcon` on its own `.app`, creating `FinderInfo`/`ResourceFork` metadata and failing strict codesign verification after launch. Removed signed-bundle mutation; persisted Light/Dark/Auto selection, in-app icon previews and Dock runtime icon remain. Finder uses the bundled icon/appearance catalog. This intentionally stops forcing a custom Finder icon onto the signed bundle.

## Notchie-Droppy-20261029-v17 — verified shelf polish
- Replaced always-visible widget headers/reorder arrows with a dedicated widget editor popover; all three content slots have the same 136pt height. Local stats/focus/notes cards now fill and outline the same bounds.
- Added a searchable two-column All Tools library with color-coded native SF symbols, selection feedback and English/Korean/ID lookup. Existing enabled tabs remain; selecting a tool enables it explicitly.
- Shared tool tab labels use the app's localization resolver, avoiding mixed-language tool labels inside the notch. Idle media label localized. Stats have a bounded live CPU graph with a gradient fill, without fabricated data.
- Teleprompter ticks only while reading; paused/editor states have no periodic task.
- No raster asset was necessary for these small control surfaces. Existing artwork/icon assets are retained; new visual treatment uses native SwiftUI drawing.

## Notchie-Clipboard-20261029-v19 — clipboard list/reference redesign
- Compact Notes / Clipboard / Starred header, capsule search, type/sort menu, thin separators, source/time column, whole-row copy feedback and right-click preview/copy/star/remove. Reuses existing notes and snippet engines; existing personal snippets preserved.
- Persisted text/link/code filter, favorites-only and sort controls. Keyboard Return copies the first visible result. Large previews are bounded, but copying always uses original complete text.
- Clear history now confirms an explicit count and preserves favorites; current search/filter scope is disclosed in the dialog.
- Optional sourceAppName metadata is added compatibly to v1 documents. Source is the foreground app observed at auto-capture time, not a guaranteed original app; old records remain unknown. Concealed/transient/autogenerated pasteboard exclusion remains.
- Clipboard presentation receives additional height only in clipboard mode; tool changes refresh shared media/Quick Tools geometry, other layouts keep prior sizes.

## Notchie-Nook-20261029-v20 — simplified Nook home
- User explicitly removed the lower Home / Tray / Widgets navigation. Top Nook / Tray / Tools and existing engines/data remain. Removed the lower dock rendering and reclaimed its 36pt presentation height across shared media/Quick Tools paths.
- Nook home now shows only media, calendar and a circular Mirror pod separated by subtle dividers; no weather/solar card, task chip or productivity-hub shortcut on this home. Calendar/media reuse existing adapters and controls; legacy widget preferences are not deleted.
- Mirror is preview-only, not face enrollment/recognition: an explicit click starts authorized camera preview or requests access. Leaving Nook stops capture. Serial session start/stop and detached-view/late-permission guards prevent stale callbacks from reopening the camera. No audio/output recording or image persistence. Automated hosts never start or request the camera.

### Centered hover reveal — 2026-10-29 (v21)
- Pin the notch presentation to the overlay canvas horizontal midpoint throughout width changes.
- Give content its destination-size centered frame before reveal transforms, avoiding flexible-row lateral reflow.
- Replace the expanded content squeeze/vertical travel with a subtle centered 94%-to-100% fade/blur reveal; damp shell expansion and collapse springs.
- Preserve existing hover timing, gesture engines, settings and hardware-notch/island behavior.

### Nook calendar reference layout — 2026-10-29 (v22)
- Remove the home Mirror pod and give its width to the calendar.
- Place a large abbreviated month beside the seven-day strip, with blue selected day numerals, muted weekend dates and event dots; no filled date tiles.
- Center the selected-day agenda/empty state below. Preserve the EventKit adapter, privacy-aware titles, meeting actions and media controls. Month resets selection to today; no automatic permission prompts.

### Lock/authentication and Settings cleanup — 2026-10-29 v23
- Settings: visible sidebar groups, quieter shared cards, remove redundant General haptic/media toggles (canonical controls remain in Gestures/Now Playing), combine system permissions under Privacy and lock-screen appearance under Lock & Authentication. Old enum/deep-link routes preserved.
- Show persisted password-rejection recovery after relaunch; setup comes before collapsed animation previews.
- One lock engine now owns explicit lock-screen button retries; remove the retired always-failing presentation scanner from that path. Explicit retries never reset the password submission budget.
- Preserve retry budget on unknown lock state, distinguish unconfirmed unlock from password rejection, ignore camera contention for face retry counting, recheck cancellation after inference, clear inherited shortcut modifiers in synthetic key events.
- Reduce polling/cooldown delays and raise frame cadence to 15 fps; retain strict thresholds, anti-spoof pipeline, two consecutive accepted frames, camera warmup and one password attempt per lock episode.
- No camera permission, enrollment, password replacement, login launch or authentication enablement performed automatically. Physical Mac unlock timing requires the user's saved-password recovery and manual lock test.

## Notchie-TrayHub-20261029-v28 — Tray & Tools unification
- **Notch Top Wing Header Bar Cleanup**: Eliminated redundant "Tools" (`도구`) wing tab from the Notch header bar, yielding an uncluttered, camera-centered layout flanking the physical camera cutout: `Nook` & `Tray` on the left wing, and Apple Glass Settings gear button (`⚙`) on the right wing.
- **Unified 4-Segment Tray Drawer**: Expanded the Notch Tray into a full-featured 4-segment workspace:
  1. `Files` (`파일 보관함` / `tray.full.fill`): Drop files or folders onto the notch to temporarily stash and drag out anywhere.
  2. `Captures` (`스크린샷 기록` / `camera.viewfinder`): Auto-organized screenshot captures with quick clipboard copy and drag out.
  3. `Transform` (`파일 변환` / `wand.and.stars`): Native on-device PDF merger, background cutout remover, and OCR text extractor.
  4. `Clipboard` (`클립보드` / `doc.on.clipboard.fill`): Full local clipboard snippet history with live search, favorites, preview, and copy.
- **Settings Rebranding**: Renamed "Quick Tools Settings" (`빠른 도구 설정`) to "Tray Settings" (`트레이 설정`) across sidebar, headers, and localized strings (`Localizable.xcstrings`). Provided a 4-segment tabbed settings experience with direct "Open Tray in Notch" (`settings.tools.openNotch`) launch.
- **Dynamic Geometry**: Added height calculation for `.transform` and `.clips` modes in `shelfExtraHeight(isIsland:)` ensuring seamless presentation geometry across notch and Dynamic Island layouts.
- **Verification**: 292/292 DynamicNotchTests passed; Release build succeeded with 0 warnings; installed locally to `/Applications/DynamicNotch.app` and runtime identity verified (PID 51376, UUID `E2A5C1EC-E5E0-363A-A497-45E6BFFC09B5`, codesign verified).

## Notchie-TrayDismissal-20261029-v29 — Notch Tray auto-dismiss & outside-click collapse
- **Root Cause Resolution**: When opening the Tray from Settings via `showQuickToolsInNotch`, `QuickToolsNotchContent` was created without `openedFromIdleHover: true`, causing `pinsExpandedInteraction` to remain locked to `true`, preventing both outside-click collapse (`handleOutsideClick`) and hover-leave collapse (`shouldCollapseActiveContentOnHoverLeaves`).
- **Interactive Lifecycle**: Passed `openedFromIdleHover: true` in `AppDelegate.swift`, updated `NotchViewModel.shouldCollapseActiveContentOnHoverLeaves` to collapse on hover leaves for all `QuickToolsNotchContent` instances (unless explicitly pinned), enabling instant collapse on mouse leave and outside click.
- **Inactivity Auto-Dismiss Timer**: Added a 6-second inactivity dismissal task in `AppDelegate.swift` when opened from Settings: automatically collapses and removes the Notch Hub if the user does not hover into the notch, while keeping it open without timeout while hovering.
- **Settings Toggle & In-Notch Close Button**: Updated the button in Settings to toggle ("Close Notch Tray" / "노치 트레이 닫기" when open) and added an explicit `✕` close button to the top-right header wing of the notch beside Settings.
- **Verification**: 292/292 DynamicNotchTests passed; Release build succeeded; installed to `/Applications/DynamicNotch.app` and runtime identity verified (PID 57043, UUID `506932E3-FCC1-3D46-8B58-9692CB090785`).
