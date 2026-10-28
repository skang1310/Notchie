# Native macOS design refresh — 2026-10-28

Sources checked live:
- https://developer.apple.com/design/
- https://developer.apple.com/design/human-interface-guidelines/materials
- https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass
- https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views

## Applied decisions

Use the native navigation split view and toolbar rather than covering them with an opaque 52-point strip. Keep grouped settings content opaque and readable. Shared page spacing, maximum reading width, semantic backgrounds and section labels support a calmer hierarchy. The user's existing appearance selection is preserved.

The window can resize with a 740 × 560 content minimum and an 860 × 660 initial size. The sidebar has a flexible width. Scroll indicators remain available. Lock & Authentication has a feature selector, actual enabled/off state, switch controls, clear registration/password/permission rows and progressive disclosure for secondary detail. Destructive removal still needs confirmation. No engine, enrollment, permission or activation behavior changed.

Native glass / glassProminent button styles are used for selected principal actions on macOS 26+. Reduce Transparency or Increased Contrast uses bordered styles, as do older macOS versions. No custom motion was added. The privacy cover remains entirely opaque; only its controls use glass. The preview has an enabled return action rather than disabled authentication buttons.

## Evidence limits

Before/after UI is inspected in /Applications/DynamicNotch.app with native computer-use screenshots. Automated behavior tests are separate from visual checks. System-wide accessibility preferences are not changed for this work; their custom-style branches are source-reviewed, not physical accessibility certification. VoiceOver, all legacy feature screens, fullscreen/multiple displays and actual face/Touch ID authentication require separate checks.

Final installed checks: general and lock/auth settings visually inspected; toolbar no longer overlaps content. Opaque app privacy preview and return to settings exercised. Final installed revision Glass-20261028, matching Release UUID E080B99B-46DD-3C67-BB5A-AD9D8852C93D; whole app tests 265/265 and subsequent focused navigation/localization tests 9/9 passed. Registered-face primary action is Test; re-registration remains secondary. No protected behavior or user consent state was changed.
