# Overflow course, revision 2

The R13 course for the CARRY motor, 7 November 2026. Base: committed `275c477b` (air candidate
sha256 `aceb14e5`, shared CARRY base `1c3a4f9d`), product loop `scripts/momentum_overflow_main.gd`
from `459e5051`. Every number and layout choice here is a P hypothesis, and nothing here claims
fun. Godot 4.7.2, 120 Hz physics, headless runs plus llvmpipe renders on a private Xvfb (software
rendering: valid captures, not performance proof). Evidence lives outside Git under
`checkpoints/spillway/r13/overflow-revision/`: `LABELS.md` says which set is which, `final-275c477b/`
is the final set, and `STATE.md` is the resumable log. The first build's evidence stays in
`overflow-course/`, untouched.

Root integration: all captured run-input hashes match before/after and the current
runtime. The raw SOURCES.verdict says MIXED because HEAD and Git status changed during
the docs-only hardware commit, not because those hashed inputs changed. Root reran all
four geometry worlds and ordinary, mastery and bay-miss tapes through the actual product
main, with clean ordered finishes, zero respawns and no input/order/integrity failures.
Root inspected all five composite native strips, including the whole arrival/result
sequence. These are sampled sequences, not a claim of watching the complete movies.
See `checkpoints/spillway/r13/overflow-revision/ROOT-REVIEW.md` outside Git. The course is
ready for art integration and independent casual-input probing, not final delivery.

| File | Role |
| --- | --- |
| `scripts/momentum_overflow_level.gd` | builds the course or the frozen neutral block (`block`, `block_mirror`, `block_offset`) from convex prisms and kit props, with a geometry manifest and hash |
| `scripts/momentum_overflow_game.gd` | adapter over `momentum_carry_game.gd`: runs the candidate air law by default, `broad` or `narrow` as labelled controls; inner classes `Block`, `BlockMirror`, `BlockOffset` |
| `tests/test_momentum_overflow.gd` | geometry checks with no motor: envelope, tops and normals, lips, gap clearance, the earned jump's margins, rail feet, walking connectivity to the finish |
| `tests/momentum_overflow_driver.gd` | closed-loop, state-aware route driver; writes its applied events as a replayable tape |

## Commands

From `projects/foldrunner`, with `G=$HOME/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64`:

```sh
$G --headless --path . --script res://tests/test_momentum_overflow.gd -- --out=DIR [--worlds=course,block] [--freeze]
$G --headless --audio-driver Dummy --fixed-fps 30 --path . --script res://tests/momentum_overflow_driver.gd -- \
   --out=DIR --world=course --air=candidate --route=ordinary   # tight, mastery, wide_turn, miss, pool_miss, slot_miss
python3 tools/momentum-tape.py run DIR/events.tape.json --out RUN --headless \
   --game-script res://scripts/momentum_overflow_main.gd --game-class ''   # the product loop, records off
python3 tools/momentum-tape.py run DIR/events.tape.json --out RUN --headless \
   --game-script res://scripts/momentum_overflow_game.gd --game-class Block --motor broad   # block and controls
```

The geometry test exits 1 on any failure. A native render drops `--headless` and adds
`--display N --actor-every 3 --wall-budget 900`. The evidence directory's `rerun.sh TAG` runs the
whole headless set and `render.sh TAG ROUTE...` the renders; both snapshot every source before and
after.

## Interface

Unchanged from the first build: `spawn`, `checkpoints`, `segment_bounds`, `finish_position`,
`finish_radius`, `water_regions` (empty), `water_audio_sources`, `routes`, `reset_state()`,
`start_wheel()`, `is_finish_at(feet)`, `segment_at(position)`, `route_hint(stage, feet)`,
`geometry_manifest()` and `geometry_hash()`. New: `kill_bounds` (the respawn AABB the product loop
reads, y > -8.3, |x| < 180, -400 < z < 60) and `jump_gaps` (each designed gap's edge, landing,
design speed and kind, which the geometry test judges).

## Layout and beats

Forward is -z down to the tail race, then -x through an S-bend, then -z up to the sluice. The
crest spawn is at y 20.5 and the finish line is the top of the arrival ramp at y 0.5.

