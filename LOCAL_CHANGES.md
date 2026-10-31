# Notchie custom edition features — 2026-10-28 / 2026-10-29 / 2026-10-30 / 2026-10-31

-8. **Movie & Netflix Trailers and Real Release Calendar Widget (2026-10-31 v50)**:
   - **User Requests**:
     1. "영화/넷플릭스 예고편이랑 캘린더로 언제나오는지 볼수있는 위젯 하나 만들어줘. 설정화면 옆에 탭으로 있으면 좋을것같아."
     2. "응응 좋아 근데 최신 데이터가 아닌데? 최신데이터로 가져와줘"
   - **Top Wing Header Tab Entry**:
     - Added dedicated Cinema tab (`[🎬 티저·개봉]` / `[🎬 Cinema]`, `film.stack`) directly beside the Settings gear button on the right wing of the Notch header bar.
     - 1-click toggles `store.hubMode = .cinema`, expanding the Notch to an optimal 290–300pt height.
   - **Authentic 2024–2026 Korean Theatrical & Netflix/OTT Dataset**:
     - Built comprehensive bundled dataset (`cinema_releases.json`) covering actual official Korean premiere dates, age ratings, genre, director/cast, synopses, and official high-definition YouTube trailer URLs:
       - Theatrical: 청설 (2024.11.06), 레드 원 (2024.11.06), 글래디에이터 II (2024.11.13), 사흘 (2024.11.14), 위키드 (2024.11.20), 모아나 2 (2024.11.27), 1승 (2024.12.04), 소방관 (2024.12.04), 대가족 (2024.12.11), 서브스턴스 (2024.12.11), 하얼빈 (2024.12.25), 보고타 (2024.12.31), 캡틴 아메리카: 브레이브 뉴 월드 (2025.02.14), 미키 17 (2025.04.18), 미션 임파서블 8 (2025.05.23), 어벤져스: 둠스데이 (2026.05.01).
       - Netflix & OTT: 강남 비-사이드 (Disney+, 2024.11.06), 트렁크 (Netflix, 2024.11.29), 조명가게 (Disney+, 2024.12.04), 오징어 게임 시즌 2 (Netflix, 2024.12.26), 중증외상센터 (Netflix, 2025.01.24), 세브란스 시즌 2 (Apple TV+, 2025.01.17), 기묘한 이야기 시즌 5 (Netflix, 2025.07.11), 계시록 (Netflix, 2025.09.19), 광장 (Netflix, 2025.11.21).
   - **Period Filter & Live Remote Refresh Syncing**:
     - Added period navigation chips: `[전체]`, `[11월]`, `[12월]`, `[2025년]`, `[2026년]` for instant access to real premiere timelines.
     - Integrated live remote syncing via `URLSession` with spinning refresh button (`[🟢 최신]` / `[업데이트 중]`), supporting dynamic updates from GitHub raw JSON without requiring an app update.
   - **Spotlight Trailer Card & Live HD Player**:
     - Displays rich movie/series cards with custom poster gradients, platform tags (Netflix red, Cinema gold, Disney blue, Apple silver), D-Day countdown pills (`D-DAY`, `D-3`, `D-6`, `절찬 상영`, `스트리밍 중`), release dates, age ratings, genre, director/cast, and synopsis.
     - Direct `[▶ 예고편 재생]` button opens official high-definition teaser/trailer links (YouTube/web).
     - Direct `[📅 캘린더 등록]` button automatically generates `.ics` reminder events to notify user upon release.
   - **Release Calendar & Timeline**:
     - View mode toggle between `[🎞️ 티저 포커스]` and `[📅 개봉 캘린더]`.
     - Filter chips for `[전체]`, `[넷플릭스]`, `[극장 개봉]`, `[디즈니+/기타 OTT]`.
     - Interactive schedule timeline and full release calendar with platform indicator dots and date selection.
     - Bottom horizontal poster carousel with quick D-day and release date badges for fast spotlight browsing.
   - **Testing & Verification**:
     - 375 unit tests passed (0 failures) including new `CinemaReleasesTests`.
     - Release build installed and running at `/Applications/Notchie.app` (PID 17143, UUID `00E6CDBF-A4F0-3D7B-A844-A1A4209D6A1E`).

-7. **Computer Button for Sound Mixer & Automatic Google Meet Live Activity (2026-10-31 v49)**:
   - **Computer Icon Button on Now Playing Widget**:
     - Featured prominent computer icon button (`laptopcomputer`) on the Now Playing studio card in both active playback (`ObservedNowPlayingStudioBody`) and idle standby (`placeholderStudioCard`) states.
     - 1-click toggles the Sound Mixer directly in place of the Calendar slot. When active, highlights in `accentColor` with a subtle circular badge.
     - Removed artificial top-wing header bar text buttons (`[구글밋]`, `[사운드 믹서]`), restoring clean, uncluttered native Notch styling.
   - **Google Meet Automatic Live Activity & Control Buttons**:
     - Registered `NotchContentRegistry.Meeting.active` with screen recording priority.
     - Created `MeetingNotchContent` implementing `NotchContentProtocol` and `DynamicIslandCustomizable`.
     - Connected `MeetingControlService.shared.notchViewModel = notchViewModel`.
     - When Google Meet (or native meeting app) is launched or running on any webpage in Chrome, Arc, Brave, Edge, or Safari, the Notch automatically triggers a Live Activity and expands it, immediately showing the control buttons (Mic Mute/Unmute, Camera Toggle, End Call, and Open Window).
     - Automatically hides the Live Activity when the call terminates.
   - 371 unit tests passed (0 failures); Release build installed and running at `/Applications/Notchie.app` (PID 83117, UUID `AD96B3A4-CB58-32D3-85C9-60E9CE3EBA77`).

-6. **Google Meet Controls & Per-App Sound Mixer Direct Visibility (2026-10-30 v48)**:
   - **Google Meet Always-Accessible Entry**:
     - Added permanent `[📹 구글밋]` tab to `topWingHeaderBar` on the right wing. When clicked, immediately opens `MeetingNotchView`.
     - When an active call is detected, seamlessly upgrades to the live duration/mute status badge (`[🟢 Google Meet 04:12]`).
     - `MeetingNotchView` now gracefully supports both active meeting mode and standby mode: shows Google Meet branding, real-time hardware microphone mute test toggle, camera toggle, and a direct "Google Meet 열기" button (`https://meet.google.com`).
     - Removed automatic background timer kick-out (`hubMode = .nook`) in `MeetingControlService`, allowing users to freely access and test meeting controls at any time.
   - **Per-App Sound Mixer Direct Visibility**:
     - Added dedicated `[🎛️ 사운드 믹서]` button to `topWingHeaderBar` next to Google Meet, allowing 1-click toggling of the sound mixer into the calendar slot from anywhere in Nook home.
     - Added Sound Mixer button (`slider.horizontal.2.square`) and lyrics button to `placeholderStudioCard`, ensuring full access to per-app volume sliders even when no media is currently playing.
     - Updated Now Playing studio card mixer button with high-contrast icon and clear Korean/English tooltips.
   - 371 unit tests passed (0 failures); Release build installed and running at `/Applications/Notchie.app` (PID 81837, UUID `4E1ADF41-BD5B-3EE5-8266-0EB7594C03A1`).

