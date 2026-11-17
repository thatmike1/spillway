# Viaduct

Viaduct is a retired flood-control bridge whose maintenance terraces form a curved swing course over its stilling basin. Its landmark is one continuous overhead lifting gantry, carried by pairs of concrete piers rooted in the basin floor. From spawn the first suspended orange ring sits against open sky under the gantry, with the next pale terrace visible beyond it. Three offset bays turn right, then left, so release direction matters as much as reach. A lower maintenance court and connected ramps let a missed swing return to any terrace without restarting.

The runner is the unchanged `scripts/movement/grapple_player.gd`, configured to Elastic Arc. Coordinates are metres. Spawn is (0, 4.04, 12). Terrace centres are (0,4,8), (8,3,-22), (0,3,-52), (-15.5,2,-89); rings are (4,12,-8), (8,12,-38), (-4,12,-68). Each ring belongs to its own gantry bay and has a `viaduct-bay-N` stable ID. The lower court is y=-5 and the return ramps rise alongside each terrace.

## Verification

The route fixture instantiates the production map and production grapple runner, begins at normal spawn, and supplies only movement/look/button commands. It does not set velocity or position after spawn. This is a mechanical route proof, not a claim about enjoyment.

The proof uses manual reeling (RMB held), matching the on-screen instructions. View commands aim at the currently approached ring; movement commands point toward the receiving terrace. It uses no Movement Lab wall jump or slide.

## Reference check

Read lane 12's first MAP-DESIGN.md sheet (17 Nov). Its measured bhop_eazy movers include 180 square 64 u / 1.6256 m pads, four 32-by-64 u rectangles and four angled outlines. The dominant square is twice the 0.813 m standing hull width. Viaduct's 14 m intermediate terraces and broad final abutment deliberately offer much wider recovery landings for a fixed 30 m-range rope; a precision bhop pad is a different demand. Horizontal clear spans are 16 m, 16 m and 14 m, with 30 m between ring bays and 12 m nominal ring elevation. The documented 10-second checkpoint guidance describes optimized checkpoint intervals, not a law for individual transfers: this short experimental course offers a checkpoint per bay to isolate a failed transfer. The continuous gantry supplies one organizing landmark instead of adding unrelated obstacles. No source-map assets or geometry were imported.

The final abutment widens toward the outside of the last left-hand arc. A real-motor probe showed that a symmetric 14 m deck sat inside the natural release flight; the abutment now catches that flight instead of requiring a sharp midair correction.

The first verified basic line finishes in 1321 ticks at 128 Hz (10.3203125 seconds), attaching to all three rings. `tests/viaduct_route.gd` generates the raw event tape; `tests/viaduct_replay.gd` replays that saved tape independently with no planner or view corrections. Both reached (-25.39282, 3.281574, -86.03963). `tests/viaduct_recovery.gd` walks off normal spawn, touches the lower court, climbs the first return ramp and reaches the starting terrace without resetting.

Reproduce with the pinned locked wrapper:

```sh
python3 tools/play.py --headless --fixed-fps 128 --script res://tests/viaduct_geometry.gd
python3 tools/play.py --headless --fixed-fps 128 --script res://tests/viaduct_route.gd -- --out=/tmp/r22-01-swing-flow/proof
python3 tools/play.py --headless --fixed-fps 128 --script res://tests/viaduct_replay.gd -- --tape=/tmp/r22-01-swing-flow/proof/input.json
python3 tools/play.py --headless --fixed-fps 128 --script res://tests/viaduct_recovery.gd
```

Generated tapes and route traces belong outside Git. These are mechanical proofs, not human difficulty or enjoyment ratings.
