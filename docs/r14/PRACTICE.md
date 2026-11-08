# R14 practice map: Penstock Yard

An original bhop and air-strafe training course on the bench beside the dam. It is a separate
level, not a change to Overflow. Source acceptance is deferred: no Source motor existed when
this was built, so every movement result below comes from the R13 carry runner as a labelled
stand-in, and every "vanilla" figure is a dimension check with provisional numbers.

Files: `scripts/r14_practice_level.gd` (the level), `scripts/r14_practice_lab.gd` (standalone
lab), `tests/test_r14_practice_level.gd` (geometry and interface), `tests/r14_practice_driver.gd`
(closed-loop input driver), `tests/r14_practice_overview.gd` (still renders).

## Units and provisional numbers (P)

- 1 u = 0.0254 m. Every mark and manifest entry gives both.
- Vanilla CS:GO, pending SOURCE-REFERENCE.md: 250 u/s run (6.35 m/s), 301.993 u/s jump
  (7.67 m/s), gravity 800 u/s² (20.32 m/s²). A flat jump lasts 0.755 s and peaks at 57 u (1.45 m).
- Gaps are judged feet centre to feet centre with no hull credit, a 0.5 m landing margin, and
  "comfortable" meaning the jump can also be pressed 0.1 s early. A 32 u Source box hull gains
  about 0.81 m on every gap, so real play is easier than these numbers; advanced gaps are also
  checked to fail at 250 u/s even with that full credit.
- Tiers by the speed that clears with the landing margin: `vanilla_run` (comfortable at 250),
  `vanilla_run_tight` (clears at 250 only near the edge), `vanilla_strafe` (to 330),
  `server` (to 520), `fast` (above).

## Layout

Forward is -z, then -x after the valve bend, then -z after the pump bend. Track 16 m (630 u)
wide, training walls 2 m over the deck, pits 2.5 m deep (deeper than a jump or a crouch-jump
can climb). Plan render: `checkpoints/spillway/r14/practice-map/overview/plan.png`.

| stage | section | what it trains |
|---|---|---|
| 0 Gatehouse | pad + Penstock straight, 128 m (5039 u) flat | building speed. Lines every 8 m, wall labels every 16 m in m and u. Nothing on it adds or removes speed |
| 1 Stop logs | 5 straight blocks, gaps 2.0 / 2.5 / 3.0 / 3.5 / 4.0 m, then 3 zig blocks 2 m apart sideways | hop rhythm, then A/D placement |
| 2 Valve bend | left quarter ring, r 6-20 m islands, two 18° radial gaps | strafing round a corner: 2.5 m inside, 5.9 m outside, so the line that keeps speed needs it |
| 3 Weir gauges | two gaps whose take-off edge is slanted across the track | distance: g1 3 → 8 m (north → south), g2 12 → 3 m, so the wide line zig-zags. Ticks every metre say the width and the u/s that clears it |
| 4 Pump bend | right quarter ring: walkable inside band (r 4-12), outer band with a 30° notch | the inside walks round; the outside carries speed over an 8.3 m (mid) to 10.1 m (outer) notch |
| 5 Tail race | last gauge, 1.5 m down: 3.5 m east (inside) to 14 m west (outside) | a long finishing jump off the bend's fast exit |
| finish | Tailwater platform, band 4 m deep, 11.5 m of braking room | |

### Recovery (P decision)

Every pit walks back to where its missed jump started (the take-off deck, or the runway's end
for the blocks and the valve bend). Nothing in a pit leads forward. Reason: Source keeps
horizontal speed through a landing and a hopping runner climbs a ramp for free, so a forward
catch path would be a faster way round the gap it catches. The pump bend's notch is the one
exception: its catch is a slope back up to the inside band, which is that section's walkable
basic line anyway. Rejected: Overflow-style forward catch aprons, and teleporting fail zones.

## Gaps (from `course_manifest()`)