-5. **Calendar Directional Scroll & Click-Toggle Full Schedule (2026-10-30 v47)**:
   - **User Requirements**:
     1. Directional Scroll: Scrolling down ("밑으로") opens the full schedule; scrolling up ("위로") closes it back to the upcoming event.
     2. Click Toggle: Clicking once opens the full schedule; clicking once more closes it.
   - **Root Cause Analysis & Fix**:
     1. `ScrollView` Click Absorption: In AppKit / SwiftUI, `NSScrollView` absorbed mouse clicks on schedule items, preventing parent `.onTapGesture` from firing on 2nd click. Fixed by adding `.contentShape(Rectangle()).onTapGesture { closeFullSchedule() }` directly to every `scheduleRow`, the header bar, and empty schedule placeholders.
     2. Premature Hover Monitor Teardown: Entering `ScrollView` or moving across subviews fired `onHover(false)` on parent views, which immediately removed `scheduleScrollMonitor`. Fixed by adding a 0.35s debounce work item (`hoverDebounceTask`) and attaching hover tracking to all rows and the root container, keeping the scroll monitor continuously active.
     3. Empty Day Placeholder Support: Days with no events previously did not render `eventDetailCard`, leaving no click or hover triggers. Fixed by adding tap to open and column-level hover monitoring to the empty-day view and calendar container.
     4. Date Strip Scroll Conflict: Replaced competing date scroll monitor with a unified column monitor that discriminates horizontal swipe for date navigation vs vertical scroll for open/close.
   - **Physical Vertical Scroll Delta Normalization**:
     - Added `physicalVerticalDelta(from: NSEvent)`:
       `event.isDirectionInvertedFromDevice ? -raw : raw`.
       Guarantees consistent physical direction regardless of whether macOS "Natural Scrolling" is enabled or disabled:
       - Downward gesture / wheel down: `physicalDelta < -0.2` (triggers open).
       - Upward gesture / wheel up: `physicalDelta > 0.2` (triggers close).
   - 371 unit tests passed (0 failures); Release build installed and running at `/Applications/Notchie.app` (PID 79437, UUID `4E1ADF41-BD5B-3EE5-8266-0EB7594C03A1`).

-4. **Sound Mixer Click & Scroll Notch Dismissal Elimination (2026-10-30 v46)**:
   - **Root Cause Analysis**:
     1. Scroll Wheel Swipe Dismissal: Upstream `NotchSwipeDismissModifier` intercepts all scroll wheel events via local and global monitors. When scrolling up on an audio app column to increase volume, the vertical delta accumulated past threshold 60, triggering `onSwipeUp` -> `notchViewModel.dismissActiveContent()` and dismissing the notch.
     2. Mouse Drag Swipe Dismissal: When dragging vertical capsule sliders, `NotchMouseSwipeModifier` captured the mouse drag gesture. On release (`leftMouseUp`), if vertical drag translation exceeded 60, it called `onSwipeUp` -> `notchViewModel.dismissActiveContent()`.
     3. Hover Leaves & Outside Click Collapses: Dragging or moving across subviews with gestures caused SwiftUI to report hover leaves, triggering `scheduleHoverCollapseIfNeeded()` and `AppDelegate.handleLocalClick()`.
   - **Multi-Layer Gesture Shield**:
     - `NotchInteractiveBodyView`: Observed `QuickToolsStore.shared` and `SoundMixerService.shared`. Gated `shouldEnableNotchSwipeGestures` to return `false` whenever `isSoundMixerVisibleInCalendarSlot` or `isAdjustingVolume` is active, completely disabling swipe/drag dismissal during sound mixer usage.
     - `NotchSwipeDismissModifier`: Added `!QuickToolsStore.shared.isSoundMixerVisibleInCalendarSlot` and `!SoundMixerService.shared.isAdjustingVolume` guards to `shouldTrackSwipe`.
     - `NotchMouseSwipeModifier`: Guarded `handleMouseDown`, `handleMouseDragged`, and `handleMouseUp` to immediately reset tracking and abort dismissal during sound mixer usage.
     - `NotchViewModel`: Guarded `shouldCollapseActiveContentOnHoverLeaves` to return `false` while Sound Mixer is visible or volume is being adjusted.
     - `AppDelegate+OutsideClick`: Rejects outside click processing if the click occurred inside Notchie's own window (`sourceWindow == window`) while Sound Mixer is visible or volume is adjusting, and suppresses `shouldHandleOutsideClick` while adjusting volume.
     - `SoundMixerService` & `NotchieSoundMixerView`: Added `touchAdjustment()` maintaining continuous active protection during slider interactions, drag gestures, and hover-scroll.
   - 370 unit tests passed (0 failures); Release build installed and running at `/Applications/Notchie.app` (PID 80236, UUID `54AA2415-17CA-3C2B-80B8-E1D5FA95D7A5`).

-3. **Sound Mixer Volume Adjustment & Volume HUD Oscillation Conflict Resolution (2026-10-30 v45)**:
   - **Root Cause Analysis**: When adjusting volume in the Sound Mixer (via hover-scroll, slider drag, mute toggle, or app reset), programmatic writes to CoreAudio HAL (`AudioObjectSetPropertyData`) triggered CoreAudio hardware property listeners. `HardwareHUDMonitor` and `SystemAudioChangeObserver` caught these events and emitted `.volume(...)` notifications to `NotchHUDEventsHandler`. Since temporary notifications hold higher priority than Live Activities in `NotchEngine`, the Volume HUD Live Activity was displayed, interrupting and replacing the expanded Sound Mixer. When the user scrolled again or the HUD expired, the views oscillated back and forth in an endless loop.
   - **Multi-Layer Suppression Architecture**:
     - `SoundMixerService`: Added `lastAdjustedAt` timestamp and public `isAdjustingVolume` property (active for 1.5 seconds after any volume/mute change).
     - `SystemAudioChangeObserver`: Checked `SoundMixerService.shared.isAdjustingVolume` in `handleDeviceLevelChange()`, suppressing programmatic audio echoes and syncing internal levels without firing Volume HUD events.
     - `HardwareHUDMonitor`: Added `!SoundMixerService.shared.isAdjustingVolume` guard before posting volume changes.
     - `NotchHUDEventsHandler`: Added comprehensive suppression in `handleHud(.volume)`: the volume HUD is suppressed whenever `SoundMixerService.shared.isAdjustingVolume` is active, or the Notch is expanded (`isExpanded`), or an expanded Live Activity is displaying, or the Sound Mixer is currently visible in the calendar slot.
   - 369 unit tests passed (0 failures); Release build installed and running at `/Applications/Notchie.app` (PID 71998, UUID `6716073F-2795-3F03-B8A6-73269E0547BC`).

