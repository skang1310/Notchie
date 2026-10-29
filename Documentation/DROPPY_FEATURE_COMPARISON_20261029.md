# Droppy reference comparison — 2026-10-29

Active source: `/Users/davidkang/DynamicNotch`. The user's existing Notchie identity, bundle ID, preference stores, upstream DynamicNotch GPL-3.0 notices and HeyMac MIT notices remain. Independent implementation based on public UI/documentation. No Droppy source, artwork, trademarks or executable bundled. Reference images live only in ignored `.lazyweb/design-research/droppy-2026-10-29/`.

## Sources inspected

- https://getdroppy.app/ — actual rendered Finish / Widgets demos, assets and navigation inspected through browser.
- https://getdroppy.app/features — current public inventory; vendor advertises 43 optional Droplets, different from an older public fork's inventory.
- https://getdroppy.app/docs/notch — Home / Tray / Widgets, per-display shape and gestures.
- https://www.macrumors.com/2026/10/28/apple-brings-dynamic-island-to-mac/ — supplied report describes system Live Activities, Spotlight, Siri and touch on new MacBook Pro. This is a secondary report, not an SDK contract. New device tests and OS system-region coexistence are not claimed. Existing screen-top-inset detection cannot establish new island-camera geometry.
- Lazyweb plugin skill read; no Lazyweb MCP tools exposed in this session. Web research fallback used.

## Core features

| Droppy capability | Notchie disposition | Practical scope |
|---|---|---|
| Notch shelf | Existing retained; extended | Current hover/click/leave/swipe/pin behavior, centered panoramic layout. New small Home / Tray / Widgets page dock; original Tools beside icon rail retained. |
| File tray | Existing retained | Existing drag/drop, selection, outbound drag, AirDrop and image exports unchanged. |
| Shelf widgets / Make It Yours | Added | Three slots; media/calendar/weather/focus/stats/notes, replacement with duplicate swap, left/right reorder, persistence, reset. Defaults do not replace existing Nook dashboard. |
| Dynamic / Liquid / solid glass | Added | Existing background store now supports three finishes in Appearance. Compact camera region stays black, expanded material blends; Reduce Transparency forces opaque backing. SwiftUI material approximation, not Droppy's custom renderer. |
| Clipboard history | Existing extended | Existing local text capture/search retained, concealed pasteboards excluded. Optional favorites persist and sort first; favorite-only filter. Recapturing preserves item identity/favorite. Images, rich/code/color classification and direct cross-app paste are not added. |
| Now Playing | Existing retained | Existing source adapters/artwork/seek/transport. No fake waveform, motion-art or provider queue data added. |
| Playing Next | Not added | Requires source-specific provider queue integration. |
| Command Center | Partial existing | App settings/menu and local quick launcher remain. Seven custom menu-bar layouts are not implemented. |
| Transform | Added local subset | Select up to 20 images/PDFs, reorder, combine to PDF; on-device Vision background removal for one image; existing OCR reused with Korean/English. Explicit Save; original path rejected. 30 MB/input, image decode max 4096 px, PDF limit 200 pages. Video/GIF/trim not implemented. |
| System HUDs / Live Activities | Existing retained | Existing volume/brightness/battery/Bluetooth/download/recording/timer activity engines. No new notification scraping. |
| Dynamic Island | Existing retained + shared UI | Existing notchless/external-screen floating pill uses same shelf; new physical MacBook Pro cutout and system Island coexistence untested. |
| Lock Screen | Existing retained | Existing integration unchanged; not a new system lock-screen API claim. |
| Floating Player | Not added | Current player remains in shelf, no three-size detached player. |
| iPhone companion / Sync | Not added | Requires separate iOS product, identity/pairing and encrypted transport. Existing Mac app has no such backend. |

## Optional Droplets

