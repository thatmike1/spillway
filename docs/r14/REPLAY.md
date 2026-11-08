# R14 rate-aware input replay

P tooling decision, 8 November. Version 1 of the momentum tape (docs/momentum/TAPE.md) is
a 120 Hz claim: its `tick120` and `render30` labels cannot describe a 64 or 128 Hz
Source run. Version 2 adds an explicit per-physics-tick form at **64, 120 or 128 Hz**.
Version 1 is unchanged, and its tapes still run only at 120 Hz.

| File | Role |
| --- | --- |
| `tools/momentum-tape.gd` | executor: sets the requested rate, validates, delivers, records actual delta/rate per step |
| `tools/momentum-tape.py` | expand/validate v1 and v2, run, replay, evaluate, compare, archive, cancel |
| `tests/r14_tape_rate_game.gd` | labelled test game for the game hook: an R13 motor on a tape fixture at a declared rate, plus fault switches |
| `tests/test_r14_tape.py` | the checks below; evidence goes to outer `checkpoints/spillway/r14/tape-rates/` |

## Version 2 format

```json
{"format": "spillway-momentum-tape", "version": 2, "name": "...", "description": "...",
 "physics_hz": 128, "input_profile": "physics_tick", "duration_ticks": 384, "duration_s": 3.0,
 "mouse_quantize": "float32",
 "events": [{"tick": 0, "key": "w", "edge": "press"}, {"tick": 40, "mouse": [-3.5, 0.2]}],
 "curves": [{"kind": "mouse", "start": 24, "ticks": 72, "total": [-300, -20], "shape": "smooth"}]}
```

Events, keys, curves and mouse units mean what they mean in version 1, counted in ticks at
`physics_hz`. The header is strict, and anything unclear is rejected rather than guessed:

- `physics_hz` must be the integer 64, 120 or 128. `64.0`, `"64"` and `true` are rejected.
- `input_profile` must be `physics_tick`. `tick120` or `render30` in a v2 tape is rejected
  as a v1 120 Hz label.
- `duration_s` must equal `duration_ticks / physics_hz`. This redundancy is deliberate. If
  someone edits only `physics_hz` (a 120 Hz tape relabelled as 64 Hz), the durations no
  longer agree and the tape is refused. **Changing a header is not resampling input.**
  Event ticks are never retimed, and no command converts v1 to v2.
- Unknown header fields such as `render_fps` or `tick_hz` are rejected, as is an expanded
  tape that still carries curves, and so are tapes over ten simulated minutes.

A v1 tape at any rate other than 120 Hz is rejected and pointed to version 2. The v1
expansion of every retained tape, and of the R13 control plan, is byte-identical to the
last R13 tool (`086c9396`).

## Rate contract

1. The wrapper passes the plan's rate as `--physics-hz`. The executor applies it to
   `Engine.physics_ticks_per_second` **before** it validates the tape or builds the world,
   then rejects a tape whose rate differs from the engine's.
2. After the game's `_ready`, the run is rejected when:
   - the engine no longer runs at the tape's rate (the game set its own);
   - `Engine.time_scale` is not 1.0;
   - the game or runner **declares** a different rate. The declaration is read from
     `game.physics_hz`, then `player.physics_hz`, then `player.get_motion_state().physics_hz`.
   - nothing declares a rate and the tape's rate is not the project's 120 Hz. A probe of
     an undeclared R13 motor at 64 or 128 needs `--undeclared-rate-ok`, and `engine.json`
     then labels it an off-design probe.
3. While running, every physics step compares the engine rate, the delta handed to the
   Early (priority −1000) and Late (priority 1000) nodes, and the time scale with the
   tape's. Any change ends the run as `rate_changed` (executor exit 5) with neutral key
   release. The fault row records where, when and what changed. A preset switch during a
   tape is therefore a refusal, never a silently mixed-rate trace.

Each trace row adds `rate: {dt, dt_late, engine_hz, engine_hz_late, time_scale,
sim_dt_sum_s}` alongside the existing order fields and finite-difference displacement.
`disp_v` divides by the step's actual delta. `engine.json` records the requested, project
and post-ready rates, the declaration and its source, the rate policy, and the physics
priorities of Early, game, motor and Late. The report has a `rate` section: ok flag,
observed deltas, steps checked, the delta sum against ticks/rate, and any fault.

Delivery ordering is the v1 contract at every rate. Key edges for tick N are applied
between steps (at the end of step N−1, or from `_process` for tick 0), so they read as
pressed and just-pressed on tick N. Mouse motion for tick N is parsed at the start of
step N with `relative` and `screen_relative` both set. Actor frames (`actor/`) and
evaluator telemetry (`evaluator/`) stay separate, as in v1. That split is a directory
convention, not isolation.

## Archive, capture and storage

- `--archive` (run/replay) or `momentum-tape.py archive RUN` gzips
  `evaluator/trace.jsonl` and `frames.jsonl` after evaluation. Each file is verified by
  decompressing it to the same SHA-256 before the raw file is deleted. The uncompressed
  hash, size, line count and gzip hash go into `evaluator/archive.json`.