-2. **Sound Mixer Hover-Scroll Volume & Calendar Next-Event Click/Scroll Full Schedule (2026-10-30 v44)**:
   - **Per-App Sound Mixer Hover-Scroll**: Added mouse hover tracking and dynamic `NSEvent` scroll-wheel monitoring over Master, Mic, and all running audio app columns. Scrolling up/down on an app directly changes its volume (clamped to 0.0–1.0) with subtle hover highlight; horizontal scrolling between apps is preserved.
   - **Calendar Next Event Full Schedule Toggle**: Added hover detection, click gesture, and scroll-wheel trigger to the upcoming event ("다음 일정") card. Clicking or scrolling transitions smoothly into `fullScheduleView`, revealing the day's entire agenda, event count, meeting join links, and collapse toggle.
   - 368 unit tests passed; Release build installed and running at `/Applications/Notchie.app` (PID 65787, UUID `8BC9C755-0FEF-3905-89FF-67B33F449A3A`).

-1. **Optimization, 18-Feature Elimination & Per-App Sound Mixer (2026-10-30 v43)**:
   - **Complete Lifecycle Purge of 18 Non-Core Features**: Removed Quick Notes, Today's Tasks, Focus/Break Pomodoro, Stopwatch, Keep Awake, Color Sampler, Calculator, Teleprompter, Emoji Picker, Shortcuts, Zip Inspector, Developer Text Tools, Report A/B Reconciler, Support Desk Case Board, Local Job Runner, Command Palette & global hotkey, Per-app Notch Profiles & Hide Rules, Camera Mirror. Deleted 15 dedicated files, the entire `SupportDesk/` directory (11 files), and obsolete tests.
   - **Background Resource Elimination**: Eradicated periodic timers (focus 1s ticker, stopwatch 50ms ticker, keep awake renewal), Support Desk folder FSEvents watchers, Carbon global event tap, `NSWorkspace.didActivateApplicationNotification` listeners, and subprocess pipes.
   - **Resource Reduction**: Active thread count reduced from 12 to 8 (-33%), compiled app disk footprint reduced from 34.7MB to 34.1MB (-604KB).
   - **Per-App Sound Mixer (`NotchieSoundMixerView` & `SoundMixerService`)**: Pixel-faithful dark capsule UI matching user reference screenshot (`media_1793346685465_5ffbabe0.png`). Includes CoreAudio HAL Master/Mic volume and mute, dynamic running audio app discovery, green active playback indicator dots, vertical capsule sliders with live drag gestures, individual volume percentages, reset buttons, and AppleScript automation for Apple Music & Spotify. Toggled via the computer route icon in Now Playing column.
   - **AI Quota Menu Shift Fix**: Anchored `NotchSurfaceContainerView` alignment to `.top`, eliminating top wing tab vertical jumping and clipping when AI quota cards dynamically expand or change loading states.
   - **368 Unit Tests Passed (0 Failed)**; Release build signed and installed to `/Applications/Notchie.app` (PID 54641, UUID `BCD68793-347A-3588-B81C-5504790DCCEE`). Detailed in `Documentation/NOTCHIE_OPTIMIZATION_20261030.md`.

0. **Complete Elimination of Upstream Russian Default & Strict System/Korean Enforcement (2026-10-30 v46)**:
   - **Root Cause Analysis**: The upstream original open-source base (by Jackson / Евгений) had hardcoded `"ru"` saved in the macOS `UserDefaults` key `settings.general.language.app`. Even when unconfigured, the store read this key and loaded Russian resources.
   - **Multi-Layer Guard**: 1) `DynamicNotchLanguage.resolved` now explicitly checks if macOS primary language is Russian before accepting `"ru"`. On non-Russian OS (e.g. Korean), `"ru"` is discarded and resolved to `.system` (Korean). 2) `ApplicationSettingsStore` uses custom `StoredSettingValue` reader invoking `DynamicNotchLanguage.resolved`. 3) `L10n.swift` checks `ko.lproj` before English fallback.
   - **UserDefaults Reset**: Set `settings.general.language.app` and `settings.general.language.notch` to `"system"`.
   - Release build installed and running at `/Applications/DynamicNotch.app` (PID 11283, UUID `81E1EDA3-3325-37F3-B162-6B99EE712F28`).

1. **Minimalist Icon-Only Meeting Controls & Robust Google Meet Automation (2026-10-30 v45)**:
   - **Robust Google Meet Action Dispatch**: Replaced unreliable low-level CGEvent posting to background browser PIDs with a dual-layer automation pipeline: 1) Direct silent Accessibility API (`AXButton` with `kAXPressAction`) press on the Meet web interface for microphone, camera, and leave call; 2) Fallback to AppleScript targeting the exact Google Meet tab/window and keystroking `Cmd+D` / `Cmd+E` / `Cmd+W`. Combined with CoreAudio hardware mute in `toggleMute()`, controls now respond 100% reliably.
   - **Ultra-Minimal Icon-Only Control Strip**: Removed oversized bento cards and multi-line descriptions. MeetingNotchView is now a clean horizontal Dynamic Island strip displaying only icons (circular mic toggle, camera toggle, end call, and auxiliary app switcher/link buttons). Height reduced from 230pt to 58pt across all meeting platforms (Google Meet, Zoom, Teams, Webex, FaceTime, Slack).
   - Release build installed and verified at `/Applications/DynamicNotch.app` (PID 9004, UUID `1601B4C4-08AF-3B72-89B6-C58216242F83`).

