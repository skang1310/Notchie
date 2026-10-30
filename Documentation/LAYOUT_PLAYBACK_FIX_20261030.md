# AI viewport and playback delivery — v43 / 2026-10-30

User reported top/bottom clipping in the actual AI notch (attached screenshot) and non-working Now Playing controls. Installed baseline was v42; the feature-removal work delegated to Gemini had not appeared in this checkout. This patch addresses only these two bugs and retains existing features.

## AI clipping

The fixed hub geometry contained a content-sized VStack. Quota windows, unavailable/loading/stale labels and long model names could increase that VStack's minimum height beyond the allocated region, pushing the outer header/footer into the notch mask. Only the Antigravity quota subsection previously scrolled, leaving the rest of its card and the other cards able to grow.

AIUsageNotchView now takes the actual available GeometryReader size. A shared metrics type reserves explicit control/footer heights, spacing and padding, divides the remaining width into three equal provider columns, and bounds their height. Each complete card scrolls inside its own clipped viewport. This removes nested Antigravity-only scrolling and prevents loading/result transitions from altering the enclosing hub's minimum size. Unknown/loading providers retain their column slots. Public default initialization still uses the existing shared service; internal injection allows isolated layout regression tests without live providers or permission prompts. Small-width quota labels remain single-line.

## Media commands

Basic play/pause/next/previous commands previously skipped the existing application bridge. A truthy return from the private global MediaRemote API only indicated acceptance and could leave playback unchanged. Bridge commands for advanced actions also ran alongside global commands, and their async errors were swallowed.

Commands now serialize on the existing command owner, try the supported source application first, and issue the global fallback only after failure/unsupported routing. App acknowledgement is awaited; successful app delivery never causes a second global toggle. Music and Spotify scripts use an explicit two-second timeout and existing Automation authorization is checked without prompting. YouTube Music HTTP failures now return a failure result rather than unconditional success.

When Music Automation authorization is absent, a bounded fallback uses already-granted Accessibility access: exact native Music mini-player transport identifiers, state-aware idempotent play/pause, at most three windows/eight hundred visited nodes, one-second traversal budget, short AX messaging timeout. No app activation, global UI search or new permission request. This identifier-based integration is best effort, not a public Apple playback API. The upstream global MediaRemote private API remains a fallback and is not described as public support. The Perl adapter path now discards output rather than leaving unread pipes and has a three-second process deadline with owned-child cleanup.

## Verification

Seven new tests cover fixed three-column viewport budgets, loaded/unavailable provider results in a 190pt NSHostingView, nonnegative tiny viewport geometry, one-route-only acknowledgement/fallback ordering, and English/Korean Music transport state mapping. Full suite passed 383 tests; Release build succeeded. Existing media ViewModel tests retain command mapping, optimistic state and seek coverage. Installed UI and actual playback checks are recorded in the authoritative trackers and below; tests/build are not a substitute for observing Music playback.
