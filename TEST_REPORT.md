# Apple HIG / Liquid Glass design refresh — 2026-10-28

- Checked official Apple Design, Materials, Adopting Liquid Glass and custom SwiftUI glass guidance live. Lazyweb discovery remained empty. Before/after installed screens inspected through native screenshots; this is a scoped UI refresh, not a complete accessibility audit.
- Shared settings shell/cards/spacing refreshed; native sidebar and toolbar retained, opaque 52-point header overlays removed. Installed visual check caught scroll/title overlap; corrected NSWindow content boundary (no fullSizeContentView) and native toolbar background. Standard selection/history/search machinery preserved. Resizable settings window/minimum geometry implemented; physical minimum-size drag not tested.
- Lock & Authentication UI reorganized into status/setup/management. Actual stored registration and credential-presence indicators preserved, secure-field editing disclosed explicitly, original confirmation for removal retained. Registered users see face test before re-registration. Native glass button styles on supported systems, bordered fallback under Reduce Transparency/Increased Contrast or older OS. Source reviewed; system accessibility preferences not modified or physically certified.
- Whole app suite **265 passed / 0 failed**, `/tmp/dynamicnotch-glass-tests.log`, xcresult `build/HeyMacTests/Logs/Test/Run-DynamicNotch-2026.10.28_19-15-52-+0900.xcresult`. After toolbar-boundary correction, focused selection-history/localization tests **9/9 passed**, `/tmp/dynamicnotch-glass-final-navigation-tests.log`. Final button-priority/size-only polish followed by successful Release rebuild.
- Final Release `BUILD SUCCEEDED`; scripts/install-local.sh + strict deep signature passed. Revision **Glass-20261028**. Installed and Release executable UUID **E080B99B-46DD-3C67-BB5A-AD9D8852C93D**. /Applications app relaunched and final button ordering inspected; final screenshot captured. Normal menu quit was used before replacements.
- Installed general page and lock/auth screens inspected. New app-privacy segment, opaque preview and enabled return to settings exercised. No authentication, enrollment, credential entry, protected grants, app-lock enabling or destructive removal performed. User's existing registration/password presence and off states remained visible.
- VoiceOver, app-wide light/dark/accessibility combinations, all legacy screens and physical authentication/Spaces/hotplug remain separate gates. No new animations added; privacy cover stays opaque.

---

# HeyMac app privacy + test-host incident — 2026-10-28

- User-reported crash attachment/screenshot identifies **com.Jackson.DynamicNotch.LocalTests**, PID 21520 at 19:03, EXC_BAD_ACCESS/SIGBUS immediately after launch. Matches failing incremental unit-host bootstrap, not the separately running /Applications process. Repeated runner starts/reopens produced repeated reports. Exact compiler/runtime cause is not proven; do not equate heap instruction fault with user permission or camera failure.
- Kept failure evidence in Xcode Logs/Test and macOS DiagnosticReports. Initializer cleanup, explicit nonisolated cancellation token and clean rebuild passed **265/265** app tests. Added a quiet unit-test menu path and `scripts/test-app.sh` (clean build, one worker, test display name, ENABLE_DEBUG_DYLIB=NO). After that change final rerun again **265 passed / 0 failed**, `/tmp/dynamicnotch-privacy-tests.log`, xcresult `build/HeyMacTests/Logs/Test/Run-DynamicNotch-2026.10.28_19-06-25-+0900.xcresult`. Existing unrelated system service warnings remain non-failing.
- Vendored engine/core tests **52 + 42 passed / 0 failed**, `/tmp/dynamicnotch-privacy-engine-tests.log`. New app-state tests exercise persisted settings, isolated namespaces, recovery exclusions, session loss across restart, monotonic deadlines, focus grace, policy-change/disable/removal revocation and pause expiry. New engine tests reject cancelled face/system successes.
- Final Release build succeeded (`/tmp/dynamicnotch-privacy-build.log`). Installed with scripts/install-local.sh, strict deep signature passed. Installed and Release executable UUID **6C3E7249-7EE8-38C2-B01E-083A63C55D6F**, revision **HeyMacPrivacy-20261028**, test-host marker empty. Final localization-only English privacy correction included in last Release rebuild.
- Previous installed app quit via actual menu, canonical process absent afterward; final app relaunched from /Applications. Installed Korean app privacy segment shows both toggles off/no selected apps; real installed-app list excludes core recovery apps; opaque cover preview and Back to Settings both observed. No actual app protection enabled, permission granted, biometric registration, password entry/submission or authentication attempted by agent. User-existing face/password registration remained present on relaunch. Latest macOS crash-report filenames remained 19:03 after final app UI checks.
- User must opt in and select apps to test actual authentication. Fullscreen/Spaces, physical display hotplug, background/notification previews, sleep/wake and real Touch ID/face/password rejection remain unverified. App cover is a privacy aid, not encryption or OS access control. No watchdog/launch agent or quit trap installed.

