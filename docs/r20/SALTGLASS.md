# Saltglass component

R20 Saltglass uses the unchanged F2 Source runner on two high-entry fins, flat exit decks and a climbing crescent. This is item 1 only. Production starts through `scenes/r20.tscn` and `scripts/r20_main.gd`; the R20 catalog replaces only the `saltglass` script and keeps every R19 entry and its order.

## Geometry choices

These dimensions are game design choices, not Source physics changes.

- Remove the free turnaround connection. The salt-step tail runs east of the east fin, away from spawn. The nearest stage-3 solid is 54.3 m away in plan view. Progress still uses the inherited support/checkpoint rules, including open finishes. There is no new checkpoint gate or route trigger.
- Define near-top as actual first feet **and contact point** at least 80% of the 18 m crest. Both headraces are at 15.5 m, or 86.1%. Entry position, view and velocity come from normal spawn and real input.
- Each fin is 168 m long, made from eight 21 m convex prisms. The face remains 56.31 degrees, normal y approximately 0.55466. This gives a long surf rather than stretching the course clock.
- Each fin first lands on a horizontal 14 m deck. There is no inclined exit mouth. The crescent climbs from that deck through 14.5, 15.0 and 15.5 m islands to the 15.5 m east headrace.
- No safety platforms, catch courts or return ramps exist. A failed surf falls into the inherited kill/respawn lifecycle at the last checkpoint. Water is a visual mesh without collision.
- The salt tail descends 13.5 to 11 m across six broad islands. Its 0.5 m gaps allow a natural hop chain; the crescent's 2 m gaps and half-metre rises require jump timing. Wide landings leave room for skilled flings and cuts.
- Keep the inherited 2 cm downhill relief at each internal fin join. It is explicit in every prism's vertices and geometry hash. There is no motor, global collision or velocity adjustment. All fourteen joins must be crossed by the real runner without blocking end contacts or a 20 u/s seam loss.

The level identity is `r20-saltglass`, version 2, with public map id `saltglass`. The geometry hash includes every solid, checkpoint, spawn, finish and kill volume. Old Saltglass ghosts are incompatible; the menu and map notification explain the older-map mismatch. The original eight maps keep identical R19 motion identities, including Breakwater's delivered gate revision. Compatible local ghosts continue to use the inherited loader.

LookC is attached by the existing R19 map-id hook with its practice palette: pale landings, dark sides, ink, small lip accents and the static painted sky. L changes presentation without changing collision or the motion identity. Structural LookC contours outline the crests; there are no separate crest cylinders floating above the seam relief.

## Verification

Run from the project, using a new external output directory:

```bash
python3 -I tests/r20_surf_check.py --out=/tmp/r20-surf-recheck
```

The helper freezes source and its hashes, copies the existing import cache when available, uses the pinned Godot 4.7.2 runtime sequentially, isolates engine profiles and measures scratch separately from engine RSS. It rejects HOME below 15,000,000,000 bytes or task scratch above 350 MiB. It removes its own source/import/profile copy after proof. A supplied `--source` remains the caller's responsibility. It never touches the live `.godot` symlink.

The proof instantiates the configured production scene. The controller sends ordered key edges and float32 relative mouse events through `Input`; it never writes the runner's body, view, velocity or progress. It has no dwell nodes, clock waits or low speed target. It runs up to the high entry, surfs through genuine contacts, times island jumps and chains real tail hops. This is a coordinate-aware existence proof, not a fastest line or a model of imperfect human input.

The gates cover:

- a clean 40–70 second F2 run at 128 Hz, no respawns, both high first contacts, every fin piece, flat first supports and natural hop events;
- exact equality of every telemetry field against the ordered fixed-input replay and the same replay with LookC disabled;
- original Godot/Python strict recording reads, full position/velocity/reference-feet/view/progress alignment and ordered input retention;
- controlled early departures from both fins, sharing the intended input prefix, falling and respawning at checkpoints 0 and 2 respectively;
- straight and diagonal reverse-at-spawn attempts that fall without reaching stage 3 or finishing;
- actual collider/manifest correspondence, no walkable under-fin support, and mutation controls for an unlabelled safety floor, an inclined exit, a descending crescent, a spawn-side stage-3 bridge and collider/manifest drift;
- original catalog/ghost identity integration, title/build identity, the experimental suffix, inherited crouch, style, recording and preservation unit suites.

The bailout comparison is a physical failure versus a completed surf line. It does not assign a fabricated slower completion time to a bailout. There is no claim that all possible skips are impossible; a sufficiently skilled high-speed fling may remain.

The normal R20 proof logs must be clean. The inherited recording suite intentionally tests failed writes and is checked using its original format verifier, which distinguishes those diagnostics from normal execution.

## Native and release boundary

`tests/r20_surf_native.gd` is the parent-owned native observation seam. Run it with the same pinned engine and a verified private display, the normal `--path`, `--fixed-fps 128`, `--script res://tests/r20_surf_native.gd`, and user arguments `--out=<new external directory> --tape=<accepted run/events.tape.json>`. It takes selected frames after actual rendered draws without moving the body or camera. `--old-look=1` gives the same collision trace with the original presentation. No helper chooses a display or uses desktop :0.

The component proof is headless. Parent still owns native moving-view inspection, landing/sky/ink legibility, final configured-host parity after later items, source/package provenance, Linux/Windows exports and final promotion. This component does not establish enjoyment, a fastest human route or a final release.