- `evaluate`, `replay` (`applied_tape`) and `compare` read a raw file or its `.gz`
  transparently, in memory, and write no raw file back. They refuse an archive whose
  content no longer matches its recorded hash. A `.gz` with no manifest (the R13 control
  baseline) is read and reported as unverified, and `BASELINE.json` holds its hash.
- Native runs refuse to start below **15 GiB** free on the evidence filesystem
  (`--min-free-gib`). The refusal launches nothing and keeps `run.json`, `end.json` and
  `cleanup.json`. A movie larger than `--max-movie-mib` (default 2048) is cancelled.
- `--resolution WxH` sizes the window and the private Xvfb screen. `--actor-limit N`
  keeps at most N evenly spaced actor frames plus a contact sheet. `--mp4` encodes
  `movie.avi` with libx264 at CRF 18 and deletes the AVI only when both have the same
  frame count, size and duration and the MP4 decodes cleanly (`evaluator/movie.json`).
  Compare's SSIM uses whichever movie exists, and on an MP4 that includes encoder loss.
- Default behaviour is unchanged: no archive, a 1280×720 AVI, every sixth frame.
  `tools/check-overflow.sh` and `tools/package-overflow.py` read the raw
  `evaluator/trace.jsonl` directly, so they must not pass `--archive`.
- CLI run/replay now exits 2 for `rejected` and `rate_changed`, as well as for launch and
  wrapper failures. Version 1 previously exited 0 on a rejected tape.

## What R14 main needs to expose (integration)

Root owns this. The executor already supports it through the existing game hook:
`--game-script res://<r14 main> --game-class '' --motor <preset alias>`.

- Read the preset alias from the `motor` string property before `_ready`, set
  `Engine.physics_ticks_per_second` for that preset in `_ready`, and expose that rate as
  `physics_hz`. A tape whose rate differs from the preset's is then refused after ready.
- The runner should expose `tape_step_count` (an exact one-step proof per tick), and
  `_previous_position`/`_current_position` with the Spillway meaning: the camera sits
  horizontally on their interpolation. That enables the exact camera-follow check.
  Without them, ordering falls back to state/priority consistency and the camera check to
  the coarse 0.35 m test.
- The view check assumes `yaw` changes by exactly `−screen_relative.x × k`. `k` is
  `tape_radians_per_count` if exposed, otherwise `mouse_sensitivity`. A Source player
  should expose `tape_radians_per_count = sensitivity × m_yaw` in radians. Pitch is clamped
  at `pitch_limit`, 1.4 rad if not exposed.
- `tape_body_yaw_policy = "axis_aligned"` declares Source's fixed hull orientation.
  The evaluator checks that its body yaw stays zero while the view turns. The default
  `view_yaw` policy still checks R13's body against its view. Unknown policies fail.
- Optional progress fields as in v1. A labelled non-spawn start sets `tape_start`.

Root integration reran the original 150 checks successfully. A real Source fixture then
exposed the old body-yaw assumption above. After correcting it, 76 focused checks passed,
including 18 new Source checks at 64 and 128 Hz, release-to-coast while looking around,
and a negative control which rotates a supposedly axis-aligned hull. These are labelled
fixture runs, not R14 main or packed acceptance. Root's evidence is in outer
`checkpoints/spillway/r14/tape-rates/root-source-integration/`.

## Commands

```sh
cd projects/foldrunner
E=/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/tape-rates
python3 tools/momentum-tape.py expand TAPE_V2.json
python3 tools/momentum-tape.py run TAPE_V2.json --out $E/my-run --headless --archive \
  --game-script res://tests/r14_tape_rate_game.gd --game-class '' --motor flow@128
python3 tools/momentum-tape.py run TAPE_V2.json --out $E/my-native --resolution 640x360 --mp4 --actor-limit 16 --archive \
  --game-script res://tests/r14_tape_rate_game.gd --game-class '' --motor flow@64:step
python3 tools/momentum-tape.py replay $E/my-run --out $E/my-replay --headless --archive --game-script ... --motor ...
python3 tools/momentum-tape.py compare $E/my-run $E/my-replay
python3 tools/momentum-tape.py archive $E/older-run
python3 tests/test_r14_tape.py [--only headers reject delivery repeat elapsed midrun archive cleanup legacy native] [--evidence DIR]
```

The test game alias is `<flow|r12>@<64|120|128>[:flat|step|glance][+declare-only|+switch@N|+timescale@N]`.

## Verified, 8 November 2026

`python3 tests/test_r14_tape.py --evidence $E/final-20261108` reported **150 passed, 0
failed** in 143 s. Godot 4.7.2, source mode from a dirty prepared worktree; dirty status,
diff and source copies are in each run's `run.json` and `source/`. Native runs used
OpenGL 3 on llvmpipe (software) at 640×360 on a private Xvfb.

