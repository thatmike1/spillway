# R14 loop review at 04532add

Three reproduced defects: a mixed-preset attempt saves a clean vanilla record, the first
immediate hop after a switch disappears from the HUD, and airborne players can be labelled
on the ground. A pending-switch/map interaction also contradicts PLAYABLE.md's stated map
policy. No runtime fixes were made by this review.

Reviewed commit: `04532add27a7d32c788bd72e3cf1892c9365c4a5`, 8 November 2026.
Read AGENTS.md, BRIEF.md, INTERFACES.md and PLAYABLE.md before testing. The related active
bead is ccChat-general-rowb. Source contact repair and actual Source practice routes remain
separate work. This report neither repeats SOURCE-REVIEW.md nor accepts those routes.

Evidence root, outside Git:
`/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/loop-review/`.
Final machine-readable results are `headless-final-3/checks.json`, its `trace.jsonl.gz`,
`reductions-final-3.json`, `native-default/run.json` and `manifest.json`.

## P1: a jump begun in F2 saves as a clean F1 record

Location: scripts/r14_main.gd:298, 306, 478. `_switch_to()` uses `not _started` to mean an
untouched spawn. `_started` only becomes true after the feet move more than 0.5 m. A real
initial jump has already applied F2's law before that threshold.

Exact automated reproduction: `early-midflight-switch` in tests/r14_loop_review.gd.

1. Start a settled server128 runner on the flat loop fixture.
2. Hold Space for six physics-frame waits, then release it. The body is airborne and above
   0.2 m, but the timer has not armed yet.
3. Select vanilla64 immediately. Allow twenty callback waits. Feet reach
   `(0, 1.414008, 4)` and `_started` is true, but `clean_eligible` remains true and
   `practice_reason` remains empty. The switch's old-delta callback happened before the
   timer armed, so the rate safeguard does not disqualify it either.
4. Hold W through the actual fixture decks and finish. This uses real collision and input;
   the driver does not write progress, elapsed time, splits or call `_finish()`.

Actual consequence: `early-mixed-records.cfg` contains section
`course_bc69d3453de29166`, `preset="vanilla64"`, `physics_hz=64`, `clean_best=6.75`,
`clean_splits=[2.9375, 4.5, 6.75]`, `clean_segments=[2.9375, 1.5625, 2.25]`.
The attempt began its jump under server128. `finish_kind="clean"` and `last_save_ok=true`.
This defeats preset isolation even though the key itself correctly fingerprints vanilla.

Affected fields: clean eligibility/reason, finish kind, best/open best, full clean splits
and segments in the destination preset's record section. Fix the distinction between an
untouched spawn and an attempt whose timer has not started; preserve clean switching at a
truly untouched spawn.

## P2: the first immediate post-switch hop is omitted

Location: scripts/r14_strafe_stats.gd:102-108. `watch()` resets the observer, and its first
callback returns without reading that step's jump event.

Repro: settle F2 on the fixture, select F1 while grounded, immediately send one wheel-up
press and release before the next callback. Wait for the real hop to land. Phase
`first-hop-after-switch` has a jump event at main callback 16 and landing at callback 63.
Positions rise to 1.418520 m and descend. The motor records a 48-tick hop, but the observer
still has `hop_count=0`, empty `last_hop`, no flight, and no jump feedback. No pose/velocity
write is used in this case.

Affected fields: `flight`, `hop_count`, `last_hop`, completed-hop sync totals, and all four
strafe-panel lines for that hop. Establishing a baseline must not discard a real jump
that happened on the first observed callback.

## P2: an empty hop accumulator falsely means grounded

Location: scripts/r14_hud.gd:227 and scripts/r14_strafe_stats.gd:118-120.

Repro A: accelerate with W for 55 callback waits, jump for 12, release Space, apply a
0.3-radian yaw and 0.2-radian pitch change, then hot-switch through F1, F3 and F2 with three
callback waits after each. Every switch preserves feet, velocity, yaw and pitch at the
switch instant, and the body then travels horizontally. At the three checks, feet heights
are approximately 0.869, 1.007 and 1.099 m and the runners report airborne, while the HUD
says `on the ground · run sync —`.

Repro B: phase `drop-labelled-placement` places the fixture runner at `(0, 1.5, 4)`, resets
stats, and lets gravity run. Actual positions fall while airborne, but the same ground
message persists. This placement is a labelled drop fixture, not a played course route.

The switch deliberately resets stats, and a drop need not invent a jump. Neither requires
lying about current contact. The panel chooses its motion label from `flight.is_empty()`
instead of actual grounded state. A fresh airborne accumulator or an explicit airborne
state with unavailable takeoff statistics would both avoid the false statement.

## P3: changing map applies a waiting preset rather than retaining the active one

Location: scripts/r14_main.gd `select_map()` → `restart_run()` → `_try_pending()`.

