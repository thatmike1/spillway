# Optional solid style passages

`scripts/r16_style_opportunities.gd` appends three original steel/concrete installations to two frozen R15 maps. The normal deck remains open beside every installation. Physics and the production style service discover ordinary solid boxes; nothing is a trigger, progress surface, scoring callback, movement modifier or grapple target.

| installation | existing route deck | centre, metres | physical choice |
|---|---|---|---|
| Breakwater `RunwayCrouch` | `s3_runway_2` | `(-81.3, 0, -166)` | 2.8 m wide opening between a 1.4 m sill and 3.05 m lintel underside; 0.28 m deep |
| Breakwater `RunwayThread` | `s3_runway_3` | `(-81.3, 0, -198)` | two 3.6 m high steel walls, 1.05 m clear width and 1.5 m track length |
| Whiteout `ApronCrouch` | `s0_apron` | `(-8, 0, -28)` | same short crouch frame, beside the centre apron line |

Dimensions and locations are agent choices. The 1.65 m vertical opening admits the 1.3716 m crouched hull and excludes the 1.8288 m standing hull. Its elevated sill makes it an airborne choice. The short depth fits around the ordinary jump apex. The side passage leaves 11.86 cm per side of a perfectly centred 32 u hull. Each has a small physical-world CROUCH/STYLE label facing the approach.

The Breakwater installations occupy the western edge of its 17 m runway. Preserved ordinary inputs travel farther east; the preserved earned line is also east of the frames. The Whiteout frame occupies the western apron beside the hangar exit, east of the existing generator, with the existing centre approach open. These placements use the maps' existing `route` manifests and retained R15 traces, rather than adding a new route deck.

Every solid has an opaque `BoxMesh` exactly matching its `BoxShape3D`. Materials use existing CC0 albedo textures: Breakwater's `rusty_painted_metal_diff_1k.jpg` and the existing momentum `concrete_layers_02_diff_1k.png`, through `StandardMaterial3D`. No new art files or shader are introduced. Added bodies have collision layer/mask 1 and `surface=r16_optional_style`; they never receive `progress_stage`.

## Root integration

After the base level's `build()`, with the level in the tree, before calculating R16 record/ghost identity:

```gdscript
var opportunities := preload("res://scripts/r16_style_opportunities.gd").apply(level)
```

The requested callback is unchanged. `apply(level: Node3D) -> Dictionary` is idempotent, appends only `R16Opportunities`, and returns detached copies on repeated calls. It caches its report in `level` metadata `r16_opportunities`. Exact original level script paths and built level IDs guard the targets. Fixtures, legacy maps, the lab and the other three course maps return `applied:false, reason:non_target_map`; null, off-tree, unbuilt and reserved-name failures have explicit reasons. Failed preconditions remain retryable.

Reports contain `version`, `applied`, `reason`, `map`, named opportunities, deck roles, opening measurements, each actual solid's stable relative path, shape dimensions, global origin/basis, collision layer/mask and material choice. `hash` is SHA-256 of the deterministic JSON report before the hash field is added. No runtime IDs, timing or process state enter it.

`geometry_hash()` and the map's manifest remain the frozen base identity. Root must combine that hash and `report.hash` in the R16 geometry/record/ghost identity. An empty non-target overlay hash must have an explicit meaning in that identity. A placement/material change requires a new report hash; root still includes the style rules identity separately.

Current overlay hashes:

| map | overlay SHA-256 |
|---|---|
| Breakwater | `2590f2e57702c52cc4f48231b1dad5ddcf9be64174dfe1d3463dada882ce053e` |
| Whiteout Relay | `8f71afface3d8bc1b17edabc5a3d9ea54a88dd16ec3928b8765f7127df6d956e` |

## Executed evidence

Evidence is outside Git at `/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r16/opportunities/`. `final-headless/RESULTS.json` records executed source and engine hashes; `SOURCE-HASHES.json` identifies the handoff files. The pinned editor is Godot 4.7.2, SHA-256 `8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e`. Source/import/profile snapshots use owned `/dev/shm/r16-opportunities-*` directories, below the initial 300 MiB cap, and are removed after execution. The shared checkout is never imported.

The supplemental run's broad checkout-unchanged flag is false: other builders changed `docs/reboot/decisions.tsv` and `tools/check-r16-preservation.py` while it ran, and this task changed its Python harness to put temporary trace output in RAM. The executed snapshot hashes remain recorded. The frozen runtime sources and owned runtime/driver files match those snapshots; the final RAM-output check exercised the updated harness. `HANDOFF.json` records this distinction explicitly.