- **Delivery at 64, 120 and 128 Hz.** Each rate ran the same time-placed tape. Five keys
  produced ten edges, including a release and a press on one boundary and a one-tick S
  hold. There were 28, 50 and 53 mouse deltas, including one at tick 0. Every edge was
  just-pressed or just-released on its own tick, and absent from the tick before. The
  grounded jump fired on its press tick (16, 30, 32). Every mouse delta arrived at the
  start of its tick with `relative` = `screen_relative` = planned, and yaw changed by
  exactly −dx × 0.0022.
- **Repeat.** A fresh run and profile at 64 and at 128 Hz differed from the first run by
  0.0 m, 0.0 m/s and 0.0 rad. The same events as v1 `tick120` and as v2 at 120 Hz produced
  identical motion.
- **Elapsed time (labelled consistency check).** One second of held W gave 64, 120 and
  128 ticks. Every engine delta was exactly 1/rate, and the deltas summed to 1.0 s. The
  game's own delta sum advanced (N−1)/rate. As an observation only, the unchanged R13 flow
  motor travelled 7.720, 7.688 and 7.685 m: it is off its design rate, and this is not an
  R14 claim.
- **Changed rate.** A game that switched the engine to 128 Hz on its 40th physics call
  under a 64 Hz tape was stopped at tick 30 as `rate_changed`. So was `time_scale` 0.5.
  Both stopped with exit 5 and neutral input, and the fault said what changed. After-ready
  refusals: a game setting 128 Hz, a game declaring 128 Hz without setting it, and an
  undeclared R13 motor at 64 Hz without `--undeclared-rate-ok`. The executor itself also
  rejects tampered plans that bypass expansion: a v1 header at 64 Hz, a v2 tape at 100 Hz,
  `duration_s` 0.5 for one second, and v2 carrying `tick120`.
- **Header rejections.** 18 malformed or conflicting headers were refused with explicit
  messages, including the header-only 120→64 relabel.
- **Archive.** Archiving replaced the raw files with gzip whose decompressed hash equals
  the raw trace. Evaluate from the archive equals evaluate from raw. Applied events,
  compare against an unarchived copy and a replay built from the archive were all exact.
  No raw trace was restored. A modified archive was refused. The R13 control trace
  shrank from 15.8 MB to 1.1 MB.
- **Native, non-120.** At 64 and 128 Hz on the step fixture, the run approached the 0.7 m
  face. The contact stop fell on the same simulated time at both rates (ticks 121 and 242,
  1.89 s), and the jump at 2.5 s recovered onto the ledge (end height 0.70 m). Across 180
  drawn frames, the camera's horizontal position was within 1.8 µm of the interpolated
  physical body. The AVIs (10.2 MB, 185 and 183 frames) became 2.1 MB MP4s that passed
  every completeness check before the AVIs were removed. 16 selected frames and a contact
  sheet were kept, and I inspected them.
- **Cleanup.** A headless 128 Hz cancel was acknowledged at tick 7007 with neutral input
  and exit 4. A native 64 Hz cancel was acknowledged and its display socket and lock were
  released. A capture over a 1 MiB movie budget was cancelled. A non-executable engine
  under a private display produced `launch_failed` with provenance, a cleaned display and
  CLI exit 2. A start below the free-space floor launched nothing. No owned Godot or Xvfb
  process remained.
- **Legacy v1.** The R13 control route through the unchanged Overflow main still finishes
  clean in 24.8916667 s with no respawn. It is identical tick by tick (0.0 m, 0.0 m/s,
  0.0 rad) to the archived baseline, and the movement flags and outcome equal the baseline
  report. Ordering is counter-verified, and the 120 Hz rate is now recorded as held. The
  v1 replay of the archived applied events was exact. In `render30`, tick and process
  injection agree. A 3 s native v1 run on the real course matched headless exactly, with
  the camera on the body. The R13 suite's headless groups (units, audit, negative,
  review: 40 checks) pass unchanged. The R13 native groups (smooth, replay, render30,
  realtime, cleanup) were not re-rendered.

Negative controls that must fail did fail. Key edges parsed inside the physics step at
128 Hz produced `edge_not_seen_by_motor_tick` on the planned ticks. A missing
`screen_relative` at 64 Hz produced `mouse_screen_relative_differs` and
`view_did_not_follow_mouse`. The rate faults, header faults and tampered archive are
above.

## Not established here

- **Source acceptance is deferred.** Every run used R13 motors through the labelled test
  game. The Source motor and the R14 main are not exercised, and passing these checks
  says nothing about CS-like movement.
- Mouse look is checked against engine-level events. Real device polling, OS input, focus
  and pointer capture are not tested.
- Replay determinism is established for the same build on this machine only.
- Native rendering is software llvmpipe, so frame times are not performance evidence.
- There is no seconds-based authoring. A tape for another rate is written for that rate,
  as the test does by placing events by time and rounding to ticks once, before expansion.
- Compare at different rates only labels the comparison. Tick n is not the same time at
  both rates.
