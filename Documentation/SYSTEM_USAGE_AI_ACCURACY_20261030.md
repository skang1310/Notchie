# Home system usage and AI quota accuracy — 2026-10-30 v39

## System usage

The existing ShelfSystemStats engine now supplies the home footer and the existing System Stats tool. The footer shows CPU, used/total RAM, receive/send rates; it opens the detail tool. Home reserves 34 additional points for this footer. Details include bounded CPU/download history, swap, memory pressure and available disk capacity.

One reference-counted sampler serves both presentations. It runs every two seconds only while a consumer's window is visible, and stops after the last consumer disappears. CPU/network baselines are reset on resumption; initial rates show unavailable rather than fabricated zero. CPU is the system aggregate. RAM remains active + wired + compressed pages, not a claim of identical Activity Monitor accounting. Disk capacity uses volumeAvailableCapacityForImportantUsage, including OS-reclaimable availability, refreshed at most every 30 seconds.

Network counters come from active en* AF_LINK interfaces through getifaddrs, excluding loopback/VPN/tunnel duplication. They are actual byte deltas over monotonic uptime, not an internet speed test. Newly added or reset/wrapped interface counters establish a fresh baseline rather than producing a spike. This does not attribute traffic per process and does not cover unusual interfaces outside en*. Legacy if_data byte-counter wrap skips the affected interval.

Memory pressure is a best-effort, read-only `kern.memorystatus_vm_pressure_level` sysctl. Availability and mapping are OS-specific, not a public compatibility guarantee. Missing/unknown pressure reads display unavailable. Swap uses vm.swapusage. No privileged helper, new protected permission, packet capture, SMC/temperature or GPU private API was added.

## AI discrepancy diagnosis and correction

The previous implementation divided local Claude messages by 45/350, Codex sessions by 25/40, Gemini requests by 50/200, imposed artificial minimum percentages, assigned guessed plan badges, and fabricated reset dates. These calculations are not provider quota and have been removed. Labeling them estimates did not make the underlying percentages reliable.

Codex now reads actual provider quota snapshots from `event_msg` / `token_count` / `rate_limits` in recent session JSONL files. Used percentages, window durations, reset timestamps and plan are taken from the record. The newest timestamp wins, not file modification time. Unrelated model-limit IDs are ignored. At most 32 recent files from three UTC date directories are considered, with at most a 1MiB tail per file; parsed results (including missing snapshots) are metadata-cached, bounded to 64 entries. No transcript content, credentials or account IDs are stored in new evidence.

At the validation comparison, the native Codex current-account usage tool reported primary 49%, secondary 70%; the latest local record at `2026-10-30T02:39:31.747Z` also reported 49%/70%, with matching windows and essentially matching reset timestamp (one second difference in the primary). This validates the recorded source at that point, not continuous equality with a live endpoint.

Six recently modified local log files per Claude/Gemini were checked for recognized quota events, without dumping message content. No recognized quota event was found. Those cards retain local activity but show `Quota unavailable`; no percentage, plan inference or reset countdown is fabricated. This is not a claim that those services lack usage screens or remote APIs. No OAuth, API key or credential storage was accessed for a new provider integration.

Cards label provider record time and stale records (>15 minutes). Refresh time does not replace record time. Expired reset times say a new record is needed, not that a reset succeeded. Warning notifications require recorded, fresh quota and a future reset; local interaction counts and generic old exhaustion errors cannot trigger them. No real-time quota claim is made for a local snapshot. All three provider cards remain together.

## Verification

- Final app suite: 336 tests, zero failures. Six new tests cover actual quota schema/mapping, no invented percentages even with many sessions, stale/malformed suppression, newest-record/file-replacement behavior, network baselines/reset/hotplug, and shared sampling/host reads. Earlier geometry assertion expected the pre-footer height and was updated to reserve the added 34 points; failed initial result retained.
- Release build, local installer and strict post-launch signature validation passed. Revision `Notchie-SystemUsage-20261030-v39`; installed and Release UUID `9FC2EDA1-6EC8-3F5D-8E57-0F5B85FBCDEB`. Canonical process observed (PID 78775).
- Installed AX inspection of System Stats showed live CPU/RAM, RX/TX, memory bytes, swap, pressure and disk availability. An immediate installed screenshot showed both CPU/network graphs and detail rows. A continuous native interaction switched from Stats to Nook and captured the home footer beneath the preserved media/calendar layout.
- Further footer-click/AI-card visual automation was interrupted by the inherited six-second quick-tools dismissal / active recording activity and UI state changes. Full final AI-card pixels, footer-to-detail round trip, hidden-window no-wakeup measurement and multi-display interactions are not claimed. Unit tests and source wiring cover those paths but are separate from these UI gates. No recording was stopped, no calendar interaction invoked, and no private calendar screenshots saved to the repository.
- Evidence: `build/SystemUsageEvidence-20261030/{tests-final.log,release.log,install.log}`. No sustained CPU/energy reduction or camera/physical unlock performance claim.
