# Penstock Yard v3 independent practice review

Reviewed commit `379d8f9f`, 8 November 2026. **No input-earned floor fall-through,
unrecoverable pit or blocked required route reproduced.** The useful counterexample is a
reachable catch at the tail return ramp's inner corner. The residual cast fault also reaches
the production adapter as brief deck penetration in seeded diagnostics, but that is not an
observed player fall. Advanced forgiveness remains unproven by this review.

Scope is geometry `8475d8a82763ee502c6c8dca1393f6756d574d36ebea4c67c3ff46efba77cddd`,
player `a8fc48738ac48ac31f325a916c0081ea5ea595c98e9a4db00705081bcc0f2e64`, motion
`6c529b2c90f3e9db69aa962fbef4a7295e0a4b5de864c238b4a1ea78a8485a5b`, Godot 4.7.2,
Godot Physics, actual `r14_main.gd`, default `server128`. F4 is integrated in this base.
No runtime, level, existing driver or existing test was changed. R13 was not re-reviewed.

## Reachable tail-return corner catch: small course usability issue

After missing the final gap, approach the return ramp close to its inner deck face.
The Source hull catches the vertical nose of `s6_runin` before it can climb
`s6_lane_ramp`. This is ordinary hull blocking at a square corner, not a repaired-adapter
regression or a softlock. It makes the apparent edge of the recovery lane unusable.

Normal-spawn reproduction, entirely through keys and mouse after the main's spawn reset:

- Server, noisy policy seed 1, final-gap miss. All seven stages reached in order, zero respawns.
- After walking into the return lane, face back up the ramp and align at x about −227.8 m.
- Holding forward stalls at **(−227.811, −3.999, −134.908) m** from input tick 7373.
  It is still there 256 ticks later. Contacts identify `s6_runin`, normal `(0,0,−1)`.
- An input-only move toward the ramp centre and continued ascent finishes cleanly at
  **68.835938 s**, zero respawns. No pose or velocity rescue was used.

The local sweep brackets it: x −228.28, −228.05 and −227.8 stall in both presets;
x −227.4, −226 and −224.4 climb and return to the run-in. At x −227.8 the 0.8128 m
hull overlaps the adjacent deck by about 0.206 m. Moving roughly half a metre into the
lane clears that overlap. The two weir return ramps climbed without this catch in all 20 initially clear local
approaches. Eight additional edge setups overlapped the middle deck or outer wall at
initialization and are excluded from gameplay evidence.

Native inspection confirmed the square deck face and the open ramp beside it, both in a
local player view and in the actual product after the normal-spawn approach. The product
capture has its HUD. [Player view at the catch](/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/practice-review/native-product-edge/tail-edge-product.png).
This supports a small entry bevel or a painted centre line if recovery is meant to invite
wall hugging. It does not justify changing the collision adapter. Mike can use the ramp
by keeping away from its inner deck face.

## Cast misses reach production as a one-tick dip, not a demonstrated fall

The unchanged map diagnostic reproduced **307/195,066 missed casts**, including
**62/40,698 on the four runway sections**. This count is still a raw test-motion diagnostic.

The review scanner independently selected 296 raw-miss states across the map, including
62 on those runway sections, then ran the real Source physics callback for eight ticks
from each labelled seed. Its per-piece counts match the control except the pad, where it
selects 8 rather than 19. This is not an exact replay of all 307 original states, and the
lower selection count is not evidence of an engine improvement.

Initial hull overlap is checked separately. One seed already intersected `s1_return`:
its floor ray started below the ramp's top and selected the pit underneath. Production
then depenetrated it sideways by 2.29 m and it fell outside the pit. **Reject that as an
invalid setup, not a player fall-through reproduction.**

For the 295 initially clear seeds:

| Production result | 64 Hz | 128 Hz |
| --- | ---: | ---: |
| Seeded states examined | 51 | 244 |
| Greatest feet penetration below the face | 42.832 mm | 21.416 mm |
| Penetration duration in each case | 1 tick | 1 tick |

All recovered above their landing face on the next tick. Some subsequently coasted beyond
an island or slanted deck edge; their eight-tick grounded flag is not a recovery verdict.
No continuing fall through an interior floor was reproduced.

A minimal production diagnostic is `s4_runin_dir0_64_157`: setup feet
`(−160.380096, 0.0754363, −93.280594)` m, velocity `(300, −291.75, 0)` u/s,
airborne, vanilla 64 Hz. After half gravity the requested velocity is `(300, −298, 0)` u/s.
No input follows setup. The first tick has no slide contacts, puts feet at y −0.0428324 m
and nevertheless reports grounded. The next walking tick depenetrates/snaps back above
zero. This is a real production contact-correctness defect at a manufactured state.
The relevant code is the null-hit branch in `r14_source_player.gd::_slide`, followed by
`probe_ground` and the next tick's `_stay_on_ground`; a probe can categorize the body
without correcting its already penetrated pose immediately.

