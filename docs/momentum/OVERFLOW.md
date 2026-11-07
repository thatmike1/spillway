# Overflow course, first build

Root integration checkpoint: this is a retained first prototype, not the finished course.
After the support fix at `fd38b1e9`, root reran all four geometry variants with zero
failures and the ordinary closed-loop line finished cleanly in 16.292 s, with six jumps,
zero respawns and no stalls. Evidence is in `root-post-fd38b1e9/` under this course's
evidence directory. Other numerical results below remain the worker's labelled pre-fix
results. Root inspected the truncated ordinary contact sheet, not a complete movie.

The next course revision must address the nearly free diagonal, its 0.30 s net reward,
the bay exit behind a failed arrival, and the sparse short route. Root chooses the new
air challenger provisionally for that iteration, pending independent challenge and
comparison on the frozen block. Keep the original block/holdout geometry intact as
controls, and label any progress-metadata corrections separately. The next course should
add a purposeful momentum choice rather than plain running to fill time. Complete native
ordinary, shortcut and physical recovery captures remain required.

The R13 course for the CARRY motor, 7 November 2026, on base 390cb022. Every number and
layout choice here is a P hypothesis. Nothing here claims fun. Godot 4.7.2, 120 Hz physics,
headless runs plus llvmpipe renders on a private Xvfb. Evidence is kept outside Git under
`checkpoints/spillway/r13/overflow-course/`, and `STATE.md` there is the resumable log.
R12 is still the baseline and is untouched.

| File | Role |
| --- | --- |
| `scripts/momentum_overflow_level.gd` | builds the course or the neutral block (`block`, `block_mirror`, `block_offset`) from convex prisms and kit props, with a geometry manifest and hash |
| `scripts/momentum_overflow_game.gd` | thin adapter over `momentum_carry_game.gd` that sets `level_script`; inner classes `Block`, `BlockMirror`, `BlockOffset` |
| `tests/test_momentum_overflow.gd` | geometry checks with no motor: envelope, tops and normals, lips, ordinary gap clearance, rail feet, walking connectivity to the finish |
| `tests/momentum_overflow_driver.gd` | closed-loop, state-aware route driver; writes its applied events as a replayable tape |

## Commands

From `projects/foldrunner`, with `G=$HOME/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64`:

```sh
$G --headless --path . --script res://tests/test_momentum_overflow.gd -- --out=DIR [--worlds=course,block] [--freeze]
$G --headless --audio-driver Dummy --fixed-fps 30 --path . --script res://tests/momentum_overflow_driver.gd -- \
   --out=DIR --world=course --air=broad --route=ordinary   # also mastery, miss, slot_miss, basin_miss
python3 tools/momentum-tape.py run DIR/events.tape.json --out RUN --game-script res://scripts/momentum_overflow_game.gd \
   --game-class '' --motor broad --headless                # Block, BlockMirror or BlockOffset for the block
```

The test exits 1 on any failure. A native render drops `--headless` and adds `--display N
--wall-budget 900`. At the default 120 s budget, llvmpipe stops after about 13 s of play.

## Integration interface

The level extends `Node3D`; a factory sets `next_variant` (or `--overflow-world=`), and
`build()` runs once. It exposes `spawn` (a feet transform), `checkpoints`, `segment_bounds`,
`finish_position`, `finish_radius`, `water_regions` (empty: there is no swimming water in
reach), `water_audio_sources`, `routes`, `reset_state()`, `start_wheel()`,
`is_finish_at(feet)`, `segment_at(position)` and `route_hint(stage, feet)`. The finish is a
box on the sluice deck. `start_wheel()` spins the hand wheel, lifts the sluice gate 3.6 m and
releases a sheet of water. Materials come from the kit's `get_material(kind)`;
`--overflow-neutral` swaps in flat colours. `geometry_manifest()` and `geometry_hash()`
cover the solid pieces, not the materials.

## Layout

Forward is -z, then -x round the pier head, then -z again. The crest spawn is at y 20.5 and
the finish is on the sluice deck at y 5.0. All coordinates stay inside y > -8.3, |x| < 180
and -400 < z < 60.

1. **Open descent.** A 15° apron runs off the crest onto terrace 1, then slot hop 1 (3.0 m
   across, 1 m down). Terrace 2 leads to a descent and a run-out, then slot hop 2 (3.5 m
   across, 1 m down) onto the pier. Each slot is a trench with a catch floor and a visible
   ramp on the right that climbs back out.
2. **Pier bend.** A 10 m wide pier with kit rails on its right edge. The ordinary line runs
   to the pier head, turns left and goes down the exit ramp onto the pier deck. The diagonal
   leaves from the ochre nosing on the pier's left edge and crosses the bay, about 11 m,
   onto the bottom of the exit ramp or the deck. A short jump drops into the bay, a catch
   floor whose ramp on the far (west) side rises onto the pier deck.
