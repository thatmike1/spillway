# Momentum tape executor

A bounded, source-mode test tool for the R13 movement experiments, not part of the game. It plays a finite, open-loop keyboard and relative-mouse tape through ordinary `InputEvent`s at declared physics-tick boundaries. It records what the motor actually did after it ran, keeps rendered frames apart from evaluator telemetry, and replays the applied events in a fresh run. It never reads game state to choose input. After labelled setup it writes no pose, velocity, camera or progress.

| File | Role |
| --- | --- |
| `tools/momentum-tape.gd` | engine side (SceneTree script): delivery, per-tick samples, frame log, neutral end |
| `tools/momentum-tape-fixture.gd` | labelled calibration/contact fixtures `flat`, `step`, `glance` (no game rules, no HUD) |
| `tools/momentum-tape.py` | expand/validate, run, replay, evaluate, compare, minimize, cancel; owns the display and engine processes |
| `tests/test_momentum_tape.py` | end-to-end checks; evidence goes outside Git |
| `tests/momentum_tapes/*.json` | small example tapes, including one retained minimized failure |

## Tape format, version 1

```json
{"format": "spillway-momentum-tape", "version": 1, "name": "...", "description": "...",
 "physics_hz": 120, "input_profile": "tick120", "duration_ticks": 480, "mouse_quantize": "float32",
 "events": [{"tick": 12, "key": "w", "edge": "press"}, {"tick": 40, "mouse": [-3.5, 0.2]}],
 "curves": [{"kind": "mouse", "start": 24, "ticks": 72, "total": [-300, -20], "shape": "smooth"},
            {"kind": "hold", "key": "a", "start": 53, "ticks": 44}]}
```

- Ticks count physics steps from tape tick 0. Keys are `w a s d space ctrl`, and each key gets independent press/release edges. Mouse values are relative pixels: `dx > 0` turns right, `dy > 0` looks down, scaled by the game's sensitivity setting (0.0022 rad per pixel at 1.0).
- `curves` are conveniences only. `momentum-tape.py` expands them into explicit per-tick events before anything runs, and the executor rejects a tape that still has curves. `smooth` is a smoothstep stroke (accelerate, then stop); `linear` is a constant step per sample.
- Mouse deltas are rounded to float32, which is all a Godot `Vector2` carries, so the plan equals what is sent. `"mouse_quantize": "integer"` produces whole device counts and carries the remainder forward.
- Validation rejects double presses, unmatched releases, a press and release on the same tick (Godot would deliver no held tick), events outside the tape, events off the profile's cadence, and tapes over ten simulated minutes.

### Input profiles are different claims

- `tick120`: an event may sit on any 120 Hz physics tick.
- `render30`: events only on every 4th tick, which is the 30 Hz render boundary of the old `visual-play` helper. `tests/momentum_tapes/render30-batches.json` reproduces that helper's held-key batches with a constant per-sample mouse step. It reproduces the cadence, not the helper's pauses between requests or its paused decision screenshots.

Input, physics and capture rates are set separately: tape profile, `physics_hz` (120), and render/capture (`--render-fps`, default 30, with actor frames every Nth draw).

## Ordering contract

Measured on Godot 4.7.2: an action parsed *inside* physics step N reads as pressed in N but only as `just_pressed` in N+1. One parsed between steps reads as both in the next step, which is how real device input arrives. So for each physics step N:

1. **Before step N:** the key edges for tick N are applied at the end of step N−1 (or from `SceneTree._process` for tick 0 and in process injection).
2. **Early, priority −1000, in step N:** the executor samples the pre-step body and delivers tick N's mouse motion (`relative` and `screen_relative` both set), recording yaw/pitch before and after dispatch.
3. Game code and the motor run (priority 0).
4. **Late, priority 1000, in step N:** the executor samples the post-step body, then applies tick N+1's key edges.

