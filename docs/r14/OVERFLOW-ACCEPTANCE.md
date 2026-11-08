# Overflow with all five R14 presets

P execution proofs, 8 November 2026. The unchanged Overflow geometry is
`3a04610b4cbf3ff7596ac864f3d31e5bfed36fa3fa4d94c80ab904468f12b99e`.
Every line below starts at the normal spawn, uses only key/mouse events, visits stages
0, 1, 2, 3 in order and finishes clean with zero respawns. These are authored lines,
not discovery or a verdict on feel.

| Preset | Current input-only replay |
| --- | ---: |
| F1 vanilla 64 Hz, reconstructed stamina | 46.515625 s |
| F2 server AA 100, 128 Hz | 45.9609375 s |
| F3 original R13, 120 Hz | 24.891666666665895 s |
| F4 Quake III-inspired, 128 Hz | 35.8671875 s |
| F5 server AA 1000, 128 Hz | 45.9609375 s |

Source-family recordings were made with the repaired chronological collision adapter,
contact guard 3 and actual `r14_main.gd`. The coordinate-aware recording controller
reads player state and chooses ordinary inputs. Its tapes were then replayed open loop
through that same actual main, one drawn frame per physics tick, warmup 8. Source look
uses the labelled authored sensitivity 5.729577951308232 (0.0022 rad/count), not the
product default 2.5. No pose, velocity or progress is restored during a run.

`tests/r14_overflow_driver.gd` preserves the R13 recording controller unchanged and
hosts it in R14. A setup-only compatibility sensitivity value lets that old controller
read the active look scale; gameplay does not use this extra dictionary key. The driver
writes version 2 tapes with integer header/event ticks, plus current R14 source hashes.
Its F2 verification also finishes in 45.9609375 s with zero stalls and respawns.

The old Source-2 open-loop tape fails under guard 3. The first support difference is at
tick 1224; a later landing falls short, and the tape eventually releases W at tick 5953.
That failed attempt is retained. A new current-controller route succeeds without
reverting the support correction. Two harness failures are separate: missing the old
controller's sensitivity dictionary key, and Godot JSON turning integer tick fields
into floats. Both are retained and labelled; normalising JSON number types changed no
event timing or values.

F3 reuses the original R13 tape and unchanged motor/camera. Its 3,372 ticks have identical
velocity and view to the retained R13 product control, but position differs by up to
1.697 cm. This is within the previously observed initialization-dependent discrepancy;
its cause remains unresolved, and it is not an exact-position equivalence claim. Only
the Chute progress flag differs at ticks 1287 and 1288. Finish time and outcome agree.
Final packed acceptance must compare against the new R14 source reference, retaining
any discrepancy rather than relaxing exact comparison.

Evidence under outer `checkpoints/spillway/r14/overflow-final-source/`:

- `CURRENT-REPLAY-ACCEPTANCE.json`: F1, F4, F5 and F3 actual-main replays.
- `replay-server2-normalized/`: current F2 open-loop replay.
- `RECORD-RESULTS.json`, `record-server2/`, `project-driver-server/`: labelled recordings.
- `R13-CONTROL-COMPARISON.json`: root's independent trace comparison.
- `server128/`: failed old Source tape; `record-server/`: rejected first harness.

The separate private AMD/X11 backend study replays the current F2 tape cleanly with
0.0 position/velocity/yaw difference against its headless reference. That is source-mode
hardware rendering evidence, not final-pack, latency, Windows or human play acceptance.