---

# HeyMac delivery — 2026-10-28

- Final Release `xcodebuild` succeeded with CODE_SIGNING_ALLOWED=NO; `/tmp/dynamicnotch-heymac-build.log`.
- Whole app tests: **257 passed, 0 failed**, isolated LocalTests app; `/tmp/dynamicnotch-heymac-app-tests.log`; xcresult `build/HeyMacTests/Logs/Test/Test-DynamicNotch-2026.10.28_18-49-53-+0900.xcresult`. Final follow-up changed section title/subtitle only; Release rebuild and localization JSON validation passed afterward.
- Vendored engine/core: **50 + 42 passed, 0 failed**, `/tmp/dynamicnotch-heymac-tests.log`. Includes fixtures/model execution, encrypted storage/tamper handling, password rejection and newly added post-match disable/stop no-typing regression checks.
- `scripts/install-local.sh build/HeyMacRelease/Build/Products/Release/DynamicNotch.app` exit 0. Installed strict signature verification exit 0. Revision `HeyMac-20261028`; installed and Release executable UUID **623705D4-3B6A-3206-BA42-89CEC18770BF**.
- `/Applications/DynamicNotch.app` launched, canonical process path observed. Final Korean Settings screen and screenshot inspected: 얼굴 잠금 해제 title and HeyMac subtitle correct; registration/password controls and opt-in disabled state visible. No face enrollment, credential submission, Camera/Accessibility grant or login launch enabled by agent. Existing Alcove-inspired behavior retained; current Alcove activation screen prevented new detailed interaction comparison.
- UI automation intermittently timed out during menu/quit operations; final full-path app settings retry succeeded. No clean-quit/resource-cleanup claim for this delivery. No physical face enrollment/lock-screen unlock/impostor-resistance/wake/reboot verification. See `Vendor/HeyMac/LOCAL_INTEGRATION.md` for private lock-state API and model redistribution limits.

---

# Application identity and duplicate registration cleanup — 2026-10-28

The canonical installed app is **/Applications/DynamicNotch.app**. It already matches the latest Release artifact, so no replacement/build was necessary in this checkpoint.

Fresh checks:
- Installed and Release Mach-O UUID both **3EE4FA5B-FF60-3F32-8373-6DA6A9674F4A** (arm64).
- Compiled __text section SHA-256 both **9445f93fa12e400b109088267f56dee9516afb7ec9bfc72bd086c7c1b5c2b9fe**. Packaged LOCAL_CHANGES includes approved productivity extensions. Local marker true; test-host marker empty.
- `codesign --verify --deep --strict /Applications/DynamicNotch.app`: exit 0.
- Eight noncanonical DynamicNotch LaunchServices registrations (builds, old backups, stale temporary staging URLs, user Xcode Debug output) unregistered individually; every command exit 0. Registered the canonical app explicitly; after-dump shows only /Applications/DynamicNotch.app as the DynamicNotch app registration. No global registry reset performed.
- Preserved four previous installed app bundles by renaming build/installed-backups to **build/installed-backups.noindex**. Preserved failed-signing-stage similarly as **build/DynamicNotch-failed-signing-stage.noindex**. No app/source/user data was deleted. Installer now uses the noindex backup directory for future installs; `zsh -n DynamicNotch/scripts/install-local.sh`: exit 0.
- Spotlight still reports the canonical app plus two legitimate development output files (Release and Xcode DerivedData Debug). These are retained for development; do not claim every filesystem search contains only one matching file. Opening a development output again may re-register it.
- Native launch/inspection attempted but Mac is locked. No fresh launch or screen-success claim. Unlock and open the canonical Applications path to use the installed build.

No Swift/application implementation changed; **build and automated tests were not rerun**. Prior 244/244 and 14/14 results below remain dated prior evidence. Latest cleanup manifest and identity record: build/checkpoints/productivity-20261028/app-registration-cleanup.json and installed-build-identity.json. The noindex move mapping supersedes older backup paths in historical entries.

---

Full authoritative prior evidence: /Users/davidkang/Documents/ChatGPT/myownnotch/TEST_REPORT.md

