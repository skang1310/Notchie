# DynamicNotch security review — 2026-10-28

## Scope and conclusion

Reviewed upstream ec927e198550fd6c731b9135c159736c8ab0e0cf (1.6.3), the local patch, the user's Xcode checkout at /Users/davidkang/DynamicNotch, and the installed bundle identity. Source search covered 426 Swift files, networking, child processes, account credentials, persistence, protected-folder reads, updater behavior, permissions and bundled helper linkage. No confirmed spyware, credential exfiltration, command-and-control, hidden persistence or analytics implementation was found in the reviewed source. This is a scoped code review, not proof that all executable code is benign.

The installed original developer-signed app differed from the locally patched source. Its signing metadata identified upstream team WZHZ6LB2F6; the user's Xcode project uses their own team AXCMBMA992. Preserve that project setting. The original bundle's strict verification failed on resource-fork/Finder metadata in Sparkle; this alone does not establish malware.

## Findings and remediation

| Severity | Existing behavior | Change |
|---|---|---|
| High | FaceIDKeychainService requested/verified/stored the Mac login password; FaceIDService typed the password and Return into the lock screen. Camera face presence and simulated fallback were insufficient identity verification. | Removed credential service, password entry/enrollment UI, OpenDirectory verification and keyboard injection. Face scan compatibility stub always fails. Lock-screen wake path is gated off. No user Keychain entries were read or deleted by this review. |
| Medium privacy | IP geolocation automatically contacted api.country.is, ipapi.co and ipwho.is. Recipients necessarily see the public IP. | All IP lookup requires an explicit off-by-default Privacy preference. |
| Medium privacy | Lyrics providers transmit current artist/title/album to lrclib.net and artist/title to api.lyrics.ovh. | Network provider entry points require an off-by-default Privacy preference. Existing locally available lyrics remain separate. |
| Medium privacy | Folder download monitor watched six standard folders; browser metadata discovery could inspect browser profiles. | Default monitoring off, no automatic folder list; user-selected folder bookmark only. Browser metadata separately opt-in. |
| Medium privacy | Full Disk Access detection probed protected system databases; background HUD could request Accessibility. | Local builds do not probe those databases. Accessibility request remains an explicit user action. |
| Low privacy | YouTube Music remote uses HTTP on localhost:26538 and an application authentication endpoint. | Local remote auth/commands require explicit opt-in. No external remote server was found. |
| Integrity | Sparkle could replace the custom artifact with upstream. | Local build marker disables Sparkle update checks/downloads; Settings explains this. |

Opt-outs prevent new provider requests, but do not recall an already completed request or guarantee cancellation of an in-flight one. Do not describe ordinary declared provider traffic as proven malware.

## Network and process inventory

- Optional lyrics: lrclib.net/api; api.lyrics.ovh/v1. Track metadata only at reviewed call sites.
- Optional VPN/IP country: api.country.is, ipapi.co/json, ipwho.is. Public IP visible to service.
- Optional local music: localhost:26538; /auth/boringNotch is an upstream compatibility identifier, not evidence of a remote C2.
- Sparkle update configuration/framework retained but inactive for the marked local build.
- About/Support/Onboarding links open official GitHub, Telegram, developer, Boosty and DonationAlerts pages only after user actions.
- Reviewed child-process calls include fixed-argument scutil/pmset/system log commands, a bundled media adapter Perl bridge, screenshot helpers and relaunch. No arbitrary downloaded script execution or hidden LaunchAgent/cron installer was found. Explicit login launch remains user-controlled and defaults off for fresh local builds.

## Residual trust boundaries

Upstream includes precompiled MediaRemoteAdapter.framework and test helper code, BSD-licensed to Jonas van den Berg, and Sparkle dependencies. Framework linkage is Foundation/AppKit/JavaScriptCore/UniformTypeIdentifiers/ImageIO/CoreFoundation/libSystem. No NSURLSession/socket/connect/CFNetwork/exec/posix_spawn/SecItem undefined-symbol hit was found in the inspected adapter; this limited static check cannot rule out runtime resolution or all malicious behavior. Binary hashes are recorded separately in the checkpoint evidence. No reproducible source rebuild of that framework or full packet-capture sandbox investigation was performed.

Upstream uses MediaRemote, DisplayServices/SkyLight and other system-specific/private integrations. Existing functionality is preserved; this patch adds no private API. Camera mirror, calendar, tray, clipboard or system monitoring features may legitimately require their own permissions when used. This review neither grants those permissions nor promises removal of macOS consent dialogs for intentionally invoked protected features.

The new Quick Tools use local atomic JSON notes, ContinuousClock, public IOPM assertions, and NSColorSampler. They make no network requests. Keep Awake acquires power assertions only after a button press and releases them on expiry/stop/normal quit. Color sampling occurs only on request; clipboard writing occurs only on Copy. Notes are not encrypted; the file is user-readable only (0600).

## Verification

See ../TEST_REPORT.md for current commands, failures corrected, pass counts, build/sign/install and runtime evidence. Automated tests cover denied network entry, always-failing Face Unlock, privacy persistence and tool lifecycle. Hardware lock/unlock, camera, full traffic analysis and every inherited feature are not verified by those tests.


## Additional findings during productivity work

A whole-app test sample exposed an inherited automatic screenshot monitor scanning Desktop and changing macOS screenshot save/thumbnail preferences (including a SystemUIServer restart). This behavior was not covered by the initial download-monitor fix. The final local build disables that interception and explains it in screen capture settings; tests also skip it. No guessing/resetting of prior OS preferences was attempted. Screen-recording activity monitoring remains separate.

Legacy tests used live UserDefaults and real tray storage, and asynchronous download expectations could fire again after their test ended. The final test command uses a separate app bundle ID, test tray storage uses a per-process temporary directory, queued download publications are invalidated on stop/restart, and expectations complete once. The observed Korean Settings language affected by an earlier unisolated run was restored through the UI. Other historical preference values were not guessed. The final full suite passed 244/244; see latest TEST_REPORT.md for exact verification limits.

The new job runner allows only explicit xcodebuild/shasum executions with argument arrays, not shell strings; selected project scripts are disclosed before execution. No added cloud/analytics endpoint, background clipboard listener, login service or private framework dependency. Clipboard snippets are explicit local captures and exclude the concealed pasteboard type; text without such a marker may still be sensitive, so storage is disclosed as unencrypted. App display rules and Carbon hotkeys run only while this app runs.
