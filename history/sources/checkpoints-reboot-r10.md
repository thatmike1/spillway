# Spillway reboot checkpoint

**Delivered: spillway-2026.11.05-r10, runtime source 5a8cf81e.** One finished three-segment level replaces the retired reconstruction target. Mike extended the run past 20:00; the build continued through progress, recovery and delivery faults. [Play instructions and packages](../REPORT.md). [Exact build manifest](../delivery/spillway-r10/BUILD.json).

Mike subsequently extended work through at least 08:00 Prague on 6 November. [The active overnight checkpoint](spillway/overnight/STATUS.md) tracks later source changes; this section records the stable R10 packages.

## Actual delivered-file evidence

[Direct native default startup](spillway/delivery-checks/r10-native-default-startup.log) launches the delivered package without a script override; [pause identity](spillway/delivered-r10/identity.png) visibly identifies r10.

Both archives pass CRC, pack/runtime SHA256, x86-64 ELF/PE headers and licence checks in the [archive audit](spillway/delivery-checks/r10-archive-audit.json). Linux actually launches from an extracted path containing spaces, outside the source checkout. [Separate profile writer](spillway/delivery-checks/r10-write-profile.log) and [reader](spillway/delivery-checks/r10-read-profile.log) verify settings, clean records and practice protection. These use an isolated synthetic record, never Mike's profile.

- [Packed motor checks](spillway/delivery-checks/r10-packed-test_spillway.gd.log): 93/93. The external source fixture loads gameplay from the delivered PCK. Includes immediate run/brake, jump grace, standing air correction, free look, momentum through ordinary landings and slide release, ceiling clearance, no flat slide pumping, actual stair seams and deliberate mantle cancellation.
- [Native flow](spillway/delivery-checks/r10-native-flow.log): 93/93. Headless source 94/94 includes one extra startup assertion. Covers clean/practice/exploration records, ordered splits, R/F, result preservation, settings, menu focus and ultrawide projection.
- [Native actual-level access](spillway/delivery-checks/r10-native-access.log): 66/66. Includes the ordinary apron rail hop, housing/bridge turns, roof mantle/cancellation, low-yard guards, skipped-stage finish, direct wheel approaches, post-finish fall and stale-contact resets. [Complete fixture movie](spillway/delivery-checks/r10-access-frames/access.mp4) and [sheet](spillway/delivery-checks/r10-access-frames/access-sheet.jpg). [Rail-hop result](spillway/delivery-checks/r10-access-frames/rail-hop-clean-result.png) and [exploration result](spillway/delivery-checks/r10-access-frames/exploration-result.png) show the actual rendered labels; [scope](spillway/delivery-checks/r10-access-frames/SCOPE.txt) identifies fixture clocks. Labelled fixture spawns are not whole-route proof.
- [Packed boundary sweep](spillway/delivery-checks/r10-packed-test_spillway_boundaries.gd.log): 92/92, 52 input episodes. Three samples per edge, diagonal corners of three recovery floors, plus misleading headings and exit seams. This is sampled coverage, not every possible fall.

## Uninterrupted native routes

Each folder retains exact BUILD.json, command, engine log, input trace, native AVI with audio, MP4, contact sheet and extracted stills. The observer loads the configured default scene from its normal spawn, writes no player pose/velocity/camera/checkpoint and holds the finish for 2.5 s. Driver success requires an ordered, non-exploration result.

| Line | Driver time | Full native movie | Frames |
|---|---:|---|---|
| Safe stairs and gantry | 48.433 s | [safe](spillway/delivered-r10/safe/safe.mp4) | [sheet](spillway/delivered-r10/safe/safe-sheet.jpg) |
| Chute, gate and diagonal jumps | 22.358 s | [fast](spillway/delivered-r10/fast/fast.mp4) | [sheet](spillway/delivered-r10/fast/fast-sheet.jpg) |
| Misses and water recovery | 43.933 s | [recovery](spillway/delivered-r10/recovery/recovery.mp4) | [sheet](spillway/delivered-r10/recovery/recovery-sheet.jpg) |
| Ordinary rail hop and basin return | 28.383 s | [rail_hop_recovery](spillway/delivered-r10/rail_hop_recovery/rail_hop_recovery.mp4) | [sheet](spillway/delivered-r10/rail_hop_recovery/rail_hop_recovery-sheet.jpg) |