## Support workflow checkpoint — 2026-10-28
- Initial Debug build failed on multiple @State bindings; fixed.
- Initial focused suite crashed on inherited MainActor closure in utility-queue filesystem callback; explicit Sendable callbacks fix it. Next run: 22/23 (Bearer token masking defect); fixed order.
- Final focused `scripts/test-local-tools.sh`: exit 0, **24 passed / 0 failed**, log `/tmp/dynamicnotch-support-final-focused.log`. Includes real ZIP deflate + forged size rejection and real image/export/folder-watch fixtures.
- Whole app `xcodebuild -project DynamicNotch.xcodeproj -scheme DynamicNotch -configuration Debug -derivedDataPath ../build/DynamicNotch DYNAMICNOTCH_TEST_HOST=YES PRODUCT_BUNDLE_IDENTIFIER=com.Jackson.DynamicNotch.LocalTests CODE_SIGNING_ALLOWED=NO test`: exit 0, **254 passed / 0 failed**, `/tmp/dynamicnotch-support-final-tests.log`. LocalTests identifier and temp stores isolate production data.
- Parent `scripts/test.sh`: exit 0, registry Python **2/2**, all printed Swift core groups PASS; `/tmp/nookflow-support-regression.log`. Historical NookFlow source retained only.
- Release build exit 0 (`/tmp/dynamicnotch-support-release.log`); install script exit 0 and deep strict ad-hoc signature check exit 0; installed revision Support-20261028.
- New installed launch exposed an inherited blocking IOBluetooth registration in main-thread AppContainer construction. Sample `/tmp/dynamicnotch-support-launch-sample.txt`; targeted deferred/background registration fix under validation. No startup success claimed yet.
- Warnings: existing unused test scale variables/unreachable localization test code and AppIntents metadata skipped.
- Manual gates: final installed launch/UI, direct notch typing, Apple Shortcuts real execution, ZIP UI save/extract, report compare UI and image caseboard export UI; CPU/battery savings unmeasured.

## Notchie-Droppy-20261029-v16 — delivery checkpoint

- Final app suite: **283 tests, 0 failures**, including 9 new ShelfExperienceTests. Exact final log: `build/DroppyEvidence-20261029/build-droppy-tests-signed-bundle.log`; xcodebuild **TEST SUCCEEDED**. New regression coverage: widget replacement/reordering/persistence and malformed saved lists; CPU deltas; teleprompter timing/pause/sleep/restore; glass persistence; optional favorite migration/recapture; bilingual emoji lookup; actual PDF output/order/dimensions/original preservation and corrupt-input rejection.
- First test run retained: 2 geometry assertions expected the previous content height; updated the specified expanded sizes for the added navigation dock. Subsequent full runs passed. Initial Release import-access mismatch (`Darwin`) fixed in the added stats file; failed log preserved.
- Final Release: DynamicNotch.xcodeproj / DynamicNotch, CODE_SIGNING_ALLOWED=NO, **BUILD SUCCEEDED**. Log: `build/DroppyEvidence-20261029/build-droppy-release-signed-bundle.log`.
- Installed by `scripts/install-local.sh` at `/Applications/DynamicNotch.app`, existing app backed up by the installer. Local Apple Development signing identity reused. Installer log: `build/DroppyEvidence-20261029/install-delivery.log`.
- Final installed and Release executable UUID: **7F5C9C20-42C7-34F1-9695-4B141E4F0689** (arm64). Revision **Notchie-Droppy-20261029-v16**. Canonical executable observed running as PID 69668 after final launch. Strict `codesign --verify --deep --strict` returned **0 after launch**.
- Integrity repair: first installed launch exposed the existing Finder icon mutation (`Icon\r`, FinderInfo/ResourceFork) causing post-launch strict signature failure. Removed NSWorkspace.setIcon on the signed bundle; dynamic Dock/in-app icon and persisted selection remain. Rebuilt, reran all 283 tests, reinstalled, relaunched and verified final strict signature. No claim that Finder custom-icon forcing remains.
- Installed native UI observed before the final integrity-only rebuild: new tools present, clipboard favorite controls, teleprompter editor/read mode/start and return-to-start state after completion. A temporary test script was entered and its new preference key removed before the final reinstall; no personal script existed before this test. Initial pre-update app normal Cmd-Q and process absence observed. Later final update used targeted process termination while locked; no final clean-quit UI claim.
- **Runtime limits:** native UI subsequently reported the Mac locked. Final Widgets/material visual checks, widget swapping through physical input, transform Save/background-removal/OCR quality and clipboard favorite physical-copy flow are not certified. PDF output and persistence models have automated coverage. The original Nook/weather/tray/providers were retained, not newly field-tested. No permissions, face enrollment, login launch or external sync configured. New MacBook Pro system Island/touch/geometry/coexistence remains unverified.
- Scope and all omitted/partial integrations: `Documentation/DROPPY_FEATURE_COMPARISON_20261029.md`. Local visual research: `.lazyweb/design-research/droppy-2026-10-29/report.html` (ignored references; not app assets).

## Revalidation and shelf polish — v17, 2026-10-29