Each trace row carries the proof: the same physics frame for both samples, and the motor's `_previous_position` equal to the pre sample's `_current_position`, with `_current_position` equal to the body afterwards. That means the motor ran exactly once between the samples. Each planned edge must appear in the motor tick's `just_pressed`/`just_released`. Tape tick 0 is always the first step of an engine iteration, so tick and process injection line up.

`--inject process` (render30 only) applies everything from `SceneTree._process`, where the old helper did. On the same tape, both injection points produced bit-identical motor results.

## Worlds and setup

- `lab` (default): the game factory hook (below) builds the real course. The default is `LabMain` from `scripts/momentum_flow_lab.gd`, used unedited with records and settings writes disabled. The game's own `restart_run()` places the runner at the **normal spawn**, and both `flow` and `r12` get the same default settings and camera.
- `fixture:NAME`: a labelled fixture. The runner is placed with one `reset_to` before tick 0, and the game's settings mapping is applied through an unattached main instance. Fixture frames carry a visible `FIXTURE ... not normal spawn` label, and `engine.json` records `start: fixture`.
- A sensitivity change is the only other setup write, through the game's `_apply_settings`. `engine.json` lists every setup write.

## Outputs

Each run writes to a fresh directory under `checkpoints/spillway/r13/tape-executor/` (outside the checkout):

- `actor/`: sampled native frames named by sequence and simulated time, `manifest.json` (sequence, file, sim time only) and a contact sheet. The game's own HUD is the only visible feedback.
- `evaluator/`: `plan.json` (expanded submitted tape), `trace.jsonl` (per tick: applied events with application point and wall time, pre/post position, post velocity, `get_real_velocity`, `get_position_delta`, finite-difference displacement, reported speed, mode, contacts, camera, observed held/just-pressed actions, ordering proof, simulation and wall timestamps), `frames.jsonl` (per drawn frame: physics step, last tick, wall time, camera and feet), `engine.json`, `report.json`, `cleanup.json`, `godot.log`.
- `movie.avi`: Godot's own `--write-movie` MJPEG. Movie frame i is the i-th `frame_post_draw` since the executor started. Frames after the end record are the lab's 8-frame quit tail.
- `run.json`: run id, config, plan hash, engine binary hash, wrapper and executor hashes, renderer/adapter/display/viewport, timing mode, input profile, sensitivity, and the source identity. The source identity covers mode (**source checkout via `godot --path`, not a frozen pack**), git HEAD, dirty flag, porcelain status, a diff hash plus `source/git-diff.patch`, and a per-file manifest of scripts, shaders, scenes, data, `project.godot` and the tape tools, with copies under `source/`. The `.godot/` import cache is not hashed.

The actor/evaluator split is a directory convention. It is not filesystem isolation, and frames-only output does not by itself establish pixel-only discovery: anything that can read the run directory can read the telemetry.

## What the evaluator judges

Each category is a separate result field; none of them is folded into an overall pass:

