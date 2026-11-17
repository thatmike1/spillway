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

Reference revision 2 reports five mover pads per recovery target median and explicitly finds no comparable measured rope-course spacing standard. Its 0.813 m Eazy figure is adjacent-pad spacing, not a measured runner jump gap: players can skip pads. The later independent-review correction withdraws the bonus gap percentiles because missing sloped supports made false gaps; neither statistic is used as a Viaduct spacing target. Viaduct's 14–16 m gaps therefore remain grounded in its own Arc motor proofs, rather than widened or narrowed to fit bhop measurements. Its per-bay recovery is intentionally more frequent than the sampled bhop grouping, so failed rope acquisitions can be isolated. The last bay changes both transfer direction and receiving footprint; this follows the sheet's recommendation to vary direction, elevation and recovery rather than merely escalating every gap. The wider final abutment is the concrete spacing revision prompted by executable flight evidence. No downloaded reference geometry or art is used.

## Earlier-release line

`tests/viaduct_route.gd --fast` keeps the first two verified transfers and releases the third once the feet rise above 3.5 m rather than 5 m. It cuts across the lower outside arc into the broad abutment, with less height available for correction. The real-motor planner and independent saved-event replay both finish in 1237 ticks (9.6640625 s), 84 ticks / 0.65625 s earlier than the basic line. All three rings attach. This is the intended tighter timing challenge; its human difficulty remains for playtesting.

Geometry version 2 adds solid concrete plinths beneath every terrace, rooted at y=-5.8. Both saved tapes replay with identical finish ticks/endpoints after this addition, and the normal-spawn walk-off recovery still returns without a reset. The deck footprints, rings and Arc law remain the same.

Geometry version 3 cuts clear four-metre arches around the two return ramps that enter beneath earlier terraces. Four low-court motor fixtures independently walk every return to its terrace. Both canonical tapes still finish clean through the live host with every checkpoint and zero respawns. The numeric geometry digest includes collision points, anchor IDs, checkpoint poses, spawn basis and course bounds.

The later played-reference samples are SourceJump rank-one/world-record AA1000 runs, not typical-player routing or F2 calibration. Duster's measured flat-hop medians include a 7.315 m gap, 6.502 m landed support width and 26.084 m/s horizontal travel speed. That example reinforces the need to consider receiving width and speed together. Viaduct's 14–16 m spans instead rely on the 30 m-range Arc rope and its local tapes; a SourceJump gap is not a rope-gap target. The course changes horizontal direction and receiver width across three bays rather than simply enlarging every gap. Slower human lines may use the recovery terraces differently.


## Scoped presentation

Version 4 places a solid control house on the west abutment beyond the canonical finish approach. The two saved tapes and all four return walks pass with that collision geometry; the course key is `710f5abd3eb4befe`. Structural joints, bay numbers, dark-rimmed orange rings and arrival lips describe the existing gantry rather than adding unrelated obstacles. Decks use the existing redistributable surface/wear shader; the painted sky is the project's original `assets/look/r17/practice-sky.png`. No private moodboard or concept image is a game asset.

`own_look` prevents the inherited experimental-map presentation layer from replacing these authored materials. `tests/viaduct_presentation.gd` checks the final live-host deck shader and color. The map-local cable observer duplicates only the visible CylinderMesh and its material, with a 1.5 mm radius; it restores those resources on exit. It does not change anchor acquisition, collision, input, velocity or rope coefficients. The presentation test also checks motion identity and law hash, optional shared rope hiding/restoration, and the original Tether Yard cable radius after switching maps.

Native captures use `tools/shot.py`, a private display, a normal-spawn restart, and legal-range analog strengths from `basic-native-input.json` / `fast-native-input.json`. The generator clamps dot-product results to avoid floating-point overshoot above 1. Independent canonical replays of the clamped tapes retain the same 1321/1237 finish ticks. Native captures also finish clean through every checkpoint with zero respawns. Their displayed finish clocks differ from the manually stepped headless fixtures; native images are clean-completion and visual evidence, not a claim of exact full-route step equivalence. Both proofs are retained separately.


## Downstream dam, wave 2

Viaduct now sits in the maintenance basin of a curved dam. Its crown and three spillways are the large landmark seen through the swing bays. The gantry and control house form a service approach below it. Asymmetric valley shoulders connect the dam to the horizon. The playable terraces retain cream tops, mint return slopes and warm edge trim against darker teal structure.

The new dam, outlets and valley are authored mesh scenery under ViaductDam, outside the course. They contain no collision or anchor nodes and do not enter the physical manifest or geometry digest. Both existing saved tapes must retain their exact canonical finish ticks; the presentation fixture pins the earlier course key and checks that the set piece has no collision objects. Three fresh passes and a follow-up critique drove warm weathered concrete, painted blue steel with exposed joint plates, restrained hull outlines, a railed service carrier, and solid retaining abutments. Original value-noise shaders break up the flood curtains and receiving foam. The original redistributable overflow sky replaces the earlier practice panorama. All geometry and shader code is original project work; no private concept or research texture is imported. The overhead walkway and the ramp trim are scenery. Post plates sit beyond the 1.6 m front face rather than buried within the post.


## Upper inspection line, version 5

The advanced branch uses the same three rings and fixed Arc law. Instead of releasing the last swing at5m toward the downstream abutment, its tape holds until7.5m and releases back upstream onto a6-by-8m inspection pier at y8, x[-18,-12], z[-72,-64]. The pier is supported to the basin floor, outside both existing flight paths. The original checkpoint bounds and normal finish remain unchanged. The new pier carries stage3, so its physical landing collects the final checkpoint through the existing host. Its alternate finish accepts a nearby real runner only when the motor reports grounded; an empty point or an airborne pass through the volume does not finish.

The production upper tape finishes clean in1205 ticks at128Hz (9.4140625s), all checkpoints and zero respawns. Existing raw basic/fast tapes retain1321/1237 ticks and their exact previous endpoints. Controlled early5m release and held-rope variants both miss the upper exit across4000 ticks. Those are tested counterfactual inputs, not a mathematical exclusion of every possible human strategy. Enjoyment and human difficulty still need playtesting. Geometry version5/course44de048079be5549 deliberately segregates the added physical receiver from earlier bests without modifying old recordings.

Generate with `python3 tools/play.py --headless --fixed-fps 128 --script res://tests/viaduct_route.gd -- --advanced --out=/absolute/external/path`. Replay independently with viaduct_replay.gd and verify clean host/checkpoint/grounded completion with `python3 tools/play.py --headless --fixed-fps 128 --script res://tests/viaduct_host.gd -- --upper --tape=/absolute/external/path/input.json`. Negative controls use --advanced --release-height=5 and --advanced --hold-last on the generator. No input tape, generated recording or render is committed.
