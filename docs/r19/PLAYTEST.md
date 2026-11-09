# Mike’s R18 playtest, read for R19

All 32 sealed recordings passed the project’s strict R16 reader. The recording bytes are **29 F2 (`server128`) attempts and three AA1000 (`server128_aa1000`) attempts**, rather than 32 F2 attempts. All three AA1000 attempts are on Breakwater, and both recorded falls are in those attempts. There are no recorded F2 respawns in this sample. The source files and settings were not edited. Before/after input SHA256 values match in `r19-analysis.json`.

## What he played

| Map | Attempts | Recorded time | Restarts | Finishes | Falls | Best clean F2 |
|---|---:|---:|---:|---:|---:|---:|
| Breakwater | 15 | 154.09 s | 8 | 2 | 2 | 22.836 s |
| Night Shift | 7 | 179.63 s | 3 | 3 | 0 | 26.109 s |
| Whiteout Relay | 5 | 82.15 s | 3 | 1 | 0 | 29.711 s |
| Rainline | 3 | 63.21 s | 0 | 2 | 0 | 23.555 s |
| Sunken Court | 1 | 39.02 s | 0 | 1 | 0 | 37.609 s |
| Movement Lab | 1 | 20.95 s | 0 | 0 | 0 | none |

Breakwater has the most attempts and restarts; Night Shift has the most recorded play time. Recorded time includes waiting, title/menu pauses between physics steps and post-finish ticks, so it is not a measure of enjoyment. Clean finish times come from the sealed outcome, rather than total tick duration. A restart or Quit says what was pressed, not why.

## Breakwater

The two clean F2 lines finish in **28.0625 s** and **22.8359375 s**, with all four course checkpoints. The faster line crosses the container roofs, bends onto the quay, then uses the east side of the runway around x=−78 through z=−198 before the breach. It stays available.

Two independent F2 attempts lose **901.8** and **802.7 u/s** at the optional RunwayThread installation. Both settle at z≈−196.84. They approach different sides of its 1.05 m opening: x≈−80.8 and x≈−81.7. The real player hull’s collision queries hit the named EastWall and WestWall, respectively, at exactly this front. This supports a local obstacle diagnosis rather than inferring it solely from speed loss.

**R19 change:** move each wall outward by 0.50 m, making the clear opening **2.05 m**. Their sizes, height, depth, deck, stage triggers, spawn, finish and kill bounds stay unchanged. The queries clear both observed approaches after the change; the faster east line clears both versions. Near-miss scoring still uses ordinary physical proximity to either wall. This loosens the installation rather than adding a route or requiring its use. It has a new geometry and overlay identity; earlier recordings are kept as older-map ghosts and cannot race this revision.

A separate F2 stop near spawn has no movement input, and an AA1000 fall near the quay is not evidence for changing F2 geometry. Eight attempts end in restart, two in preset changes, one in practice, one in Quit and one in map selection.

## Night Shift

Three clean lines finish in **35.109375**, **35.6796875** and **26.109375 s**, reaching all five checkpoints. The lines cross the switchyard, thread the transit works and return on the elevated route. Some broad cuts differ between runs; no new mandatory waypoint or barrier is added.

There is one sharp **654.1 u/s** loss in five ticks near (18.3, 0.2, −95.4) with jump/left held and no motion event. It merits a future contact replay, but this sample does not identify the collider. Another **793.5 u/s** drop near (50.3, 0, −81.4) includes landing and a 0.664 s slow span with movement held for 84% of it. The remaining ≥0.5 s slow span has no movement input. Three restarts, one map change, no falls. **No geometry change:** the fastest clean line works and the suspect contact is not yet diagnosed.

## Whiteout Relay

Five F2 attempts include three restarts, one map change and a **29.7109375 s** clean finish through all four checkpoints. The lines follow the radar apron, road hurdles and trenches, pylons, saddle and receiver.

