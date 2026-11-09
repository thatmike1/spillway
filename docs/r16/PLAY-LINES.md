# R16 whole-run input lines

Both new lines finish cleanly from normal spawn on production `r16_main.gd`, with automatic runner selection, no fixture geometry, no pose/velocity restores and zero respawns. Final executions froze pushed commit `a26d94c0ccaa7fd764bbff6ed751892682b9fa05`, including the repaired `r16-style-2` service and recording session. These are coordinate-aware bots driven through ordinary engine key and mouse Input events. They prove playable lines and input-only replay, not human feel.

Evidence root: `/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r16/player-routes/`.

| final line | clean clock | ordered checkpoints | style | exact driver/executor ticks | checks |
|---|---:|---|---:|---:|---:|
| `final-a26d94c0-whiteout` | 63.3671875 s | 0, 1, 2, 3, 4, finish | 1790 | 8138 / 8138 | 15 / 15 |
| `final-a26d94c0-lab` | 14.4609375 s | 0, 1, 2, 3, finish | 1631 | 1878 / 1878 | 20 / 20 |

Every compared tick agrees exactly in position, velocity, yaw, pitch, grounding, the complete motor/duck/lab report, checkpoint, course clock, finish and respawn state. Each driver captures its final neutral-input physics step, so no executor-only tail is omitted. Standard executor reports have clean delivery, order, rate and neutral-input checks, with no movement or integrity flags. Whiteout's one legitimate duck-origin compensation is verified by the executor; neither run has an actual-travel mismatch in the production session.

## Whiteout earns the apron passage and continues the ordinary course

`tests/r16_player_routes.gd` subclasses the frozen `r15_whiteout_driver.gd`, using its ordinary node controller and `ROAD + PYLONS + CATWALK + RING + WEAVE + RELAY` data. The new approach uses the successful ApronCrouch driver's normal-spawn approach, then rejoins the existing road. No old controller or map file changes.

The actual production style service awards one **900-point airborne crouch save** against `R16Opportunities/ApronCrouch/Lintel`: 250.56 u/s entry, 9 u air lift, 1.207 u minimum room, 7.793 u standing intrusion, 1.094 m forward progress, no actual duck-hull contact. Its five gap events add 890 points. Event sum, seal outcome, finish summary, in-memory best and saved profile all agree at **1790**. The saved time best is 8111 ticks; the live and saved ghost pointers name that same valid fastest recording.

The passage happens in the full attempt. This is not the earlier short opportunity reduction or Breakwater stage practice. Breakwater's optional alternative was not pursued because Whiteout satisfies the themed-course condition.

## The lab chains bhops, a held-Space landing slide, two A/D kicks and grapple

The map is `experiment`, automatically selecting `scripts/r16_experiment_player.gd` with all three moves on. The line uses the existing rack, trench, wall chamber, mezzanine, A1 anchor and dispatch finish.

- Three completed bhop flights precede the landing slide. The opening uses A/D and integer mouse turns to reach 281.68 u/s, then holds Space into the Shift-armed landing. Slide entry is tape tick 450, grounded and ducked, with `space_held`, `held_space_ignored` and the production `slide_landing` event.
- Space releases at tick 630 and freshly presses at 631. The real motor reports `jump` at 631, leaving the slide and crossing the trench.
- In the real chamber, the next jump releases W and keeps A with one mouse count per tick. Before the west kick, the motor books **81.53 u of air gain**. The west kick fires at tick 1183 with A still held; the east kick at 1235 with D held. Neither kick needs W. Their locations are z -52.205 and -54.560 m, on the actual chamber walls. The first kick preserves its 228.20 u/s tangent. The flight spends exactly two kicks, then lands on the mezzanine; no flight exceeds two.
- E attaches the inherited grapple to **A1** at tick 1549. The bot releases it after crossing z -83 m and reaches the dispatch finish.

The run has one 600-point slide crouch save and two gap events worth 1031, totaling **1631**. Its saved time best is 1851 ticks. The style total and the live/saved fastest ghost pointer agree with the valid clean recording. This is a fresh R16 tape; no R15 tick-1291 parity is assumed or forced.

## Recordings, inputs and ghosts agree independently

There are four final `.r16run` files: driver and standard-executor recording for each line. All four read complete in the production Godot reader and the independent Python reader/analyzer. Their dense finite tick streams, stable 128 Hz timed clocks, zero-respawn clean rows and matching seals pass the repaired reader's clean-finish checks.

All binary tick and input columns match exactly across readers. JSON event/seal numbers use a stated absolute tolerance of `1e-12` for Godot parse/print rounding; the largest measured difference is `2.842170943040401e-14`. Structure, strings and booleans must match. This tolerance does not apply to tick/input binary columns or driver/executor motion comparisons.

Executor recording alignment has zero misplaced inputs: Whiteout records 125 key edges and 2226 mouse rows before its seal; the lab records 49 and 319. Every recorded key has equal physical and logical codes. Tapes also expose the final release edges after the finish, when the already sealed recording correctly stops observing. Each simulator mouse event is one emitted integer-count pair per tick; the final harness never hides multiple events by merging them.

