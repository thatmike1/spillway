# R15 Movement Lab: slide, wall jump and grapple

Built 8–9 November 2026 and integrated into the R15 source host. This is the
sixth, optional map (`experiment`, kind `lab`). It is not one of the five courses and makes no
feel claim: every move below is a labelled game choice (**P**) that has passed headless input
checks, not a human playtest.

## What it is

A service and test workshop: one lit hall, 24 m wide and 110 m long (forward is −z), built from
named convex collision prisms with `assets/r15/library` Kenney factory and industrial props for
machinery. No new assets. A hub with station boards, then three stations in a line that is also
the combined route:

| stage | station | what it asks | miss |
|---|---|---|---|
| 0 | Hub (spawn 0,0,4) | read the boards | |
| 1 | Slide lane (checkpoint z −10) | run, Shift at the mark, slide 5 m under a 60 u (1.52 m) pipe rack, jump the 2.6 m trench past a 1 m run-out | trench catch, ramp back to the run-up |
| 2 | Wall chamber (checkpoint z −33) | 3.2 m slot between 8.5 m striped housings, a 3.2 m mezzanine wall at its end: two wall jumps | chamber floor |
| 3 | Grapple gap (checkpoint z −62, on the mezzanine) | 14 m pit to the dispatch bay; swing from ring A1 (0, 10.5, −80), let go, coast | right: pit catch with a ramp back up; left: scrap chute, respawn at the checkpoint |
| | Finish | the dispatch bay's far band (box z −94..−100) | |

Ring A2 (−7, 9.5, −88) sits behind a column (x −4.8..−4.0, z −78.4..−77.6), so a blocked
target and a line broken by an obstruction both have a real cause in the room.

Level interface as Breakwater's: `level_id` `r15-movement-lab`, `level_version` 1, manifest
and `geometry_hash`, stage/segment bounds, finish box, kill bounds, route hints, plus
`mechanics` and `anchors`. 53 pieces, longest walkable 24 m.

## The moves

The runner is `scripts/r15_experiment_player.gd`, which extends the approved crouch runner
(`r15_source_player.gd`, MOTOR_VERSION `r15-source-crouch-2`). It does not clone the Source tick
and keeps no separate speed. Each move is either a velocity impulse written to the body before
the inherited tick reads it, or, for the slide, the inherited duck request plus a lower ground
friction for the slide's ticks. The inherited motor then moves the body with its own
collide-and-slide, so a move never places the body. No R14 file, no Source module and no hook in
`r15_source_player.gd` changed.

**Off means off.** With a move off its key is ignored. With no Shift, no E and no fresh Space
press near a wall, the tick is r15's exactly: no velocity write, the approved settings
dictionary and the approved duck request. The parity group checks this tick for tick.

All values are in Source units (u = 0.0254 m). Each table enters the record identity.

### Slide (`r15-lab-slide-1`, Shift)

| rule | value | tag |
|---|---|---|
| Start | a fresh Shift press while grounded, Space not held, horizontal speed ≥ 180 u/s | P |
| Hull | the real crouched hull (54 u), ducked on the ground, so the feet do not move | P |
| Motion | the inherited ground move at `sv_friction` 0.25 instead of 5.2; steering stays the 85 u/s crouch wish | P |
| End | Shift released, 1.5 s, below 100 u/s, a jump, or leaving the ground | P |
| Repeat | a new slide needs a fresh press after a 0.5 s cooldown; there is no toggle | P |
| Stand-up | the slide's duck is released only on the ground; standing then waits for room exactly as crouch does | P |

A slide never adds speed, and it never ducks the hull in the air, so the tape evaluator's air
duck rule never sees a slide-caused hull change. Ctrl and C stay crouch.

### Wall jump (`r15-lab-wall-jump-1`, Space)

| rule | value | tag |
|---|---|---|
| Trigger | a fresh Space press while airborne, a vertical static face (\|normal.y\| ≤ 0.2) within 6 u of the hull, found by `test_move` in 8 horizontal directions | P |
| Impulse | outward speed set to 230 u/s, vertical to at least 290 u/s; the tangential part is kept | P |
| Speed cap | horizontal speed after ≤ max(before, 340 u/s) | P |
| Limits | 3 per flight, 0.25 s apart, never the same face twice in a row; landing resets them | P |

Held autohop never wall-jumps, because it needs a fresh press. Floors, ceilings and walls more
than 6 u away are refused, and each refusal has its reason in the motion state.