### Completed live checks
- Mac unlocked during retry. Closed Settings to inspect the actual notch (not just the Settings window). Observed Home/Tray/Widgets/Tools navigation and original Nook/calendar/media retained.
- Actual Widgets selection, media→middle reorder and reverse restoration passed. CPU moved from baseline unavailable to real 19–20% values while RAM updated 72–75%; this is observation, not a performance benchmark. Calendar event contents not copied into evidence artifacts.
- Material picker switched Liquid Glass then Dynamic Glass. Final Dynamic Glass selection persisted across normal app quit, reinstall and relaunch. No system-wide appearance/security settings changed.
- Actual Transform file picker imported only a generated local verification fixture. OCR returned `NOTCHIE LOCAL OCR 2026` and `PDF and OCR verification`. Actual Save dialog wrote cutout.png and combined.pdf to the evidence folder. Output inspection: PDF 1 page, 2000×1200 bounds; PNG 2000×1200, alpha enabled, transparent corner alpha 0.0 and foreground alpha 1.0. Cutout visually isolated the synthetic foreground; no claim about quality on all photos. No personal file uploaded or transformed.
- Before final installation, normal Cmd-Q and canonical process absence verified.

### Implemented polish
- Equal-height widget cards with replace/reorder/reset editor popover; editor controls removed from the default content row.
- Searchable two-column native-symbol tool library (English, Korean, IDs), selection feedback and per-tool tint. Existing enabled tools preserved.
- App-localized tool tab titles and idle media label, matching stats card bounds, gradient CPU history, and no paused teleprompter tick loop. Native drawing used; no new raster/imagegen asset required.

### Final delivery evidence
- `build/PolishEvidence-20261029/tests.log`: **284 tests, 0 failures**, TEST SUCCEEDED. New bilingual library lookup regression added to existing 9 shelf regressions.
- `build/PolishEvidence-20261029/release-final.log`: **BUILD SUCCEEDED**, DynamicNotch scheme / Release / CODE_SIGNING_ALLOWED=NO.
- `scripts/install-local.sh` exit 0, log `build/PolishEvidence-20261029/install.log`.
- `/Applications/DynamicNotch.app` revision **Notchie-Droppy-20261029-v17**, executable UUID **048B2C55-DD8B-3F8D-A1FB-E055287F7670**, identical to Release. Canonical process observed PID 72345. Post-launch `codesign --verify --deep --strict` exit 0.
- Reference/review artifact: `.lazyweb/design-improve/notch-2026-10-29/report.html`. Lazyweb tool discovery still empty; reused already-observed official reference images. No app assets copied from Droppy.

### Remaining limits
- Final v17 popover/library UI automation did not complete: native controller explicitly reported the user changed the app; fresh state showed the user's Lock & Authentication settings. Stopped sending input to avoid conflicting with user work. v17 source/models/build/install are verified; final popover appearance and in-popup keyboard/mouse selection are not marked passed.
- Emoji/clipboard favorite physical-copy round trip, broader accessibility/display/fullscreen combinations, and new Mac system Island hardware coexistence remain separate checks. No protected permissions, enrollment, passwords, login launch or external services changed.

### Final v18 retry — supersedes v17 pending visual gates above

User explicitly asked to proceed with an uninterrupted final UI check after the native controller reported concurrent user changes. Retry succeeded:

- **Installed v18** Widgets screen visually inspected: equal 136pt card surfaces, live CPU/RAM/history, retained calendar/media, footer editor button; Korean `재생 대기 중` displayed.
- **Installed v18** widget editor popover visually inspected: dark native surface, legible text/pickers/buttons. Actual move-down then move-up restoration succeeded. No default layout reset performed.
- **Installed v18** All Tools library visually inspected: dark surface, readable bilingual-localized card titles, two-column layout and search field. The previous white-background/white-text bug is repaired. v17 same search engine had already passed actual `emoji` lookup → Emoji selection → Korean `로켓` lookup → Copy → Command-V yielding `🚀` in the search field. The final v18 Enter-selection retry encountered `elementHasNoFrame`; refreshed state returned to user Settings, so that particular keyboard selection is not claimed as verified. Search matching itself passes automated regression tests.
- Final **284 tests / 0 failures**: `build/PolishEvidence-20261029/tests-v18.log`, TEST SUCCEEDED. Final Release: `release-v18.log`, BUILD SUCCEEDED. Installer: `install-v18.log`, exit 0.
- Final revision **Notchie-Droppy-20261029-v18**; installed and Release UUID **82A95874-1128-3325-9F31-33309DE87CC9**; canonical PID observed **74064**. Post-launch strict signature verification exit **0**.
- Earlier shared-engine fixture OCR, actual PNG/PDF Save and alpha/page inspection remain valid; these engines were unchanged in v17/v18. Individual clipboard favorite physical-copy testing, every accessibility/Space/display combination and new Mac hardware/system Island remain separate, unverified gates.

## Clipboard reference redesign — Notchie-Clipboard-20261029-v19

