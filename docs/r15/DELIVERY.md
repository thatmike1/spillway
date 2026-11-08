# R15 portable release tools: initial port

No R15 package has been accepted. This is the first R15-specific port of the verified R14 release tools, alongside the unchanged R14 tools. It is not a release result. The remaining integration gates are in DELIVERY-PLAN.md.

`tools/package-r15.py` has `package`, `check`, `source` and owned-child `engine` commands. `tools/check-r15-pack.sh` wraps `check`. The package tool freezes committed source outside Git, pins the official Godot 4.7.2 editor and Linux/Windows release templates, imports/exports the R15 preset and verifies published ZIPs with the shipped Linux runtime. Dirty source is refused. Source mode reads identities and replays tapes from an already imported external snapshot.

The fixed identity is R15 Breakwater / F2, `scenes/r15.tscn`, `scripts/r15_main.gd`, `user://spillway_r15.cfg` and `R15 Pack`. The map set must contain all five new courses, both retained courses and the movement lab. Non-diagnostic packaging requires F2 play proofs on all seven courses and an F5 comparison; startup-only output cannot be a release candidate. The current three-map tree is correctly refused.

The new probe reads the R15 runtime registry, actual motor version, hull/mechanics identities and R15's integer-tick record format. Recursive licence collection preserves complete asset paths, including the new nested kits and their notices. Resource coverage includes raw bounds JSON and imported HDR skies. Both source and packed trace comparators require complete finite three-component position and velocity vectors, sequential unique ticks, exact velocity/position agreement and the existing clock/progress checks. The inherited ownership, alpha/text visibility, nested error-log, manifest-reconciliation and external-reference protections remain.

## Evidence so far

Outer `checkpoints/spillway/r15/delivery-port/` holds a frozen diagnostic using the real R15 scene and motor, with the uncommitted initial helper bytes recorded in `identity/executed-probe.gd` and its logs. The identity probe runs without errors: all three current maps and all four presets produce 12 identities, and every Source-derived preset reports motor version 2. The enclosing source-identity gate then refuses the five missing modules. This is intentional incomplete-build rejection, not final source acceptance.

`tests/test_r15_release.py --out RESULT.json` currently passes 23 offline checks: nested licence/notice paths, JSON/HDR coverage, retained R14 profile identity, fixed map/rate/startup policy, complete trace controls, velocity-only lies, malformed traces and package refusal before output when course proofs are absent. These checks use synthetic traces and disposable scratch; they do not run a release runtime or export a pack.

## Still required

- Finish the source-suite wrapper and carry the actual map/lab test contracts into it.
- Exercise the probe on an exported release runtime, including the new map grid, crouch/blocked standing, F2/F5 switching, checkpoint practice, record purity, exact save/reload and Quit.
- Add and prove the movement lab's optional mechanics controls; source-only fixture results do not cover them in a pack.
- Challenge the tools independently, including cancellation and deliberate broken packages, then rerun the repaired helpers on a fresh candidate.
- Promote only the accepted immutable Linux/Windows ZIPs and their provenance/evidence into outer `delivery/spillway-r15/`; replace the outer REPORT then.

The published command shapes are available from `python3 tools/package-r15.py --help`. No completed source-suite, portable-package, Windows-native, latency or feel acceptance is claimed here.