Two losses reach the first hurdle’s leading face around z=−54.6: **450.7 u/s** during an airborne duck/stand sequence, and **490.3 u/s** over a longer approach ending with input released. Its 0.55 m height is deliberately above the motor’s 18 u step. The successful run clears it, so lowering it would erase an authored jump challenge without enough evidence. Stops at the road trench and first hurdle have movement input released for almost their whole duration. A **591.7 u/s** saddle loss also includes a large view turn. No falls. **No geometry change.**

## Rainline

Two clean rooftop lines finish in **25.59375** and **23.5546875 s**, reaching all four checkpoints. The third attempt ends on map selection. There are no restarts, respawns or ≥0.5 s low-speed spans. Crouch saves and edge/near-miss events show that the roof furniture and gaps are being used. The lower route and rooftop cuts remain open. **No geometry change.**

## Sunken Court

The single F2 line finishes clean in **37.609375 s**, reaching all four checkpoints through the terraces and ruin. A **796 u/s** loss near (35.7, 5, −56.9) includes a large view turn and released movement keys. The 4.55 s near-spawn slow span also has almost no movement input. One run cannot establish a recurring snag. No restart or respawn. **No geometry change.**

## Movement Lab

One **20.945 s** recording ends with Quit, with no restart or respawn. It reaches the first practice checkpoint, records six jumps and an actual `slide_armed → slide → slide_landing → slide_end` sequence. Eight `hop_held_ignored` events are the deliberate slide rule, not failed bhop input. A 4.12 s stop near (0.7, 0, −10.1) has movement held for 0.4% of the span. This does not establish frustration or a broken mechanic. **No geometry change.**

## What style actually fired

These totals include unfinished attempts and the three labelled AA1000 runs. They describe R18 scoring, before R19’s new direction awards.

| Map | Recorded awards (count / points) |
|---|---|
| Breakwater | sync: 122 / 17320, gap: 34 / 18983, speed: 35 / 5539, crouch_save: 2 / 9000, near_miss: 2 / 1223 |
| Night Shift | sync: 124 / 16924, speed: 41 / 4519, edge: 7 / 2553, near_miss: 1 / 448, crouch_save: 3 / 10497 |
| Whiteout Relay | sync: 65 / 9615, near_miss: 1 / 152, speed: 20 / 2833, gap: 12 / 6785, crouch_save: 1 / 4500 |
| Rainline | sync: 50 / 6215, speed: 18 / 2713, gap: 4 / 809, edge: 5 / 1061, crouch_save: 4 / 17049, near_miss: 3 / 1513 |
| Sunken Court | sync: 27 / 3878, gap: 9 / 4168, speed: 9 / 1201, crouch_save: 1 / 900 |
| Movement Lab | sync: 2 / 94, crouch_save: 1 / 750, gap: 1 / 158 |

## Method and limits

Run from `look/wt/projects/foldrunner`:

```bash
python3 -I tools/analyze-r19-playtest.py /home/thatmike1/foldrunner-build-2026-11-05/playtest-r18/userdata-spillway/r16_runs --output /home/thatmike1/foldrunner-build-2026-11-05/playtest-r18/r19-analysis.json
```

The committed helper imports the existing strict `tools/analyze-r16-runs.py` reader, validates each complete hash chain and pins every file and both helper versions. Speed uses `actual_v`, excluding duck-origin shifts. Slow spans mean <25 u/s for ≥0.5 s while started and unfinished, split at teleport/lifecycle discontinuities. Held input is a recorded fact, not an intent classifier. The quarter-second feet lines and checkpoint times remain in the JSON, along with full per-run speed losses, motion/style events and stop coordinates.

`tests/r19_course_contacts.gd` is a labelled physical collision-query fixture, not a replay of Mike’s movement or a parity result. Its 44 checks pass: both original contacts name the optional thread, both widened approaches clear, the faster east approach remains clear, all eight maps keep their spawn/checkpoint/finish/kill bounds, and only Breakwater changes its motion identity. Final full-input parity and packaged/native acceptance are separate release gates.