- Reference: user-attached compact black clipboard list inspected directly. Lazyweb tool discovery returned no tools; no new screenshot database evidence claimed. The attachment temporary file later disappeared, so it was not copied into the app or report. Local design rationale: `.lazyweb/design-improve/clipboard-2026-10-29/report.html`.
- New UI reuses existing snippet and note engines: Notes / Clipboard / Starred switcher, capsule search, text/link/code filters, sort, thin row separators, source/time column, whole-row copy feedback, right-click preview/actions and settings popover. Clipboard receives extra height; other tools retain prior geometry. Favorites-only/type/sort persist. Clear history requires a confirmation count and preserves favorites (not executed on personal data).
- Optional `sourceAppName` is backward-compatible with v1 storage. Old source values remain absent. Automatic capture records the foreground app observed at capture time; this can differ from the original copying app, disclosed in UI. Concealed/transient/generated pasteboard items remain excluded. No auto-capture preference or permissions enabled by this change.
- **Final full app suite: 289 tests / 0 failures**, `build/ClipboardEvidence-20261029/tests-delivery.log`, TEST SUCCEEDED. Five new tests cover classification/bounded previews without mutating copied text; source/type/star/sort composition; star/source recapture + clear preservation + disk roundtrip; concealed pasteboard exclusion; clipboard-only geometry expansion and restoration. Existing geometry expectation updated for the explicit clip page height.
- Initial compile failed on SwiftUI ShapeStyle vs Color ternary; corrected to explicit Color and retained failed logs. Final Release `release-delivery.log`: BUILD SUCCEEDED, DynamicNotch scheme, CODE_SIGNING_ALLOWED=NO.
- Installed via `scripts/install-local.sh`; `install-delivery.log` exit 0. Installed/Release executable UUID **A6E41D0F-5958-3137-8AFF-51B75A6A599A** matches. Installed revision **Notchie-Clipboard-20261029-v19**; canonical PID observed **6498**. Strict post-launch codesign verification exit **0**.
- Actual first v19 UI: enlarged clipboard layout, segmented header/search/empty state visually inspected. Search for an existing public verification emoji reduced the list to one row. Row click showed `복사됨`; independent readback printed only `Clipboard copy matches test emoji: true`. Existing contents were not dumped into a report or deleted. A synthetic input/copy attempt through native keys did not populate the clipboard; manual Capture correctly reported no text at that time. Do not claim that initial capture attempt passed.
- Final time-format-only correction explicitly formats Korean/English relative time and passed the final complete suite/build/install. Installed app relaunched; final new-format row timing was not visually re-exercised because live desktop state kept changing. Filter/favorite UI controls were observed, but the full physical favorite/filter/Return-copy/preview flows are not certified. Their model behavior is covered above. No new full-hardware/accessibility claims.

## Simplified Nook home — Notchie-Nook-20261029-v20

- User reference inspected directly; Lazyweb tool discovery empty. Lower Home / Tray / Widgets dock removed from the shared hub. Top Nook / Tray / Tools retained. Old widget preferences/engines not deleted.
- Nook now has only existing media, existing calendar and a circular preview-only Mirror pod, separated by thin dividers. Weather/solar card, task chips and productivity-hub shortcuts removed from Nook home. Shared card chrome suppressed for this home only. Footer's 36pt height reclaimed; clipboard retains its larger content area with the corresponding height adjustment.
- Mirror uses video preview only; no microphone, recording output, face enrollment or recognition. Only explicit click can request/start camera access. Nook exit invalidates permission response and dismantles/stops capture on a serial queue; detached views ignore late completion callbacks. Tests do not start/request a camera.
- **Full suite: 290 tests / 0 failures**, `build/NookEvidence-20261029/tests.log`, TEST SUCCEEDED. Added regression covers permission-response cancellation, superseded requests, denied access and one-shot consumption. Existing shared geometry assertions updated for removed footer.
- Final Release `build/NookEvidence-20261029/release-final.log`: BUILD SUCCEEDED, DynamicNotch.xcodeproj / DynamicNotch / Release / CODE_SIGNING_ALLOWED=NO. Installer `install.log` exit 0.
- Installed at `/Applications/DynamicNotch.app`, revision **Notchie-Nook-20261029-v20**. Installed/Release UUID **A35CB410-41DD-3D67-91AF-E1786B3ED460** matches. Canonical process observed PID **9771**. Strict post-launch signature check exit **0**.
- Installed UI visually checked: active Nook, media | week/calendar/event | circular Mirror arrangement, no weather/tasks shortcut and no lower page dock, reduced height with no observed clipping. Existing actual calendar contents were not saved in evidence files. AX booleans verified `bottomDockRemoved=true`, `mirrorControlPresent=true`, `nookHomePresent=true`, `productivityShortcutRemoved=true`.
- Native desktop state changes interrupted earlier navigation attempts; fresh state + closing Settings eventually exposed the final actual notch and screenshot. No final UI-pending claim for this home layout.
- **Limits:** Mirror button remained off during verification; no camera permission granted and no camera/face image captured. Actual camera availability/preview and physical start/stop/hotplug remain unverified. All hardware/security gates from previous checkpoints remain separate.

