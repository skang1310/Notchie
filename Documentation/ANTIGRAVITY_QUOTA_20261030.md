# Antigravity quota — 2026-10-30 v41

The third AI card previously used Gemini/Antigravity session logs but could not report allowance. The user requested Antigravity usage. The persisted provider key remains `gemini` to preserve existing alert/settings state; English/Korean UI now names the service Antigravity. Existing local session discovery is retained separately from quota.

## Read-only local IDE integration

The installed Antigravity 2.28.2 language server was inspected and its `RetrieveUserQuotaSummary` RPC successfully returned actual grouped quota. The running executable must match `/Applications/Antigravity.app/Contents/Resources/bin/language_server`; only that process's ephemeral CSRF parameter and its loopback listening ports are inspected in memory. No Google OAuth files, cookies, refresh tokens, keychain records, login, purchase, prompts, or IDE settings are accessed or modified. Notchie does not launch or restart Antigravity. The existing IDE must be running and logged in.

This is a **private local IDE protocol**, not a documented public Google API. Official CLI `/usage` and statusline documentation confirm separate quota buckets exist, but do not establish support/stability of this local RPC. The IDE's existing service refreshes its own backend state; Notchie can report only the values the local service returns. No TLS validation bypass is used. Requests use HTTP exclusively on 127.0.0.1, the exact quota method, no redirects, no proxies or persistent URL cache, two-second request/three-second resource deadlines and a two-MiB response validation ceiling. Endpoint discovery commands have two-second deadlines and validate the executable, port and token format. Tokens and raw user status are neither logged nor persisted. No cloud credential forwarding occurs.

Successful snapshots and in-flight reads coalesce for ten seconds. Existing visibility/background policy is shared with the other providers: ten-second visible checks, sixty-second warnings background checks. Failures preserve the previous snapshot's original timestamp; absent/malformed data never becomes 100% available. The UI can mark that original snapshot stale. Closing the IDE is not interpreted as exhausted allowance.

## Mapping and display

The actual `response.groups[].buckets[]` schema provides group and bucket display names, `remainingFraction`, and `resetTime`. Each bucket maps to its own quota bar, retaining the actual reset date. Examples observed during verification were Gemini Models (weekly/five-hour), Claude and GPT models (weekly/five-hour), and Gemini 4 Argon (weekly). These pools are independent of the user's company Claude Team seat and standalone Codex subscription. No minimum, sum, session-count estimate, or guessed plan is substituted. Missing fractions, booleans, out-of-range values, invalid dates and malformed schemas are rejected. Explicit zero is a valid exhausted quota. Stable group+bucket IDs deduplicate identical rows; all accepted buckets participate in warnings.

The existing three-card screen remains. The third card is Antigravity, with an Antigravity-specific local-query source label. Additional buckets extend the shared quota window representation without changing other providers. Long provider header omits unrelated activity age. Unavailable state instructs the user to open/sign in to Antigravity. No new permissions or persistent setting was introduced.

## Verification

Five regression tests cover grouped schema, independent zero/exhausted and fractional quotas, all-window warning gates, timestamp freshness, invalid/missing data, duplicate buckets, trusted process/port/token parsing, actual URLSession POST method/header/path using a controlled URLProtocol, request coalescing and failed-read timestamp preservation. Existing provider-name expectations were updated for the requested rename. Initial tests retained in evidence failed only the two old Gemini name expectations, which were then corrected.

Official documentation consulted: https://antigravity.google/docs/cli/commands/usage and https://antigravity.google/docs/cli/statusline. Local successful smoke read is separate evidence for the private RPC.

The Antigravity quota area is capped at 118pt and scrolls vertically, so five independent buckets do not exceed the existing 260/270pt notch presentation. A bilingual scroll hint exposes the additional rows. Provider cards align at the top.

### Antigravity quota v41 — completed 2026-10-30
- Final 362 tests passed, Release build succeeded, installed and launched `/Applications/DynamicNotch.app` PID39709, UUID `0978FD1D-3A77-3879-A994-2307E177CE38` matching final Release artifact; strict deep codesign verification passed. Logs: `build/AntigravityQuotaEvidence-20261030/{tests-final2,release-final,install-final}.log`.
- Installed Settings > Tray > AI verified via AX and screenshot: Antigravity local-query timestamp, independent Gemini weekly/five-hour, Claude/GPT weekly/five-hour and Argon weekly values displayed; scrolled to the final Argon bucket, then restored scroll to top. At observation Gemini remaining57%/72%, Claude/GPT50%/0%, Argon~1%; these are timestamp-specific observations, not permanent live values.
- Fixed 118pt scrolling quota region avoids expanding the existing notch height; all three card headers align at top. Settings UI/scroll behavior verified; no claim of separately testing every physical display's notch interaction. Private IDE protocol and requirement to keep Antigravity running/logged in documented.
