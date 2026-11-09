# R16 playable host

`scenes/r16.tscn` runs `scripts/r16_main.gd`: the frozen R15 courses, presets and approved runner, with style scoring, a recording of every attempt, a best-run ghost and the reworked Movement Lab. R15 (`r15_main.gd`, `scenes/r15.tscn`) stays the unchanged reference.

| file | role |
|---|---|
| `scripts/r16_main.gd` | the game. A self-contained copy of the R15 main in its own namespace (build id, profile, CLI flags, preset actions). Its physics callback is R15's line for line. |
| `scripts/r16_run_session.gd` | attempt session: opens, samples and seals attempts; owns the style service, the recorder and the ghost. Only reads the game. |
| `scripts/r16_hud.gd` | R15's HUD plus the style panel, the style best, the ghost switch, the recording line and R16 wording. |
| `scripts/r16_launch.gd`, `scenes/r16.tscn` | launch: the scene persists records and records attempts. |
| `scripts/r16_style_opportunities.gd` | the optional solid style passages on Breakwater and Whiteout (`docs/r16/OPPORTUNITIES.md`); the main adds them, the builder owns them. |

```sh
godot --path . res://scenes/r16.tscn [-- --no-records] [-- --r16-profile=PATH]
  [-- --r16-recordings=DIR | --no-run-recordings] [-- --r16-preset=ID] [-- --r16-map=ID]
  [-- --r16-source-sensitivity=S] [-- --r16-standin-runner=r14]
godot --path . --script res://scripts/r16_launch.gd      # same, physics rate set before the world
```

## Controls (new in R16)

- **G**: ghost on or off (also the menu switch "Ghost of the fastest clean recorded run"). G is bound only when no other action uses it; the menu switch always works. The setting is saved.
- Everything else is R15's: F2 / F5 presets, Ctrl or C crouch, R restart, F last checkpoint, Esc menu.
- Movement Lab: the copy is `docs/r16/LAB.md`'s. "Space at a wall: kick off, 2 per landing, each wall once (A/D can stay held)". "Shift in the air before landing: slide on landing; release and press Space to hop out". Grapple unchanged (hold E). 1 / 2 / 3 toggle the moves.

## When the game samples (the post-step sample)

Godot calls the main's physics callback before its children. So in frame N the host first does R15's bookkeeping on the body left by motor step N-1 (a preset switch waiting for room, timer, kill bounds and respawn, checkpoints, finish), then the runner takes motor step N, then the strafe stats (priority 100) read it. R16Session runs at **priority 999**, after the stats and before any priority-1000 observer (the tape executor's and pack probe's Late nodes), and takes sample N from the body exactly as motor step N left it, with the host state as that frame left it. This is the accepted R15 tape-trace convention, so recordings and tape traces read alike.

- Sample N is stepped through style and written before frame N+1 starts, so a switch, respawn or reset in frame N+1 is never attributed to motor step N.
- Priority 999 matters: a tape executor injects the next tick's key edges from its priority-1000 node. With the session after it, 213 input rows of the Breakwater tape land one tick early (negative control, retained); at 999 all 149 key edges and 4,820 mouse rows land on their own tick.
- `actual_v` is the runner's own `get_motion_state().actual_velocity`: its displacement over its own step from where the step began (after any host placement), excluding duck-origin compensation, in m/s. On every continuous tick the session checks it against `(p − previous p − motion.duck_shift) / dt` and counts disagreements over 1 mm/s (`session.actual_v_mismatches`). A runner without the field gets the finite difference, reset at every placement.
- `held` is `Input.is_action_pressed` for the movement, look, jump, crouch, slide and grapple actions at the sample. `input_events` are copies of every event the main's `_input` received since the last sample, in delivery order (key physical and logical codes, mouse `relative` and `screen_relative`, buttons and wheel, joypad), each followed by an action row for every non-UI action it matches. Nothing is consumed.

## Attempts and recordings