### Centered hover reveal — 2026-10-29 v21
- [x] Horizontal midpoint pinned during shell resizing; destination-sized centered content prevents row reflow. Expanded reveal uses a subtle centered scale/fade/blur, with damped expansion/collapse.
- [x] DynamicNotchTests 290/290 passed; final Release build succeeded; installed with scripts/install-local.sh.
- [x] Canonical /Applications/DynamicNotch.app launched (PID 12034), revision Notchie-CenteredHover-20261029-v21, UUID 9D6BBFF6-1AE3-3427-A9D7-EE108166BC9B; strict post-launch signature verification passed. Compact screenshot observed centered shell.
- [ ] Continuous physical pointer-hover animation remains unverified: native tool exposes click/drag, not hover/move or frame capture; Settings quick-tools activation did not produce a verifiable expanded overlay in this inspection. Static screenshot is not motion verification.
Evidence: build/HoverEvidence-20261029/{tests.log,release-final.log,install.log} in /Users/davidkang/DynamicNotch.

### Nook calendar reference layout — 2026-10-29 v22
- [x] Removed home Mirror pod. Calendar takes remaining width next to media, large month beside the seven-date strip, blue selected numerals, muted weekend dates and event dots, centered selected-day agenda/empty state.
- [x] Existing EventKit data/privacy-aware event titles and meeting actions retained; no permissions requested.
- [x] 290/290 tests, Release build and scripts/install-local.sh pass. Canonical app revision Notchie-Calendar-20261029-v22, UUID DFB2B8C7-D14A-3527-B66B-D0473AC9EC30, running PID 12962; strict signature verified after launch.
- [x] Actual installed Nook screenshot/AX confirmed wide calendar and no Mirror control. Selected Oct 31: selected trait and empty-day state observed; month button restored Oct 29 today. No clipping observed at current display size.
Evidence: /Users/davidkang/DynamicNotch/build/CalendarEvidence-20261029/{release.log,tests.log,install.log}. No private calendar screenshot persisted to repository.

### Standard macOS App Icon grid sizing — 2026-10-29 v24
- [x] Conformed all application icon assets to Apple's macOS Human Interface Guidelines (macOS Big Sur+):
  - Canvas: 1024×1024 pt (and downscaled proportional sizes).
  - Squircle body: 824×824 pt (80.5% scale ratio) centered at (100, 100) with 100 pt margins.
  - Dual native drop shadows: key shadow blur 30px, y -18px, opacity 0.25; ambient shadow blur 14px, y -4px, opacity 0.16.
  - Re-rendered all 20 assets in `AppIcon.appiconset`, `NotchieIconDark`, `NotchieIconLight`, `logo`, `simplifiedLogo`, and docs assets. Master full-bleed artwork backed up to `Design/AppIconOriginal-FullBleed/`.
  - Removed redundant SwiftUI `.shadow(...)` modifiers in `AppearanceSettingsView.swift` to prevent double-shadowing.
- [x] DynamicNotchTests: 291/291 passed (added automated regression in `AlcoveSettingsExtensionTests.swift` enforcing 824px squircle width between 815...835 and 100px margins).
- [x] Final Release build succeeded: `build/DynamicNotch-release/Build/Products/Release/DynamicNotch.app`. Built `AppIcon.icns` verified: body 823×822 pt, ratio 0.804.
- [x] Installed to `/Applications/DynamicNotch.app` via `scripts/install-local.sh`; strict ad-hoc signature verification passed. Release and installed UUID **9E237F2C-9102-3812-97D7-0DBB666362C5** match.
- [x] Canonical runtime verification: `/Applications/DynamicNotch.app` running (PID 37458); `NSWorkspace.runningApplications` runtime `applicationIconImage` measured at body 824×824 pt (ratio 0.805), perfectly matching macOS Dock standards and other running apps (Safari, Notes, Calendar, Slack, ChatGPT).

