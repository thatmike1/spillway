# Review my run

The pause-menu review screen reads local `.r16run` attempts and compares the selected one with the fastest validated clean finish of the exact same motion identity. It does not write recordings, bests or configuration. The recent list is ordered by recorded creation time, with filenames as a stable tie-breaker.

The screen shows cumulative checkpoint times, cumulative differences and individual segment differences. Positive differences mean the selected attempt was slower. Selecting a checkpoint scrubs to that checkpoint's time in the selected attempt. The horizontal-speed traces share a course-clock axis and a metres-per-second axis. Teal is the attempt; rust is the matching best. The scrubber uses seconds after the timer starts, excluding pre-start idle ticks.

Incomplete attempts sealed by restart or quit can show reached checkpoints. Unsealed, partial, damaged and sealed-but-unrenamed files cannot be compared. A complete recording that has no timed samples also receives an explanation. A comparison best must pass the reader's full `clean_finish` validation, including clocks, flags, counts, tick density, finite poses and seal agreement. Summary scans alone never establish a best.

Comparisons require map, geometry, preset, motor version, timing, physics rate and runner identity, then use the reader's exact identity comparison for all remaining fields, including course key and overlay. A different checkpoint order is refused. An unfinished tail has no invented finish or segment loss.

## Integration

Instantiate `scripts/ui/run_review.gd` in the paused menu. Set `directory` before adding it if recordings live somewhere other than `user://r16_runs/`. Connect `closed` to free the screen and restore menu focus. The owner retains pause control. The screen processes while paused and emits `closed` on Back or Escape.

## Verification

`python3 tools/play.py --headless --script res://tests/run_review_model.gd` tests the real frozen Breakwater recording, exact identity refusal, truncated data and damaged data.

`python3 tools/play.py --headless --script res://tests/run_review_screen.gd` opens a real fixture pair, selects a checkpoint and scrubs the screen. It compares every recording filename and SHA256 before and after the review session.

`python3 tools/play.py --headless --script res://tests/run_review_performance.gd` copies a real recording to 300 temporary attempts, measures list and pair-selection costs, then deletes its temporary recordings. Engine launches use the pinned wrapper and shared lock. Import assets through the wrapper before a first UI check.

## Largest loss and follow camera

The callout names the individual segment with the largest positive loss, rather than the largest cumulative gap. If no completed segment lost time, it says so. An unfinished tail has no loss attributed to it.

The optional `attach_map(host.level, host.motion_identity())` API enables Follow camera. The preview uses an independent World3D with MeshInstance3D and MultiMeshInstance3D copies of the current map, shared immutable mesh/material resources, its own lighting, and two nonphysical capsule ghosts. No source scripts, collisions or player are copied. It interpolates recorded feet on the common course clock, holds each endpoint outside its recorded interval, and follows the selected attempt. Teal is the attempt, rust the best. Other recording identities remain available in the split/speed view and receive an explanation in the 3D view. This choice avoids displaying an old recording against a map rebuilt with different geometry.

Godot's [Viewport reference](https://docs.godotengine.org/en/stable/classes/class_viewport.html) describes independent viewport worlds. The [MeshInstance3D reference](https://docs.godotengine.org/en/stable/classes/class_meshinstance3d.html) defines material lookup used for the render-only map copies.

## Responsiveness

Folder scanning validates the existing reader's summary chain in slices with a 4 ms target, rather than blocking the first screen frame on hundreds of files. A single file read cannot be interrupted, so an exceptionally large file can exceed that budget. Only the selected attempt and plausible best candidates are decoded. Selecting the best itself reuses its already decoded track. The initial 300-attempt benchmark measured 347.326 ms listing and 64.806 ms selection before slicing and reuse. The performance check prints current timings and worst scan-slice cost; it cleans up all 300 test copies.

For static UI frames, `python3 tests/test_run_review_capture.py --out /absolute/new/external/folder` calls `tools/shot.py`'s full capture entry point with the review test harness. It retains engine pinning, snapshotting, the engine lock, private display, desktop-safety receipt and cleanup. It captures 1280×720 splits, 960×640 splits and 1280×720 follow view. These are static UI evidence, never traversal evidence. It reads two distinct frozen Breakwater finishes (44.6015625 and 55.4765625 seconds) into temporary review-only copies. The model test asserts their real 10.875 second finish difference; the screen test proves the selected attempt and best are distinct paths and that both copies remain byte-identical.

At course time zero the preview holds the last recorded pre-start feet, matching the production ghost. Its capsule follows the recorded standing/crouched state, and yaw interpolates across recorded samples. An absent recordings directory is an empty library; reviewing it does not create the directory.

## Practise the largest-loss segment

The largest-loss callout offers `Practise this segment` when the loaded map, layout and movement identity match. The screen emits `practice_requested(request)`; the pause-menu owner closes review and restores host input before calling `scripts/recordings/run_review_practice.gd.start(game, request)`. A refusal keeps the game paused and explains the missing map, checkpoint or PB recording.

The helper validates the PB with the existing production ghost loader and calls `practise_stage()` once. The player uses the authored checkpoint pose and existing zero-speed start. A temporary production ghost follows the PB's recorded checkpoint entry time, then holds the next checkpoint or finish pose. Restart, a different identity or finish retires it. Ghost preferences are preserved. The host's existing recorder creates an ordinary ineligible practice attempt; the reviewed recordings and bests stay unchanged. No recording schema is added.
