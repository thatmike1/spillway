# Independent contact guard and tail review

Reviewed parent base `bae2d37118c68b2e7e9adcaa111d2eca26aaf009`, specifically
`a89360be` and `fabe254a`, with Godot `4.7.2.stable.official.ed1daf0bf`.
The Source record family is version3 and Penstock Yard is version4; the pure
Source motion module is outside both reviewed production diffs.
No newly reproduced blocking regression. The practice-map corrections tested here
preserve horizontal travel and landing order. The tail edit improves the measured
local return and leaves the tested sibling recoveries usable. Two qualifications
below should accompany those claims.

Only this document and new `tests/r14_guard_review*` scripts/UIDs belong to this
review. Production and existing tests are unchanged. Everything is uncommitted for
parent integration.

## Findings

### The helper does not guarantee the first contact across disjoint intervals

Non-blocking contract limitation, reproduced twice at each tick rate. In
`scripts/r14_source_player.gd:519`, whole-segment bisection advances `lo` past an
earlier occupied interval if a later midpoint happens to be clear. It can then
accept a later floor despite an earlier nonwalkable wall touch. Twenty iterations
improve precision inside the selected interval; they cannot recover the skipped one.

The reduced, production-speed fixture is `tests/r14_guard_review_first_touch.gd`:

- 64 Hz: feet `(1.4, 0.1, 5.2)`, motion `(1, -0.125, 1)` metres.
- A block occupies x `[2,3]`, z `[-5,5]`, top y `3`; the deck is y `0`.
- The box hull briefly grazes the block's corner at fractions about
  `0.1936..0.2064`. The midpoint is clear. The helper accepts the deck at `0.799200`.
- At 128 Hz, halve the motion and initial feet height. The earlier interval is
  about `0.3872..0.4128`; the helper accepts the deck at `0.798400`.
- The initial velocities are about `(2519.685, -308.711, 2519.685)` u/s at
  64 Hz, with the appropriate half-gravity adjustment. They are within the
  per-axis 3500 u/s bound.

**This is not a reproduced motor defect.** In all four reduced cases, the actual
engine sweep reports the block, the slide guard never fires, and the guarded full
ticks match an unguarded run. The 24 accepted missed casts in the map scan also
showed no skipped interval. No production sweep that both missed this corner and
reached the later floor was found. The first larger helper exploration used an
unrealistic 10 m sweep; it is retained, superseded by the reduced probe above.

The unconditional first-touch wording in `CONTACT-GUARD.md` and the helper comment
is stronger than this implementation proves. Describe that limitation before
reusing the helper as a general sweep replacement. A runtime rewrite is not
justified by these diagnostics alone.

### The tail repair does not clear every inward-facing approach

Qualification of coverage, not a new regression. From clear pit floor at
`(-228.28, -3.9988, -137.4)`, yaw `PI - 5 degrees`, held W for seven seconds
still fails to climb at both rates. New-map endpoints are approximately
`(-228.8669, -3.9989, -134.3825)` at 64 Hz and
`(-228.7098, -3.9989, -134.3825)` at 128 Hz. Both failures repeat in `routes-new1`
and `routes-new2`, without setup overlap or velocity injection.

Those same approaches already fail on map3, including `routes-old2` with the
identical guarded player. Across seven x positions and headings -5/0/+5 degrees,
map3 passes 24/42 and map4 passes 40/42. The original five north-facing positions
pass 10/10 on map4; all seven north-facing positions pass 14/14. Keep the published
claim tied to those approaches. The residual angle does not warrant reverting
the taper or inventing another guide shape during this review.

## Checks I ran

Evidence root, outside Git:
`/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/contact-guard-review/`.
`EVIDENCE.json` records hashes, run results and storage size. Traces are gzip.

| Run | Actual coverage and result |
| --- | --- |
| `final-scan1`, `final-scan2` | Identical summaries, 95/95 checks each. 69,120 candidate edge sweeps across walkable practice pieces, eight headings, 64/128 Hz and 300/1100/3500 u/s horizontal speeds. 32,914 overlapping starts rejected; 36,206 clear starts remain. 34,189 raw casts hit; 2,017 reported no hit. The guard accepts 24, with no earlier occupied interval found by the independent 128-part segment search followed by local bisection. The other 1,993 are clear-end or declined cases, not additional corrected misses. |
| Map full ticks within those scans | 17 selected seeds, guard off/on, twelve ticks each. All first-tick corrections land, clip descent to zero, retain horizontal velocity within 0.002 u/s, and retain horizontal travel within 0.1 mm. These are seeded cast diagnostics, not earned movement. The 24 accepts are flat tops; they do not establish a corrected ramp-miss population. |
| Mixed fixture within those scans | 28 direct helper floor/wall timing cases plus the large disjoint-interval exploration. Separately, 42 full-tick floor/wall cases, each compared with three unguarded runs. All match an unguarded outcome, fire no catches, and gain no upward velocity. This exercises contact order near a seam, not a claim that every helper rejection was reached by a raw missed sweep. |
| `reduced-first-touch` | Four checks pass: two rates, twice each, with full-tick guard/off controls. Demonstrates the helper limitation and checks that the real cast prevents it from reaching the slide guard. |
| `parent-controls` | Existing guard suite, selected groups `minimal,decisions,controls,earned,earned_box`, `--earned=12 --box=12`: 36/36. Includes walkable 30-degree and declined 50-degree faces, side-first/top-first edges, overlap rejection, ledges, wall contacts, step and fast landing controls. Twelve input-earned runway episodes stay clean. Of twelve input-earned oversized-box episodes, one unguarded 41.75 mm dip is corrected; no guarded penetration over 0.1 mm. |
| `geometry2` | 1653/1653, comprising the unchanged 1599 geometry gates plus 54 review controls. Gap sizes, pit return/no-forward/no-walkaround checks remain active. |
| `routes-new2` versus `routes-old2` | 66 input-only episodes per map, same guarded player. Tail 40/42 versus 24/42; six sibling recovery itineraries, two rates, two noise seeds: 24/24 on both maps. Every final setup is hull-clear. No velocity/pose rescue occurs after setup. Both diagnostic runs intentionally exit 1 for the retained tail-angle failures. |

