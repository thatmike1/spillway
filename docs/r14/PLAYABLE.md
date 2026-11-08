# R14 playable comparison loop

P product decisions, 8 November 2026. This is the game Mike plays: one process, several real
movement laws, two maps, a strafe HUD. It is not evidence that any preset feels like CS:GO or
that a Source course route is playable; root runs those acceptance checks separately.

| File | Role |
| --- | --- |
| `scripts/r14_main.gd` | game loop: maps, preset switching, rate check, progress, records, pause and quit |
| `scripts/r14_presets.gd` | preset registry: families, hot-key slots, cvars, rates, labels, record fingerprint |
| `scripts/r14_strafe_stats.gd` | read-only strafe observer that runs after the runner's step |
| `scripts/r14_hud.gd` | HUD, finish card and pause menu |
| `scripts/r14_launch.gd` | launcher: sets the starting preset's rate before the world exists, then loads the scene |
| `scenes/r14.tscn` | the launch scene; the only place persistence is switched on |
| `tests/test_r14_loop.gd`, `tests/r14_loop_fixture_level.gd` | headless loop checks on a labelled fixture level |
| `tests/test_r14_loop_tour.gd`, `tests/test_r14_loop_native.py` | native UI tour under a private Xvfb |

The loop task left existing Source, R13, map, replay and delivery files unchanged. Root
integrated it in `70409e61`: `project.godot` now starts R14, and `R14 Pack` is its export
preset. The global 120 Hz project default remains for historical R13 tools; R14 selects
the active preset's rate when it builds the game.

## Playing

```sh
G=~/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64
$G --path . --script res://scripts/r14_launch.gd -- --r14-preset=server128 --r14-map=overflow --no-records
$G --path .                               # default R14 scene; records enabled
```

It starts on Penstock Yard with the CS:GO bhop-server preset. The top-left line always names
the map, the active preset with its key, the physics rate and the air acceleration.

| Key | Preset | Rate | Air | Jump |
| --- | --- | ---: | --- | --- |
| F1 | CS:GO vanilla (shown with "vanilla cvars · stamina reconstructed") | 64 Hz | AA 12 | press Space or scroll for each hop; holding jumps once |
| F2 | CS:GO bhop server (default) | 128 Hz | AA 100 | hold Space to autohop; wheel works too; no stamina, no takeoff clamp |
| F3 | R13 Overflow (unchanged) | 120 Hz | R13 bend + carve | R13 autohop |
| F4 | reserved for a later independent Quake/air-control motor | - | - | does nothing yet, says so |
| F5 | P server config AA 1000 | 128 Hz | AA 1000 | as F2; a configured comparison some servers run, not universal CS |

R restarts a clean attempt in the active map and preset, F practises from the last stage
reached, Esc opens the menu, F11 toggles fullscreen. The menu lists every preset with its air
acceleration, rate, jump policy and controls (clicking one switches), the map selector
(Penstock Yard, Overflow), and the look settings.

## Switching (P decisions)

- **Preset switch** keeps the exact feet position, velocity, yaw and pitch, starts no process,
  and turns a started attempt into practice ("PRACTICE (preset switched mid-run)"). A switch at
  the untouched spawn keeps the attempt clean. Between the two Source presets the same body
  takes new cvars; between families the runner is replaced in place. R13's pitch is clamped to
  its own ±1.40 rad.
- **Hull fit**: before a family change the new standing hull is tested where the runner stands
  (Source: 0.81 m square, 1.83 m box; R13: 0.6 m wide, 1.8 m capsule). If it does not fit, the
  switch waits and says so, and applies on the first physics step with room. Pressing the
  active preset's key cancels the wait. R applies a waiting switch at the spawn when it fits
  there. The runner is never moved to make room.
- **Map switch** frees the map, builds the other one and starts a clean attempt at its spawn,
  with the same preset.
- **Rate**: the engine can deliver a few callbacks at the old delta after
  `Engine.physics_ticks_per_second` changes. The main compares every callback's actual delta
  with `1/physics_hz`, logs each mismatch (`rate_log`, bounded), shows "(settling)" beside the
  rate, and turns a started clean attempt that sees one into practice. Observed here: one
  mismatched callback at startup (before the attempt started) and one after a live switch.
- **Stats** reset on restart, practice, respawn, map and preset changes.

## Look settings stay per family

- Source: sensitivity in Source units times `m_yaw` 0.022 degrees per count. P: it starts at
  **2.5** (0.055°/count), a build choice. FOV is the 4:3 reference angle widened for the screen.
  Wheel jump is on for every Source preset.
- R13: its original **0.0022 rad per count at 1.0**, literal 90° horizontal FOV, its speed FOV
  and landing dip, autohop on.