3. **Baffles and arrival.** The course alone adds a 6 m apron on the pier deck, so an
   overspeed runner can turn south, and moves everything after it 6 m further south. Three
   baffle blocks (8, 7.5 and 7 m long, yawed 0, -5 and +5°) set a rhythm of one hop per
   block at the 13.75 m/s the ordinary line carries. The basin floor runs beside and between
   them, and past the last block the whole floor climbs to the sill (21°). From the sill, a
   rising arrival ramp (1.8 to 5.0 m over 18 m) spends speed. The sluice deck leaves 20 m
   for braking and looking round before the wheel.

Every catch surface walks to the finish (the test floods a 0.5 m grid backwards from the
finish). There is no death pit, hidden teleport or recovery cave. Respawn happens only
below y -8.3, which a run cannot reach.

## Neutral block and freeze

The block is the course from terrace 2 to the pier deck, built by the same functions in the
same coordinates, with its finish band on the pier deck. It and two holdouts were frozen
(v5) before any side-key or holdout route ran: `block_mirror` (x mirrored) and
`block_offset` (everything past slot 2 shifted 3 m sideways). Criteria C1 to C5 and the
manifests are in `freeze-v5/` (`CRITERIA.md`, `freeze/*.json`). Frozen geometry hashes:
block `a6030e6e`, mirror `a203695f`, offset `bc843788`. They are unchanged at the end.
Nothing was tuned against a holdout.

Gap check (C1: 8.5 m/s run, 7.2 m/s jump, 20 m/s², pressed 0.25 s early, landing 0.5 m
past the far edge). Every ordinary gap passes:

| Gap | Distance / drop | Early-press tolerance |
| --- | --- | --- |
| slot 1 | 3.0 m / 1.0 m | 0.427 s |
| slot 2 (block and course) | 3.5 m / 1.0 m | 0.369 s (offset 0.363) |
| baffle entry, 1 to 2, 2 to 3 | 3.0 to 3.3 m / 0.1 to 0.3 m | 0.348, 0.312, 0.287 s |

Baffle 3 to the sill is now a drop onto the climbing floor, not a gap. Lips: none on the
ordinary line (sampled every 5 cm, 1 cm tolerance). The steepest walkable top is 19.65°.
Rails stand on decks within 2 cm.

## Results before the shared-base air-contact patch

All results below use the pre-patch base (`momentum_carry_player.gd` sha256 `280be87c`).
Root is patching a support-relative air-contact filter into the shared base, and every
motor-dependent result is rerun after it, in separate directories. Source hashes before the
patch: `pre-base-patch/SOURCES.txt`.

**Profiles.** With only W and jump, broad and narrow produce identical traces in every run
(compared by position-trace hash). The profiles differ only on side keys. Every result here
is therefore one result for both.

**Block, closed loop** (finish times; 0 respawns and 0 stalls in all 30 runs):

| Line | block | mirror | offset |
| --- | --- | --- | --- |
| ordinary | 8.467 | 8.467 | 8.492 |
| tight ordinary (hug the corner) | 7.633 | 7.642 | 7.600 |
| corner hop | 7.492 | 7.492 | 7.450 |
| held-jump diagonal | 7.358 | 7.358 | 7.408 |
| W-run diagonal miss, bay recovery | 16.300 | 13.475 | 16.533 |

**Course v8, closed loop** (geometry `f3f46656`; checkpoint times are crest to pier, pier
deck and sill):

| Line | Finish | Checkpoints | Notes |
| --- | --- | --- | --- |
| ordinary | 16.292 s | 6.61 / 8.74 / 13.97 | tapped slot hops, one hop per baffle at 13.75 m/s |
| mastery | 15.992 s | 6.49 / 7.63 / 13.20 | held hops from slot 2, diagonal, brake to 13.5 m/s on the deck |
| miss (braked approach) | 23.133 s | 6.98 / 13.52 / 20.16 | diagonal falls into the bay, climbs the west ramp |
| slot miss | 19.717 s | 6.83 / 10.79 / 16.97 | runs past slot 2 into the trench, climbs the right ramp |
| basin miss | 17.492 s | 6.61 / 8.73 / 14.77 | drops off beside the baffles, climbs the sill floor |

**Open-loop imperfect tapes.** These are the recorded events replayed through
`tools/momentum-tape.py` with jump edges shifted -12, -6 or +6 ticks, or mouse scaled by 0.9
or 1.1, on both profiles. Nothing was tuned between runs. A replay of the unperturbed
ordinary tape matches the closed-loop trace to 0.05 mm.