One file per attempt, in `user://r16_runs/` by default (`docs/r16/RECORDINGS.md` has the format, the analysis tool and the exact Linux and Windows folders). The player scene records; anything built with `new()` records only when given `recordings_dir` and `record_runs = true`; a headless run records only into a folder named with `--r16-recordings=DIR`. `--no-run-recordings` turns recording off; `--no-records` is the profile only and does not stop recordings.

| boundary | the old file | the next file |
|---|---|---|
| spawn (start of the game) | none | begins, `start_reason` spawn |
| R / menu Restart | `restart` event with the R press as `edge`, inputs delivered before it in that batch, sealed `kind: restart` | begins after the body is at the spawn |
| F / menu stage practice | `practice`, same | begins as practice (`clean_at_start` false) |
| map (menu) | `map`, sealed before the level is freed | begins with the new map |
| preset (F2, F5, menu; or a waiting switch applied inside the physics callback) | `preset`, sealed before the switch | begins at once, the attempt continues (practice unless untouched); inputs before the edge in the same batch stay with the new file, since the body keeps moving |
| lab loadout (1, 2, 3, menu) | `loadout`, same as preset | same as preset |
| finish line | the finish sample is captured, then sealed `kind: finish` with clean, time and integer `time_ticks`, respawns, style score | none until R, F or a map: untimed play after the line writes nothing |
| quit (menu, window close, game freed) | `quit` | none |
| fall / respawn | stays in the file: `respawn` event, style discontinuity, travel check restarts | |
| pause / resume | `pause` and `resume` events carrying the Esc edge; paused frames take no sample | |
| settings | `settings` event with the new value and look rate per count; a look change is a style discontinuity that keeps the combo | |
| ghost toggle | `ghost` event | |

Header metadata (`recording_metadata()`): map, preset, attempt, start reason, practice stage, clean at start, timer state; `identity` = `motion_identity()`; `scoring` (style identity and key, timing rules) kept outside the identity; the full `record_identity`; physics (rate, family, motor version, runner, stand-in, Source fingerprint, hull, mechanics); `look` (sensitivity, m_yaw, m_pitch and radians per count, FOV); `laws` (approved R15 or experimental, each named); lab loadout; the overlay id; the sample convention.

A write or open failure is shown once on screen and pushed as a warning; play continues and the file stays `.part` (`docs/r16/RECORDINGS.md`).

## Records: `user://spillway_r16.cfg`

- **Time**: R15's sections, integer ticks, now keyed by the R16 record identity (`r16-timing-1`, plus the overlay id). No R15 or R14 record is read.
- **Style best**: section `style_<hash of time key and style rule key>`: the integer score of the best clean whole-map run (a clean finish of every stage) under those exact style rules. Practice, respawns, mid-run preset or loadout changes and open lines show their score but never save it. New style rules start fresh bests and leave times and ghosts alone.
- **Ghost pointer**: section `ghost_<time key>`: the absolute path, run id and integer time of the fastest clean complete recording. Written only after that recording sealed and read back as a complete clean finish for this identity; an equal time keeps the earlier file. On load the pointer is verified by the ghost reader; if the file is missing or refused, one scan of the recording folder (per identity and process) finds the fastest valid file, and a dead pointer is dropped at the next save.
- Saving writes a temporary file beside the profile and renames it over the old one; if the rename is refused a direct save follows. A failed save is shown once and the bests stay in memory.
- First launch with no R16 profile may read R15's look settings (sensitivity, FOV, volume, m/s line) from `spillway_r15.cfg`, once, read-only. Nothing older is ever written.
- `new()` games keep every best in memory only.

## Style passages

`_build_level()` calls `r16_style_opportunities.gd`'s `apply(level)` once per built level: after `build()`, the art and readability dressing and the kill bounds, with the level in the tree, before any identity is taken. Breakwater gets `RunwayCrouch` and `RunwayThread`, Whiteout Relay `ApronCrouch`; every other map, the fixtures and the lab get nothing. `game.opportunities` keeps the report.