### Settings cleanup and lock authentication repair — 2026-10-29 v23
- [x] Visible sidebar groups; common card spacing/borders simplified; duplicate General haptic/media controls removed (canonical controls retained). Permissions integrated under Privacy; lock-screen appearance integrated into Lock & Authentication beside face/app privacy, legacy saved/deep-link routes retained.
- [x] Persisted password-rejection state now appears after relaunch. Setup/recovery shown before collapsed animation preview. Installed screenshot and AX verified General, Face authentication recovery, Lock Screen tab and Privacy > Permissions navigation; no grants/enrollment/credential replacement/feature enablement performed.
- [x] Retired always-failing lock-screen scanner path replaced with real opt-in engine retry. Wake scanning remains engine-owned. Explicit retry never rearms an already attempted password submission.
- [x] Unknown lock state preserves attempt budget; unknown confirmation distinguished from rejection; camera contention does not consume face retries; cancellation rechecked after inference; synthetic events clear inherited shortcut modifiers. Polling/cooldowns shortened, frame cadence 15 fps, strict thresholds/liveness/consecutive-frame checks/camera warmup retained.
- [x] Final app tests 291/291; engine tests 56/56 and core tests 42/42 (98 total) passed. Final Release/install and strict post-launch signature pass. Revision Notchie-SettingsAuth-20261029-v23, installed/Release UUID D63AD786-5216-315F-A3FE-DED0790D82C9, canonical process PID 20652.
- [ ] User confirmed affected flow is Mac lock-screen face unlock. Prior saved events show successful matches/unlocks then password rejection and engine stop. Current persisted rejection requires the user to re-save their password and explicitly enable, then manually lock/unlock. No actual lock/unlock round trip or Face ID-equivalent latency claimed. User handoff requested; awaiting completion.
Evidence: /Users/davidkang/DynamicNotch/build/SettingsAuthEvidence-20261029/{ARCHITECTURE.md,app-tests-final2.log,engine-tests-verified.log,release-final.log,install.log}. An initial shared build-directory lock was resolved by isolated derived-data directories; a stale expected test result was updated for the safer unknown-state behavior and re-run successfully.

### Lock verification follow-up — 2026-10-29
- Read-only persisted-state refresh: lockScreenNeedsPassword=false, enabled.v1=false. Password recovery has already cleared; do not ask the user to replace it again. User only needs to enable and manually lock for the remaining verification.
- Additional events.log evidence: engine start 14:06:51; scanning 14:07:10 -> unlocked 14:07:12 (5 face frames, strict matching, liveness passed); engine stop 14:09:06. Log does not record executable revision, so do not attribute that success or coarse ~2-second interval to v23. Current app remains signed v23; process has since restarted (PID 60480).
- Hardware confirmation and latency for the installed revision remain pending user action. This supersedes the preceding current-password-rejection status, not its historical diagnosis.

### Physical failure follow-up and v24 delivery repair — 2026-10-29
- [!] User explicitly tested v23 Mac lock and reported failure. Engine events show scanning at 20:16:35 and password rejection/engine stop at 20:16:43. OS loginwindow confirms password field first responder, submission at 20:16:37.710, and INCORRECT password at 20:16:40.555. Previous hardware verification remains failed, not complete.
- [x] v24 explicit password Save verifies current Mac account via OpenDirectory before encrypted persistence. Validation failure preserves prior saved credential and rejection state. No user password was read/typed/stored by automation.
- [x] Keyboard event plan supplies current ASCII-capable layout's real key codes and required modifiers alongside Unicode; no arbitrary US layout assumption, automatic input-source changes or inherited Command/Control. Added local phase/revision logs without password contents or length.
- [x] 297/297 app tests and 58 engine + 42 core tests passed. Release/install and post-launch strict signature pass. Installed revision Notchie-PasswordDelivery-20261029-v24; UUID 69D56F0E-090F-3A2A-90C8-C164B6ED1486; PID 74529.
- [ ] v24 physical lock test pending. Installed settings opened on face authentication; user asked to explicitly Save/verify their password, enable and manually lock once. Neither a correct saved password nor actual unlock success inferred from test/build/install.
Evidence: build/SettingsAuthEvidence-20261029/{v24-app-tests.log,v24-engine-final.log,v24-release.log,v24-install.log,ARCHITECTURE.md}.

### v24 physical failure isolated; v25 thread fix in progress — 2026-10-29
- User confirmed explicit password Save succeeded but manual Mac lock did not unlock. v24 revision-stamped log: face matched in 2.258 s (strict, 2 accepted frames), password submission started, then no completion.
- Fresh diagnostic report DynamicNotch-2026-10-29-202609.ips identifies SIGTRAP / _dispatch_assert_queue_fail inside TSMCurrentAsciiCapableKeyboardLayoutInputSourceRefCreate, called by KeystrokeInjector.keyboardLayout on verification worker. This is a v24 regression, not a wrong-password result. No matching loginwindow incorrect-password entry during this attempt.
- Main checkout now routes only the read-only Carbon keyboard-layout snapshot to DispatchQueue.main.sync; typing remains on the worker. Added production-path regression from Task.detached; it passes (59 engine + 42 core tests).
- Current password-rejection flag false, explicit enabled preference true. Do not require password re-save or reset credentials for this thread fix.
- Combined calendar worktree/app builds must include this auth fix in Vendor/HeyMac/Sources/HeyMacEngine/KeystrokeInjector.swift. Main checkout v25 build/tests in progress; avoid replacing the final installed artifact with older v24 auth code.