1. **Open descent** (unchanged). A 15° apron, slot hop 1 (3.0 m, 1 m down), terrace, descent,
   slot hop 2 (3.5 m, 1 m down) onto the pier. Each slot has a catch trench with a ramp out.
2. **Pier and spill bay: the earned choice.** The pier is a 34 m flat at y 8.5. A plain W run
   drains on it to about 11.8 m/s at the bay edge. Held hops keep the flight speed, so a runner
   who hops the pier reaches the edge at about 16.8 m/s. The bay's wide end is 16 m straight on
   and lands on the 18° chute downslope at the crest. At carried speed it clears with 0.17 s of
   early-press tolerance; a drained runner falls 2.4 m short.
   - **Ordinary:** the platform widens left onto a slipway (x -25 to -11) that drops 6.5 m, dips and
     rises 1.5 m to the crest, so height becomes speed and it joins the chute straight on.
   - **Miss:** a short jump lands on the bay apron, a stained catch slab that climbs forward at
     about 20° to the crest and joins the chute in the same direction. No turning round.
3. **Chute, flip bucket and plunge pool.** The chute narrows from 34 to 23 m over 24 m, down 8 m,
   to a toe at y -4.5. The flip bucket's lip (y -3.0) throws the runner over an 11.5 m plunge pool
   onto the tail-race deck. A short or slow throw lands on the pool apron, which climbs forward.
   At about 20 m/s even a run-off without a jump clears the pool, so only a slow approach drops in.
4. **Tail race: the braking choice.** A wide deck, then a left bend round a run-off berm (rising
   3 m, open on the outside) and a right bend onto the arrival straight, with a second berm. The
   ordinary line brakes to 12 m/s for the first bend; the fast line swings wide and keeps 23 m/s.
5. **Arrival and sluice.** A 20 m ramp rises 4 m to the sluice deck. The finish line is its top
   edge, an ochre strip. Past it are 25 m of level deck, then the brick sluice house with its
   handwheel facing the runner. Crossing the line turns the wheel; the gate beside it lifts and
   water runs down the outflow channel toward the tail race, below the deck and currently
   outside the runner's stopping view.

Every gap lands short on a catch surface that climbs forward toward the next stage. The test
floods a 0.5 m grid back from the finish, and every catch surface walks to it. There is no death
pit, hidden teleport, boost, invisible wall or forced slowdown. Joins are flush (5 cm sampling,
1 cm tolerance), and concave creases such as toe to bucket are allowed because the step is
explained by the surface it climbs onto.

**Look.** Course-only material variants from the licensed kit (`Materials.variant`): landing decks
a step lighter than running decks, catch aprons and the pool darker and stained with a waterline,
mossy hills to separate the far bank from the course. The sun was moved to light the run's faces
(yaw +35°, energy 1.25), fog and sky were adjusted. Landmarks are real dam construction: crest
gantries over the spawn and the chute, the pump house beside the pier, the gate and outflow at the
sluice. No signs or arrows.

## Block, freeze and checkpoint correction

The block and its holdouts are geometrically unchanged: block `a6030e6e`, mirror `a203695f`, offset
`bc843788`, checked by the frozen manifests in every set. One metadata correction, separate from
geometry: the block's "Pier deck" checkpoint box covered the bay's airspace, so a falling-short
diagonal collected it in flight. It is now `_box(Vector3(-45 + o, 3.3, -62), Vector3(26, 6, 15))`,
the deck only. No hash covers checkpoint metadata, so this is reported here.

## Results on 275c477b

All closed-loop runs are labelled CLOSED LOOP: a state-aware execution proof from the normal spawn,
not imperfect play. Inputs start after the game's own `restart_run()`; no pose, velocity or camera
writes, no velocity restore.

Geometry: 4 worlds, 0 failures (course `3a04610b`, 105 pieces). Gap tolerances at their design
speed: slot 1 0.427 s, slot 2 0.369 s, plunge pool 0.258 s at 14 m/s, and the bay's wide end 0.171 s
at 16.8 m/s carried, 2.39 m short at 11.8 m/s drained.

**Course, closed loop** (candidate air; 0 respawns and 0 stalls in every run; checkpoint times are
pier, chute crest and tail race):