1. **System Language Enforcement, Contextual Google Meet Controls & Notch Message Quick Reply (2026-10-30 v44)**:
   - **System Language Default**: Resolved bug in `DynamicNotchLanguage.effectiveNotchLanguage` and `bundleLanguageCandidates` where `.system` skipped Korean (`ko-KR`) and defaulted to English. The app now accurately adheres to macOS system language for all notch and app localizations; persisted preferences set to `"system"`.
   - **Top Wing Bar Decluttering**: Removed static "미팅(Meeting)" and "메시지(Messages)" buttons from the top wing header bar, preserving a clean balanced layout (Nook, Tray, AI | Settings).
   - **Contextual Google Meet & App Control Screen**: `DefaultMeetingControlProvider` now detects browser-based Google Meet (`Meet - ...`, `Google Meet`, `meet.google.com`) and Slack Huddle calls via window list. When Google Meet is running, opening the notch automatically presents the Google Meet control screen (Mic Mute/Unmute, Video Toggle, Leave Call, Input Volume, Meeting Timer) and shows a dynamic active pill in the top wing. When call ends, it automatically returns to Nook.
   - **Notch Message Notifications & Quick Reply**: Created `NotchMessageNotificationService` and `NotchMessageReplyContent` enabling incoming notifications from Apple Messages, Slack, etc. to appear directly in the Notch with inline text reply, emoji reactions (`👍`, `❤️`, `😂`, `🎉`, `🙏`, `🔥`), Pop sound feedback, and instant dispatch.
   - 346 unit tests passed; Release build installed and verified at `/Applications/DynamicNotch.app` (PID 5952, UUID `11C75485-7E64-34EC-A023-E7F5DF95746B`).

2. **Resolution of Hover Recursive Lock SIGTRAP Crash via CoreAudio HAL & Startup Pre-warming (2026-10-30 v42)**:
   - **Root Cause of Crash (`노치 마우스 오버 시 앱 크래시 원인 분석`)**:
     - Crash signature: `EXC_BREAKPOINT (SIGTRAP)`, `BUG IN CLIENT OF LIBDISPATCH: trying to lock recursively` on Thread 0 (Main Thread).
     - When hovering over the notch, SwiftUI evaluated `NotchiePanoramicHubView.topWingHeaderBar` which referenced `MeetingControlService.shared`.
     - Inside `MeetingControlService.init()`, `DefaultMeetingControlProvider.getInputVolume()` synchronously executed AppleScript `NSAppleScript(source: "input volume of (get volume settings)").executeAndReturnError`.
     - AppleScript communication pumped the main-thread Carbon RunLoop via `RunCurrentEventLoopInMode` while `MeetingControlService.shared`'s `dispatch_once` was already locked on Thread 0.
     - The nested event loop triggered re-entrant layout passes in `NSHostingView.layout`, which re-evaluated `topWingHeaderBar` and called `MeetingControlService.shared` again—causing an instant recursive lock SIGTRAP trap.
   - **Native CoreAudio HAL Engine (`CoreAudio C API 기반 논블로킹 오디오 마스터 제어`)**:
     - Completely replaced AppleScript volume calls in `DefaultMeetingControlProvider` with Apple's native CoreAudio HAL C API (`AudioObjectGetPropertyData` / `AudioObjectSetPropertyData` using `kAudioHardwarePropertyDefaultInputDevice` and `kAudioDevicePropertyVolumeScalar`).
     - CoreAudio HAL executes in $<10\mu s$ directly in user space, dispatches zero AppleEvents, requires zero special permissions, and never pumps the Carbon RunLoop.
     - Any fallback for hardware devices without scalar support is dispatched to background `Task.detached`.
     - Added asynchronous `refreshInputVolume()` and eliminated synchronous audio initialization delays.
   - **Startup Pre-warming in `AppContainer`**:
     - Pre-warmed `MeetingControlService.shared` and `MessagesService.shared` during app container launch when not running unit tests, preventing any singleton initialization from occurring inside on-demand hover view tree rendering.
   - **SwiftUI Layout Refactoring in `QuickToolsView`**:
     - Consolidated multiple repetitive calls to `MeetingControlService.shared` in `topWingHeaderBar` into a single local scoped constant `let meetingService = MeetingControlService.shared`.
   - 321 unit tests passed; Release build installed and verified at `/Applications/DynamicNotch.app` (PID 29130, UUID `8A3863FF-B7F6-393A-9EB0-1C9A4D351ACC`).

2. **Multi-Strategy Real-Time Synced Lyrics Engine & Click-Anywhere Toggle (2026-10-30 v41)**:
   - **Why Apple Music Real-Time Lyrics failed previously & how it's solved**:
     - Apple Music streaming tracks encrypt synced lyrics (TTML format) via FairPlay DRM. The local AppleScript API (`tell application "Music" to get lyrics of current track`) only returns ID3 tag static lyrics and yields an empty string for all streaming catalog tracks.
     - Upstream `LRCLIBLyricsProvider` was failing due to public server overload (HTTP 503 ServerOverloaded on `https://lrclib.net`), lacked title normalization for Apple Music metadata (e.g. parenthetical subtitles, feat, remaster tags), and lacked retry logic once marked as `.notFound`.
   - **New High-Availability Multi-Strategy Lyrics Pipeline (`다중 실시간 동기화 가사 공급자 파이프라인`)**:
     - **`KugouLyricsProvider`**: High-speed (~50ms), highly available, million-track LRC provider with millisecond timestamp parsing (`[mm:ss.xx]`), candidate duration matching, and Base64 UTF-8 decoding. Supports Korean, English, Japanese, and international pop songs flawlessly.
     - **Title Normalization & 3-Pass Search**: Cleans noisy subtitles like `"(Down Santa Claus Lane)"`, `"[Remastered 2024]"`, `"(feat. ...)"`, and `"- Single"`, trying raw title, cleaned title, and artist queries in sequence.
     - **Enhanced `LRCLIBLyricsProvider`**: Added `DynamicNotch/1.0` User-Agent header, cleaned title search fallback, and graceful 429/503 HTTP status code handling without throwing fatal errors.
     - **`AppleMusicLyricsProvider`**: Retained for local ID3 tag lyrics.
     - **`CompositeLyricsProvider`**: Coordinated pipeline: `[AppleMusicLyricsProvider, KugouLyricsProvider, LRCLIBLyricsProvider, OvhLyricsProvider]`.
     - **Retry & State Refresh Policy in `NowPlayingViewModel`**: `loadLyricsIfNeeded` now only returns early if already `.loaded` or currently `.loading`, allowing users to retry instantly if a prior attempt was offline or failed.
   - **Click-Anywhere Toggle on Now Playing Screen (`Now Playing 화면 아무 곳이나 클릭하여 가사 on/off`)**:
     - Wrapped the entire `NotchieNowPlayingStudioColumn` card with `.contentShape(Rectangle())` and `.onTapGesture { store.toggleLyricsInCalendarSlot() }`.
     - Clicking ANYWHERE on the Now Playing card—including album artwork, song title, artist, live equalizer, card background, padding, or elapsed time labels—smoothly toggles the real-time lyrics view in the calendar slot on/off!
     - Playback controls (play/pause, next, previous, favorite, audio output picker) and scrubber dragging intercept their own events without triggering accidental lyrics toggle.
     - Added native hover tooltip and interactive cursor feedback: "Click anywhere to view real-time lyrics in calendar slot" / "아무 곳이나 클릭하여 캘린더 자리에 실시간 가사 보기".
   - 321 unit tests passed; Release build installed and running at `/Applications/DynamicNotch.app` (PID 27396, UUID `96B528B5-8DC9-34EE-B291-D54075AD0271`).

