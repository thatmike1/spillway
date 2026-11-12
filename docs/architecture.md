# Live code and stable identities

The configured scene is `scenes/r21.tscn`. It loads the stable `scripts/r21_main.gd` resource, which inherits the named `scripts/game.gd` implementation. This composes the catalog and current HUD over the live R20/R19/R17/R16 host chain. `r16_main.gd` owns the shared map lifecycle, ordinary input/physics loop, records and session boundary ordering. `r17_main.gd` wraps presentation; R19/R20 add experiments and manual run export.

The named modules are implementations, while their historical path wrappers preserve script resource identities. This matters particularly for `scripts/r15_source_player.gd`: its runner path participates in motion identities, so renaming the resource would invalidate matching ghosts and bests despite identical numerical physics. The forwarding script inherits the same original implementation body, rather than copying or rewriting its arithmetic. Existing scene/registry references continue to point to the stable resource.

`scripts/movement/course_player.gd` owns the ordinary course collision body and its velocity, using `source_motion.gd`. `grapple_player.gd` composes the current Tether Yard rope forces over the inherited Tether/Source path. Movement Lab retains its own experiment runner; Through Line also has a separate runner. Neither adds its mechanics to the approved ordinary runner.

The catalog composes `scripts/maps/catalog.gd` over existing map registries. Original geometry modules and their asset manifests stay together. Saltglass and Tether Yard have named current geometry implementations. Fall Line and Line Drive remain dependencies of the inherited catalog construction, then are removed from the current menu. Their dependency status is different from a dead prototype.

`scripts/recordings/session.gd` receives the completed motor sample. It owns recorder, independent reader, ghost and style lifecycle boundaries. The ordinary recorded format, motor version, course key, timing rules, preset and geometry identity stay unchanged. `scripts/scoring/style.gd` owns scoring; a time best and a style best are different records. `r20_run_export.gd` owns explicit manual bundles and is part of the live host chain.

`scripts/ui/pause_menu.gd` contains current pause/HUD additions. Its inherited R18 theme and R20 HUD remain live code. Presentation consumes gameplay state. `assets/` and `shaders/` retain the original old/new look resources so L toggling changes presentation without changing physics.

`verification/frozen/` contains only the Godot executors/reference modules reached by the current suite. `verification/lib/` holds the comparison/reader code extracted from the release-verifier chain. Frozen test inputs belong in `tests/fixtures/original-map-parity/`; generated test output belongs outside the checkout. Historical delivery-specific orchestration and superseded prototype sources remain recoverable from Git history.

The `r15_main.gd` / `r15_launch.gd` host pair is retained for the current frozen comparison fixtures, not as a player entry point. Its stable source paths keep that reference separate from the current host.
