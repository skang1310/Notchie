# App profiles, AI warnings and performance — 2026-10-30

## Features and operation

- **App profiles:** AI Usage → sliders menu → App Notch Profiles, or the existing App Rules tool. Add an installed app and choose Home/Music/Calendar, AI Usage, or Meeting Controls. Persisted separately in the existing ProductivityStorage settings, so existing JSON/hide rules migrate unchanged. Rules apply to the next notch opening; expanded, pinned and locked interactions remain stable. Leaving a profiled app restores the previous hub mode unless the user has chosen another mode. Hide rules take priority. No apps are configured automatically.
- **AI usage warning:** sliders menu → Usage warnings; default off, threshold 90%, options 70/80/90/95%. Uses the existing temporary-notch notification engine, requires no macOS notification permission. Warn once per high-usage episode/window, rearm below threshold minus five points. Latches persist across relaunch. Expanded/pinned/locked/hidden activity presentation is not interrupted. Enabled warnings refresh local data approximately every minute; disabled warnings run no background refresh loop.
- **Reset countdown:** default on, optional via sliders menu. All three existing service cards remain together. Both primary and secondary windows use their model-provided labels and reset times. Mounted visible pages tick at most every 30 seconds and refresh local records approximately every minute.

**Data limit:** existing providers primarily infer utilization/reset timing from local interaction/session records. These are local estimates, not official account-wide quota. All three cards and warnings explicitly label this. No API keys/OAuth, network requests or unofficial account scraping were introduced. An estimated reset does not guarantee the provider will accept requests. An expired window does not trigger a warning. Recorded Codex exhaustion signals remain part of the existing parser.

## Performance changes

1. Replace screenshot/recording 350ms folder polls with directory dispatch sources, short bounded partial-write retries, and a 15-second recovery poll with tolerance. Recovery rebinds replaced directories and discovers destination setting changes. Existing file recognition/callbacks are preserved; user files are not deleted.
2. Read JSONL in 64KiB blocks, keeping at most a 4MiB input line. Skip oversized/malformed lines and resume at the next newline. Project records to the fields actually used, retaining a 512-character display snippet and the first model record. Legacy history/session-index tails stay at 20/25 records. Larger raw transcript text is neither cached nor exported.
3. Cache parsed records by path, inode, byte size, modification timestamp and tail mode. Cache limits: 128 entries / 8MiB estimated cost. A changed file is reparsed; unchanged files reuse parsed records. Files changed while reading are not cached. SQLite state remains queried live. Refresh coalescing is retained and visible/background consumers share a 45-second freshness guard.
4. Window occlusion reader pauses view-owned schedules when NSPanel is ordered out, including AI, music progress, lyrics, stopwatch, compact/expanded timers and expanded downloads. Timer completion, recording detection and explicitly enabled monitoring continue normally. A shared visibility-aware timeline reuses each view's existing cadence.
5. Support thumbnails: file identity/size/subsecond modification and actual redaction geometry participate in the cache key. Duplicate requests share work; at most eight decoder requests are admitted and decoding remains serialized by the existing actor. Others wait cancellably. Pixel size capped at 3000; cache costs include estimated decoded pixels. Views retain decoded NSImage rather than decoding PNG again on every render. Previous displayed images clear when masks change; changed-during-decode results are discarded.

Cache budgets are NSCache advisory eviction limits, not hard process-memory guarantees. Parser arrays, image processing and model assets still consume memory. No general CPU/energy percentage or physical face-unlock latency claim follows from these source changes.

## Validation

- Whole-app XCTest: 330 tests, zero failures, including eight new regressions for profile/settings persistence, hide precedence, alert hysteresis and stale/expired suppression, block boundaries/Unicode/partial appends, cached unchanged logs and file replacement, oversized-line recovery, real temp-directory dispatch events/rebinding, redaction invalidation and thumbnail queue completion.
- Final-source whole-app rerun: 330 tests, zero failures (`tests-final2.log`). Initial generic timeline build error was corrected by making the context type independent of its content generic. Failed build logs retained.
- UI/runtime/build/install results are appended after validation. Evidence: `build/ProfilesPerformanceEvidence-20261030/`.

## Installed artifact verification

- Release build and `scripts/install-local.sh` passed. Canonical installed revision `Notchie-ProfilesPerformance-20261030-v38`; UUID `96FCE230-FB55-3237-A9B6-97652EC174C7` matches Release. Strict deep signature verified after launch. Process observed at `/Applications/DynamicNotch.app/Contents/MacOS/DynamicNotch`, PID 66660. No fatal/assertion/uncaught-exception markers found in this launch's captured stdout/stderr (not a comprehensive crash audit).
- Logical regular-file size excluding symlinks: prior v37 **34,775,465 bytes**, v38 **34,875,362 bytes**, increase **99,897 bytes**. Existing stripped Release settings retained. No user data, caches or backups were removed.
- Native UI inspection returned a locked-Mac blocker. Actual installed profile selection, threshold-menu interaction, visual countdown layout, warning presentation and hide/show resume remain unverified. No automatic unlock, authentication changes or credential handling was performed. Unit/build/install success does not complete those interaction gates.