- Block, all three variants: 47 of 48 finish. Ordinary lines finish under every
  perturbation (8.467 to 8.55 s), and so do the hop lines (7.29 to 7.46 s), except
  mirror-hop with mouse ×1.1. That one falls into the bay's south pocket, and with no
  steering its held autohop repeats against the pier deck's 2 m east face.
- Course v7: 9 of 12 finish. All three failures (ordinary mouse ×0.9, mastery jump -12 and
  +6) dropped into the basin and ended pressing W into the sill's 1.8 m face. The only way
  up was a 4 m side ramp. Course v8 replaced that face with the full-width climb.
- Course v8: 15 of 18 finish (ordinary 16.20 to 16.87 s, mastery 15.65 to 16.40 s, basin
  miss 17.43 to 18.01 s). The other three (ordinary mouse ×0.9, mastery jump -12, basin
  miss mouse ×0.9) fell into the basin and climbed the sill floor. They were still moving
  on the arrival ramp or the sluice deck when the recorded tape released W, with no stuck
  or hard-stop flag. The tapes are open loop, so a perturbed run reaches the finish later
  than the recording's W release.

## After the base patch

[pending root's committed hash: geometry test, closed-loop block and course matrix,
open-loop tapes and native renders, all in `post-base-patch/`, produced by `rerun.sh`]

The base changed in the working tree partway through a baseline rerun (player `1c3a4f9d`,
uncommitted). That set is kept, labelled mixed, in `mixed-280be87c-1c3a4f9d-uncommitted/`.
Its 9 course runs on `1c3a4f9d` match the pre-patch times and trace hashes exactly. It is
not a substitute for the committed patch.

## Findings and weaknesses

- **The diagonal is not hard-earned on the course.** A full W run from the crest reaches
  the nosing at about 14.75 m/s and makes the diagonal without technique. The miss line has
  to brake on the run-out to fall short. On the block, which starts on terrace 2, a W run
  falls short.
- **The diagonal's reward is small.** On the block it is 0.28 s against a tight ordinary
  line, and the corner hop takes 0.14 s of that. On the course it saves about 1.0 s on the
  pier, but it lands heading about 34° further south than the ordinary line. At 16 m/s that
  forces a brake before the basin, which gives about 0.7 s back: net 0.30 s.
- **Basic time is about 16 s,** under the brief's 25 to 45 s. The course was not padded.
- **The bay pocket faces walls.** A short diagonal lands in the bay's south pocket looking
  at the exit ramp's side face and the pier deck's east face. The recovery ramp is behind
  and to the right. It is visible and walkable, and the hint text names it, but the player
  has to turn round to find it. This pocket is where the mirror holdout's open-loop failure
  ends.
- **Mirror asymmetry.** The W-run miss finishes in 16.30 s on the block and 13.475 s on the
  mirror, and the mirror's hop line is the only block tape to fail open loop. The driver
  mirrors its route nodes, so the geometry and the plan are symmetric. The difference
  arises somewhere in the bay contacts or in how the closed loop responds to them, and is
  not yet isolated.
- **Block checkpoint.** The block's pier-deck checkpoint box still covers the bay's
  airspace, so a falling-short diagonal collects it in flight. The course's box was
  narrowed to the deck. The block box is a frozen holdout definition and is reported here,
  not changed.

## Rejected layouts

- A helix bend: it rewarded no more than a square pier head and risked trimesh contacts.
- A 90° arc with a chord cut: the chord saves only about 0.16 R.
- Guard rails at the inner corner: short tries hit them in the air.
- A pump house in the inner corner: it blocked every straight diagonal.
- A 4 m bay notch beside a narrow exit ramp (v2): the shortest cut pointed about 90° west,
  so W-only lines failed or only lip-caught the ramp edge.
- A screen wall on the pier's last 6 m (v3 and v4): honest diagonals and edge-huggers hit
  its end face and dead-stopped.
- Course pier deck without an apron: a 17 m/s arrival off the exit ramp could not turn into
  the basin.
- 4 m baffles: at 13.75 m/s a hop overshot onto the next block's face.
- A sill face with one 4 m side ramp (v7): open-loop misses ended against the face.

## For root to integrate

- Default-game wiring, records, the final UI and packaging. The adapter needs only
  `level_script`. Nothing in `main`, the HUD, the player, `project.godot` or old evidence
  was changed.
- The `.uid` files were generated in a scratch copy of the project, so the shared `.godot`
  cache was not touched. None collides with an existing uid.
- Whether the diagonal should be made harder on the course (for example a slower run-out),
  given the findings above. That is a design call for after the base patch.
