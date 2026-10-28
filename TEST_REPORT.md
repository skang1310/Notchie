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