### v25 installed, physical retry pending — 2026-10-29
- [x] Production keyboard-layout lookup regression from a detached verification worker passes; all 59 engine + 42 core and 297 app tests pass. Release/install/post-launch strict signature pass.
- Installed revision Notchie-AuthThreadFix-20261029-v25, UUID 69F05CCC-5E81-3DF4-8A32-6F6CAF01DEC5, PID 76657. Revision-stamped engine-start log at 20:30:03 confirms resumed existing explicit opt-in. No credentials replaced or permission/enrollment changes.
- [ ] Awaiting user's manual lock test on v25; do not request password re-save for this fix. v24 physical attempt remains failed (crash), not fixed by build results alone.
- Concurrent calendar chat (Droppy 기능과 UI/UX 적용 (2)) installed DayCalendar-v33 at 20:27:12; this auth chat subsequently installed v25. Cross-chat coordination authorization requested from user to avoid alternating app replacements and to carry this main-thread fix into combined calendar build. No message sent without authorization.
Evidence: /Users/davidkang/DynamicNotch/build/AuthThreadEvidence-20261029/{engine-tests.log,app-tests.log,release.log,install.log}; system crash report DynamicNotch-2026-10-29-202609.ips.

### v25 physical Mac unlock verified — 2026-10-29 20:31 KST
- [x] User explicitly reports manual lock -> face unlock SUCCESS on v25. Same revision's engine log: scanning 20:30:58; live strict match at 20:31:02 in 3.187s (2 accepted frames, liveness 1.000); password submission completed in 0.221s; macOS unlocked confirmed at 20:31:03. No crash/second submission occurred.
- Physical functionality is now verified for this one Mac/session. End-to-end coarse interval about 4–5 seconds from second-resolution event timestamps; measured face + typing phases 3.408s plus confirmation. Do not claim Face ID-equivalent speed, broader lighting/device reliability, or a performance distribution from one trial.
- Password was already user-verified/saved; no re-save was needed for the thread fix. Final functional revision remains Notchie-AuthThreadFix-20261029-v25.
- Cross-chat coordination question still pending; do not send messages without explicit user authorization. Calendar combined build must carry the TIS main-thread fix before replacing the verified app.

### v35 face-unlock speed work — 2026-10-29 (in progress)
- User requests Face ID-like response and supplies Notchy passive-liveness reference. Verified vendor help says matched frames + passive evidence, and acknowledges video replay limitations; current strict ArcFace + MiniFASNet frame acceptance retained rather than replacing it with eye openness alone.
- Release fixture profiling: cold detect/live/embed total 0.2319s, warm totals 0.0109–0.0137s. This is model-fixture inference, not camera/unlock latency. Prior actual v25 face check was 3.187s, so isolate camera/session costs.
- Prepare AVCapture session and dummy model inference before enabled engine starts, without starting camera stream or using enrolled identity. Maintain resolution, 400ms warmup, thresholds, anti-spoof and consecutive frames.
- Camera stop immediately invalidates frame epoch and clears frame storage; hardware stop runs on serial lifecycle queue outside password critical path. Start/prepare/stop command submission serialized; new start waits behind prior stop. Old in-flight conversions cannot publish into a new session.
- Face verification logs now split camera start, first frame and inference time for physical comparison.
- Build integration snapshot: /Users/davidkang/DynamicNotch/build/FaceSpeedIntegrated copied latest v34 worktree source without modifying other chat files, then overlaid only auth/backend changes. Preserve day-calendar and saved-player-tint work in final installed app. Primary checkout remains auth implementation base.

### Face-speed backend validated; combined install delegated by authorized coordination — 2026-10-29
- [x] Final auth speed sources: engine/core 61+43 tests passed; v34 integration snapshot app tests 303 passed; final Release passed. Fixture inference baseline cold 0.2319s, warm 0.0109–0.0137s; no hardware speed claim from fixture measurements.
- [x] Verified other worktree's CameraCapture, FaceVerifier, HeyMacRuntime, KeystrokeInjector and adapter controller byte-match final primary auth changes (including lifecycle command lock and main-thread keyboard lookup).
- [x] Read direct human approval in Droppy 기능과 UI/UX 적용 (2): “Yes, coordinate the install.” Sent narrow install coordination message: this auth chat holds all /Applications installs; AI/fluid-motion chat owns one combined final install and sends revision/UUID/signature handoff. Do not roll back current calendar/progress/AI changes with older snapshot.
- [ ] Await combined install handoff, then user manual lock test to compare measured cameraStart/firstFrame/inference and total face time against prior v25 3.187s. No password replacement, enrollment, permission grants or opt-in changes needed.
Evidence: build/FaceSpeedEvidence-20261029/{baseline.log,engine-verified.log,app-tests-final.log,release-final.log}; integration source snapshot build/FaceSpeedIntegrated (not installed).
