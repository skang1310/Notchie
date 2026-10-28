# Ten current Mac notch apps — official-source comparison

Reviewed 2026-10-28. Public comparable usage/market-share data was not available; this is a representative ten-app comparison, not a measured popularity ranking. Features below are vendor claims from official pages, not hands-on verification of each app. Lazyweb tools were unavailable; fallback: official sites/repositories/App Store plus previously observed Alcove 1.7.7 settings.

| App | Official evidence | Relevant capabilities | DynamicNotch decision |
|---|---|---|---|
| Alcove | https://tryalcove.com/ | Live activities, gestures, HUD, lock-screen presentation | Existing engine reused; added persistent hover delay, independent dismiss/restore, quick controls. No executable/assets copied. |
| Boring Notch | https://github.com/TheBoredTeam/boring.notch | Media, calendar, file shelf, AirDrop, HUD | Already substantially present upstream; preserve modules. |
| NotchNook | https://getnotchnook.com/ | Notes, tasks, timers, meeting links, mirror, shortcuts, tray | Added local notes; preserve existing timer/calendar/tray. Meeting auto-join needs dedicated integration verification before adding. |
| Droppy | https://getdroppy.app/ and https://getdroppy.app/docs/notch | Notes, Keep Awake, files, media, clipboard, conversions, AI integrations | Added explicit-duration Keep Awake and notes; no new AI/cloud or clipboard permission added. |
| Notchy | https://notchy.dev/ | Quick Notes, Keep Awake, color picker, stopwatch and broader utilities | Added all four real local tools through existing notch engine. |
| DynamicLake | https://www.dynamiclake.com/ | Media/HUD, calendar alerts, plugins, conversions, weather | Preserve existing media/calendar; defer unsigned plugin execution and unconfigured weather provider. |
| MediaMate | https://wouter01.github.io/MediaMate/ and https://github.com/Wouter01/MediaMate-Releases/releases | Audio/brightness/keyboard HUD, Now Playing, filters and duration settings | Preserve upstream HUD/filter/settings; no new private display-control integration. |
| NotchBox | https://apps.apple.com/us/app/notchbox-easier-drag-drop/id6737410946?mt=12 | Notes, clipboard, countdown/stopwatch, calendar, network, mirror, launcher | Added notes/stopwatch; existing calendar/network/mirror remain. |
| NotchDrop | https://apps.apple.com/us/app/notchdrop/id6529528324?mt=12 | Temporary file tray/retention and AirDrop | Preserve existing tray/AirDrop. This is Lakr233's App Store product, not another similarly named website. |
| Cove | https://heycove.app/ | File tray/vault, widgets, local AI, capture/color tools, timers | Added on-demand system color picker and HEX copy; no unconfigured AI dependency. |

## Shipped local scope

Quick Tools is available in Settings and the menu bar, and opens inside the existing notch activity engine. Notes support create/edit/pin/search/explicit save and reload with corruption protection. Stopwatch uses a monotonic clock and pause/resume/reset; it does not persist across app termination. Keep Awake offers 15/30/60 minutes, explicit stop, automatic expiry and quit cleanup. Color picker uses Apple's NSColorSampler and copies sRGB HEX only when requested.

Privacy & Security lists three optional connection controls (lyrics, public-IP country lookup, local YouTube Music remote), initially off. Risky password-based Face Unlock is removed rather than imitated. Existing camera mirror is a separate feature.

Not every advertised competitor capability is implemented: weather/AI need real provider configuration, automatic meeting actions need explicit tested integrations, and plugin execution expands trust. Do not mark these as completed or expose nonfunctional toggles. Feature presence, source tests, installed runtime checks and physical-device evidence remain distinct in FEATURE_REGISTRY.md and TEST_REPORT.md.
