# Wet-chute proof

P / shallow water slows walking while adding only 0.25 m/s² drag to a slide. A slide keeps its downhill acceleration. Carried hop speed is preserved.

Run `./tools/check-wet-chute.sh --evidence-dir=/absolute/path/outside/git`. The optional `--main-pack=/absolute/path/spillway.pck` tests a packed build from the external evidence directory. The wrapper fails on script errors, incomplete travel, missing water contact, lost slide mode or wet/dry exit-speed retention below 80%.

The test reads the real WetSpillwayBed collider and adds a labelled matching dry run-up above it. One initial spawn starts at rest. Subsequent motion uses only W and crouch. The water membership rule matches main's feet-in-AABB check. The dry control disables water drag while preserving geometry. This is an actual-chute fixture, not route completion evidence.

Source-stage evidence in outer checkpoints/spillway/r12/bugs/water/: R11 wet3.2000 / dry15.1225 =21.16%; frozen R12 source wet14.7682 / dry15.1225 =97.66%. Native before/after strips were inspected. The evidence README records snapshot hashes, immutable R11 pack identity and capture caveats. Final r12 package verification remains pending.
