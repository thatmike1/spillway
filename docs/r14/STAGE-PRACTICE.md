# R14 stage practice

P product decisions, 8 November 2026. The pause menu can start an unrecorded practice attempt
from any stage of the loaded map, so Mike can go straight to Penstock Yard's 128 m runway and
compare presets there. It changes `scripts/r14_main.gd` and `scripts/r14_hud.gd` only; no
physics, preset, level or record-key code moved. It is evidence that the menu route works, not
that any stage or preset feels right.

## Using it

Esc opens the menu. Under Resume / Restart R / Practise F / Quit, before the preset list, a row
reads "Stage practice, not recorded", a stage dropdown and **Practise here**.

- The dropdown lists the loaded map's checkpoints in stage order, titles from the map. The
  spawn's stage reads "Start", and the numbers count the stages after it, as the splits do:

  | map | items |
  |---|---|
  | Penstock Yard | Start Gatehouse, 1 Stop logs, 2 Valve bend, **3 Penstock straight** (the runway), 4 Weir gauges, 5 Pump bend, 6 Tail race |
  | Overflow | Start Crest, 1 Pier, 2 Chute, 3 Tail race |

- Each opening of the menu selects the last stage reached, so Practise here without a change
  is the same as F. A preset click while paused keeps the stage you picked. A map switch
  rebuilds the list and selects that map's start.
- To compare on the runway: Esc, pick 3, Practise here, play; Esc, click another preset, Practise
  here again (the dropdown is still on 3). F also repeats the runway, since practice sets the
  stage reached to the chosen one.
- **F** still practises the last stage reached. **R** always starts a clean attempt at the normal
  spawn.

## One practice path

F and Practise here both call `practise_stage(index)`. It:

- clamps the index to `0 .. stage_count() - 1` and logs a warning when it had to;
- cancels a waiting preset request (below);
- starts a new attempt (`attempts + 1`), clock 0 and unarmed (the 0.5 m start threshold applies
  again), stage times, split deltas and respawn count cleared, stats reset, speed readout cleared,
  level `reset_state()`;
- sets `checkpoint_index` and `practice_stage` to the stage, places the runner at the stage's
  authored checkpoint pose (spawn for stage 0) and unpauses;
- labels it: top right "PRACTICE (stage practice from <title>) · R for a clean run", clock line
  "practice · not recorded", a notice "Stage practice from <title> · not recorded".

The practice status moves below the introductory controls when it would overlap the active
preset. Dynamic status and notice backgrounds shrink to their current text. This matters for
the longer vanilla label, which also keeps the reconstructed-stamina qualification visible.

`clean_eligible` is false and `practice_reason` is "practice", so `_finish()` returns
`finish_kind = "practice"` and never saves. That holds however practice was entered: at an
untouched spawn before the timer starts, mid-run, after a finish, or with a preset request
waiting. A preset switch during practice keeps it practice; only R starts a clean attempt.

A fall during stage practice respawns at the stage reached and keeps the "stage practice"
label, rather than relabelling it "respawned" (it was never recordable either way).

## Pending preset request: cancelled, active preset kept

A preset whose hull does not fit waits ("…waits for room") and applies on the first step with
room. Selecting stage practice, from the menu or with F, **cancels** that request and keeps the
**active** preset; the notice says "<preset> request cancelled, staying on <active>".

Why: the map switch already cancels a waiting request, for the same reason. Choosing where to
practise is not a request for the other law. A stage pose is usually open floor, so a kept
request would apply on the first tick there and change the law the player had just placed
themselves to compare. The interrupted partial patch applied the request at the stage pose when
it fitted; that made the result depend on where the stage happens to be, so it was replaced.
To practise with the other preset, click it in the menu (or press its key) and then Practise here.

## Hooks for packed and later tests

| hook | what it is |
|---|---|
| `hud.stage_picker` (`OptionButton`, node `StagePicker`) | item `i` has id `i`; text from `R14Hud.stage_item_text(i, title)` |
| `hud.stage_practice_button` (node `StagePractice`) | calls `practise_stage(stage_picker.get_selected_id())` |
| `hud.practice_button`, `hud.restart_button`, `hud.preset_buttons[id]`, `hud.map_buttons[id]` | existing menu buttons |
| `hud._pause_scroll` | the menu's scroll container; the F4/F5 presets and maps can be below its fold |
| `game.practise_stage(i)`, `game.practice_restart()` | the shared path; F calls the second |
| `game.practice_stage`, `checkpoint_index`, `practice_reason`, `clean_eligible`, `finish_kind`, `pending_preset` | state to assert |
| stdout `r14: stage practice; stage=S/N; title=…; map=…; preset=…; attempt=…` | one line per practice |

The picker's popup opens with a click; its highlight starts unfocused, so the first arrow key
may only focus the list. Walk with arrow keys until `get_focused_item()` is the target, then Enter.

## Checks

```sh
G=~/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64
$G --headless --audio-driver Dummy --fixed-fps 120 --path . --script res://tests/test_r14_stage_practice.gd -- --out=DIR [--only=GROUPS]
```

All input is keys, relative mouse, clicks and wheel pushed through the viewport, and arrow/Enter
in the popup. One labelled check calls `practise_stage` directly to test clamping.

| group | what it proves |
|---|---|
| penstock | from the default start, menu to stage 3, runner at the runway pose and facing, labels; then for server, vanilla, R13 and F4: preset click keeps stage 3, Practise here, 2 s of W runs > 8 m along the runway without a fall |
| overflow | Overflow's four stages in the picker after a map switch, Chute practised and moving |
| order | Penstock's seven items in checkpoint order with ids = indices; Overflow replaces them; back again; clamping of 99 and -4 |
| keys | F after reaching Alpha, menu to Beta, F repeats Beta, R clean at spawn, Restart button, clean finish |
| stats | after hops, sync samples, a respawn and a running clock, practice clears all of them |
| purity | on server, R13 and F4 with an isolated profile file: practice entered at an untouched spawn, by F at a fresh start, mid-run and after a finish all finish "practice" with the file unwritten or byte-identical and the best unchanged; a clean R finish (the control) does write it |
| pending | R13 in the fixture slot with F2 or F4 waiting: Practise here and F each cancel it, the R13 runner stays to the finish though a Source hull fits at the stage, nothing is saved |
| control | without practice the same request applies once there is room; picking a stage and closing the menu without Practise here moves nothing and stays clean |

Root integration passed 107/107 checks, including four new checks that the active preset and
practice label occupy separate rectangles. Before the layout repair, three of those failed
after the vanilla name had enlarged the identity label. A native 1280×720 tour then passed
3/3 and root inspected the server runway, vanilla runway and Overflow Chute frames.
Evidence: `checkpoints/spillway/r14/stage-practice/root-layout-before.log`,
`root-layout-after/summary.json` and `root-native/` in the outer build workspace. The tour uses
software rendering and injected input; it is not a physical-input or Windows test.

`--tour` runs the native pause/player tour on the real scene for frames; run it under a private
Xvfb with Dummy audio, an isolated XDG profile and `--write-movie` (evidence in
`checkpoints/spillway/r14/stage-practice/`, outside Git).

## Limits

- The fixture runs prove the record path; Penstock and Overflow are reached and driven briefly,
  not completed.
- Overflow's Chute deck slopes: the runner settles a few centimetres in the ticks after the
  reset, so that pose check allows 0.15 m.
- `last_save_ok` keeps reporting the most recent save; after a clean save a later practice
  finish leaves it true. The profile file's hash is what shows nothing was written.
- No real mouse, Windows or feel check.
