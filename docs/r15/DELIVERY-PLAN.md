# R15 release checklist: completed 9 November 2026

R15 is accepted in outer `delivery/spillway-r15/`; the outer REPORT is the R15 player guide. See RESULTS.md and the immutable verification/promotion receipts for the exact scope. The historical plan below remains the acceptance checklist.

- [x] Actual R15 default scene, separate profile, F2/F5, crouch, map grid and checkpoint practice.
- [x] Approved uncrouched route parity through the real R15 host and motor version 2.
- [x] Breakwater route proofs through the strict executor, including physical return and checkpoint respawn.
- [x] All five new course modules, plus the separate optional movement playground, integrated and played through the R15 host.
- [x] Source/native per-course F2 ordinary route, deliberate recovery and F5 basic route. Failed and unfinished attempts are retained.
- [x] Experimental slide, wall jump and bounded grapple with explicit controls, state and record identity. Normal maps retain approved movement.
- [x] Independent contact/checkpoint/crouch/record challenges; unfinished source player-view discovery retained; exact final-byte Linux OS-input smoke. No human-feel claim.
- [x] Fresh portable Linux and Windows release ZIPs; 304/304 packed Linux checks outside the checkout, 15 play/reload cycles, 78/78 exact-byte negatives, player report and pushed source. Windows remains static-only.

## Delivery tooling

Use separate R15 wrappers and probe, preserving frozen R14 tooling. The existing release tools provide official engine/template hashes, safe owned-process cleanup, strict finite trace comparison, integer record checks and the checked private AMD/X11 backend. Carry those protections forward; none of the historical R14 pass counts proves R15 acceptance.

Pin `spillway-2026.11.08-r15`, `scenes/r15.tscn`, `scripts/r15_main.gd`, `user://spillway_r15.cfg`, `R15 Pack` and actual runtime registry identities. Source mode freezes the committed project outside the checkout. Package mode refuses dirty source, exports that same snapshot, and checks the actual release runtime and pack before promotion. A later check must reconcile both source and helper manifests and execute the helper bytes it names.

The expected final map ids are `breakwater`, `whiteout-relay`, `sunken-court`, `rainline`, `night-shift`, `practice`, `overflow` and `experiment`. Planned modules may not silently disappear from final acceptance. F2 is default; F5 is primary; F3/F4 remain labelled advanced comparisons. Vanilla64 is excluded from R15.

Collect asset notices and manifests recursively. The old one-level `assets/<kit>/licences` selector misses both `assets/r15/library/` and `assets/r15/breakwater/`. Preserve relative paths in the licence bundle so repeated names cannot overwrite each other. Include raw JSON dependencies such as `BOUNDS.json`, and verify imported HDR skies as resources as well as meshes, textures and shaders. Do not demand that imported model source buffers remain raw files when Godot has compiled them into its resource format; prove the actual loaded dependency graph.

The release probe must exercise the real map grid and checkpoint picker, crouch/blocked standing, live F2/F5 switching, practice purity, complete exact saved records and reload, drawn preset/speed/jump/sync labels, visible course surfaces and Quit. Check engine errors in nested executor logs too. Text that is transparent or has zero visible characters does not count as displayed.

Packed route evidence uses explicit rate, sensitivity and warmup from each source reference. Compare every sequential tick and complete vectors; reject missing/duplicate ticks, NaNs, failed input delivery and unexplained resets. Keep rounded driver samples distinct from full-precision standard-executor traces. Crouch hull-origin compensation must pass the narrow observer contract in REPLAY.md. Native AMD means the device log plus kernel GPU activity, not an inherited environment label.

HOME needs at least 15 GiB free before every export/native launch. Keep the pinned Weston package used by `r14_native_display.py`; it is a current R15 dependency despite its historical checkpoint path. Bound scratch, retain compressed traces, selected JPEGs and final MP4s, and remove owned import/profile/shader caches. Do not touch the desktop display or current final R12/R13/R14 deliveries.

Promote only the accepted immutable ZIPs and their BUILD, checksum, verification and licence evidence into outer `delivery/spillway-r15/`. Windows remains static-only unless it is actually run on Windows. The outer REPORT tells Mike how to launch, choose maps/checkpoints, crouch, use F2/F5 and enter the experimental playground; it states actual caveats and leaves feel to him.

Current packed route admission remains clean, ordered and zero-respawn. Deliberate fall/respawn proofs are reported separately as source/native recovery evidence; packed checkpoint-picker and practice controls do not upgrade them into packed recovery routes. A reset exception would need its own narrow rule and independent challenge before recovery tapes could be admitted.