| gap | line | width m / u | drop m | clears at u/s | comfortable u/s | intended u/s | tier | slack at 250 u/s |
|---|---|---|---|---|---|---|---|---|
| block_1 | basic | 2.00 / 79 | 0 | 130 | 150 | - | vanilla_run | 0.361 s |
| block_2 | basic | 2.50 / 98 | 0 | 156 | 180 | - | vanilla_run | 0.283 s |
| block_3 | basic | 3.00 / 118 | 0 | 183 | 210 | - | vanilla_run | 0.204 s |
| block_4 | basic | 3.50 / 138 | 0 | 209 | 240 | - | vanilla_run | 0.125 s |
| block_5 | basic | 4.00 / 157 | 0 | 235 | 270 | - | vanilla_run_tight | 0.046 s |
| block_6 (zig) | basic | 2.50 / 98 | 0 | 156 | 180 | - | vanilla_run | 0.283 s |
| block_7, 8 (zig corner) | basic | 3.20 / 126 | 0 | 193 | 222 | - | vanilla_run | 0.172 s |
| block_to_bend | basic | 3.00 / 118 | 0 | 183 | 210 | - | vanilla_run | 0.204 s |
| bend inside (r 8) | basic | 2.50 / 99 | 0 | 157 | 181 | - | vanilla_run | 0.282 s |
| bend outside (r 19) | advanced | 5.94 / 234 | 0 | 336 | 387 | 420 | server | - |
| g1 north (1 m in) | basic | 3.31 / 130 | 0 | 199 | 229 | - | vanilla_run | 0.155 s |
| g1 south (1 m in) | advanced | 7.69 / 303 | 0 | 427 | 492 | 540 | server | - |
| g2 south (1 m in) | basic | 3.56 / 140 | 0 | 212 | 244 | - | vanilla_run | 0.115 s |
| g2 north (1 m in) | advanced | 11.44 / 450 | 0 | 623 | 718 | 720 | fast | - |
| notch middle (r 16) | advanced | 8.28 / 326 | 0 | 458 | 528 | 580 | server | - |
| notch outer (r 19.5) | advanced | 10.09 / 397 | 0 | 552 | 637 | 680 | fast | - |
| g3 east (1 m in) | basic | 4.16 / 164 | 1.5 | 200 | 225 | - | vanilla_run | 0.183 s |
| g3 west (1 m in) | advanced | 13.34 / 525 | 1.5 | 595 | 668 | 700 | fast | - |

Intended entry speeds are design choices for the advanced lines, not measurements. Painted
gauge rate: flat gaps need 52.15 u/s per metre, the 1.5 m drop 42.97 u/s per metre.

## Interface

The level publishes Overflow's public fields and methods, read from the actual consumers
(`momentum_overflow_main.gd`, its HUD, audio and art pass): `spawn`, `checkpoints` (pose, title,
`radius: 0` so stages are collected only by standing on their decks), `segment_bounds`,
`segment_at()`, `finish_position`, `finish_radius`, `finish_title`, `is_finish_at()`,
`kill_bounds`, `water_regions` (empty), `water_audio_sources`, `routes` (`ordinary` = `basic`,
`advanced`, one per recovery), `jump_gaps` (Overflow's keys plus metres, units, tiers),
`route_hint()`, `start_wheel()`, `reset_state()`, `manifest`, `geometry_manifest()`,
`geometry_hash()`, `material_mode`, `variant`. Added: `level_id`
(`r14-practice-penstock-yard`), `level_name`, `level_version` (1), `markings`, and
`course_manifest()`. Solids are named `s<stage>_<piece>` and never renamed; renaming changes the
hash. `variant` accepts only `practice`; precision variants (shallower blocks, narrower landings)
or a Quake/CPMA challenger line can be added as new variants without touching this one.

R13's main hosts it unchanged:
`godot --path . res://scenes/momentum_overflow.tscn -- --overflow-level=res://scripts/r14_practice_level.gd --no-records`.

## Lab

`godot --path . --script res://scripts/r14_practice_lab.gd -- [--r14-runner=res://...] [--stage=N]`

R restart from the gatehouse (the only run that can finish clean), F restart this stage, 1-6
practise stage N, Esc pause. The HUD shows speed in u/s and m/s from actual travel, and every
jump's measured distance, air time, take-off and landing speed and the declared gap it crossed
("made" or "short"). Runner: `--r14-runner`, else `r14_source_player.gd` once it exists, else
the R13 carry runner labelled "stand-in, NOT Source". No profile or record is read or written.

## Checks

- `godot --headless --path . --script res://tests/test_r14_practice_level.gd -- --out=DIR`:
  1411 checks: interface, unique stable names, repeatable hash, planar walkable tops, every
  declared gap measured in the collision within 3 cm of its declared width, basic gaps clear at
  250 u/s, advanced gaps fail at 250 u/s (even with box-hull credit) and clear at their intended
  speed, every pit walks back along its recovery and never forward, no gap can be walked round
  except the notch, the finish cannot be walked to, and the R13 main hosts the level.
- `godot --headless --path . --script res://tests/r14_practice_driver.gd -- --out=DIR --route=basic|block_miss|g1_miss|g3_miss [--late=TICKS --jitter=PX --seed=N]`.

## Limitations

- No Source movement was available: vanilla and server viability is arithmetic on provisional
  numbers. True Source acceptance (actual A/D + mouse runs at 64 and 128 Hz) is deferred.
- The R13 stand-in runs at 335 u/s and flies 6.16 m per hop; it cannot earn the advanced lines'
  speeds on flat ground, so no advanced line has an execution proof.
- The R13 body has no step-up. Source's 18 u step would also walk the lower centimetres of a
  return ramp's sloping side; the stand-in needs each ramp's flush end.
- With the stand-in, pressing every jump 33 ms late failed at the third block: its 6.16 m flight
  over 3 m blocks leaves about a 0.3 s window and the driver's planned take-off sat near its end.
  Whether 3 m blocks suit Source speeds (4.8 m flights at 250 u/s, 10 m and more at server
  speeds) needs Source runs; deeper blocks are a one-line change in `BLOCKS`.
- Gauge paint is legible from a standstill; in shadow at speed it is hard to read.