The separate input-earned check starts each episode at rest on the real runway, then uses
W, one jump press, A or D and bounded mouse motion. All 1,000 jumps landed without sinking
or wall contact. Their maximum speed was only **257.08 u/s**. They are local pose-only
setups, not normal-spawn routes or tests of 1,100 u/s arrivals. Recovered callback deltas
match the declared 64/128 Hz to within 2 ns. Thus **seeded production penetration is proven;
an input-earned version of it remains unreproduced**. Do not label the 307 raw misses as
307 player falls, or the local hops as proof that the residual fault is unreachable.

## Imperfect feedback play: basic and recovery work, advanced remains conditional

`r14_practice_review_policy.gd` hosts the actual main with its default Source sensitivity
**2.5**, converting desired turns into integer mouse counts. It inherits the author's
waypoint goals and takeoff planner, including exact ground/ray information. It reads exact
position, velocity and grounded state. It is **coordinate-aware, not discovery, screenshot-led
play or a human trial**.

The air policy is independently replaced: fixed 1.5° banking relative to travel, 32 Hz
feedback, coarse A/D changes, proportional view correction, a 360°/s turn cap and bounded
±0.5° noise before integer count rounding. It does not use the author's optimal wish-angle
or air-budget calculations. W is used on the ground; the air corrections use A/D and mouse.
Jump planning remains unusually informed. This measures one imperfect feedback policy,
not general human forgiveness.

| Normal-spawn product run | Result |
| --- | --- |
| Server basic, seed 1 | clean 54.148438 s, ordered stages, zero respawns or detected sink |
| Server basic, seeds 2–4 | miss the last zig block; catch pit, not floor penetration |
| Vanilla basic, seeds 2–4 | clean 56.921875 / 57.250000 / 57.000000 s |
| Server final-gap miss, seed 1 | clean recovery and finish, 65.140625 s |
| Vanilla final-gap miss, seeds 1–2 | clean 68.484375 / 67.656250 s |
| Both presets, block miss | return ramp, then blocks 1–5 again |
| Both presets, first gauge miss | return and clear the narrow first gauge |

All listed completed routes had zero respawns and no detected sink. Failures remain in the
evidence; this is not a claim that every seed succeeds.

The same policy's advanced attempts fail. Seeds 2–4 on server miss in the zig blocks.
The lower-noise, seed-1 attempt reaches the outside valve line, takes off at about 277 u/s
and falls short into its pit. Faster feedback variants also fail. A further itinerary takes
the basic valve line before trying the wide gauges: it earns 490–584 u/s on the runway,
then jumps too early for the wide first gauge. The inherited takeoff planner and new air
policy do not cooperate well enough there. These are controller counterexamples and
unproven forgiveness, not evidence that the root's known 28.609375 s advanced line is
impossible or that a collider swallowed the player. This review did not independently
complete the full advanced or outer-notch line. Vanilla advanced attempts also land short
at the first outside valve gap; no new vanilla advanced line is claimed.

Low valve arrivals and ring/pit junctions received separate pose-only probes: eight angles
straddling island boundaries, four radial lines and both presets. The 64 curved return
trials all walked through the outer moat, joined the blocks' pit, climbed the return and
reached the run-in without a reset or detected sink. The initial straight-chord return
policy hit islands and was superseded by an explicit curved path. That discarded policy
failure is not a map defect. Hull-edge stage attribution was not exhaustively tested.

## Reproduce and inspect

From `projects/foldrunner`, with `O` set to a fresh evidence directory outside Git:

```sh
G=~/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64
$G --headless --path . --import
$G --headless --audio-driver Dummy --fixed-fps 128 --path . \
  --script res://tests/r14_practice_review_policy.gd -- \
  --out="$O" --route=g3_miss --preset=server128 --seed=1 --tail-edge=block
# use --tail-edge=rescue to take the input-only escape and finish
$G --headless --audio-driver Dummy --fixed-fps 128 --path . \
  --script res://tests/r14_practice_review_contacts.gd -- \
  --out="$O" --mode=casts --scope=all --only=s4_runin_dir0_64_157
# other probes: --mode=earned --cases=1000, or --only=valve / --only=tail128
python3 tests/r14_practice_review_native.py --product --out "$O"
```

Use separate output directories per command. Policy runs for vanilla use `--fixed-fps 64`
and `--preset=vanilla64`; tapes remain native-rate v2. The inherited 33/32 arming steps
match the executor's requested 32-step warmup at 128/64 Hz. No tape was retimed. These new
product tapes use sensitivity 2.5; the existing worker tapes still require the root's thin
look-scale subclass and 0.0022 rad/count. No bit-identical lab/product claim is made.

Evidence is under outer `checkpoints/spillway/r14/practice-review/`.
`review-results.json` is regenerated by `tests/r14_practice_review_analyze.py --out DIR`.
`native-product-edge/`, `normal-spawn-tail-edge-v2-{block,rescue}/`,
`all-cast-production-validated/`, `minimal-seeded-production/`, `earned-floor/`,
`valve-curved-return/`, `weir-validated/` and `raw-control/` hold the relevant traces, setups and results.
Selected native frames use private Xvfb, Dummy audio, isolated profiles and llvmpipe.
Final retained evidence is under 43 MiB, with gzip traces and selected frames only.
Both native launches recorded more than 15 GiB free first; their profiles and owned
processes were removed. No Windows, GPU performance, actual mouse hardware or enjoyment
claim follows from these runs.
