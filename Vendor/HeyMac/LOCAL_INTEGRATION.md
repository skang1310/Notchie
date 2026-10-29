# DynamicNotch local integration

Source: https://github.com/iharshitmaurya/HeyMac
Pinned upstream revision: 8cfbe360dc1cccd5cae42f44727da68685e549dc (2026-10-28 checkout).
HeyMac source is MIT; preserve LICENSE and THIRD_PARTY_NOTICES.md. DynamicNotch remains GPL-3.0. No HeyMac app UI, animations, updater or launch agent is included.

Local changes: library-only Package.swift; Keychain service/label and EngineSettings keys isolated from HeyMac; DynamicNotch adapter uses a dedicated support directory and event log. Existing DynamicNotch settings and notch presentation are reused. Tests copied with the engine/core. Added a post-match stop/enable/permission gate before typing, with cancellation regression tests.

Models and model notices are retained as supplied upstream. InsightFace pretrained model terms are distinct from MIT source licensing; this build is for the user's local personal use, not a commercial redistribution license grant. Review model rights before distribution.

Camera matching uses ArcFace + anti-spoof classification; it is not Apple's Face ID and does not provide TrueDepth/Secure Enclave biometric authentication. Saved face embedding and login password use AES-GCM; encryption key is stored in this app's login Keychain item. Camera frames are processed locally. Login password must be entered explicitly by the user. Registration is staged and followed by a live confirmation before replacing the previous identity.

The lock-state reader uses private CGSessionCopyCurrentDictionary (runtime resolution). Password typing uses Accessibility-authorized CGEvent HID events, not a public macOS face-unlock API. FileVault/pre-login cannot be unlocked. API changes and login Keychain restrictions can prevent operation. Engine stops after password rejection and requires the user to save a password again. Neither camera/accessibility permission, enrollment, activation nor login launch is enabled automatically.

Physical enrollment, impostor/photo resistance, real lock-screen unlock, password rejection, sleep/wake and reboot must be verified separately on the user's Mac. Build and fixture tests do not establish those properties.

## Additional app privacy integration — 2026-10-28

DynamicNotch now connects HeyMac LockedAppStore, SessionBook, AuthCoordinator, LocalSystemAuth, InstalledApps and FaceVerifierAuthSource to native AppPrivacy settings and opaque all-display covers. App list/activation/focus/termination events use NSWorkspace; sessions are revoked on sleep/session resignation/lock notification and stop. Relock deadlines use monotonic uptime. App selection, policies and face-first preference persist in namespaced defaults. Disabling/pause/removal revokes sessions and cancels auth. A per-attempt UUID blocks stale results. Added AuthCoordinator cancellation checks after both face and system results with tests.

Targets are hidden before authentication; a cover is shown on each display and recreated on display changes. Covers lower below macOS authentication dialogs while the target stays hidden. Explicit Back cancels the attempt, keeps the target hidden and opens settings. Touch ID/account-password verification uses LocalAuthentication and never saves the system password. Optional face-first uses the existing registered face only if Camera access is already granted; no automatic camera prompt. No Screen Recording or Accessibility grant is required by this privacy cover.

This is an application-level privacy aid, not a macOS access-control or encryption boundary: notifications, previews, other system surfaces, initial activation frames, killing DynamicNotch or direct file access are not covered. No self-restarting launch agent or quit trap is installed. The screen/window tracking/blur implementation of HeyMacApp is not copied. Existing DynamicNotch presentation and settings components are retained. Actual configured-app auth/Spaces/fullscreen/hotplug/sleep-wake tests remain distinct from state/engine tests and safe cover preview.

### Lock/authentication and Settings cleanup — 2026-10-29 v23
- Settings: visible sidebar groups, quieter shared cards, remove redundant General haptic/media toggles (canonical controls remain in Gestures/Now Playing), combine system permissions under Privacy and lock-screen appearance under Lock & Authentication. Old enum/deep-link routes preserved.
- Show persisted password-rejection recovery after relaunch; setup comes before collapsed animation previews.
- One lock engine now owns explicit lock-screen button retries; remove the retired always-failing presentation scanner from that path. Explicit retries never reset the password submission budget.
- Preserve retry budget on unknown lock state, distinguish unconfirmed unlock from password rejection, ignore camera contention for face retry counting, recheck cancellation after inference, clear inherited shortcut modifiers in synthetic key events.
- Reduce polling/cooldown delays and raise frame cadence to 15 fps; retain strict thresholds, anti-spoof pipeline, two consecutive accepted frames, camera warmup and one password attempt per lock episode.
- No camera permission, enrollment, password replacement, login launch or authentication enablement performed automatically. Physical Mac unlock timing requires the user's saved-password recovery and manual lock test.

### v24 password delivery follow-up
KeystrokeInjector now resolves the ASCII-capable layout and supplies actual key codes/modifiers with Unicode overrides. Engine logging adds revision and stage durations without credential data. Physical validation is pending; private lock detection and synthetic-input platform caveats still apply.

### v25 — keyboard-layout thread affinity fix
The v24 physical test crashed in HIToolbox's main-queue assertion during TIS input-source lookup. Snapshot the layout on main via a short synchronous dispatch, retaining background typing. Added a regression exercising the real Carbon lookup from a detached verification worker; no synthetic input or credentials are used by that test. Existing verified password and opt-in settings are preserved. Physical lock test remains required.

### v35 capture lifecycle optimization
Preconfigure without starting stream at explicit engine enable; prime inference with anonymous synthetic pixels. Invalidate stopped frame epochs immediately; serialize lifecycle commands and perform hardware stop off the password-delivery critical path. Keep camera off outside verification/cleanup, identical models/security thresholds, and fresh consecutive frame checks. Hardware latency is measured separately from fixture inference.
