# Sluice Six

Sluice Six is a tidal settling channel whose maintenance caps have become a running course. Its landmark is a square spill tower at the downstream end, with daylight through its crown. From spawn the player sees pale caps stepping across blue-green water toward that tower. The retaining banks connect the entire place, and every cap continues below water to a foundation. Orange marks only exposed landing lips; dark concrete sides separate the route from its water and walls.

## Route and measurements

The apron provides 20 m of acceleration before the first gap. Four broad 12 m caps introduce timing; five 9 m caps offset across the race test landing placement; five 3.2512 m square caps narrow the final approach. Four checkpoints support practice without changing F2. The direct centre line is reserved for the faster proof; ordinary caps remain wide enough to change approach.

`tests/sluice_six_measure.gd` instantiates all three original R15 maps and emits every route-piece footprint, top elevation, gap distance and rise. Raw evidence stays outside Git under the run folder. Collision pieces are not whole platforms: a Breakwater container roof is 2.438 m wide but six roofs form its 14.628 m landing.

| Course | Declared horizontal gap range | Declared rise range | Representative landing |
| --- | --- | --- | --- |
| Breakwater | 2–8.5 m | -1–0 m | 6.058 m long container rows, 14.628 m across six roofs |
| Whiteout Relay | 2–6.5 m | -1–0.4 m | 3–28 m collision-piece widths |
| Sunken Court | 2–8.382 m | -1.2–0.8 m | 0.583–28 m collision-piece widths, including curved wedges |

These are measurements of built geometry and authored gap declarations, not inferred jump limits. The initial Sluice Six greybox uses flat 6.5 m caps, 2 m opening gap and 2.5 m repeating gaps. Community-map comparison remains pending until lane 12's reference sheet arrives.

## Verification

`tests/sluice_six_tapes.gd` drives the unchanged course player from normal spawn using input commands at 128 Hz. Evidence includes its F2 identity, geometry digest and per-tick commands outside Git. The lane report distinguishes complete slices from pending work.

## Community-scale revision

Lane 12's 17 Nov preliminary sheet was checked against `bhop_eazy-platforms.csv`: 188 `func_door` rows, of which 180 are 64×64 u (1.6256 m square), four 32×64 u, four with angled bounds. This is pad-size evidence, not a measured route-gap distribution. No source map layout or asset was copied.

The final five Sluice Six caps now measure 128×128 u (3.2512 m square), down from 6×6.5 m. Their pitch tightens from 9 to 6 m, leaving 2.7488 m gaps and requiring more frequent landings. Offsets reduce from ±1.5 to ±0.8 m so the unchanged F2 hull retains a direct line. The tower court moves forward 15 m with the shorter race. Opening and middle sections retain their broad landing margin. These spacings are original F2 design choices, not claimed measurements from CS:S. Both scripted F2 lines finish after the revision; retained evidence is named in the lane report.

## Retained fast-line proof

The normal v2 tape finishes in 2821 ticks; the paired-strafe line finishes in 2491 ticks, 330 ticks faster at the same F2 preset. The fast driver releases W while airborne, completes matched strafe pairs before coasting, and avoids steering during the initial spawn-floor settle. Its view yaw stays within 0.120 radians of forward on this straight course. This proves a scripted faster line, not a human difficulty rating.

Generate both tapes with `python3 tools/play.py --headless --fixed-fps 128 --script res://tests/sluice_six_tapes.gd -- --expert --out=/absolute/external/new-folder`. The output contains commands, action/mouse event arrays, tick counts, grounded section visits and the geometry hash. Independently replay its `tapes.json` with `python3 tools/play.py --headless --fixed-fps 128 --script res://tests/sluice_six_replay.gd -- --tape=/absolute/path/tapes.json --out=/absolute/external/replay-folder`. Replay reads commands without choosing takeoffs or consulting landing geometry, rejects mismatched geometry/preset, and verifies safe completion and the recorded final-position strings.