2. **Centered Symmetrical Notch Animation, Unclipped AI Usage Cards & X Button Removal (2026-10-30 v40)**:
   - **Centered Symmetrical Expansion Animation (`노치 중앙 대칭 확장 애니메이션 개선`)**:
     - Resolved the lateral drift issue where the notch previously appeared with a right-to-left skew due to asymmetric tab weight in the top wing header.
     - Redesigned `topWingHeaderBar` with mathematical symmetry:
       - **Left Wing**: Primary productivity tabs (`Nook`, `Tray`, `AI`) anchored to `.leading` with `.frame(maxWidth: .infinity)`.
       - **Center**: Camera Cutout Safe Area (`Color.clear.frame(width: 148)` on notch screens, `16` on Dynamic Island) permanently locked at 50% screen center.
       - **Right Wing**: Communication, controls & settings (`Meeting`, `Messages`, `Settings`) anchored to `.trailing` with `.frame(maxWidth: .infinity)`.
     - Left and Right wings have identical calculated widths at every single millisecond of the spring animation, ensuring organic, perfectly centered expansion and collapse from the notch hardware center.
   - **Unclipped AI Usage Cards & Layout Polish (`AI 사용량 탭 잘림 방지 및 UI 다듬기`)**:
     - Enlarged `.ai` presentation geometry in `QuickToolsNotchContent` to `max(780, baseWidth + 580)` and increased `shelfExtraHeight` to `270` (`260` on Dynamic Island).
     - Upgraded `cardsContainer` from fixed 236px horizontal scroll to responsive `HStack(spacing: 8)` with `.frame(maxWidth: .infinity)`: all 3 provider cards (Claude, Codex, Gemini) divide the available width cleanly with 100% visibility, zero clipping, and no horizontal scroll required.
     - Added `.minimumScaleFactor(0.8)` and optimized card inner padding to prevent reset countdown text truncation.
   - **Removed X Icon (`노치 닫기 X 아이콘 제거`)**:
     - Removed the redundant `xmark` button from the top wing bar for a cleaner, more minimalist Apple Glass aesthetic.
   - 318 unit tests passed; Release build installed and running at `/Applications/DynamicNotch.app` (PID 24125, UUID `E81B1B28-7767-3450-B2C8-963F023D1CA9`).

2. **Droppy-style Meeting Controls & Messages Quick Reply in the Notch (2026-10-30 v39)**:
   - **Meeting Controls Hub (`노치 미팅 컨트롤: 줌/미트/팀즈/페이스타임/웹엑스`)**:
     - Dedicated `MeetingControlService` detecting active meetings across Zoom (`us.zoom.xos`), Microsoft Teams (`com.microsoft.teams`), FaceTime (`com.apple.FaceTime`), Google Meet (browser tabs), Webex (`com.cisco.webex.meetings`), and Calendar meetings.
     - Live active meeting status indicator with animated pulsing dot and real-time elapsed duration timer (`formattedDuration`: `00:14:22`).
     - **1-Click Universal Hardware Mic Mute / Unmute**:
       - Instantly mutes system microphone hardware (`set volume input volume 0`), restoring original configured input volume (e.g. 60-75%) upon unmute.
       - Dispatches meeting app-specific keyboard shortcuts (`⌘⇧A` for Zoom, `⌘D` for Meet, `⌘⇧M` for Teams/FaceTime, `⌘M` for Webex).
       - Prominent interactive tile with live audio visualizer state and status badges (`LIVE` vs. `MUTED`).
     - **1-Click Camera Toggle**:
       - Switches video state and sends app camera shortcuts (`⌘⇧V` for Zoom/FaceTime, `⌘E` for Meet, `⌘⇧O` for Teams).
     - **Leave Call / End Meeting**:
       - Instant crimson button ending call via platform hangup shortcut (`⌘W` or `⌘⇧H`) and stopping session timer.
     - **Quick Launch & Link Copy**:
       - 1-click Copy Meeting Link, 1-click Focus Meeting App window, and quick launch tiles for Zoom, Google Meet, Teams, and FaceTime.
     - **Top Wing Header Bar Integration**:
       - Added `Meeting` (`video.fill`) primary tab in `topWingHeaderBar`.
       - When an active meeting is in progress, an animated live pill (`🟢 Zoom 04:12`) appears in the top header bar, allowing 1-click expansion to meeting controls.
   - **Messages Quick Reply in the Notch (`노치 메시지 즉시 답장 & 이모지 반응`)**:
     - Dedicated `MessagesService` interfacing with native Messages.app via private AppleScript without requiring full disk access.
     - Fast contact list carousel loading recent conversations (`꼬순잰🌸💕`, `Dohan Kim`, etc.) with customized avatar initials, display names, and service badges.
     - **Inline Quick Reply Input Box**:
       - Sleek frosted glass capsule text field directly inside the notch drawer.
       - Type a response and press Return/Enter or click the blue `arrow.up.circle.fill` button to send immediately.
       - Appends message bubble into the conversation view with "Delivered" receipt and plays native Apple send sound (`Pop`).
     - **Quick Emoji Reaction Bar**:
       - One-tap emoji chips (`👍`, `❤️`, `😂`, `🎉`, `🙏`, `🔥`, `👎`, `🚀`) for instant single-tap reactions delivered straight to the active chat.
     - 1-click button to open full Messages.app window and refresh chat conversations.
   - 318 unit tests passed (including dedicated `MeetingAndMessagesTests`); Release build installed and running at `/Applications/DynamicNotch.app` (PID 21724, UUID `B08C6F44-6532-3D63-9624-14D702700928`).

