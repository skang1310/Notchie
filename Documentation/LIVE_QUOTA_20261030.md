# Live quota refresh — v40 / 2026-10-30

## Codex: server reads instead of waiting for local activity

The installed Codex CLI supports the official app-server initialization handshake and `account/rateLimits/read`. A live smoke read with the user's existing Codex authentication succeeded. No credentials are copied into Notchie, no login is started, no threads/turns are created and no quota-reset or credit actions are exposed.

The app starts its own stdio child only for an active UI/background-alert consumer. Native installed npm/Homebrew Codex locations are discovered; no CLI is downloaded or bundled. The child receives only initialize, initialized and account/rateLimits/read. Output is bounded; requests have eight-second deadlines; duplicate/in-flight requests and successful results within ten seconds coalesce. Transport shutdown resumes pending callers, closes pipes and terminates only its own child, with a bounded kill fallback. Restart epochs prevent stale completions from replacing a new connection.

Visible AI screens check quota every ten seconds. Local activity/log scanning retains a separate approximately minute-long cadence. With usage warnings enabled, background checks remain every 60 seconds; disabling warnings and closing the last AI view releases the child. Actual server completion time is recorded. Failed reads retain the previous real snapshot and show failure/retry state; they never renew its age or manufacture zero usage. Live results older than two minutes are stale. Legacy recorded quota fallback stays explicitly distinguished.

Source: https://learn.chatgpt.com/docs/app-server (`initialize`, `initialized`, `account/rateLimits/read`, multi-bucket `rateLimitsByLimitId`). Installed CLI direct smoke query succeeded; a current-account tool comparison later matched installed UI primary/weekly values (19% / 81% used at that comparison, not permanent current values).

## Claude: my company Team allowance

The user requested the allowance of their own company Team seat, not team-wide analytics. The company's existing Chrome Team Usage page was inspected. Claude Code was not logged in, so no CLI-based quota/account inference was used. The actual Team page first showed 18%/12% used; after a later fresh page load a new session showed 4%/19%. These are observations at different times, not contradictory cached records.

Connection is an explicit persisted toggle in AI Usage Settings: **Read my Claude Team usage page**. It uses already-granted Accessibility access; never requests access automatically. The bounded background reader visits only Chrome windows and then only an https://claude.ai Usage-settings web area. It rejects ordinary chat URLs, other sites, non-Team plans and unrelated analytics pages. It reads the displayed current-session/all-model percentages and reset labels. Missing weekly quota remains missing. Korean and English clock/weekday labels are parsed in the current calendar; a passed session time cannot become an invented tomorrow reset. Reads are capped by node count, windows and a 1.5-second deadline.

Snapshots contain quota fields/scope/time only. No cookies, passwords, OAuth tokens, email identity, chat transcripts or admin keys are collected. The code does not navigate or reload Chrome automatically, and does not change Claude authentication. The enabled connection and latest snapshot persist. Disabling the connection hides its quota even if a prior capture finishes late.

**Important limit:** this is a periodic observation of the already-rendered Team Usage page, not a server polling API. Chrome must have that page open in a non-minimized window for new observations. If the website itself has old data, the user needs to refresh the page. Closing/changing the page does not renew the saved confirmation timestamp. No guarantee of live Team updates while the page is closed, or of server push/poll frequency, is made. The existing Open Team Usage action opens the proper page. Official Team analytics and the Claude Platform Admin API are separate; no API subscription is assumed from a Team seat.

Sources: https://support.claude.com/en/articles/9266767-what-is-the-team-plan and https://code.claude.com/docs/en/statusline (documented statusline rate-limit fields do not establish universal Team availability).

## Presentation and verification

All three services remain on one screen. Recorded, live-server and Team-screen values carry distinct source/confirmation labels. Card headline and progress fill now represent **remaining percentage**, with used percentage accessible on hover and to assistive technology. Short provider names and a compact Team badge avoid wrapping; the AI panel retains a dark backing in light settings windows for contrast. Unknown Gemini quota remains unknown.

Tests cover Team scope/URL restrictions, real percent mapping, optional weekly window, reset rollover/invalid-time rejection, opt-in persistence, live multi-bucket decoding, actual stdio handshake against a controlled mock server, read-only method sequence, caching, pending-request cancellation and child cleanup. Initial transport testing exposed that FileHandle.read(upToCount:) could wait for a full buffer on the test pipe; the implementation now uses the repository's established readiness-driven availableData pattern. Failed logs remain in evidence. Final result/install/runtime identity is recorded in the task trackers and evidence folder.

External-monitor support in the same session: Window Top Margin was disabled through installed settings (previously enabled at 18pt), persisted false, then Chrome Window > Fill applied on LG. No display resolution, arrangement, browser content or system permissions changed. The false preference is retained across app installation.

### Live AI quota v40 — completed 2026-10-30
- Installed Release `/Applications/DynamicNotch.app`, UUID `4B835DA1-E4D0-319E-8041-E485D1B513E8`, PID 36397; matches Release build UUID; deep strict codesign verified. External notchless window top-margin preference remains false.
- Final full DynamicNotchTests rerun passed (357 tests). Prior final2 run had one unrelated timed NotchViewModel restore-stack test failure; final3 full rerun passed without changing that test. Evidence: `build/LiveQuotaEvidence-20261030/tests-final3.log`, `release-final2.log`, `install-final2.log`.
- Installed Settings AI screen visibly verified: remaining-only cards, readable dark backing, Team personal quota source/time and Codex live-server source/time. At observation Claude session/weekly remaining 96%/81%, Codex 73%/17%; these are time-specific observations.
- Visible screens query every10s; warnings-only background every60s. Codex uses official read-only app-server account/rateLimits/read and existing authentication. Claude observes the already-rendered company Team Usage page in a non-minimized Chrome window; it does not guarantee fresh server data if that page is stale or closed. Gemini remains unavailable instead of fabricated. See `Documentation/LIVE_QUOTA_20261030.md`.