The real ghost loader accepts all four recordings. At recorded course-clock times, 478 sampled Whiteout poses and 109 lab poses per recording agree within 1 micrometre, with zero failures. The production fastest selector and saved pointers agree on the clock and path for each isolated run directory. These directories each contain one clean candidate; this whole-run proof is not an additional multi-candidate selection challenge.

## Reproduction and package inputs

Run from `projects/foldrunner`, with a new output directory each time:

```sh
python3 tests/r16_player_routes.py --route whiteout-apron --out /home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r16/player-routes/final-a26d94c0-whiteout --expect-head a26d94c0 --replay
python3 tests/r16_player_routes.py --route lab-flow --out /home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r16/player-routes/final-a26d94c0-lab --expect-head a26d94c0 --max-ticks 4500 --replay
```

Those exact commands were executed successfully. Their `RESULTS.json` files retain every expanded command, executed source hash, engine hash, check result and cleanup receipt. The harness freezes tracked project files plus its own new tests into `/dev/shm/r16-player-routes-*`, imports only that copy, uses isolated XDG/profile/recording directories and deletes its scratch. Maximum checked scratch storage was **212.49 MiB** for Whiteout and **180.27 MiB** for the lab, below the 300 MiB cap. Standard-wrapper cleanup reports engine exit 0, neutral input and no owned processes left.

The replay uses the unchanged `tools/momentum-tape.py run ... --headless --render-fps 128 --warmup 33 --motor server128 --game-script <evidence>/replay-game.gd --game-class ''`. That generated adapter only selects the map, Source sensitivity, isolated profile and recording folder. It overrides no gameplay method. Both driver and executor settle 33 physics steps before tape tick 0; the lab uses 33 too, explicitly chosen and proven exact here rather than borrowing the old lab tape's warmup 8. Rate is 128 Hz with one physics step per render frame.

Source sensitivity is explicitly overridden to **2.5 Source units** in both setups, `m_yaw = m_pitch = 0.022`, giving `0.000959931088596881` radians per integer count. The wrapper's separate generic sensitivity multiplier remains 1.0. The tapes are strict version 2, `physics_tick`, finite 128 Hz durations, using only the accepted eight-key alphabet and integer mouse counts.

`ROUTES.json` in the evidence root contains the two full root-package specifications, each in this form:

```text
map=ID,preset=server128,tape=ABSOLUTE_PATH,sensitivity=2.5,name=NAME,warmup=33,reference=ABSOLUTE_EXECUTOR_TRACE
```

The references are full standard-executor traces, gzipped, suitable for the source/packed one-step-per-frame comparison. Package/release execution is root's separate gate, not claimed here.

| file | SHA-256 |
|---|---|
| Whiteout `driver/events.tape.json` | `1acb6bfd8b1296f1be680375767cf34378da7fefa5270d37883f12336b41b0bb` |
| Whiteout `executor/trace.jsonl.gz` | `aebf297f9306e6e94c1e49dc750b2bb4998d1f1f2fb61805a60ece147e5d1131` |
| lab `driver/events.tape.json` | `5ba1d5f6a366f4a96478e6aadc6adfc5f347f42d29897574480ef49160f11158` |
| lab `executor/trace.jsonl.gz` | `c2e351e42fd0dc70c85f8db389686859090b2e9b4cbf2022920e2f3918de22fb` |
| pinned Godot 4.7.2 editor | `8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e` |
| repaired `r16_style.gd` | `3d7e233fc66cf531bf375647161933222aa7077bf503743e2c906b080f0ebe62` |
| repaired `r16_run_session.gd` | `8705d1e1e08e4aef5c11a6216652d7e689318d029ee4a67bd4613bd0e3fe0a76` |

`FINAL-INSPECTION.json` holds all new-test/runtime hashes and the four recording hashes. Each final directory holds the compact run files, full gzipped driver/executor traces, Godot cross-reader decodes, analyzer output, profile and execution logs.

## Retained attempts and limits

`c071-whiteout-v1` and `c071-lab-v1` retain the initial c071 baseline controller and direct-executor runs. `lab-v2` adds the chained bhop start; `lab-v3` uses the standard Python executor and exposes one mouse event per tick. These development freezes name c071 HEAD and retain their actual source hashes; some include the then-uncommitted root repair, so only the `final-a26d94c0-*` directories establish the final committed runtime.

No generated line failed to finish. The genuine failed verification is `lab-v3`: the harness required exact equality after reserializing JSON event/seal numbers and rejected differences of at most `2.842170943040401e-14`. Its failed `RESULTS.json` remains. `comparator-recheck.json` passes with the documented tolerance, `lab-v4` passes the complete corrected harness, and both final committed-runtime reruns pass. Early traces also leave one terminal neutral step to the executor; the final driver records that step itself and compares every tape tick.

Total retained evidence is about **25.2 MiB**, below 35 MiB. Imports and owned scratch/processes are cleaned. The shared checkout was never imported. Only the new `r16_player_routes*.gd/.py` tests and UIDs plus this document are source changes. No production, old test, asset or helper edits, commits or pushes were made by this task.

This is headless Linux source evidence using engine-dispatched Input events, not OS keyboard/mouse input. No native player view, feel, Windows or packaged-release claim is made. Decisions and motion/scoring behavior are grounded in the seven R16 contract docs, the inherited route/test files, production runner/session/readers and commands retained above; no guessed completion is substituted for a trace.
