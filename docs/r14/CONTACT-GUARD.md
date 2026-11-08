# Source adapter contact guard

8 November 2026, on base `1d7fe13d`. **Production change, adapter only.**
`scripts/r14_source_player.gd` now checks the end of every sweep the engine reports as
contact-free, and the end of every stay-on-ground snap. When that pose sits inside geometry
and the sweep started clear, it bisects the same straight path with the engine's overlap test.
It corrects the sweep only when the bisection-selected contact is walkable support.
This assumes a contiguous occupied interval; it is not a general earliest-contact guarantee.
Anything else is left as
the engine made it and counted as declined. `r14_source_motion.gd` is unchanged. No cvar,
preset, course geometry, R13 file or main/HUD file was touched.

| file | sha256 |
| --- | --- |
| `scripts/r14_source_player.gd` (base `a8fc4873…`) | `0557d4859508f2e492806e453595b07c2d45c46ac3214a47040161b0460004a5` |
| `scripts/r14_source_motion.gd` (unchanged) | `6c529b2c90f3e9db69aa962fbef4a7295e0a4b5de864c238b4a1ea78a8485a5b` |
| `tests/r14_contact_guard.gd` (new) | `b4bde808469fb2408046da258b2a44df6fcf1641633c9d10917676bf8aa65c07` |

## The defects

Godot 4.7.2 shape casts against the practice map's `ConvexPolygonShape3D` prisms (and the
Source review fixture's 20000 u box) fail in two ways. Both were measured on the real map
and through the real adapter.