`course_geometry` stays the frozen base `geometry_hash()`. `overlay_id` says what was added on top: `r16-opportunities-1:<report hash>`, or `r16-opportunities-1:none (non_target_map)` where nothing was. Both sit side by side in `record_identity()` (so in every time, style and ghost key) and in `motion_identity()` (`geometry`, `overlay`). Recording headers also carry `opportunities` (version, applied, reason, hash, the base hash and the passage names). A target map that refuses the passages for any other reason (an unbuilt level, a name clash) is pushed as a warning and its identity says why. Bests and ghosts from before the passages carry a different key and are not matched.

## Ghost

The fastest clean recorded run for the current `motion_identity()` (map, geometry, overlay, preset, runner and motor, rate, physics, hull, loadout, timing rules; no style rules). Nonphysical, no collision, no progress. It takes the course clock between the last two samples (like the runner's camera takes its feet) so an equal run overlaps at every frame; it waits at the start before the timer and holds the finish pose after the line; it fades out near the player's eye (the reader's 1.5–6 m fade, checked headless only). Hidden during practice from a later stage, whose clock does not match.

## Integration hooks (root)

- `game.session`: `recorder`, `style`, `ghost`, `last_sample`, `last_seal`, `sealed`, `attempt_live`, `ghost_path`, `ghost_ticks`, `ghost_state`, `actual_v_*`.
- `game.motion_identity()`, `recording_metadata(reason)`, `look_metadata()`, `law_labels()`, `style_best`, `previous_style_best`, `style_new_best`, `style_state`, `finish_style`, `ghost_pointer`, `ghost_new`, `ghost_shown()`, `toggle_ghost()`.
- `opportunities` (the overlay report) and `overlay_id` (its explicit identity), set by `_build_level()` for every map.
- A pack or tape observer should run at priority 1000 or later.

## Evidence and limits

Executed headless on Godot 4.7.2 (SHA-256 `8d106cbe…`), on an imported copy of the source, never the shared checkout. Inputs go through `Input.parse_input_event` and viewport pushes, not OS input. Compact results are in `checkpoints/spillway/r16/product-loop/` outside Git, with the source hashes they ran (`SOURCE-HASHES.txt`).

- `tests/test_r16_loop_tapes.py --all --recordings --routes-file …/r15/release-plan/ROUTES.json`: 31 plays, 0 failed, with the style passages in place. All 14 accepted R15 course tapes (Breakwater basic and return, Whiteout, Sunken, Rainline, Night Shift, Penstock, Overflow F2/F5, crouch and duct lines, Night F5 earned) replay through the R16 main with position, velocity and yaw differences of 0.0 and no game-state difference, plain and with recording on. Each recording matches the trace tick for tick; every key edge and mouse row sits on its own tick; each seal's style score is the sum of its style events, none after the finish. The Breakwater recording names overlay `r16-opportunities-1:2590f2e5…` beside the base geometry hash.
- `lab-combined` is a known law difference, not parity: the R16 wall-jump rule (2 per landing, each wall once) refuses a third air kick the R15 lab allowed, from tick 1291. The same tape with the R15 lab runner on the R16 host is exact (control play).
- Negative control: the session at priority 1001 (after the tape's Late node) puts 213 input rows one tick early; kept in `tapes/negative-priority1001-summary.json`.
- `tests/test_r16_loop.py`: 13 driver checks and 118 engine checks, 0 failed, 32 recordings all read complete from a copied folder; damaged neighbours (truncated, flipped byte, empty, a text file) are labelled and leave every valid report unchanged. Groups: isolated `new()`, lifecycle (R, F, map, quit, pause, fall, finish, style best), preset (F2/F5 mid-run), pending switch (a waiting hull switch inside the physics callback, a hop on the new body's first step, no old step in the new file), ghost (parity shown, hidden, absent), lab (runner, identity, loadout boundary, landing slide then hop), HUD/menu, overlay (passages, base hash, identity, headers per map) and persistence across processes (R15 profile bytes unchanged, moved and corrupt ghost files).

Not covered: the lab's wall jump is exercised through the R16 main only by the `lab-combined` tape, not by a loop-test reproduction. No native window was run: HOME free space was below the 15 GiB floor (14.6 GiB at the last check), so the menu, finish panel, ghost and passages have not been looked at on screen. The fixture levels are labelled test geometry. Nothing here says how anything feels, and nothing was run on Windows.