Repro: with R13 active, place its capsule in the fixture's 0.7 m slot at `(9, 0.04, -1)`.
Request F2. The wider Source hull correctly waits. Select Penstock Yard. The map's restart
applies the pending F2 at the new spawn, so the active preset becomes server128.

This is an actual family/rate/record-key change, not just a stale menu label. PLAYABLE.md
says a map switch keeps the same preset and explicitly grants pending-application behavior
to R. The pending request makes either behavior defensible, but implementation and policy
must agree. Treat this as a product-policy discrepancy, not a collision failure. Active-key
cancellation, movement into room, and R applying the pending switch at spawn all passed.

## What was checked

The final adversarial run executed **52 assertions across 3,109 real post-step callbacks**:
43 passed, 9 failed. Seven failures substantiate the three defects above, one is the map
policy discrepancy, and one is the deliberately retained manual-input negative case below.
This count is separate from the root's reported 166/166 and worker's reported native 30/30;
those earlier results were not promoted into this review's denominator.

- Real default scene instantiation with the project's original 120 Hz starting setting,
  without the early-rate launcher: F2/server128, actual 1/128 callbacks, clean untouched
  spawn. No startup mismatch occurred in this run.
- Mid-flight same-body and cross-family switches: exact immediate feet, velocity, nonzero
  yaw/pitch preservation, followed by measured horizontal displacement. R13's permitted
  extreme pitch clamp was not exercised.
- Actual callback deltas after live switches and pauses, not only the engine rate property.
  Paused position/time and all three settled resume rates passed. Old-rate callbacks were
  observed and retained. Aggregate deltas are in reductions-final-3.json; its 64/128/120 Hz
  distribution includes intentional transition callbacks and separate game creations.
- Vanilla held Space jumps once; an isolated wheel pulse jumps; held-input-to-wheel with a
  neutral command also jumps. Server behavior and source sync are covered by actual input,
  rather than asserted from a stored velocity value.
- Narrow hull wait/cancel, actual movement out of the slot, pending switch at restart,
  restart counters, one-step jump/landing, short drop, practice after finish, actual clean
  and practice fixture finishes, map changes and record-key isolation.
- Exact saved split and segment arrays reload into a fresh game instance, return when
  switching back to the preset, and remain untouched after a practice finish. Source look
  settings do not change the key. A map change gets its own key and reset attempt/stats.

### Independent jump and sync reductions

tests/r14_loop_review_analyze.py imports neither game implementation nor Source oracle.
It reduces trace endpoints, actual successive positions, yaw differences and applied A/D,
including the landing callback. **23/23 final reduction checks passed**, subject to the
contact-transition exclusion below. Values below are u/s; distances come from resolved
positions, not velocity integration.

| Fixture episode | Takeoff → landing | Gain | Contact | Air | Sync | Resolved air distance |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| No-input coast with mouse turn | 235.599 → 235.599 | 0 | 0 | 0 | unavailable, 0 eligible | 4.442 m |
| A with opposite turn | 235.599 → 237.501 | +1.902 | 0 | +1.902 | 0/93 | 4.478 m |
| A with same-direction turn | 235.599 → 269.073 | +33.474 | 0 | +33.474 | 93/93 | 4.772 m |
| Same-direction turn into wall | 220.784 → 76.215 | -144.569 | -152.690 | +8.121 | 93/93 | 3.030 m |
| Vanilla before delayed next hop | 242.425 → 268.812 | +26.387 | 0 | +26.387 | 45/45 | 4.781 m |

The delayed vanilla next takeoff independently gives chain -182.623, ground -209.009 and
15 ground ticks. Restart's counter discontinuity and a one-callback ceiling hop both
counted once. The ceiling fixture produced both `jump` and `land` on the same step and
actual vertical displacement. A very short drop produced no invented jump.

Contact loss uses requested versus resolved **endpoint** speed, backed by observed blocked
travel on wall ticks. Mean travel during a partially blocked step differs from endpoint
speed, so treating displacement/delta as that endpoint would be wrong. On unobstructed
non-jump air steps, endpoint speed agrees with measured travel within 0.004 u/s.

Sync is deliberately turn-direction agreement, not efficiency. The native hop's 100%
sync with only 3 eligible samples is labelled `(3/3)`. Neither a poor turn rate at 100%
nor the opposite-turn hop's small positive gain is called a defect.

### Native default launch and presentation

The final native launch used only the pinned Godot binary, `--audio-driver Dummy` and
`--path` to this project. No scene override, preset/rate override, fixed-fps flag or
early-rate script. It started at Penstock Yard/F2, with `records=new` in an empty isolated
XDG profile. Xvfb display :160 and llvmpipe were private; the desktop and speakers were not
used. Native rendering is not a physical-performance measurement.

Inspected full-size 1280×720 player frames, including the spawn, switch presentation,
pause, settings, actual strafe and completed-hop panel. Final MP4 is 18.167 seconds,
544 frames, and decodes without errors. Native results:

- OS hotkeys updated the actual window title through F1/64, F3/120 and F2/128: 3/3.
- OS click selected vanilla in the paused preset list: 1/1. Separate native screenshots can
  show a previously rendered frame while the title already reflects the new state; labels
  in PNG filenames are event intents, not independent claims of that rendered frame's state.
- OS click changed Source sensitivity from 2.50 to 7.10: 1/1, confirmed in the rendered
  look line and isolated profile cfg. The metric toggle was visible but not clicked.
- Speed at 231 u/s and later hop gain +5, sync 100% (3/3), 47 ticks and 228 → 233 u/s were
  readable. In these inspected frames the strafe panel did not overlap the speed readout.
  This is a bounded readability check, not all resolutions or extreme count widths.
- Native map click: 0/1. The helper clicked y=255 while the final map button was at y≈275;
  it hit the heading. `13-map-overflow.png` still shows Penstock's paused menu. Excluded as
  a helper miss, not a product defect. Real map changes are verified by the headless driver.

## Retained failures, exclusions and limits

- Initial manual-wheel assertion failed because release of held Space and the wheel pulse
  shared one command interval. No neutral command reached the manual motor, so `jump_prev`
  remained held. The pulse after one neutral callback passed. Retained in all checks.json
  files as an input-sampling limit; not counted as a proven Source defect.
- The first position/endpoint reducer was 19/23. Jump-transition ticks had up to 1.465 u/s
  residual, about 0.00029 m at 128 Hz, even without reported contacts. Retained in
  reductions-v2.json. Final 23/23 excludes those transition ticks from the unobstructed
  travel equality check. Source contact repair owns that discrepancy; it is not declared
  fixed or silently absorbed into the final tolerance.
- Native attempts: one early X focus failure before capture, two startup captures excluded,
  one valid default smoke and one final default/settings/strafe capture. The two excluded
  movies and EXCLUDED.txt files remain. Window creation and even the scene-ready log can
  precede shader compilation's first rendered player frame. The final helper waits longer
  and rejects a splash-sized first screenshot. All owned processes were terminated.
- Earlier adversarial iterations remain: 36/43, 42/49, 42/49 and 43/51 before final 43/52.
  Some earlier check-detail arrays were mutable references; final helper freezes detail
  dictionaries/arrays at assertion time. Final results and raw per-callback traces prevail.
- No full Source practice route, engine/binary CS fidelity, enjoyment, real human feel,
  Windows execution, physical mouse latency, gamepad or hardware performance acceptance.
  Flat fixture finishes prove loop behavior. Source-OS early-rate fixtures are not product
  acceptance and were not used to waive any of these failures.

## Frozen source, helpers and cleanup

`manifest.json` records SHA-256 for 116 scripts, scenes, the project config and existing
fixture, all verified byte-for-byte against 04532add. This includes the unchanged R13
runtime. No runtime, existing test, oracle, Source review or another worker's file changed.

Key frozen SHA-256 values:

```text
r14_main.gd          ba1262d85404c5ea2ce8148a2ba705419d4365354077d08bd84ed1d5f2e6ed58
r14_strafe_stats.gd  9b26e75b464f3f642688c1c8cdd9f3a1b9c1004520eb3ab9f4c78bc04f66fd7c
r14_hud.gd           181003d364787e42a1f3a067a10dbb7e4dee49e6a535cdbe654965d5f784fc41
project.godot       76c063899cfff2609de2338c42a735641e58e1b7d6af68d0cd8a3ca2a2288e21
review driver       718ef44686d0f7e55d3091e1e44953851e03107fda199995d9a6baf004778f40
native helper       905b1dd45a70df7735039cc9d802c3784efb36aa395798276f944b87aab0128c
reduction helper    ab13fb3df4ab63e5afcf165cf75b9c42dac10d7d73b559848bbaa0373d385b30
Godot binary        8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e
```

Godot: `4.7.2.stable.official.ed1daf0bf`. Python helpers compile; final Godot import has no
script errors. Every raw trace was gzipped and decompressed-hash checked before removal.
All four MP4s decode cleanly. Evidence is approximately 32.55 MiB, below the 100 MiB cap.
Each native launch checked /home for at least 15 GiB free. Final recorded prelaunch free
space was 16,708,472,832 bytes. Displays, sockets, locks and isolated profiles were removed;
only intentional evidence remains. No commits, pushes or child agents.

Reproduce from projects/foldrunner, using an isolated XDG environment:

```sh
G=/home/thatmike1/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64
$G --headless --audio-driver Dummy --fixed-fps 120 --path . \
  --script res://tests/r14_loop_review.gd -- --out=/absolute/evidence/path
python3 tests/r14_loop_review_analyze.py /absolute/evidence/path/trace.jsonl \
  --out=/absolute/evidence/path/reductions.json
python3 tests/r14_loop_review_native.py --out /absolute/native/evidence/path
```

The adversarial driver intentionally exits 1 on this frozen revision because its failures
are retained. Use a fresh evidence path for another run.