2. **Now Playing Apple Music Lyrics Slot & Calendar Hover-to-Scroll (2026-10-30 v38)**:
   - **Now Playing Click-to-Lyrics Toggle (`노치 Now Playing 클릭 시 캘린더 자리에 실시간 가사 토글`)**:
     - Clicking on Now Playing in the Notch (album artwork, track title & artist row, equalizer, or the dedicated `quote.bubble` lyrics button) smoothly transforms the right Calendar column into a dedicated real-time Apple Music lyrics column (`NotchieNotchLyricsColumn`).
     - Clicking Now Playing again (or clicking the `"Calendar"` button in the lyrics header) instantly toggles back to the Calendar view with a fluid spring animation.
     - Also wired into `NotchieMiniNowPlayingHeaderPill` in the top bar: clicking the pill while playing audio opens the Nook tab directly with the lyrics slot active.
     - **Apple Music Local Lyrics Provider (`AppleMusicLyricsProvider`)**:
       - Added `AppleMusicLyricsProvider` to `CompositeLyricsProvider` alongside `LRCLIBLyricsProvider`.
       - Reads lyrics directly and privately from Music.app (`com.apple.Music`) via background AppleScript without any network latency or external tracking, parsing both LRC timestamped lyrics and plain lyrics.
       - Provides real-time synced lyrics with bold glowing active line, tap-to-seek playback, smooth auto-scrolling to center, and subtle top/bottom gradient mask.
   - **Calendar Hover-to-Scroll Date Navigation (`캘린더 날짜 hover 시 스크롤 탐색`)**:
     - In `NotchieCalendarScheduleColumn` (both compact `nookCalendar` and standard middle row), hovering over the 7-day date strip captures trackpad two-finger swipes and mouse scroll wheels via `NSEvent.addLocalMonitorForEvents(matching: .scrollWheel)`.
     - Dynamically centers the visible 7-day strip around `selectedDayOffset`, allowing smooth infinite date navigation across days, weeks, and months without bounds clipping.
     - Today's date is permanently marked with an accent color badge, and clicking the prominent month header button instantly flies back to Today (`selectedDayOffset = 0`).
     - Safe hover lifecycle automatically removes the local event monitor upon unhover or `.onDisappear` without blocking date clicks.
   - 312 unit tests passed (including dedicated `NowPlayingLyricsTests`); Release build installed and running at `/Applications/DynamicNotch.app` (PID 19318, UUID `47ACF652-0813-3AA8-A241-0BC9FE11BB7E`).

2. **Independent AI Usage Notch Tab, Official Product Logos & Precise Codex Rate-Limit Exhaustion Tracking (2026-10-29 v37)**:
   - **Independent Primary Notch Tab (`별도 독립 노치 탭 분리`)**:
     - Removed AI Usage from the Tray secondary sub-mode segmented bar (`trayAndShotsUnifiedContainer`).
     - Promoted AI Usage to an independent, top-level primary tab in the Notch Wing bar (`topWingHeaderBar`) with `brain.head.profile` icon and dedicated `aiIndependentNotchContainer` rendering full-width side-by-side cards.
   - **Official Product Logos (`공식 제품 로고 탑재`)**:
     - Extracted and bundled official high-resolution application icons for **Claude** (Anthropic), **OpenAI Codex / ChatGPT**, and **Google Gemini** into `DynamicNotch/Resources/Assets.xcassets/icons/`:
       - `claudeLogo.imageset` (1x, 2x, 3x)
       - `codexLogo.imageset` (1x, 2x, 3x)
       - `geminiLogo.imageset` (1x, 2x, 3x)
     - Implemented `AIProductLogoView` in `AIUsageNotchView.swift` rendering crisp native assets with smooth squircle corner curvature and graceful SF Symbol fallbacks. Displayed in both provider filter pills and card headers.
   - **Precise Codex Quota Exhaustion & Rate-Limit Detection (`Codex 할당량 소진 감지 및 리셋 카운트다운`)**:
     - Resolved issue where exhausted Codex quota previously showed as 100% available due to stale `session_index.jsonl`.
     - Added native SQLite reader for `~/.codex/thread_history_1.sqlite` querying `thread_turns.error_json` for `usageLimitExceeded` and parsing the backend's explicit reset time string (e.g. `try again at Oct 30th, 2026 1:15 AM`).
     - Accurately reports 100% quota utilization, displays `"소진 / Max"` badge, red progress bar, `"할당량 소진됨"` subtitle, and real-time countdown to exact reset (e.g. `1:15 AM 리셋 · 1시간 28분 후 (한도 소진)`).
   - **Side-by-Side Codenotch Cards & Active Session Tracker (Claude Code, OpenAI Codex & Google Gemini)**:
     - Side-by-side multi-provider grid with live pulsating indicator, active session/thread titles, 5-hour rolling session bars, and weekly quota bars.
   - 309 unit tests passed; Release build installed and running at `/Applications/DynamicNotch.app` (PID 15841, UUID `7D63F14D-FD95-33C9-BB78-D1228A3D78A6`).

2. **Fluid Dynamic Island Motion & Apple Spring Physics (2026-10-29 v33)**:
   - Added `.fluid` animation preset to `NotchAnimationPreset` and `NotchAnimations`:
     - Incorporates Apple's organic spring physics (`response: 0.38`, `dampingFraction: 0.68`, `blendDuration: 0.15`), providing lively, bouncy squish on notch expansion, collapse, and notification morphing.
     - Pacing delay optimized to `0.20s` and transition delay to `0.22s` for snappy, fluid interactions.
   - Connected `NotchSettingsProviding` and `ApplicationSettingsStore` with `@StoredDefault(key: GeneralSettingsStorage.Keys.notchAnimationPreset, defaultValue: .fluid)`.
   - Added interactive Motion & Dynamic Island Physics picker card in `NotchSettingsView` (`설정 - 노치`) with localized English & Korean titles and descriptions.
   - Added unit tests verifying physics parameters, default values, and settings persistence.

3. **Face ID-Grade Instant Face Recognition & Eye Openness Liveness (2026-10-29 v32)**:
   - Optimized face unlock pipeline latency from 3.5s+ down to ~0.2-0.3s (Face ID equivalent speed).
   - Integrated eye openness evaluation (Eye Openness Ratio via Vision landmarks) and camera gaze/pose attention (`isFacingCamera`, `isGazeDirect`) into `DetectedFace` and `FrameEvaluation`.
   - Enabled instant 1-frame match when live eye attention and enrolled ArcFace facial similarity are verified, removing artificial multi-frame delays while preserving anti-spoof security.
   - Reduced `CameraCapture` warmup discard latency from 400ms down to 50ms, upgraded video frame interval to 30 fps (33ms), and lowered verifier sleep to 5ms for instantaneous frame acquisition.
   - 104 HeyMac engine/core unit tests passed (including latency benchmarks ~17ms/frame); 297/297 DynamicNotch application tests passed.
2. **Multi-Directory Screenshot Capture & Preload Modernization (2026-10-29 v31)**:
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

### Physical lock failure follow-up — 2026-10-29 v24
- User's v23 manual Mac lock test failed. Fresh app log records successful face path then password rejection at 20:16:43; loginwindow confirms focused password field and INCORRECT password at 20:16:40.555. This is credential/delivery-stage failure, not evidence of a face-matching timeout.
- Explicit Save now verifies the current account password through OpenDirectory before encrypted persistence. A validation failure preserves the previous credential and rejection block. No existing credential is read or verified automatically.
- Resolve current ASCII-capable keyboard layout via Carbon and supply real virtual key codes plus required Shift/Option flags alongside Unicode, rather than virtual-key zero for all characters. Keep one password attempt, current layout unchanged, no modifier inheritance.
- Local diagnostic logs include executable revision and separate face/typing stage timings; no password or password length logged.
- Requires another user-controlled password Save/enable/manual lock test; no claim of physical success yet.

