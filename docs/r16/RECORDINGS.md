# R16 recordings, analysis and ghost

Every played attempt is written to its own file in user data. A Python tool with only the standard library reads copied files (one or a whole folder) and summarises them. The fastest clean finished recording for the exact course identity can be shown as a nonphysical ghost.

Owned files: `scripts/r16_run_recorder.gd`, `scripts/r16_run_reader.gd`, `scripts/r16_ghost.gd`, `tools/analyze-r16-runs.py`, `tests/r16_record_adapter.gd`, `tests/test_r16_record.gd`, `tests/test_r16_record_format.py`, `tests/r16_record_native.gd`, `tests/r16_record_native.py`.

## Where the files are

Default directory: `user://r16_runs/`. On Linux that is `~/.local/share/godot/app_userdata/<project name>/r16_runs/`, on Windows `%APPDATA%\Godot\app_userdata\<project name>\r16_runs\` (exported builds with a custom user dir use that instead). Mike copies the whole folder; nothing is uploaded.

| name | meaning |
|---|---|
| `<run_id>.r16run` | complete: sealed, then atomically renamed. The only state a ghost or a best run may use. |
| `<run_id>.r16run.part` | being written, or the writer stopped: a crash, a kill, or a write failure. |
| `<run_id>.r16run.aborted` | ended by `abort(reason)`: the stream is intact up to an ABORT chunk, but not sealed. |

`run_id` is `<map>_<preset>_<YYYYMMDD-HHMMSS>_<ms>_<8 hex>` from the local clock, lowercased, with anything but `a-z 0-9 -` replaced by `-`. File names are labels only: the reader decides the state from the bytes, and refuses to call a `.part` file complete even when its content is sealed (`sealed-unrenamed`).

## Recorder API (`r16_run_recorder.gd`, `extends RefCounted`)

| call | behaviour |
|---|---|
| `begin_run(metadata: Dictionary, directory := "user://r16_runs/") -> Dictionary` | creates the directory, opens `<run_id>.r16run.part`, writes the header. Returns `ok, status, path, run_id, final_path` or `ok=false, error`. Refused while a run is open, when `enabled` is false, when the header JSON exceeds 64 KiB, or on a double-precision engine build. |
| `capture(sample: Dictionary, events := []) -> void` | one post-step sample (INTERFACES.md fields). `events` are this tick's style events (Dictionaries; recorded with kind `record_kind` or `"style"`). |
| `event(kind: String, data := {}) -> void` | a lifecycle event, stamped with the last captured tick (`-1` before the first sample). |
| `finish(outcome: Dictionary) -> Dictionary` | flushes, writes the SEAL chunk, closes and renames to `.r16run`. Returns `ok, status, error, path, run_id, counts, dropped_ticks`. |
| `abort(reason: String) -> Dictionary` | flushes, writes an ABORT chunk, renames to `.r16run.aborted`. |
| `is_open() -> bool`, `status`, `last_error`, `counts()`, `dropped_ticks`, `enabled` | `status` is `idle, open, complete, aborted, disk-error, error, disabled`. |

The recorder only observes. It never reads or writes the body, input, physics, progress, best times or config. Per-tick work is appending to packed columns (measured headless on the R15 host: median 51 µs, p99 114 µs per `capture()`, worst 819 µs on a chunk write, against a 7.8 ms tick). Compression, SHA-256 and the write happen once per chunk: every 256 ticks (2 s at 128 Hz), or sooner at 4096 input events or about 64 KiB of event JSON. Memory stays bounded at one chunk.

Metadata is root's. Recommended keys: `map`, `preset`, `attempt`, `start_reason` (`spawn`, `restart`, `practice`, `map`, `preset`), `build`, `practice_stage`, and `identity`. **`identity` is the dictionary a ghost must match exactly**, so it should hold what makes runs comparable as motion: map, preset, geometry and overlay identity, physics rate and the mechanics/motor version. Keep the style/scoring version elsewhere in metadata (for example `scoring`), so a new score rule does not throw away ghosts. A ghost identity must name at least `map` and `preset`. Vectors, transforms, NaN and objects in metadata are converted to JSON-safe values (`[x, y, z]`, `"NaN"`, `"<Object>"`); nothing is variant-encoded.

### What each tick stores

Every captured sample becomes one row, with no subsampling: `tick`, `flags`, `dt`, `elapsed`, `physics_hz`, `checkpoint`, `respawns`, `p`, `reference_p`, `v`, `actual_v`, `yaw`, `pitch`, `held`. Vectors are stored as the engine's float32 components, which is exact for Godot's single-precision `Vector3`. `dt`, `elapsed`, `yaw` and `pitch` are float64, exactly as GDScript holds them. `flags` bits: 0 started, 1 finished, 2 clean, 3 grounded, 4 ducked. `held` is a 64-bit mask of the sample's `held` actions, with bit order announced by `held_names` events (names are sorted when first seen; more than 64 names go to `held_extra` events).

Every element of `input_events` becomes one input row, in order, stamped with the sample's tick. InputEvent objects and the dictionary forms below are accepted:

| kind | code | flags | aux | x, y | x2, y2 |
|---|---|---|---|---|---|
| 1 key | keycode | bit0 pressed, bit1 echo | physical keycode | 0 | 0 |
| 2 mouse button | button index | bit0 pressed, bit2 double click | 0 | wheel factor, 0 | 0 |
| 3 mouse motion | 0 | 0 | 0 | `screen_relative` (what the Source look reads) | `relative` |
| 4 action | index announced by an `action_name` event | bit0 pressed | 0 | 0 | 0 |
| 5 joypad button | button index | bit0 pressed | device | 0 | 0 |
| 6 joypad motion | axis | 0 | device | axis value, 0 | 0 |
| 7 other | 0 | 0 | 0 | 0 | 0, plus an `input_other` event with its text |

Dictionary forms: `{"type": "key", keycode, physical_keycode, pressed, echo}`, `{"type": "mouse_button", button_index, pressed, double_click, factor}`, `{"type": "mouse_motion", relative, screen_relative}`, `{"type": "action", action, pressed}`.

`motion` and `stats` dictionaries are not stored per tick. The recorder derives sparse events from them and from the flags instead (source `"recorder"`):

| event | when |
|---|---|
| `timer_start`, `timer_reset` | the started flag rises or falls |
| `finish_line` | the finished flag rises (with elapsed and clean) |
| `clean_lost` | the clean flag falls (with `practice_reason`) |
| `checkpoint` | the checkpoint index changes (`from`, `to`, `elapsed`) |
| `respawn_count` | the respawn counter rises |
| `context` | any of checkpoint, respawns, practice_reason, physics_hz, dt, `motion.mode`, `motion.motor_version`, `motion.experiment.enabled` changes (changed keys only) |
| `motion` | the tick's motor events: `motion.events`, plus `motion.duck.events` and `motion.experiment.events` names not already listed (for example `jump`, `perfect`, `land`, `step`, `duck_air`, `unduck`, `wall_jump`, `slide`) |
| `hop` | `stats.hops` rose: the strafe stats' `last_hop` (takeoff, landing, gain, contact, air, sync...) |
| `tick_gap` | a sample's tick is not the previous + 1 (`expected`, `got`) |
| `sample_missing` | a mandatory sample field is absent (once per field; its zero value is stored) |

Root's `event()` calls carry source `"event"`, style events passed to `capture()` source `"capture"`.

## Attempt lifecycle (contract for root)

- **One file per attempt.** Begin at spawn, R, F/stage practice and after a map or preset change. Root decides the outcome kind; the tests use `finish`, `restart`, `practice`, `map`, `preset`, `quit`.
- **Boundary edge.** The R/F press that ends an attempt is delivered before the next physics step. Record it in the old attempt, as the data of its boundary `event()`, then `finish()`, then `begin_run()` for the new one. Do not put it in the new attempt's first tick.
- **Finish.** Seal on the sample where the game reports finished, with `outcome = {kind: "finish", clean, finish_kind, time, respawns}`. Untimed exploration after the line is not recorded; the next R starts a new file.
- **Falls and respawns** stay inside the attempt: an `event("respawn", ...)` plus the derived `respawn_count`. A clean finish therefore has zero respawns.
- **Ticks** are attempt-local and start at 0. Idle ticks before the timer starts are recorded like any other; `timer_start` marks where the course clock begins. A clean recording is still small: an idle minute at 128 Hz compresses to a few kilobytes.
- **Pause.** Paused steps are not physics steps, so there are no samples. Root sends `event("pause")` and `event("resume")`. Likewise settings, loadout, preset or map changes that do not end the attempt are `event()` calls with the new values.
- **Quit** seals the open attempt with `outcome.kind = "quit"` before the tree exits. A process that dies without that leaves a `.part` file, which the reader recovers as partial.
- **Programmatic and test games** record only into a directory root gives them (`--r16-recordings=DIR`); `--no-run-recordings` disables recording. `--no-records` is best/config persistence and is unrelated.

## Byte layout (format version 1)

All integers are little-endian unsigned unless marked. The engine refuses to write on a big-endian platform or a double-precision build.

```
prefix (16 bytes)
  0  8  magic "FRR16RUN"
  8  2  u16 format version = 1
 10  2  u16 reserved = 0
 12  4  u32 header_len (<= 65536)