The segment search is an independent check against bisection's monotonicity
assumption, not an exact continuous collision oracle. It can miss occupied
intervals shorter than its sampling spacing. At map-scale coordinates, float
precision also limits contact-time distinctions below tens of micrometres.

## Why the anchor refinement and taper passed

`tests/test_r14_practice_level.gd:283` first requires the exact anchor to hit an
eligible walkable face. It then chooses the original cell or a sample on that
same named body within 0.375 m. It does not substitute a neighbouring deck for an
anchor over a pit. The revised walking test still checks all original gap and
return predicates.

The independent controls reject a wrong named body and a distant same-named body
at all 21 declared takeoff anchors. An anchor over the tail pit cannot select a
fake run-in cell. The one actual adjustment, `g3_east`, moves the sample
0.250078 m on `s6_runin`; 21 rays along that exact anchor-to-cell segment hit the
same walkable body. Each current prism has a convex top, so this remapping cannot
cross a hole within that body. This is a geometric anchor check, not proof of
whole-hull walking on every sampled grid path.

The only changed collision volumes are `s6_runin` and `s6_lane_top`
(`scripts/r14_practice_level.gd:337`). The tapered run-in is contained in the old
convex run-in. Split the extended landing at x=-228: its added rectangle
x `[-228.8,-228]`, z `[-118.5,-114]`, y `[-6,0]` was already occupied by the old
run-in. The east half is unchanged. The convex-corner checks establish this to
0.1 mm, allowing map-coordinate float rounding. Thus the edit adds no new support
volume outside the old collision union. The original no-forward/no-walkaround
checks and both maps' six driven return itineraries address the remaining concern
that removing the corner could open a walking bypass. No such bypass was found.

## Retained unsuccessful work and evidence I did not rerun

`geometry1` has one failed review containment assertion caused by using a fixed
cross-product tolerance at a float-rounded edge. `geometry2` uses a 0.1 mm distance
tolerance. No production geometry changed between them. `routes-new1` and
`routes-old` retain eight invalid starts each: four block setups inside a block
and four notch setups below the uphill hull corner. The corrected runs put the
block start on open pit floor and support the notch's whole hull before input.
Those initial eight cases are excluded from the final 24/24 sibling denominator.
The first parse-error log is retained. An unknown case filter is checked to fail
instead of returning a false zero-case pass.

I inspected, but did not execute again, root's `tail-return/product-guard3`,
`geometry-guard3`, `map4-routes`, `map4-warmup32`, and `native-final` metadata.
The 66.6171875 s full approach, all final main-scene tapes, and native before/after
movies remain root's evidence, not fresh review runs. I did not render or claim to
inspect those movies. The parent-reported full guard43, pure177/live63/repair135,
loop166/F4-84/section107 and Source559 suites were not rerun here. The Source559
suite's ten unsuccessful-reproduction failures are not new findings.

The late Overflow update was inspected separately. Only `phase == "tape"` rows
were used: 6,248 rows, excluding eight warmup rows. W is held at tick5952, released
at tick5953, and the runner decelerates to rest by tick6016. Guard counters are
unchanged from tick5700 through this interval; there is no new hard contact at
the final stop. `overflow-tail-observation.json` and its compressed excerpt retain
that evidence. It explains the final rest without classifying the earlier route
divergence, render cadence, or warmup difference. There was no matched runtime
Overflow replay by this reviewer, and its older completion is not treated as a
current guarded completion.

The known reported-hit sub-millimetre dips, clear-end thin-solid tunnelling and
declined nonwalkable misses are not relabelled as new regressions. No CS binary,
Windows execution, human feel or enjoyment was tested or claimed.

## Reproduction

From `projects/foldrunner`, with `O` an absolute directory outside Git and `G` the
pinned Godot executable named in the task:

```sh
$G --headless --audio-driver Dummy --fixed-fps 128 --path . \
  --script res://tests/r14_guard_review.gd -- --out="$O/scan"
$G --headless --audio-driver Dummy --fixed-fps 128 --path . \
  --script res://tests/r14_guard_review_first_touch.gd -- --out="$O/first-touch"
$G --headless --audio-driver Dummy --fixed-fps 128 --path . \
  --script res://tests/r14_guard_review_geometry.gd -- --out="$O/geometry"
$G --headless --audio-driver Dummy --fixed-fps 128 --path . \
  --script res://tests/r14_guard_review_routes.gd -- --out="$O/routes"
```

For the old-map control, add `--geometry=old --old_source=ABSOLUTE_FILE` to the last
command. `baseline-map3.gd` in the evidence root is the exact level source from
`fabe254a^`; the player remains current and guarded. A reduced residual return is
selected with `--case=tail_64_x-228.28_yaw-5.0` or its `128` counterpart. The latter
diagnostic and the full broad return diagnostic retain their expected failures.