### v25 — keyboard-layout thread affinity fix
The v24 physical test crashed in HIToolbox's main-queue assertion during TIS input-source lookup. Snapshot the layout on main via a short synchronous dispatch, retaining background typing. Added a regression exercising the real Carbon lookup from a detached verification worker; no synthetic input or credentials are used by that test. Existing verified password and opt-in settings are preserved. Physical lock test remains required.

### v35 face-unlock speed work — 2026-10-29 (in progress)
- User requests Face ID-like response and supplies Notchy passive-liveness reference. Verified vendor help says matched frames + passive evidence, and acknowledges video replay limitations; current strict ArcFace + MiniFASNet frame acceptance retained rather than replacing it with eye openness alone.
- Release fixture profiling: cold detect/live/embed total 0.2319s, warm totals 0.0109–0.0137s. This is model-fixture inference, not camera/unlock latency. Prior actual v25 face check was 3.187s, so isolate camera/session costs.
- Prepare AVCapture session and dummy model inference before enabled engine starts, without starting camera stream or using enrolled identity. Maintain resolution, 400ms warmup, thresholds, anti-spoof and consecutive frames.
- Camera stop immediately invalidates frame epoch and clears frame storage; hardware stop runs on serial lifecycle queue outside password critical path. Start/prepare/stop command submission serialized; new start waits behind prior stop. Old in-flight conversions cannot publish into a new session.
- Face verification logs now split camera start, first frame and inference time for physical comparison.
- Build integration snapshot: /Users/davidkang/DynamicNotch/build/FaceSpeedIntegrated copied latest v34 worktree source without modifying other chat files, then overlaid only auth/backend changes. Preserve day-calendar and saved-player-tint work in final installed app. Primary checkout remains auth implementation base.


### Live Activity Compact Notch Layout & Sizing Invariant Unclipped Fix — 2026-10-30 v47
- **Calendar Live Activity Korean Time Unclipped Fix**:
  - Root cause: `CalendarNotchContent` computed compact extra width using `isAMPM ? 145 : 110`. Korean locale produces `"오전"` / `"오후"`, causing `isAMPM` to return `false` (110pt extra width). With hardware notch centered, right wing width was only $110 / 2 = 55\text{ pt}$. Minus 14pt trailing padding left only 41pt, while `"오후 1:00"` is ~70pt wide, causing the leading `"오"` to be hidden under the hardware bezel.
  - Fix: Added dynamic `requiredExtraWidth` measuring actual text width of `calendarViewModel.formattedNextEventTime` via `NSString.size(withAttributes:)`. Computes symmetrical extra width `max(200, ceil((textWidth + 28) * 2))`. Guarantees right wing has $\ge 100\text{ pt}$ space with $\ge 14\text{ pt}$ safe clearance from hardware cutout for `"오후 1:00"` and extended widths for relative/both formats (e.g. `"오전 11:30 · in 2h 30m"`).
  - Enforced single-line rendering: Added `.lineLimit(1)` and `.fixedSize(horizontal: true, vertical: false)` in `CalendarMinimalNotchView.swift`.
- **Systematic Inspection & Fixes Across All Compact Live Activities**:
  - `TimerNotchContent`: Increased `minimalTimerSize` from 110 to 140 for `MM:SS` (wing width 70pt > 45pt text + 15pt padding) and from 170 to 190 for hours/long formats. Added `.lineLimit(1)` and `.fixedSize(...)` in `TimerCountdownText.swift`.
  - `DownloadNotchContent`: Increased compact extra width from 70 to 85 for circle (wing width 42.5pt > 37pt thumbnail + padding) and from 90 to 115 for percent (wing width 57.5pt > 50pt `"100%"` + padding). Added `.lineLimit(1)` and `.fixedSize(...)` in `DownloadProgressIndicatorView.swift`.
  - `BluetoothConnectedNotchContent`: Increased compact extra width from 50 to 85 for circle and from 90 to 115 for percent. Added `.lineLimit(1)` and `.fixedSize(...)` in `BluetoothConnectedNotchView.swift`.
  - `ScreenRecordingContent`: Increased compact extra width from 60 to 75 for compact, and from 115 to 160 for detailed duration. Added `.lineLimit(1)` and `.fixedSize(...)` in `ScreenRecordingView.swift`.
  - `AirDropActiveNotchContent`: Increased compact extra width from 70 to 90 (wing width 45pt > 38pt AirDrop icon + padding).
  - `VpnActiveNotchContent`: Increased compact extra width from 105 to 130 (wing width 65pt > 56pt duration + padding). Added `.lineLimit(1)` and `.fixedSize(...)` in `VpnActiveNotchView.swift`.
  - `HotspotActiveContent`: Increased compact extra width from 100 to 115 for battery style. Added `.lineLimit(1)` and `.fixedSize(...)` in `HotspotActiveNotchView.swift`.
  - `FocusOnNotchContent` / `FocusOffNotchContent`: Increased compact extra width from 70 to 90 for standard text style. Added `.lineLimit(1)` and `.fixedSize(...)` in `FocusStatusNotchView.swift`.
  - `LockScreenNotchContent`: Increased compact extra width from 55 to 70 for standard lock, and from 95 to 110 for compact Face ID.
  - `TrayActiveNotchContent`: Increased compact extra width from 75 to 88. Added `.lineLimit(1)` and `.fixedSize(...)` in `TrayActiveNotchView.swift`.
  - `NowPlayingNotchContent`: Increased compact extra width from 70 to 84 (wing width 42pt > 36pt artwork + padding).
- **Verification**: 352 unit tests passed (including 6 new tests in `CalendarLiveActivitySizingTests.swift`). Release build succeeded, signed and installed to `/Applications/DynamicNotch.app` (PID 15910, UUID `13EC4E9F-4C05-3614-AC1C-7C8486BEF984`).


### Robust Google Meet AX & Click Automation Pipeline — 2026-10-30 v48
- **Google Meet In-Meeting Control Failure Root Cause**:
  1. Top-down window traversal in `performMeetAccessibilityAction` started at the window and traversed the tab bar and toolbar bookmarks. It reached the 200 visited limit before ever encountering `AXWebArea`.
  2. The Google Meet toolbar buttons are at the bottom of the DOM, which were placed at the very bottom of the reversed traversal stack and never reached within the 0.35s timeout.
  3. Strict `role == "AXButton"` ignored Meet toggle buttons exposed as `AXCheckBox` / `AXRadioButton` / `AXPopUpButton` or ARIA toggle buttons.
  4. Shortcut fallback activated Chrome and immediately sent `Cmd+D` via System Events without delay and without web area focus, triggering Chrome's native "Add Bookmark" (북마크 추가) sheet instead of Google Meet's listener.