### Grapple (`r15-lab-grapple-1`, hold E)

| rule | value | tag |
|---|---|---|
| Target | a marked anchor (group `r15_grapple_anchor`) within 1181 u (30 m) and 9° of the view, with a clear ray from the eye | P |
| Latch | E held with a valid target; after a forced release a fresh press is needed | P |
| Rope law | an inelastic rope that reels in at 260 u/s down to 96 u. While taut it removes the outward radial speed and adds a spring pull of 30/s² per unit over length, capped at 1300 u/s² | P |
| Speed cap | the pull never raises speed above max(speed before, 650 u/s) | P |
| Release | E up (coast), 3 s, 80 u past range, a blocked line, the move turned off, death or reset | P |
| Feedback | a tether from the hand to the ring and a target ring on the anchor; the HUD says target ok, far or blocked, and attached | P |

A rope only pulls along its line, so a blocked line or a wall stops the body through ordinary
collision. Nothing ever teleports the body.

## Integration in the game

- `r15_main.gd` picks the lab runner only when `is_lab()` and no `source_runner` override is
  set. Every other map plays `r15_source_player.gd` exactly, with empty lab state and an empty
  `mechanics` identity.
- `select_map` now swaps the runner when the new map wants a different script (`_sync_runner`):
  the old body is freed, the new one is placed at the new map's spawn, and audio and stats follow
  the live body. Leaving the lab restores the approved runner; re-entering starts with every
  move on again.
- The lab runs F2 and F5 only. Entering it from F3 or F4 switches to F2 and says so on screen;
  F3 and F4 are refused inside it. Normal maps keep every advanced comparison.
- The window title and HUD say **EXPERIMENTAL · MOVEMENT LAB**. The HUD shows a lab keys line,
  each move ON/OFF with its live state, and a reticle that turns orange on a valid target.
- On/off: keys 1, 2 and 3 live, or switches in the pause menu. **All three start on.** Turning a
  move on or off mid-run makes the attempt practice ("lab moves changed mid-run").
- Records: the lab's identity adds the runner path and each move's on/off, version and tuning,
  so every loadout has its own best. It never reads or writes a course's section.
- R, F, Esc, the menu, quit, crouch, checkpoint practice and F2/F5 all work as on the courses.
  Reset, practice, respawn and death clear every move's state.

## Tape keys

`tools/momentum-tape.py` and `tools/momentum-tape.gd` accept `shift` and `e` in version 2 tapes
only, mapped to the `r15_slide` and `r15_grapple` actions. A version 1 tape keeps the old
alphabet. Unknown keys, and lab keys in a version 1 plan, are still refused by both the wrapper
and the executor. The executor also refuses a tape whose keys need an action the game does not
bind. The action loops skip unbound actions, so games without lab actions report as before.
There are no new header fields.

## Tests

- `tests/test_r15_experiment.gd --out=DIR` (also `tools/check-r15.sh` as `map geometry: experiment`):
  425 checks in 30 s headless, driven by key and mouse events after one labelled setup per
  episode. It covers geometry, host integration (every playable non-lab map in the registry),
  parity, slide, wall, grapple, the combined line and records. Episodes go to `DIR/episodes/*.json` with per-tick position, velocity, contacts,
  events and impulses by cause. The combined line is exported as a strict v2 tape,
  `DIR/tapes/r15-lab-combined.json`.
- `tests/r15_experiment_tape.py --tape TAPE --out DIR`: 34 real-input checks of the key
  extension. They compare expansion of every retained tape against the committed helper, run the
  refusals in the wrapper and (bypassing it) in the executor, replay the lab tape for real, and
  rerun the retained air-crouch replay with its corrupt-capture controls.
- `tests/r15_experiment_tape_game.gd`: the actual r15 main on the lab map, for
  `momentum-tape.py run --game-script`.
- `tests/r15_experiment_native.py movie|osinput`: native evidence on the private AMD/X11
  display; `tests/r15_experiment_observer_game.gd` is its read-only observer.

Measured headless (scratch copy of this worktree, Godot 4.7.2, 128 Hz):

- Slide: entry 250 u/s, lane mean 207 u/s, 185 u/s at takeoff, crosses the trench. Crouch walk
  through the lane: 85 u/s, lands in the trench. Standing, braking, or Shift with the slide off
  all stop at the rack face.
- Wall: two wall jumps (off the west face, then the east) reach the mezzanine at 3.2 m. The same input with the
  wall jump off stays on the chamber floor. Spamming one wall gives one jump, top 1.51 m.