| Line | Finish | Checkpoints | Top speed | Notes |
| --- | --- | --- | --- | --- |
| ordinary | 24.892 s | 6.62 / 10.56 / 13.69 | 20.9 | tapped slots, plain pier run, slipway, brakes to 12 m/s for the first bend |
| tight ordinary | 24.458 s | 6.49 / 10.33 / 13.39 | 21.8 | held hops from slot 1, slipway |
| mastery (earned shortcut) | 22.475 s | 6.48 / 9.76 / 12.13 | 25.5 | held hops along the pier, jumps the bay's wide end, brakes for the bend |
| wide turn | 22.500 s | 6.48 / 9.76 / 12.14 | 25.5 | mastery without braking, swings wide over the berm |
| miss (bay recovery) | 25.592 s | 6.61 / 10.50 / 14.02 | 17.1 | plain W run tries the wide end, lands on the bay apron, climbs to the crest |
| pool miss | 27.767 s | 6.62 / 10.56 / 15.77 | 18.4 | brakes on the chute, runs off the lip, climbs the pool apron |
| slot miss | 28.650 s | 6.83 / 13.87 / 17.26 | 18.8 | runs into slot 2's trench and climbs its ramp |

The earned jump saves 1.98 s over the tight ordinary line and 2.42 s over the plain one. Its
reward lands in the bay crossing: 0.57 s to the chute crest and a faster chute, worth 1.26 s at
the tail race. Broad and narrow give byte-identical results on the ordinary, tight, mastery and
miss lines (W-only within 45°, where the laws agree). Every finish counts as ordered (all
checkpoints in order) and `finish_kind` is `clean`.

**Product loop.** The course tapes replay on `momentum_overflow_main.gd` (records off, built with
`new()`) to the same finish times. The v4 ordinary tape matched the driver trace to 5e-5 m.

**Block matrix, closed loop** (3 variants × candidate, broad, narrow × 5 lines = 45 runs): 43
finish clean, with the first build's times (ordinary 8.467 to 8.492 s, tight 7.600 to 7.642 s,
corner 7.450 to 7.492 s, hop 7.358 to 7.408 s, miss 13.475 to 16.533 s). The candidate's W-run
miss on `block` and `block_offset` never finishes: it stops dead in the bay against the side face
of the bay return ramp (x -30 to -20, rising from z -37 to -47 with an open east side). The
candidate's slightly different landing meets it at z -37.75, where the face is 15 cm tall; broad
crosses at z -37.33, where it is 7 cm. This is frozen holdout geometry, so it was not changed.

**Open-loop imperfect tapes** (product loop for the candidate course tapes, the adapter with
`--motor` for controls and block): jump edges shifted -12, -6 or +6 ticks, or mouse scaled by 0.9
or 1.1, each also as a hold-W copy that drops the recording's last W release and holds W 10 s
longer. Nothing was tuned between runs, and all 120 are kept.

- **Course: 42 of 42 hold-W tapes finish** (ordinary 24.89 to 26.04 s, tight 24.40 to 25.54,
  mastery 21.83 to 23.09, miss 24.85 to 26.35, pool miss 26.95 to 28.85), 0 respawns. Every
  perturbed mastery tape still clears the bay, every miss tape lands on the bay apron, and the
  perturbed ordinary and miss lines that fell into the plunge pool climbed out. As recorded, 27 of
  42 finish: the other 15 reach the arrival ramp late and stop on it where the recording let go of
  W. None stalls or respawns.
- **Block:** candidate ordinary and mirror hop 24 of 24. Broad's offset miss 6 of 12: the six
  failures end stuck at (-16.7, -46.7), against the same bay return ramp's open side.
- On the course the executor's stuck and hard-stop flags occur only 3 s or more after the finish,
  when hold-W tapes reach the wheel plinth or the sluice house. None occurs before a finish.

**Native renders** (`final-275c477b/render/`): the closed-loop tapes replayed open loop on the
product loop, private Xvfb :161, Dummy audio, isolated XDG, `--actor-every 3`, 900 s wall budget,
one at a time. All four completed the whole run through the finish with no flags:

| Line | Finish | Wall time | Movie |
| --- | --- | --- | --- |
| ordinary | 24.892 s clean | 189 s | `render/ordinary/movie.mp4` |
| mastery (earned shortcut) | 22.475 s clean | 188 s | `render/mastery/movie.mp4` |
| miss (bay apron recovery) | 25.592 s clean | 194 s | `render/miss/movie.mp4` |
| pool miss (pool apron recovery) | 27.767 s clean | 205 s | `render/pool_miss/movie.mp4` |

Each run keeps the executor's contact sheet, every fifth sampled frame (0.5 s apart) and its
trace; `render/inspection/` holds the composite sheets used for inspection. What the frames show: the
bay's wide end and the chute crest beyond it are visible from the pier, under the chute gantry.
The mastery jump lands on the chute downslope. The miss falls onto the darker apron with the ochre
crest nosing ahead and the hint "Short of the crest: the apron ahead climbs back to the chute."
The pool miss climbs straight out toward the lighter tail deck. On the arrival the handwheel is
dead ahead from the ramp, the finish strip is where the finish triggers (the "WATER RUNNING" panel
appears on that frame), and the runner stops on the deck in front of the turning wheel. Each
native run wrote 2 files into its temporary XDG directory; they were removed with it and not
inspected.

## Weaknesses

- **Basic line is about 25 s** with the driver, at the bottom of the 25 to 35 s target. A human
  line will be slower, but nothing was added for length.
- **The arrival climb equalises speed.** Every line, fast or slow, reaches the arrival ramp at
  about run speed and climbs it at 8.3 m/s. The last 3 s do not reward what came before.
- **The pool miss needs a deliberately slow approach.** At chute speed the bucket throws even a
  run-off clear of the pool.
- **A plain 8.5 m/s run drains on flats.** That is what makes the bay jump earned, but it also means
  the pier feels slow to a runner who doesn't hop.
- **Hold W past the line and you run into the sluice house.** 25 m of deck is enough to brake, but
  the open-loop hold-W tapes end against its face (flagged by the executor after the finish).
- **The released water is out of view at the stop.** The wheel turns ahead and the gate lifts in
  its frame on the right, but the water runs in the outflow channel 5.5 m below the deck, so the
  runner never sees it flow. Moving the release sheet is visual only; giving it a line of sight
  from the deck would change geometry.
- **The plunge pool is a dry, dark slab.** It reads as a catch surface, not as water.
- **The tail race is still a broad pale deck** in the renders, with little to read at 20 m/s. The
  run's other stretches have landmarks; this one does not.
- **A braking driver frame faces the chute wall** for about half a second on the pool miss. That
  is the driver's steering under S, not the level, but a human braking hard there could get the
  same view.
- Renders are software (llvmpipe): valid captures, not performance proof.
- **Frozen block pocket.** Two block faults are in the frozen holdout geometry and were not tuned:
  the bay return ramp's open east side stops the candidate's W-run miss dead (a 15 cm side face),
  and perturbed broad offset misses stick against the same ramp. See results.
- **Driver line, not discovery.** The tight ordinary, mastery and wide lines are the driver's
  best of a few tries, not optimal play.

## Rejected designs

- Narrow-end hop across the bay (v1, v2): the detour and its 5 m drop onto a flat cost as much as
  falling, so the miss beat the ordinary line.
- A corner-cut diagonal with a lateral cut: slow runners turn first and the cut is always open.
- A straight gap over a down-and-up channel: it saves nothing.
- Baffles after a variable-speed merge: overspeed runners hop onto the next block's face.
- A 13° chute: drag dominated and the bucket throw was too short; steepened to 18° with an 8 m drop.
- A flat tail and a higher sluice (v3, about 18 s): replaced by the S-bend and a lower sluice.
- A 14 m plunge pool: only 0.07 s of tolerance at 14 m/s; shortened to 11.5 m (0.26 s).
- Hopping the pier into the slipway as the tight ordinary line: slower (26.4 to 26.6 s), because a
  17 m/s runner swings wide of the slipway.

## For root

- Integration, packaging and final discovery. Nothing outside the owned files was changed: no
  main, HUD, audio, project settings, material kit, tape helper or CARRY source.
- No new files, so no new `.uid` files.