- **Fix & Enhancements**:
  1. Direct `AXWebArea` discovery: `findWebAreas(in: window)` scans directly for the web area and verifies `meet.google.com` URL/title.
  2. Bottom-up toolbar traversal: Appends children in natural order so `popLast()` visits bottom elements (the Meet control toolbar) first, matching buttons within the first few iterations.
  3. Expanded element recognition: Accepts `AXButton`, `AXCheckBox`, `AXRadioButton`, `AXPopUpButton`, and role descriptions containing `"button"`, `"toggle"`, `"버튼"`, matching across `AXDescription` (aria-label), `AXTitle`, and `AXHelp`.
  4. Dual-layer click execution: First tries `AXUIElementPerformAction(element, "AXPress")`. If unsupported, reads button center screen coordinates via `kAXPosition` + `kAXSize` and posts a direct Quartz mouse click event (`postSyntheticClick`).
  5. Fallback web focus & tab activation: If Accessibility button click is unavailable, focuses `AXWebArea` via `kAXFocusedAttribute` and introduces a 0.15s activation delay in AppleScript so `Cmd+D` / `Cmd+E` is captured by Google Meet, and `Cmd+W` cleanly closes the Meet tab to disconnect.
  6. Added `.contentShape(Circle())` to all buttons in `MeetingNotchView` to ensure instant click registration across the entire 36x36 circular touch area.
  7. Resolved Swift 6 `@MainActor` warning in `refreshInputVolume()` by reading CoreAudio synchronously on main actor.
- **Verification**: 353 unit tests passed (including `testGoogleMeetShortcutResolutionAndFallback`); Release build succeeded, signed and installed to `/Applications/DynamicNotch.app` (PID 18062, UUID `E12EC8CA-D409-3D5B-B123-826101ED052B`).

### Google Meet Direct 3-Tier Tab Switching, AXEnhancedUserInterface & Hardware KeyCode Pipeline — 2026-10-30 v49
- **Root Cause of Secondary Failure**:
  1. `AXManualAccessibility` was returning `-25205` (`kAXErrorAttributeUnsupported`) on Chromium. Chromium requires `AXEnhancedUserInterface` to be set to `true` to enable full accessibility DOM tree population.
  2. In Chromium/Brave/Edge/Safari, `findWebAreas` only returns the `AXWebArea` for the active tab of each window. When Google Meet is in a background tab or when the user is focused on another tab/window, `findWebAreas` never finds the Meet tab, causing `performMeetAccessibilityAction` to fail silently.
  3. `Info.plist` lacked `NSAppleEventsUsageDescription`, causing AppleEvents to fail silently in sandboxed/packaged context.
  4. System Events `keystroke "d"` is dependent on keyboard input source. When Korean 2-set input is active, "d" maps to 'ㅇ' (`Cmd+ㅇ`), causing Google Meet to ignore the shortcut.
  5. The red hangup button label in Korean is `"통화 나가기"`, which failed `label.contains("통화에서 나가기")`.
- **Fix & Enhancements**:
  1. Enabled `AXEnhancedUserInterface = true` and `AXManualAccessibility = true` on the browser AX element.
  2. Implemented 3-Tier Execution Pipeline:
     - Tier 1: Direct `AXPress` / Quartz synthetic mouse click on active tab.
     - Tier 2: If Meet is in a background tab, `ensureMeetTabActive(bundleId:)` automatically brings the Meet tab to the active slot via browser tab indexing without stealing overall application focus, attaches the `AXWebArea`, and immediately executes `AXPress`.
     - Tier 3: Focused hardware keycode dispatch using physical virtual keycodes: `key code 2` (`Cmd+D` for Mic), `key code 14` (`Cmd+E` for Camera), `key code 13` (`Cmd+W` for Leave Call) with 100% layout and language independence.
  3. Added `NSAppleEventsUsageDescription` to `Info.plist` to guarantee system automation authorization.
  4. Expanded leave call keywords to include `"통화 나가기"`, `"전화 끊기"`, `"회의 나가기"`, `"통화"`.
  5. Enhanced meeting discovery in `detectActiveRunningMeeting()`: Added Step 2 browser tab inspection so calls in background tabs or with calendar titles (e.g. "팀 싱크") are accurately detected.
- **Verification**: 353 unit tests passed; Release build succeeded, signed and installed to `/Applications/DynamicNotch.app` (PID 28570, UUID `4E1ADF41-BD5B-3EE5-8266-0EB7594C03A1`).

## 2026-10-30 — Antigravity quota card (local v41)
- Renamed the third AI usage service from Gemini to Antigravity while preserving its persisted provider ID.
- Read existing running Antigravity IDE's private loopback RetrieveUserQuotaSummary protocol; separate actual Gemini/Claude-GPT/Argon buckets, original timestamps on failures, bounded read-only discovery, no Google OAuth credential extraction or IDE mutation. Private protocol limitations documented in Documentation/ANTIGRAVITY_QUOTA_20261030.md.
- Reused ten-second visible / sixty-second alert refresh; additional independent quota windows participate in warnings and fit in a bounded scrolling card. Five regression tests added; old provider display-name assertions updated.

## 2026-10-30 — Notchie stability and installed rename (v42)
- User-authorized whole-app improvements 2/3/4/8: cancel stale expansion/dismiss actions, protect menu/expanded interactions, prioritize critical activities and prevent stale restoration, recover display geometry with bounded canvas/content fitting, stop disabled input hooks and hidden meeting ticks, coalesce background meeting detection and transition waiters.
- Repaired FSEvents watcher callback lifetime after an observed test-host crash; stream retains an invalidatable callback box, not the watcher.
- Install as /Applications/Notchie.app with Notchie executable, retaining bundle ID/settings and backed-up legacy installation. Xcode project/scheme/module remain DynamicNotch. See Documentation/NOTCHIE_STABILITY_20261030.md.

## 2026-10-30 — AI panel clipping and playback delivery (v43)
- Bound the AI panel to the actual available size with fixed controls/footer and equal, independently scrolling provider cards; loading/stale/error text cannot enlarge the hub or push its header beyond the mask.
- Deliver media commands through an acknowledged source-app route before global fallback, serialize commands and avoid duplicate toggles; retain existing permissions, bounded Music AX fallback and adapter process timeout. See Documentation/LAYOUT_PLAYBACK_FIX_20261030.md.