- Grapple: latches A1, swings, lets go at z −83, lands on the bay at z −92. With the grapple
  off, the same input falls into the pit catch. A2 reads blocked from the mezzanine middle and
  ok from the pit; strafing behind the column breaks the line (`obstructed`). Holding past 3 s
  breaks it (`time`).
- Combined, from the normal spawn: clean finish in 15.031 s, no respawn. The executor replay of
  its tape (input only, warmup 8) has clean delivery and order, no flags, and the same finish
  and elapsed time.

Measured native (private AMD display, radeonsi renoir on renderD128, 1296×736 root):

- The combined tape through the executor at one draw per physics tick: 0.0 difference from the
  headless replay in position, velocity and yaw over all 1961 ticks, finished clean at 15.031 s.
  Recorded from the player's camera with the HUD.
- OS input: xdotool keys and one click plus XTest relative mouse motion drove the whole line on
  the actual main, with the actor reading a read-only observer to time presses and track A1:
  slide, two wall jumps, grapple, clean finish in about 14.95 s, no respawn, no records written.

## Findings

- **Crouch-hop under a low ceiling keeps its speed.** Holding crouch and Space under the rack
  bunny-hops at the entry speed: a perfect hop has zero friction, and the ceiling only clips the
  hop. So the slide is the grounded alternative under the rack, not the only way through. A
  crouch hop is timing-sensitive at the rack face.
- **AA100 eats a wall push held into the wall.** With the key toward the wall held, air
  acceleration cancels about 195 u/s a tick, which undoes the 230 u/s push-off in one tick.
  Players have to let go of the wall-side key before the press. The chamber's board says
  "Space at a wall"; this needs a human to judge.
- **The grapple is fast.** The swing reaches 550 to 580 u/s, under the 650 cap but about 2.2×
  run speed. This is deliberate for a lab and is the first number to try lower.
- Early trials that failed, kept for the next tuner: slide friction 0.4 decayed too much to
  clear the trench from a jump past the rack; a jump still under the rack hits the ceiling. A1
  at (0, 9.5, −76) mid-gap reeled the body up under the anchor and stalled it over the pit. At
  (0, 9.5, −80) the release came below deck height and the body hit the bay's face. (0, 10.5,
  −80) swings over the bay.

## Limits and risks

- No human feel, no "right" tuning, no Windows or pack result. Every number above is a first
  P choice.
- Wall jump faces are keyed by body name plus a rounded normal, so two coplanar faces on one
  body count as one. This holds in this room but is not a general rule.
- The compatibility renderer's 8-light limit: 6 hall lamps plus 2 anchor glows.
- Art is modest. In the native frames the hall reads as a plain concrete and steel box, the
  housing faces in the covered lane stay dark, and the rack's sign is very large at point blank.
  It is readable and lit, not dressed to course standard.
- The other five courses' workers have not landed. The host check walks every playable non-lab
  map in the registry, so they get checked once they exist.

## Evidence

Outer `checkpoints/spillway/r15/experiment/`, with `STATE.md` listing every file, command and
hash.

## Root integration (9 November)

All eight maps now exist. The full source wrapper passes the current host and every map suite, including 445 lab checks (the original 425 plus checks for the newly present normal maps). The loop passes 179 checks with exactly its five intentional refusal errors; its earlier larger totals included absent-module checks that no longer apply.

The combined line replays through the actual host and standard executor, with all 1961 ticks exactly matching the worker's reference: clean 15.03125 s, verified delivery/order/rate, neutral input, no integrity flags, clean nested logs and cleanup. The Shift/E extension passes all 34 controls, including byte-identical expansion of retained tapes against the pre-extension helper. After the host changes, all 16,356 approved F2/F5 route ticks still match their goldens exactly.

Root decoded and hashed the retained 1280×720 AMD combined movie, checked its kernel GPU and cleanup receipts, and compared all 1961 retained full-precision native samples against the headless reference (complete position, velocity, yaw, pitch, actions, ground/crouch and game state). The file named `native-trace-excerpt.jsonl.gz` contains every tick, with a flattened schema. Three root media-audit setup mistakes (movie filename, flattened schema, variable reuse) are retained; the final audit changes no capture or tolerance. The worker's seven OS-input assertions are a separate, coordinate-aware source proof.

Evidence: `checkpoints/spillway/r15/last-modules-integration/`, plus the original `experiment/`. No R15 release pack has been accepted. Human feel, hardware frame pacing and Windows play remain unverified.
