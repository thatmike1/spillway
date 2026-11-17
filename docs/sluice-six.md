# Sluice Six

Sluice Six is a tidal settling channel whose maintenance caps have become a running course. Its landmark is a square spill tower at the downstream end, with daylight through its crown. From spawn the player sees pale caps stepping across blue-green water toward that tower. The retaining banks connect the entire place, and every cap continues below water to a foundation. Orange marks only exposed landing lips; dark concrete sides separate the route from its water and walls.

## Route and measurements

The apron provides 20 m of acceleration before the first gap. Four broad 12 m caps introduce timing; five 9 m caps offset across the race test landing placement; five 6 m caps narrow the final approach. Four checkpoints support practice without changing F2. The direct centre line is reserved for the faster proof; ordinary caps remain wide enough to change approach.

`tests/sluice_six_measure.gd` instantiates all three original R15 maps and emits every route-piece footprint, top elevation, gap distance and rise. Raw evidence stays outside Git under the run folder. Collision pieces are not whole platforms: a Breakwater container roof is 2.438 m wide but six roofs form its 14.628 m landing.

| Course | Declared horizontal gap range | Declared rise range | Representative landing |
| --- | --- | --- | --- |
| Breakwater | 2–8.5 m | -1–0 m | 6.058 m long container rows, 14.628 m across six roofs |
| Whiteout Relay | 2–6.5 m | -1–0.4 m | 3–28 m collision-piece widths |
| Sunken Court | 2–8.382 m | -1.2–0.8 m | 0.583–28 m collision-piece widths, including curved wedges |

These are measurements of built geometry and authored gap declarations, not inferred jump limits. The initial Sluice Six greybox uses flat 6.5 m caps, 2 m opening gap and 2.5 m repeating gaps. Community-map comparison remains pending until lane 12's reference sheet arrives.

## Verification

`tests/sluice_six_tapes.gd` drives the unchanged course player from normal spawn using input commands at 128 Hz. Evidence includes its F2 identity, geometry digest and per-tick commands outside Git. The lane report distinguishes complete slices from pending work.