- `test_r16_opportunities.gd`: 91 live checks, zero failures. Original node identities, physics RIDs, transforms, stored shape properties, metadata and child order are unchanged after append. Base geometry hashes/manifests and spawn/checkpoint/finish/kill/route data are unchanged. All ten added solids match visible opaque meshes. Six non-target maps append nothing. Metadata copy isolation and idempotence pass.
- `final-headless/`: all four accepted `ROUTES.json` traces on modified maps replayed open loop, with original key/mouse events, 128 Hz, warmup 33, sensitivity and frozen R15 host timing. Across 29,112 samples, positions, velocities, reference/duck origins, hull/motor state, inputs, progress and clocks are exactly equal. Whiteout's complete physics trace also matches. Breakwater has three differing contact-report rows at existing coplanar floor seams: two in ordinary, one in alley return. Only which original adjacent deck face supplied contact points differs; every movement field matches exactly. `CONTACT-DIFFERENCES.json` preserves those rows. Full contact-trace parity is explicitly false for these two routes, not silently treated as equal.
- `extended-parity/`: nine additional retained R15-host earned/recovery/F5 tapes, 64,736 samples, all with exact movement parity. Seven contact-report rows differ, again only original walkable support faces. These supplement, rather than replace, the supplied acceptance manifest. Together the primary and supplemental runs compare 93,848 samples, with ten contact-report differences. A final single-route recheck also exercises the harness's RAM-only temporary trace output, at a measured 198.2 MiB snapshot/import/profile/trace scratch peak.
- `r16_opportunities_driver.gd`: state-aware key/mouse execution from normal Whiteout spawn or authored Breakwater stage practice 3. No post-setup pose/velocity restores. Both crouch passages pass without touching an overlay solid, at 249.99/250.56 u/s entry. The actual hull clears the sill/lintel while the standing counterfactual intersects the lintel. Both production `r16_style.gd` samples award a 900-point airborne `crouch_save`. Matched standing controls use the same approach/takeoff inputs except Ctrl, hit the frame, fail to pass and earn no intended points. Separate normal standing/hopping lines pass beside each installation without overlay contacts or overlay style events.
- The side passage passes at 430.46 u/s, with no overlay contact, clear entry/exit and 2.221 m measured passage track. Production style awards a 134-point `near_miss`, `thread:true`, with 4.063/5.188 u side clearances. Real A/D plus mouse inputs earn its speed before the passage.
- `test_r16_opportunities_results.py`: independently checks retained movement parity, actual passage occupancy versus hull dimensions, matched standing inputs, intended production score events and earned speed. Final headless evidence passes 133 checks including the 91 geometry checks.

The scoring service used in these proofs has source SHA-256 `833e02db5cb42a8b467f88f26c9a30c52126032076161443342fcf942dc066fd`. No style-service file is owned or edited here. The sample adapter is the style builder's `r16_style_probe.gd`, a labelled stand-in for root's actual R16 integration.

## Failed trials and limits

`trials-v1/breakwater-thread` is a genuine failed approach: its controller tried to bhop through the earlier crouch frame while aiming for the later side passage, hit the sill and exhausted its budget. The corrected approach enters the west lane after that frame. No geometry or movement tuning changed to make it pass. The failed trace and blocking contacts remain. Initial `parity-v1` reported false mismatches because the comparator included wall-clock timestamps; its mismatch specimens and recheck remain, with duplicate full traces referenced to `final-headless`. Physics comparisons exclude only wall time and last-draw camera observations; contact-report differences stay reported separately from exact movement.

Native player-camera capture is not accepted here: HOME fell below the mandatory 15 GiB floor during the run, so no private display or capture was started. The native capture path is provided using the existing private AMD/X11 helper and explicit display 198, but is unexecuted. Visibility/material appearance remains source/headless-only. Root must inspect native approaching/passing/normal views when the floor permits and repeat acceptance on the actual R16 host. No fun, feel, Windows or packaged-release claim is made.

That paragraph describes this builder's original run. Later actual-R16 AMD acceptance inspected both Breakwater passages and Whiteout's apron, including approach, passage, exit and unchanged ordinary lines. See [NATIVE-ACCEPTANCE.md](NATIVE-ACCEPTANCE.md). The complete Whiteout apron tape finishes clean with its 900-point airborne save. Final exported-pack checking is a separate result in the round's release results.

Verified commands, from `projects/foldrunner`:

```bash
python3 tests/r16_opportunities_run.py --mode all --out /absolute/evidence/directory
python3 tests/r16_opportunities_run.py --mode extended --out /absolute/extended/evidence
python3 tests/test_r16_opportunities_results.py /absolute/evidence/directory
```