- `--r14-source-sensitivity=S` sets the Source value for one run without saving it, for replays
  recorded at another setting (root's Overflow preflight tapes use 5.7295779513).

## Speed and strafe HUD definitions

Speed is horizontal travel per physics step averaged over the last 0.1 s, in u/s (1 u =
0.0254 m), with m/s below (menu toggle). The same unit is used for R13 so the numbers compare.

The observer runs after the runner's step (`process_physics_priority` 100) and never writes it.

- **Air tick**: a step that began airborne, or the step a jump left the ground on.
- **Eligible tick**: an air tick with exactly one of A/D held (|side| > 0.5), a nonzero view
  turn since the previous step, and horizontal speed above 1 u/s. **Good** when the view turned
  toward the held key (A with a left turn, D with a right turn). **Sync** = good / eligible.
  With no eligible tick it shows **—**, not 0 %. This is the SOURCE-REFERENCE A/D sync
  recommendation, not shavit's angle branches; it matches the Source motor's own count exactly.
- **Takeoff**: Source uses the motor's takeoff speed (after any takeoff clamp, before the jump
  step's air update). R13: horizontal speed at the end of the first air step.
- **Landing**: horizontal speed at the end of the step that ended grounded, before the next
  step's friction or penalty (Source: the motor's landing speed).
- **Gain** = landing - takeoff. **Contact** = summed change that collisions made to horizontal
  speed on air ticks (post-contact minus requested), so a wall or lip reads as contact, never as
  bad sync. **Air** = gain - contact. **Wall ticks** count air ticks with a contact whose normal
  is steeper than walkable (|normal.y| < 0.7).
- **Chain** = next takeoff - previous takeoff. **Ground** = chain - gain: friction, clamp,
  stamina and walking between hops. Ground ticks count steps that ended grounded in between,
  the landing step included (1 = jumped on the step after landing).

No efficiency or optimal-strafe number is shown. 100 % sync means the turn direction agreed
with the key, not that the turn rate was right.

## Records

`user://spillway_r14.cfg`, never the R12 or R13 files, which are neither read nor written. One
section per key = sha256 of timing rules `r14-timing-1`, map id/level id/version/variant,
geometry hash, stage titles, preset id, family and family version, physics rate, and the
physics fingerprint (Source: every cvar and policy except sensitivity, m_yaw, m_pitch, fov,
wheel_jump; R13: air policy, air tuning, ground tuning, autohop). Each section also stores the
preset, rate, family version and fingerprint in plain text. Clean, open and practice outcomes
follow R13. Switching preset never shows another key's best; bests of keys visited earlier in
the same process are kept in memory and come back on switching back.

Persistence is off for `new()` construction and for headless runs without an explicit
`--r14-profile=PATH`; only `scenes/r14.tscn` sets `persist`. `--no-records` turns it off.
Tests set `level_script` to a fixture level, which becomes map `fixture` with its own key.

## Replay hook

`--game-script res://scripts/r14_main.gd --game-class '' --motor <preset id or alias>`.
The main reads `motor` before `_ready`, sets the rate and exposes `physics_hz`; the Source runner
exposes `tape_step_count`, `tape_radians_per_count`, `pitch_limit` and the `axis_aligned` hull
policy. Aliases: `csgo_vanilla`, `csgo_server`, `r13`, `aa1000`, `f1`-`f5`. The executor's
`--sensitivity` multiplier is not mapped to Source units; use `--r14-source-sensitivity=`.

## Checks

```sh
G=~/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64
$G --headless --path . --import      # once per fresh checkout, or textures fail to load
$G --headless --audio-driver Dummy --fixed-fps 120 --path . --script res://tests/test_r14_loop.gd -- --out=DIR [--only=GROUPS]
python3 tests/test_r14_loop_native.py --out DIR     # refuses below 15 GiB free
python3 tools/momentum-tape.py run TAPE_V2.json --out DIR --headless --archive \
  --game-script res://scripts/r14_main.gd --game-class '' --motor server128
```

Groups: default (real Penstock Yard), hook, switch, hull, rate, wheel, stats, lifecycle, pause,
maps (real Overflow smoke), persist (child processes with isolated XDG profiles).

Negative controls in `stats`: coasting with the mouse turning, A held without turning, A with
the opposite turn (0 %, not a dash), a synced strafe into a wall (contact loss, sync stays high),
and a late vanilla jump (ground loss, the hop's sync unchanged).

## Limits

- Fixture and smoke checks exercise the loop, not a full Source route on either map.
- The progress probe is a thin box under the feet; Penstock counts only `route` decks (as its
  lab does), Overflow any tagged deck (as the R13 main does).
- Hull fit uses the standing hull; a crouched R13 runner is tested as standing.
- The movie writer owns the window title while recording, so the native tour checks the title
  in a second pass without the movie.
- Native rendering is llvmpipe on Xvfb: no performance, Windows, real-mouse or feel claim.
