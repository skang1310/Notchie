# Performance and size review — 2026-10-30

Scope: release configuration and bundle inventory; AI usage refresh concurrency and file parsing; screenshot monitoring/thumbnail generation; VPN and Bluetooth monitor lifecycle; local process output and support-image import/export. This is a scoped source review, not an exhaustive security audit or hardware benchmark.

## Fixed

- **High — overlapping AI usage scans:** `refresh()` cancelled detached tasks without cancellation checks in the parsers or publication. Multiple consumers could continue scanning the same files concurrently and publish stale results. Share the active task until publication finishes; release its handle afterwards. Regression requests 20 refreshes and verifies exactly one publication, followed by a successful subsequent refresh.
- **Medium — unoptimized native Release code:** inherited C optimization level was zero. Explicitly use level 2 for the app's Release target; retain Swift `-O` for runtime performance. Debug settings remain separate.
- **Medium — unnecessary distribution symbols:** enable Release deployment postprocessing and non-global symbol stripping. dSYM stays outside the app for crash diagnosis. Preserve global dynamic symbols and existing resources, model weights, frameworks and license notices.
- **Low — hidden System Settings polling:** stop the 500 ms VPN AX polling while Settings is hidden. Existing unhide/activation notifications immediately recheck and restart polling. This preserves detection for visible background Settings windows.
- **Low — timer wakeup alignment:** allow 100 ms tolerance for VPN polling and 70 ms for screenshot monitoring, without changing requested intervals.

## Remaining review findings

- **Medium:** screenshot monitor enumerates several folders and reads metadata synchronously on the main run loop every 350 ms. A file-system event watcher with a recovery scan would reduce idle I/O, but needs folder replacement, partial recording writes and permission regression coverage. Not changed in this patch.
- **Medium:** AI parsers load entire JSONL files and split them into arrays. Coalescing removes concurrent scans but large individual histories still cause peak allocations. Streaming/incremental parsing should preserve all usage aggregation semantics and handle file rotation before replacement.
- **Low:** support screenshot import writes source bytes and JSON on the main actor after background decoding; large imports may stall UI. Serial background persistence needs explicit ordering to prevent lost document updates.
- **Low:** existing Swift 6 actor-isolation warnings remain in download integration tests. Current build uses Swift 5 mode; migration is separate work.

No feature/assets/model compression or removal was attempted without equivalence evidence. No cache, backups, user files or existing settings were deleted. Timer tolerance is a scheduling opportunity, not a measured energy-saving percentage. App byte-size results and build/test/install evidence are recorded separately in `build/OptimizationEvidence-20261030`.

## Delivered validation

- Clean whole-app tests: 322 passed, zero failures. Final-source incremental whole-app tests: 322 passed, zero failures.
- Release build succeeded; strip step confirmed. dSYM and executable UUID both `935C49C2-AED6-3244-AA3A-642EDDB6F430`.
- Local installer succeeded; canonical `/Applications/DynamicNotch.app` strict deep signature validation passed after launch. Installed revision `Notchie-Optimization-20261030-v36`; installed UUID matches Release. Executable bytes differ after installer re-signing, so no byte-identical signed-binary claim.
- Installed process observed at canonical executable path (PID 54929).
- Logical regular-file bytes (symlinks excluded), before/after: **51,091,205 → 34,792,059 bytes**, saving **16,299,146 bytes (31.90%)**. Executable **25,163,888 → 8,862,160 bytes**. This is installed app size, not total development workspace/cache usage.
- Runtime throughput, sustained CPU/RSS, energy use, physical camera unlock, and hidden/unhidden VPN UI round trip were not benchmarked. The coalescing regression proves one result publication for 20 simultaneous requests; timer lifecycle changes were source-reviewed/build-verified.