1. **No contact reported.** A hull crossing a top face reports nothing. At the review's
   minimal seed `s4_runin_dir0_64_157`, a sweep from feet y 0.0754 m to −0.0428 m
   reports no contact. Even a purely vertical 2 u probe misses in a band of x a few
   centimetres wide on that prism. The overlap test (SAT, not the cast's GJK) sees the deck
   correctly at both ends.
2. **Contact reported past the face.** The stay-on-ground drop cast reports the deck with
   a travel that overshoots it by about 3.8 mm. The refining settle cast then goes deeper, so
   the walking hull ends 4.4 to 5.9 mm under the deck. Seen at x about −162 on `s4_runin` in
   normal-spawn routes.

## The rule

`_support_inside(from, motion, end_at, caller, depth)`:

- the end pose must overlap by more than `depth`, measured by recovery travel at Godot's
  minimum test margin of 0.1 mm. `depth` is 0.2 mm for contact-free sweeps and 1 mm (one
  margin) for a snap whose cast did report a face, so a snap resting on the raw face never
  counts
- the start pose must be clear, otherwise declined. This rejects initial overlaps such as the
  review's invalid `s1_return` setup
- 20 bisection steps refine a clear/occupied boundary on the swept line
- the first touch's contacts must include a walkable normal (`sv_walkable_normal`),
  otherwise declined. So a wall, the side of a top edge or a 50° face is never turned into
  support

Callers:

- `_slide`, contact-free bump: the hull stops at the last clear pose with the first-touch
  contacts. These then pass through the existing chronological plane clipping and standoff
  unchanged.
- `probe_ground`, contact-free probe: the first-touch normal is the support.
- `_stay_on_ground`, contact-free drop (`snap`) or a drop that ended a margin or more past
  its face (`snap_late`): the snap is redone from the first touch, then stands off.

`cast_guard` (default true) is an adapter policy, not a cvar, so it is not in `settings`.
`get_motion_state().cast_guards` counts catches by caller, plus declines. Guarded slide
contacts carry `guard: true`.

## Results

New test, 64 and 128 Hz (`--earned=96 --box=48`). Evidence is in
`contact-guard/guard-test/` (summary plus 40 gzip traces).

| group | unguarded (`cast_guard=false`) | guarded |
| --- | --- | --- |
| minimal seed, 64 Hz | tick 0 feet −42.83 mm, no contacts, lands tick 1 | feet +1.10 mm, lands tick 0, (300, 0, 0) u/s kept, 0.11906 m travel (requested 0.11906) |
| seed sweep: 295 clear raw misses (51 at 64, 244 at 128; 1 overlapping start skipped) | 295 sink > 1 mm, worst 42.83 mm (64) / 21.42 mm (128) | 0 sink > 0.1 mm, 295 land on tick 0, 295 keep horizontal speed |
| snap strip, 15,715 direct `walk_move` calls at 250 u/s | 9 end below the deck, lowest −5.89 mm | 0; 245 `snap` and 9 `snap_late` catches |
| input-earned, runway strafes, 48 per rate | 1 of 48 at 64 Hz sinks 14.19 mm | 0 sinks; that episode's one `slide` catch is the only difference among 96 |
| input-earned, open-loop hops on the 20000 u box, 24 per rate | 2 of 24 at 64 Hz sink 41.75 mm | 0 |

The runway strafes reach 966 u/s landings at 128 Hz and 323 u/s at 64 Hz. They use keys
and integer mouse counts only after a standing pose, and the view follows travel, so
**coordinate-aware, not human play**. This is the first input-earned floor penetration on
the practice map (`earned_95_64`). It is a one-tick dip, not a fall-through.

Decision fixtures, nine direct calls on a prism fixture:

- accepted: floor from above (feet stop 0.1 mm above), 30° ramp (normal y 0.866), top edge
  reached from above
- declined: a wall from the side, a wall while descending, a top edge reached side-first
  (although its end pose overlaps through the top), a 50° face, an overlapping start
- left alone: a clear end

Negative controls, full ticks, two rates: walk off a ledge, skim fast off a ledge, drop onto
50°, air into a wall at 400 and 1100 u/s, walk a 30° ramp, take an 18 u step, a fast floor
landing. All 16 have zero guard catches and match an unguarded run. None has steep support,
and no wall tick gains upward speed. The 50° drop declined once at 64 Hz: a contact-free
sweep ended inside geometry but failed the start or first-touch check, so it was left as the
engine made it. Which check it failed was not recorded.

**Engine variance, found while building the controls.** The unguarded adapter gives the
same 50° wedge drop two outcomes, 0.3 mm apart, depending on episode order in one process
(sequence off/off/off/off ends a/b/b/a at 64 Hz and a/a/b/b at 128 Hz). Two bodies touch the
hull at the wedge's foot there. Controls therefore require the guarded rows to equal one of
up to nine unguarded runs. Bit-identity between separate episodes is not a valid gate.

### Original suites, final patch

Evidence: `contact-guard/suites-guard/`; base runs from a `git archive` of `1d7fe13d` in
`suites-base/`.

| suite | base | guarded |
| --- | --- | --- |
| pure `test_r14_source_motion` (oracle) | 177/177 | 177/177 |
| live `test_r14_source_player` | 63/63 | 63/63, every detail identical |
| repair `r14_source_repair` | 135/135 | 135/135, every detail identical |
| independent `r14_source_review` (unchanged) | 559, 10 known fails | 559, the same 10 |

The review's check details are identical apart from the new `guard` contact key. Four of its
212 episodes' finals differ:

- its input-only `earned_64_sync/late/overlap` hops on the 20000 u floor: unguarded, tick 134
  lands 1.64 u (41.7 mm) inside the floor and the next autohop leaves from there; guarded,
  it lands 0.043 u above
- the seeded `ramp_transition_128_z-12.0_y24.0`, which sank 3.41 u unguarded

### Routes, base vs guarded, same process per run

Summary: `contact-guard/routes/route-comparison.json`, logs and traces alongside it.

| route | base | guarded |
| --- | --- | --- |
| driver advanced server | clean 28.609375 s | identical trace |
| driver basic server | clean 56.328125 s | same time; 2 ground blips removed, perfect hops 25 → 24 |
| driver basic vanilla | clean 57.71875 s | same time; 2 blips and one 3 mm deck dip removed, perfect hops 30 → 29 |
| driver g3 miss vanilla | clean 68.40625 s | same time; 1 blip removed, perfect hops 30 → 29 |
| driver g1 / block miss server, advanced vanilla | route_done / route_done / missed | the same, with g1 losing 1 blip |
| review policy server basic seed 1 | 54.1484375 s | same time; the 4 mm s4_runin dip and blip removed |
| review policy vanilla basic seed 2 | 56.921875 s | identical trace |
| **review policy server g3-miss rescue** | **68.8359375 s** | **68.828125 s, one 128 Hz tick earlier** |
| seam probe, both presets (84 cases each) | 0 failed, 0 sink | the same |
| loop / stage practice / quake | 166 / 107 / 84 pass | the same |

A ground blip is a walking tick where the unguarded 2 u probe missed the deck. The hull was
airborne for one tick and re-landed, which counted the next jump as a perfect hop.

The guarded runs still show grounded feet down to −7 mm on the 14° return ramps
(`s4_lane_ramp_e`, `s6_lane_ramp`, `s1_return`). Rays there find the ramp face below zero,
so those rows are legitimate. They are not dips.

## Record identity (root)

The change alters landing ticks, perfect-hop counts and at least one route time. It does
not alter `physics_fingerprint`, because `cast_guard` is not a setting. **Root should bump
`FAMILIES.source.version` in `scripts/r14_presets.gd` from `r14-source-motion-2` to
`r14-source-motion-3`.** This covers vanilla64, server128, quake3_inspired128 and
server128_aa1000. R13 is unaffected.

## Limits

- Independent review reproduced a helper-only disjoint-interval limitation: an earlier
  brief wall overlap can be skipped before a later floor is selected. The actual engine
  cast caught that wall in every reduced full tick, so no production failure was reproduced.
  Below, "first touch" refers to the selected interval's boundary. Do not reuse this helper
  as a general collision sweep. See CONTACT-GUARD-REVIEW.md for the reduced cases.

- It is a repair of Godot casts by Godot overlap tests. It is not a Source trace, and no CS
  binary fidelity or feel is claimed.
- Reported-hit landing bumps can still stop about 1.5 mm into a face. The standoff then
  leaves the feet up to 0.48 mm under it (overlap 0.56 mm), and Godot recovers next tick.
  Seen in 100 of 102,060 swept landings over `s4_runin` at 1100 u/s. A sub-millimetre
  threshold that catches these would also fire on ordinary landings, so they are left.
- Misses whose first touch is not walkable (walls, steep faces) are declined, not repaired.
  Such a hull still depenetrates on the next tick as before.
- A cast that tunnels fully through a thin solid ends clear and is not seen.
- Contact-free probe or snap catches can move a walking hull by under 0.2 mm against the
  unguarded run, because the guarded snap stands off from the first touch.
- Godot episode-order variance (above) means separate-episode comparisons are outcome
  matches, not bit-identity.

## Reproduce

From `projects/foldrunner`, `O` a fresh directory outside Git:

```sh
G=~/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64
$G --headless --path . --import
$G --headless --audio-driver Dummy --fixed-fps 128 --path . \
  --script res://tests/r14_contact_guard.gd -- --out="$O" --earned=96 --box=48
# groups: --only=minimal,seeds,snap_strip,decisions,controls,earned,earned_box
```

Evidence root: `/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/contact-guard/`,
headless only, gzip traces, no renders and no native frames.
