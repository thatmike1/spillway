# Spillway R11 delivery

Runtime source **52a66297**, build **spillway-2026.11.06-r11**. [Play instructions and portable files](../REPORT.md). [Manifest](../delivery/spillway-r11/BUILD.json), [archive audit](spillway/delivery-checks/r11-archive-audit.json), [native default identity](spillway/delivered-r11/identity/pause.png).

The 5November20:00 minimum was superseded by Mike's explicit6November08:00Prague extension. That minimum passed before this resumed validation. Disk exhaustion interrupted the previous run; no work is claimed during the gap. The user-authorized deleted game directory was not recreated. [Resume record](spillway/overnight/resume-2026-11-06.md).

## Complete native routes from the delivered pack

| Native route | Driver time | Frames at24 fps | Respawns |
|---|---:|---:|---:|
| safe | 48.300 s | 1240 | 0 |
| fast | 22.192 s | 613 | 0 |
| recovery | 43.692 s | 1129 | 0 |

- [Safe movie](spillway/delivered-r11/safe/safe.mp4), [sheet](spillway/delivered-r11/safe/sheet.jpg), [trace and media audit](spillway/delivered-r11/safe/media.json).
- [Fast movie](spillway/delivered-r11/fast/fast.mp4), [sheet](spillway/delivered-r11/fast/sheet.jpg), [trace and media audit](spillway/delivered-r11/fast/media.json).
- [Recovery movie](spillway/delivered-r11/recovery/recovery.mp4), [sheet](spillway/delivered-r11/recovery/sheet.jpg), [trace and media audit](spillway/delivered-r11/recovery/media.json).

Normal 24 fps playback; Compatibility/llvmpipe,1280x720, input events from normal spawn, no pose or velocity writes. A three-second hold shows the real wheel and water response. Original AVI and encoded MP4 frame counts agree. Driver time and HUD elapsed are different clocks; movies also include startup and the finish hold. [Signal/video audit](spillway/delivered-r11/signal-and-video-audit.json) confirms24 fps and audio peaks below full scale, without an auditory verdict. These are scripted lines, not human play or measured GPU frame pacing.

## Fixes and rendered evidence

- [Backward braking](spillway/overnight/braking/SCOPE.md): release and opposing input stop predictably;16m/s stop0.475s/3.698m. P/game choice.
- [Eye clearance and audio continuity](spillway/overnight/motor-review/eye-and-loop-fixes.md): same body positions, gate-eye intrusions2→0; loop signal tests are not listening verdicts.
- [Reachable hardware](spillway/overnight/hardware-review/fix.md), [wheel guard](spillway/overnight/r11-wheel/SCOPE.md).
- [Pump hall and cast slabs](spillway/overnight/opus-art-r11/NOTES.md), [motion fixtures](spillway/overnight/opus-art-r11/motion/SCOPE.md).
- [Terrace continuation](spillway/overnight/terrace-direction/SCOPE.md), [walking wheel arrival](spillway/overnight/front-wheel-arrival/SCOPE.md).
- [Recovery ramp](spillway/overnight/opus-recovery-clearance/SCOPE.md), [native pairs](spillway/overnight/opus-recovery-clearance/pairs.jpg): west lane obstruction removed; all three lanes walk up without jumps/resets, clear width3.86→4.74m.
- [Batch shadows](spillway/overnight/batch-shadow/SCOPE.md), [native pairs](spillway/overnight/batch-shadow/pairs.jpg): four screen panels preserve their shadow-free setting; posts and rails still cast shadows.

## Checks, failures and critique

[Source check](spillway/overnight/r11-final-source-check.log) and [delivered-file checks](spillway/overnight/r11-delivery-check.log): audio 18, motor 103, flow 94, access 123 and boundaries 92, all pass. [Resource preflight](../delivery/spillway-r11/packed-resources.txt):17 active resources load outside source. Both portable archives pass CRC, hashes, architecture and licences. Separate processes save/reload clean records/settings; practice preserves clean bests. Native Windows execution is unverified.

[Final exact-pack matrix](spillway/stress/r11-release/matrix-results.json):39/41, complete and pack unchanged. Original36-case subset35/36; five rail-hop cases4/5. All raw attempts remain. Failures: rail-hop seed4 stalls at a machinery corner; late-fast seed1 lands in the basin then pursues its elevated waypoint. Neither respawns. [Earlier placed continuations](spillway/overnight/retained-failure-continuations/SCOPE.md) establish recovery for the earlier positions, not success for these final failed attempts.

[Recovered visual discovery](spillway/interactive/sol-screened-play/REPORT.md) documents one respawn, a full restart, then ordered stages and basin recovery with no further respawn. It never recorded a finish and used the older0f195776 pack; its final PNG is truncated. [Basin discovery fixture](spillway/interactive/sol-basin-play/REPORT.md) reached a practice finish. Neither is full R11 discovery proof. [Earlier incomplete R11 captures](spillway/overnight/r11-packed-recovery/INCOMPLETE.md) remain labelled incomplete.

[Fresh R11 fast/recovery frame review](spillway/reviews/r11-running-views/REVIEW.md) found no new blocker in those two recordings, while retaining gate/exit preview weaknesses, the roof turnaround stop and quiet yard traversal. Root inspected the completed safe contact sheet separately. No real-time play or listening verdict is claimed.

[Opus trail/result critique](spillway/reviews/opus-2026-11-06-trail-review.md) verified the ramp/shadow fixes and hourly allowance. Corrections for the prematurely logged art inspection, missing dispatch and failed bead closure are appended to the trail. The Outflow recovery penalty is weak; REPORT names it. Batching ignores other per-mesh flags unused by today's boxes, a latent extension risk. Human enjoyment/comfort, listening, controllers, native Windows and desktop GPU pacing remain unverified.

[R10 checkpoint and its evidence](reboot-r10.md) remain historical. The final evidence index records current paths and archive-based resolution for losslessly compressed historical files. Private game material is excluded from Git.