- **Delivery** (input reached the game as planned): applied keys versus plan per tick; observed held set versus plan; each edge visible to the motor on its tick; the mouse event's `relative`/`screen_relative` versus plan; view change equal to `−dx × sensitivity` (pitch clamped); no unplanned view change between ticks; nothing still pressed after the neutral release; no undelivered events.
- **Order**: the proof above, contiguous steps, and the motor's body yaw following the view.
- **Movement** (from actual finite-difference displacement, never from reported speed): `stuck_windows` (movement keys held at least 0.5 s with under 0.25 m/s horizontal displacement), `contact_hard_stops` (over 4 m/s approach to under 0.5 m/s on a wall contact), and jump presses with the tick each one fired.
- **Integrity**: `reported_speed_unsupported` and `post_velocity_unsupported` (the motor's speed report or post velocity disagreeing with displacement for at least 0.25 s), and `camera_detached_draws`.
- Respawns are marked as discontinuities rather than travel. `timing` reports wall time against simulated time. Under `--fixed-fps` that is compute cost, not latency.

## Commands

```sh
cd projects/foldrunner
E=/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r13/tape-executor
python3 tools/momentum-tape.py expand tests/momentum_tapes/smooth-turn-jump-strafe.json
python3 tools/momentum-tape.py run tests/momentum_tapes/smooth-turn-jump-strafe.json --out $E/my-run [--motor r12] [--world fixture:step] [--sensitivity 1.5] [--headless] [--timing realtime]
python3 tools/momentum-tape.py replay $E/my-run --out $E/my-replay [--sensitivity 1.5]
python3 tools/momentum-tape.py compare $E/my-run $E/my-replay
python3 tools/momentum-tape.py minimize TAPE --out $E/min --world lab --flag contact_hard_stops [--final-y-above Y]
python3 tools/momentum-tape.py cancel $E/my-run        # from another shell; SIGINT/SIGTERM to the wrapper does the same
python3 tests/test_momentum_tape.py [--only units audit smooth replay render30 failure negative realtime cleanup]
```

Native runs use a private Xvfb display: `:153`, or the next display from 154 to 199 with no socket and no lock file. They also use `--audio-driver Dummy`, OpenGL 3 (llvmpipe here), a 1280×720 window, isolated `XDG_*` directories under the run's `profile/`, and no desktop device input. `--headless` skips the display and frames. It is used for minimization and the negative controls, and it matched native physics exactly.

## Timing modes, budgets and cleanup

- `fixed` (default): `--fixed-fps` with the movie writer, deterministic and not wall-paced. `realtime`: no fixed fps, viewport readback every Nth draw, and the report's wall lag. Tick-scheduled delivery is exact in both modes; only wall pacing differs.
- Budgets are finite: the tape length (at most 72,000 ticks), the executor's `--wall-budget` (it stops itself with exit 3), and the wrapper's hard `--deadline`.
- Cancellation: the wrapper writes `control/cancel`; the executor checks for it every tick and process frame, releases held keys with ordinary events, verifies nothing is pressed, writes `control/cancel-ack.json` and exits 4.
- With no acknowledgement in time, the wrapper sends SIGTERM and then SIGKILL to **only its own engine process group**, then stops its own Xvfb group. It verifies that the display socket and lock are gone and that no process carries the run id or display marker. A killed engine is reported as "neutral input not observable", not as neutral.
- The normal end does the same neutral release. Paused planning, a live chunk queue and a network client are deferred. **Disconnect is not implemented** because no live client exists, so it is not tested.

## Hook for a future controller or game

The executor does not hardcode a motor. In the lab world it instantiates `--game-script` (a `res://` Node script) or `--game-class` (an inner class of it), sets its `motor` string property if it has one (`--motor` passes any string), adds it to the tree, and requires:

- **Required:** after `_ready`, a `player` property holding a `CharacterBody3D` that reads mouse look from `InputEventMouseMotion.screen_relative` and movement from the `move_*`/`jump`/`crouch` actions (`spillway_main.bind_inputs()`), with `yaw`, `pitch`, `camera`, `is_grounded()` and `get_speed()`.
- **For the ordering proof:** `_previous_position`/`_current_position` with the Spillway motor meaning, or a `tape_step_count` incremented once per motor step. Without either, the proof degrades to same-physics-frame plus priorities.
- **Optional:** `settings` with `_apply_settings()` (needed for `--sensitivity`), `request_quit(code)`, and the progress fields `respawn_count`, `checkpoint_index`, `elapsed`, `finished`, `finish_kind`, `paused` (null if absent). `tape_requested_velocity()` is recorded as requested velocity; current motors expose none, so it is reported as unavailable. `get_motion_state()` is recorded as the motor's own report in `post.motion_state`, kept apart from movement judgement.

A `CharacterBody3D`/`move_and_slide` motor keeps all the getter fallbacks: `get_real_velocity`, `get_position_delta`, slide collisions and finite-difference displacement. For example, `--game-script res://scripts/momentum_carry_lab.gd --game-class <Main> --motor <profile>` needs no executor change if that class meets the contract above. A fixture accepts `--motor flow|r12|<script path>`. A different engine would implement the same tape and trace contract rather than this script.

## Verified results, 7 November 2026

Source mode on Godot 4.7.2 (`ed1daf0bf`), llvmpipe, Xvfb `:153`. Evidence: `checkpoints/spillway/r13/tape-executor/final-20261107/` (complete suite) and `run-20261107/` (first run, whose numbers are quoted below).

- **Control:** `smooth-turn-jump-strafe` from the lab normal spawn. A smooth 300 px left stroke whose per-tick step varies more than 10×, a 24-tick mouse stop, an overshoot and a 210 px correction, and ten key edges (W, A, D, two jumps) off the mouse segments. Every edge was visible to the motor on its planned tick, and the grounded jump fired on its press tick. The airborne press at tick 131 did not fire, which is recorded as a movement observation. R12 and flow ran the same tape with identical settings, viewport and camera defaults. The native movie showed the approach, the side-wall contact and the run on.
- **Replay:** the applied relative events of the flow run, replayed twice in fresh runs and profiles, gave 0.0 m maximum position difference, 0.0 rad yaw difference and movie SSIM 1.0. A headless replay gave the same physics. The declared tolerance is 0.0 m for the same build on this machine.
- **Sensitivity:** the same applied events at sensitivity 1.5 turned the view by exactly 1.5× with no correction (end yaw 0.638 → 0.957 rad), the line diverged by up to 17.2 m, and movie SSIM against the original fell to 0.64.
- **Cadence:** `render30-batches` with physics-boundary injection and with the old helper's process-point injection gave 0.0 m and 0.0 rad motor difference over 348 ticks. Movie SSIM was 0.93, because process injection shows each turn one frame earlier at the old position.
- **Retained minimized failure:** `course-strafe-wall-stop-min.json` came from 21 headless attempts. W, a held A strafe and the first left stroke meet the crest deck's side wall: flow's velocity goes from 9.0 to 0.0 m/s on tick 97 and displacement collapses on tick 98, the same tick as the full tape. Moving the A release to before contact leaves 2.6 to 3.1 m/s instead. On the clean `glance` fixture, both flow and R12 stop dead when the strafe pushes diagonally into a plain wall at run speed (stops at ticks 71 and 82). On the course, R12's line never reached that wall. This is a reproducible input/contact outcome, not a ruling on which motor is better.
- **Approach, contact, recovery:** on the `step` fixture, running into the 0.7 m step face stops at tick 227. A jump pressed after contact recovers onto the ledge, and the frames show all three phases.
- **Negative controls** (disposable copies under the evidence `variants/`, never game code):
  - Dropping the A release was reported as a delivery error from tick 120, plus a stuck key at neutral release, with no movement flag.
  - Omitting `screen_relative` was reported as both an event-field and a camera mismatch, with no movement flag.
  - A motor variant reporting 9 m/s while pinned was rejected as `reported_speed_unsupported`, while the real motor pinned the same way showed only `stuck_windows`.
- **Cleanup:** normal end, the executor's wall budget (exit 3), SIGINT to the wrapper (acknowledged cancel, exit 4) and a frozen engine (no acknowledgement, SIGKILL of the owned group) all left no owned engine or Xvfb process, and display `:153` released its socket and lock. Neutral input was verified on every path except the killed engine, where it is reported as not observable.
- **Cost:** about 9 s of startup for the lab and about 0.35 s of wall time per native frame. The 4 s smooth-turn tape took about 56 s in total.

## Known limits

- Engine-level injection bypasses the OS, device, pointer capture, keyboard layout and focus. It does not test real mouse hardware or polling rates.
- Floating-point determinism is established only for the same build on this machine. Cross-machine replay is unmeasured.
- Native rendering is software (llvmpipe), about 0.35 s of wall time per 1280×720 frame, so fixed-fps movies are not performance evidence.
- Physics-boundary injection means a mouse turn appears in frames only after the physics step that uses it. The old helper's process-point injection showed it one frame earlier at the old position. Motor results are identical either way.
- Thresholds for stuck, hard-stop and speed mismatch are P evaluator choices, not acceptance criteria. Flags are observations, not enjoyment judgements.