| Droppy capability | Status here | Notes |
|---|---|---|
| Agents | Partial existing | Explicit local build/task results, not automatic access to coding-agent logs or usage accounts. |
| Calendar | Partial existing | Existing EventKit read, dates, meeting join, local top-three tasks. No new Reminders/NL writer. |
| Cleaner | Not added | No app deletion, cache deletion or system cleanup performed. |
| Lyrics | Existing retained | Existing opt-in adapter, unchanged. |
| Audio Control | Not added | Output routing/HUD existing; per-app mixing/boost needs separate audio architecture/permissions. |
| Droppy Cloud | Not added | No service credentials, uploads or copied vendor backend. |
| Action Ring | Not added | Existing quick launcher retained. |
| Thunderstorm | Partial existing | Existing app launcher/calculator/units/developer tools, no full filesystem index. |
| Notifications | Not added | No unsupported global notification access or simulated message controls. |
| Meetings | Partial existing | Existing safe meeting URL join/countdown; cross-app mute/camera/end requires provider integrations. |
| DropClip | Not added | Clipboard tools explicit; no new global selection observer. |
| Notes | Existing retained | Existing persistent local note engine and pins; no Apple Notes sync or live Markdown parser added. |
| Element Capture | Partial existing | Existing screenshot history/case board/OCR/redaction/export; not element-level capture. |
| Pomodoro | Existing retained + widget | Existing FocusSessionController, pause/resume/stop/break/history. |
| Stay Awake | Existing retained | Real IOKit assertions with bounded expiry and cleanup; no auto-enable. |
| Text Capture | Existing + new entry | Existing OCR reused from selected image in Transform. PDFs can combine but OCR is image-only in this UI. |
| Sales | Not added | Requires actual provider accounts/data. |
| DockDoor | Not added | No third-party executable downloaded/installed. |
| Weather | Existing retained | Current Open-Meteo/weather/sun-arc module left unchanged. |
| System Stats | Added subset | Actual host CPU delta, active+wired+compressed RAM, 40-sample CPU history, every 2 seconds while visible. First CPU sample unavailable until baseline; no made-up GPU/thermal/network data. |
| Devly | Partial existing | Existing local developer tools retained. |
| Things 3 | Not added | Requires installed app/provider configuration. |
| Xcode Builds | Existing retained | User-launched actual Xcode jobs, exit code/duration, not auto-observed Xcode UI. |
| CleanMyMac | Not added | No provider integration. |
| MCP | Not added | No new local/network server exposed. |
| Teleprompter | Added | Local persisted script and words/minute, read/edit, highlighted seven-word lines, auto-scroll, size, pause/reset. Monotonic elapsed time with sleep-gap limit; never resumes running after relaunch or closing view. |
| Lid Fold | Not added | No private lid-angle driver assumptions. |
| Emoji Picker | Added subset | Searchable bilingual common-emoji grid and explicit copy, no global keystroke interception. |
| Kaset | Not added | No external app integration. |
| Obsidian | Not added | No vault selected or watched. |
| LocalSend | Not added | Existing AirDrop remains; no new network listener. |
| Mechey | Not added | No global key monitor/sound asset downloads. |
| Thaw | Not added | No third-party menu-bar software installed. |
| LiquidMouse | Not added | Existing notch mouse gestures unchanged; no global scrolling driver. |
| Camera | Existing retained | Existing explicit opt-in camera mirror/face setup, no permissions enabled. |
| Apple Music Controls / Spotify | Existing retained | Current media adapters preserved; no new provider scope or queue write. |
| Termi-Notch | Partial existing | Existing restricted local jobs; no arbitrary embedded shell. |
| Voice Transcribe | Not added | No model downloads or microphone access. |
| Remove Background | Added | Apple Vision foreground-instance mask on explicit selected image, local PNG export; no external AI API. |
| Window Snap | Existing retained | Existing preview/gesture path unchanged; no new Accessibility grants. |
| Alfred / Finder Services | Not added | No external extension/workflow installation. |

## Validation

See latest `TEST_REPORT.md` checkpoint for exact test/build/install/runtime evidence. This document records scope, not certification that every feature works on every macOS/hardware combination. Optional services and existing user data are not automatically enabled, deleted or uploaded.

### Installed verification notes

During installed-app testing the existing custom Finder-icon code was found to add extended attributes after launch and break strict code signature verification. Delivery removes that bundle mutation, retaining icon selection/previews and the dynamic Dock icon. Finder uses the packaged appearance assets. This is a delivery-integrity repair, not an added Droppy capability.

The installed v16 tool list, favorite controls, teleprompter editor/read/start controls were observed. A later native UI action explicitly reported that the Mac was locked. Remaining visual widget/material checks and new hardware coexistence must not be reported as passed. Automated model checks and Release/installed identity are separately recorded in TEST_REPORT.md.

### Revalidation / polish v18

Installed v18 widget cards, dark editor and dark searchable tool-library layout visually checked; actual widget down/up reorder and restoration passed. Material selection persisted through relaunch. Shared-engine actual OCR, foreground cutout PNG Save, PDF Save, output alpha/page inspection and emoji copy/paste round trip passed during this revalidation. All 284 app tests pass. Full evidence and remaining limits (including final Enter selection, clipboard favorite physical copy and new hardware) are in TEST_REPORT.md.

### User override v20 — simplified Nook

The user removed the lower Home/Tray/Widgets dock and requested media/calendar/mirror-only Nook. Upper Nook/Tray/Tools remain. Existing widget preferences were not deleted, but the lower widget navigation is no longer shown. Weather/solar/task/quick-tools home content removed from Nook. Circular video-only Mirror requires explicit click, stops when leaving Nook, and does not invoke face enrollment. Final home layout was visually checked in the installed app; physical camera preview remains unverified. Full 290 app tests and final build/install/post-launch signature passed.