All four finish with checkpoints 0→1→2 and zero respawns. Driver time includes startup before the movement-triggered HUD clock. Captures simulate 30 fps and play at 30 fps. They do not measure hardware FPS. The native access fixture uses 15 fps. AVI MJPEG replaced redundant PNG sequences because disk space ran low; full original recordings and representative/dense extracted frames remain. Historical thinning is documented by retention manifests.

[Source regression log](spillway/reviews/r10/spillway-r10-root-check.log) passes 93/94/66/92 plus all three canonical routes. [Frozen source matrix](spillway/stress/r10-release/matrix-results.json) finishes 39/41. Original 36-case subset 35/36; new rail-hop subset 4/5. Both failed traces remain: [late jump](spillway/stress/r10-release/late-fast-1/engine.log), [yard corner](spillway/stress/r10-release/baseline-rail_hop_recovery-4/engine.log). Neither respawns. The first follower waits for an elevated fast-line target after landing in water; the second cuts a machinery corner. A separate [R9 actual late-miss branch](spillway/delivery-checks/r9-late-recovery/engine.log) finishes in 38 s without a reset. R10's unchanged motor/geometry has its own complete native recovery movie above; R9 media stays labelled R9.

## Failures fixed and rendered comparisons

The early green slice concealed crouch threshold flicker and weak recovery. Full-course perturbations found solid foundations and supports in routes. Sol reproduced lost tangent momentum on mantle cancellation, missing controller focus, stale practice comparisons, ultrawide FOV errors and extracted Windows-runtime validation gaps. All received behavioral checks.

Opus then found natural approaches missing hidden checkpoint regions, a housing slot, open basin edges and post-finish falls clearing the result. Recovery now has continuous retaining faces and exit rails; the housing joins the roof with a smooth nosing and bridge. [False exit before/after](spillway/recovery-retaining-pair.jpg), [existing ramp visibility before/after](spillway/recovery-ramp-pair.jpg), [art before](spillway/opus-art/before-sheet.jpg) and [art after](spillway/opus-art/after-sheet.jpg). These are matched fixed-camera fixtures, not route proof.

An independent R9 ordinary rail hop reached the run-up and wheel but was refused: [input probe](spillway/delivery-checks/probe-r9-rail-hop.gd), [failed log](spillway/delivery-checks/r9-rail-hop.log). R10 admits actual grounded stage decks and always finishes at the wheel. Skipped stages produce an unrecorded exploration result. Finale catch surfaces do not grant Outflow because one hop from the yard entrance reaches them. Tagged-deck admission rejects side contacts, distant airborne proximity and stale reset contacts. The [Opus implementation report](spillway/reviews/r10/spillway-r10-progress-fix.md), native access movie and new whole rail-hop route show the distinction. No motor or art tuning changed in R10.

## Critique and limits

[Sol integrity review](spillway/reviews/spillway-integrity-review.md), [Opus course/trail review](spillway/reviews/spillway-final-opus-review.md), [Opus closure review](spillway/reviews/spillway-r7-closure-review.md) and the R10 report above are retained. Root reviewed the Claude progress code, added reset and driver checks, and inspected native route sheets and dense frames. Models reviewed code, traces and still frames; the complete normal-speed movies are supplied for playback. No claim of a human play session or auditory assessment follows.

Native rendering is Compatibility/llvmpipe. Earlier batching reduced 3,396 draw calls to 700; software speed stayed about 2.8 fps. Desktop GPU frame pacing, physical gamepads, Windows gameplay, listening, enjoyment and comfort remain unverified. The first course expansion preceded the slice critique, contrary to the intended gate; the [decision trail](../wt/projects/foldrunner/docs/reboot/decisions.tsv) records that deviation and subsequent rework. Final passing checks do not erase it.

[Final Opus review](spillway/reviews/r10/final-opus-review.md) found no gameplay must-fix in 30 rail-hop variations, rail-perch continuations and six direct wheel approaches against the delivered PCK. Probe scripts/logs are retained beside that report. It confirmed the hashes, source-matrix scope, counts and evidence pointers. Its required final documentation commit/push is resolved by this delivery.

Accepted polish limitation: the decorative wheel has no collider. Continuing forward after finishing can pass through its spokes; the result is already saved. The close rotating wheel can cross the results backdrop, and human comfort remains unverified. No runtime change was made for that optional item.

[Public own-session action export](spillway/reviews/public-runtime-transcript.txt) excludes hidden analysis and unrelated conversations. [Evidence path index](spillway/evidence-paths.tsv) resolves historical and current pointers. Earlier incomplete captures, follower failures and superseded builds remain identified as such.