header
 16  header_len  UTF-8 JSON object: format "foldrunner-r16-run", version 1, run_id, created_unix, created_utc,
                 engine, os, vector_precision "single", units {length m, velocity m/s, angle rad, time s},
                 metadata {...}, identity {...}
     32  digest0 = SHA-256(prefix + header JSON)
chunks, repeated
  0  4  magic "CHNK"
  4  1  type: 1 TICKS, 2 SEAL, 3 ABORT
  5  1  codec: 0 raw, 1 zlib (RFC 1950 stream; Godot COMPRESSION_DEFLATE)
  6  2  u16 reserved = 0
  8  4  u32 sequence, 0, 1, 2...
 12  4  u32 raw_len (<= 8 MiB)
 16  4  u32 stored_len (<= 8 MiB; equals raw_len for codec 0)
 20  4  u32 first_tick (TICKS; 0 otherwise)
 24  4  u32 tick_count (TICKS; 0 otherwise)
 28 32  digest = SHA-256(previous digest + bytes 0..27 of this chunk + the stored payload)
 60  stored_len  payload
```

TICKS payload after inflating, n ticks and m inputs, each column contiguous:

```
u32 n
i32 tick[n]; i32 flags[n]; f64 dt[n]; f64 elapsed[n]; i32 physics_hz[n]; i32 checkpoint[n]; i32 respawns[n]
f32x3 p[n]; f32x3 reference_p[n]; f32x3 v[n]; f32x3 actual_v[n]          (x, y, z interleaved)
f64 yaw[n]; f64 pitch[n]; i64 held[n]
u32 m
i32 tick[m]; i32 kind[m]; i32 flags[m]; i64 code[m]; i64 aux[m]; f32 x[m]; f32 y[m]; f32 x2[m]; f32 y2[m]
u32 j
j bytes UTF-8 JSON array of events {"t": tick, "q": sequence, "k": kind, "s": source, "d": data}
```

A chunk may have n = 0 (events only). Event sequence numbers `q` are dense across the whole file. The SEAL payload (raw JSON) is `{outcome, counts {ticks, chunks, inputs, events, gaps, bytes}, first_tick, last_tick, timer_start_tick, finish_tick, final {tick, elapsed, started, finished, clean, checkpoint, respawns, p}, ended_unix}`; ABORT is `{reason, counts, last_tick, final, ended_unix}`. Nothing may follow the end chunk.

Units: metres, metres per second, radians, seconds; `p` is the actual feet, `reference_p` the feet without outstanding duck-origin compensation, `v` the stored velocity and `actual_v` travel excluding hull compensation, exactly as root's sample defines them. Measured size: the 7 s fixture clean run is 23 bytes per tick (925 ticks, 21.6 KB); 6 s of Breakwater strafing with mouse motion is 25 bytes per tick (776 ticks, 19.4 KB); synthetic noise in every column is 40 bytes per tick. Short attempts cost more per tick because of the header (about 2.5 KB).

## Integrity, damage and recovery

The digest chain makes every chunk depend on the header and all earlier chunks, so truncation, a flipped bit, a reordered, duplicated or spliced chunk, or a wrong sequence number is detected at the first bad chunk, before anything is inflated. zlib's Adler-32 then checks each inflated payload. Every length is bounded before it is read, and inflation is capped at the declared size.

What it does not prove: the chain has no key, so it is integrity against damage, not authenticity. Anyone can write a consistent forged file. A recording is observational evidence of what this game sampled on that machine, not a promise that replaying its input reproduces the motion elsewhere.

Recovery: the reader returns every chunk whose chain verified, up to the first bad one, as `partial`, with `valid_bytes`. That proves those ticks, inputs and events were written in that order by a writer that produced this header. It does not prove when or how the attempt ended, its outcome or its totals, and the last up to 2 s of play before a crash (the unflushed chunk) are absent. Partial and aborted recordings are analysed and labelled as such, never used as a ghost or a best.

Write failures: after each chunk the recorder flushes and compares the file's length with its own byte count. A failed or short write (disk full, quota, file-size limit, permissions) sets `status = "disk-error"` and `last_error`, pushes one engine error, closes the file and leaves it as `.part`. Later `capture()` calls only count `dropped_ticks`, and `finish()` returns `ok = false` with the reason. Nothing else is written, and the recorder never touches the best/config file, so a failed recording cannot corrupt them. Root should show `last_error` once and keep playing.

## Reader (`r16_run_reader.gd`) and helpers

`READER.read(path, decode := true)` returns `ok, status, errors, header, seal, abort, chunks, valid_bytes, columns, inputs, events`. `status` is `complete`, `aborted`, `partial`, `sealed-unrenamed` or `invalid`; `ok` is true only for a complete, error-free stream in a `.r16run` file. `columns` holds `PackedInt32Array`/`PackedFloat64Array`/`PackedInt64Array` columns and `PackedVector3Array` vectors; `inputs` the nine input columns. `decode = false` verifies the whole chain and reads header, seal and abort without inflating tick chunks.

Helpers for root: `identity_matches(recorded, expected) -> String` ("" when equal), `clean_finish(run) -> {ok, time | error}`, and `fastest_clean(directory, expected_identity) -> {ok, path, time, considered, rejected}`. That last one verifies every candidate's chain, so call it once per map/preset load, not per frame. Root chooses and remembers the best path in its own R16 config.

The reader parses JSON with `JSON.parse_string` and binary with fixed offsets only. It never uses `str_to_var`, `bytes_to_var`, `load()` or resources, so a copied file cannot execute code or pull in a resource.

## Ghost (`r16_ghost.gd`, `extends Node3D`)

- `load_run(path, expected_identity) -> {ok, error | run_id, time, ticks, path}`. Refuses anything but a `.r16run` file that reads strictly complete, whose header `identity` equals `expected_identity` exactly (integral JSON numbers compare as integers), and whose seal outcome is `{kind: "finish", clean: true}` with a clean, finished, zero-respawn last sample and recorded timer start and finish ticks. A refusal clears any earlier ghost, so a ghost from another map, preset, geometry or mechanics identity never lingers.
- `set_time(elapsed_s)` takes the course clock. Time 0 is the timer start; the ghost waits at the last pose before the timer started, interpolates feet (lerp), yaw (shortest angle) and pitch between the bracketing recorded ticks, and holds the finish pose after the line. At a recorded tick time it stands exactly on the recorded feet.
- `clear()`, `visible` (Node3D), `pose_at(t)`, `fade()`, `loaded`, `run_time`, `near_hide_m`, `near_fade_m`, `trail_seconds`.
- Visual: an unshaded, translucent capsule (1.75 m standing, 1.30 m when the recording was ducked) with a small visor showing yaw and pitch, and a line trail of the last 0.8 s at the feet. It never writes depth or casts shadows. The body fades by distance from the active camera: hidden within 1.5 m, full alpha (0.32) from 6 m. This keeps a ghost in the player's eye, or just ahead of it, from hiding the landing.
- It owns no collision object, never reads or writes the player, and cannot trigger checkpoints, finish or kill bounds. Root adds it under the level, calls `set_time(game.elapsed)` each frame and exposes the toggle.

## Analysis (`tools/analyze-r16-runs.py`)

```sh
python3 -I tools/analyze-r16-runs.py PATH... [--json OUT] [--loss-min 0.75] [--quiet] [--strict]
```

PATH is a file or folder (searched recursively for `*.r16run`, `*.r16run.part`, `*.r16run.aborted`; other files are listed as ignored). Each file is read and analysed on its own; a malformed file is reported with its status and errors and never stops or changes its neighbours. Exit status is 0 when every path was read, 2 for a missing path, and with `--strict` 1 when any recording is not complete.

Per run, the JSON report holds: status, errors and a recovery note; identity, metadata and outcome; `ended_by`; ticks, gaps and physics rates; timer start, finish tick and final clock; `travel`, horizontal and 3D distance integrated from `actual_v` (so hull shifts and teleports add nothing) and top speed; `discontinuities`; `line`; `checkpoints`; `lifecycle`, falls and event counts; `style` totals and points by kind; `hops` and mean sync; `inputs` by kind with key presses by name and total mouse motion; and `speed_losses`.

- **Discontinuities.** Per tick, the step of `p` and of `reference_p` is compared with `actual_v * dt`. If either moves exactly with travel while the other does not, or the duck state or compensation (`p - reference_p`) changed, and the residual is at most 0.30 m (a Source air duck is 9 u = 0.2286 m), it is a **hull shift**: an air duck or stand moving `p`, or the host settling its compensation on the ground moving `reference_p`. A larger residual is a **teleport**: `respawn` when the respawn counter rose or a fall/respawn event names that tick, `lifecycle` for restart-type events, otherwise `unexplained`. Residuals under 0.1 mm are ignored; smaller unexplained ones are counted as `minor_residuals`.
- **Spatial line.** `reference_p` every 0.25 s and at breaks, as `[x, y, z, elapsed]`, split into segments at teleports, with bounds and the lowest y.
- **Speed losses.** Drawdowns of horizontal `|actual_v|`, never across a teleport. A section starts where the speed begins to fall from its running peak and ends at the lowest point before it recovers by a third of the drop (at least 0.25 m/s). Sections losing `--loss-min` m/s or more are listed, largest first, with ticks, clock, speeds (m/s and u/s), positions, checkpoint, grounded fraction, view turn, held keys at both ends, the events and motion events inside, whether it was timed, and a labelled heuristic (`mostly grounded`, `air section ending on a landing`, `airborne: collision, air law or turning`). The heuristic is a reading aid, not a diagnosis.
- **Checkpoints** give time, distance and average speed per stage from the timer start.

The human summary prints a few lines per file and a status count.

## Tests and evidence

```sh
# from a source copy with an imported project (never the shared checkout), isolated XDG dirs:
godot --headless --audio-driver Dummy --fixed-fps 128 --path SRC --script res://tests/test_r16_record.gd -- --out=OUT/godot > OUT/godot.log 2>&1
python3 -I tests/test_r16_record_format.py --run OUT/godot --out OUT/py/result.json --log OUT/godot.log --godot GODOT --project SRC
python3 -I tests/r16_record_native.py --evidence DIR --project SRC     # private AMD/X11 display, /home >= 15 GiB only
```

`test_r16_record.gd` covers 59 checks in five groups:

- **format:** labelled synthetic samples (not gameplay) over three chunks, covering every column, input kind, event source, a deliberate tick gap and a missing field, read back exactly.
- **states:** abort, a crashed `.part`, refusals and an empty attempt.
- **disk:** the labelled byte-limit hook and an unwritable directory.
- **host:** the real, unchanged R15 host on the labelled loop fixture, driven only by key and mouse events through `Input`. It records five attempts (clean finish, restart, fall then practice, practice finish, quit), each sealed by the labelled adapter `tests/r16_record_adapter.gd`, which stands in for root's wiring. It then replays the clean run three times: without the ghost, with it, and without it again. Motion with the ghost equals motion without it tick for tick (p, v, yaw, pitch, clock, checkpoint). It also covers ghost alignment and fade, and refusals of wrong preset or geometry, restart, practice and quit runs, a corrupted copy, a `.part` name and an empty identity.
- **breakwater:** the real default map and preset with strafing hops, air crouches, a restart and a quit.

The log must hold exactly five deliberate refusal lines (`EXPECTED_LOG` in the Python test) and no other engine error.

`test_r16_record_format.py` covers 38 checks:

- **Cross-reader:** byte equality with Godot's decode for all 14 tick and 9 input columns. Godot's zlib chunks are plain zlib streams.
- **Mutations:** every truncation at and around each chunk edge, plus a spread, is never complete and recovers exactly the whole verified chunks. 300 seeded bit flips are never complete and never yield a changed value. Also refused: a newer version, wrong magic, trailing bytes, swapped chunks, a sealed `.part`, and empty, text and random files. Consistent forgeries with recomputed digests are refused by the bounds: an oversized raw length, a lying inflated size, a NaN JSON token.
- **Analysis semantics** of the host and Breakwater runs.
- **A mixed folder:** valid runs plus truncated, flipped, future-version, empty, aborted, crashed and non-recording files. Every valid neighbour is analysed exactly as it is alone.
- **A real OS write failure:** the Godot suite's `--phase=rlimit` under `RLIMIT_FSIZE` 48 KiB with SIGXFSZ ignored. The kernel refuses the write with EFBIG, the recorder reports `disk-error`, counts the dropped ticks and leaves a `.part` the Python reader recovers as partial.

Evidence lives outside Git in `checkpoints/spillway/r16/recordings/`.

## Limits

- Inputs reach the game through `Input.parse_input_event` in headless tests: real engine input dispatch, not OS keyboard or mouse. Root's integration must feed `input_events` from actual event delivery.
- The adapter is a test stand-in. The sample, boundaries and outcome kinds in a shipped build are root's, and its R16 main is not yet exercised here.
- The ghost was inspected natively once with the earlier 1.2–3.0 m fade (`native-ghost-1`). The current 1.5–6.0 m fade is checked headless only: a second native render was refused because /home had fallen below 15 GiB.
- Nothing here claims human feel, Windows behaviour or replay determinism across machines. Speed-loss causes are heuristics.
