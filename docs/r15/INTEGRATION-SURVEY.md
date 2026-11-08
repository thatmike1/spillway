# R15 product integration survey

Observed in the committed R14 game before any R15 runtime integration.

`r14_main.gd` owns build/profile/timing identities, a hardcoded preset Script, two map scripts and a map switch statement. Its `_make_runner` builds by family and applies cvars before the runner enters the tree. The HUD reaches `game.PRESETS` and `game.MAPS` directly and puts the two map buttons in one horizontal row. Eight maps (five new courses, two existing maps and the lab) cannot use that row unchanged.

The reusable level interface is already sufficient for first-map work: `level_script` hosts a level as `fixture` without modifying progress or controls. `checkpoints` carry stage names and authored poses. `practise_stage(i)` is the single reset path for F and the stage picker; it cancels a pending preset request, resets clock/splits/stats and marks the attempt non-recordable. `select_map` rebuilds the world, retains the active preset and clears its pending replacement. This behavior is an established working reference, not a reason to couple every future map to the R14 class.

R15 needs its own build/save/timing identity. Preserve integer tick payloads, complete split/segment reload and preset/map/mechanic separation. R14 profiles and downloads must not be mutated. New maps publish stable body names, manifest/hash and matching visible surfaces/collision. Their fallback kill bounds come from the level, rather than an assumed dam-sized global box.

The new crouch adapter must report body-origin compensation separately from actual requested/swept travel. The product's speed display is horizontal measured travel; crouch-only camera/hull motion must not mint speed or clean-run progress. Standing-hull fit assumptions need review before allowing family changes below a low ceiling. Record fingerprints include any new hull/mechanic setting.

First integration acceptance will compare the new shell's unchanged F2/F5 input traces with the approved R14 reference on Penstock and Overflow, in addition to fixture lifecycle/persistence checks. New stage counts, loaded map names, defaults, pause selection, R/F behavior, hot profile changes and Quit must be exercised through actual inputs. Default-scene changes wait until an R15 scene launches cleanly. No new shell is implemented by this survey.
