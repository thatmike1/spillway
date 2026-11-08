# R15 portable release tools: integration in progress

No R15 package has been accepted. This is the first R15-specific port of the verified R14 release tools, alongside the unchanged R14 tools. It is not a release result. The remaining integration gates are in DELIVERY-PLAN.md.

`tools/package-r15.py` has `package`, `check`, `source` and owned-child `engine` commands. `tools/check-r15-pack.sh` wraps `check`. The package tool freezes committed source outside Git, pins the official Godot 4.7.2 editor and Linux/Windows release templates, imports/exports the R15 preset and verifies published ZIPs with the shipped Linux runtime. Dirty source is refused. Source mode reads identities and replays tapes from an already imported external snapshot. `tools/check-r15.sh` creates and imports its own frozen snapshot outside Git before running the current R15 source suites.

The fixed identity is R15 Breakwater / F2, `scenes/r15.tscn`, `scripts/r15_main.gd`, `user://spillway_r15.cfg` and `R15 Pack`. The map set must contain all five new courses, both retained courses and the movement lab. Non-diagnostic packaging requires F2 play proofs on all seven courses and an F5 comparison; startup-only output cannot be a release candidate. The current three-map tree is correctly refused.

The new probe reads the R15 runtime registry, actual motor version, hull/mechanics identities and R15's integer-tick record format. Recursive licence collection preserves complete asset paths, including the new nested kits and their notices. Resource coverage includes raw bounds JSON and imported HDR skies. Both source and packed trace comparators require complete finite three-component position and velocity vectors, sequential unique ticks, exact velocity/position agreement and the existing clock/progress checks. The inherited ownership, alpha/text visibility, nested error-log, manifest-reconciliation and external-reference protections remain.

## Evidence so far

Outer `checkpoints/spillway/r15/delivery-port/` holds a frozen diagnostic using the real R15 scene and motor, with the uncommitted initial helper bytes recorded in `identity/executed-probe.gd` and its logs. The identity probe runs without errors: all three current maps and all four presets produce 12 identities, and every Source-derived preset reports motor version 2. The enclosing source-identity gate then refuses the five missing modules. This is intentional incomplete-build rejection, not final source acceptance.

`tests/test_r15_release.py --out RESULT.json` currently passes 23 offline checks: nested licence/notice paths, JSON/HDR coverage, retained R14 profile identity, fixed map/rate/startup policy, complete trace controls, velocity-only lies, malformed traces and package refusal before output when course proofs are absent. These checks use synthetic traces and disposable scratch; they do not run a release runtime or export a pack.

## Still required

- Integrate and run the remaining map/lab test contracts through the source wrapper, then run its full eight-map identity and route gate on final committed source.
- Exercise the probe on an exported release runtime, including the new map grid, crouch/blocked standing, F2/F5 switching, checkpoint practice, record purity, exact save/reload and Quit.
- Add and prove the movement lab's optional mechanics controls; source-only fixture results do not cover them in a pack.
- Challenge the tools independently, including cancellation and deliberate broken packages, then rerun the repaired helpers on a fresh candidate.
- Promote only the accepted immutable Linux/Windows ZIPs and their provenance/evidence into outer `delivery/spillway-r15/`; replace the outer REPORT then.

The published command shapes are available from `python3 tools/package-r15.py --help`. No completed source-suite, portable-package, Windows-native, latency or feel acceptance is claimed here.

## Source wrapper

`tools/check-r15.sh --out DIR` freezes committed HEAD outside Git. It checks the actual R15 default scene, independent Source calculations, the shared pure law, real crouch/parity and the independent clearance/settings challenge, the R15 lifecycle/records, a fresh airborne crouch tape through the actual main, external asset placements, both legacy geometries and the map-specific suites. All child engines are owned by the checked process-group runner. The loop's five exact intentional refusal messages are counted individually; any extra error fails. The tape's nested engine log is checked as well as the wrapper log.

`--core-only` is an explicit development scope. Missing map suites are printed as pending and the complete registry gate is skipped. Its final line says it is not release acceptance. Omitting that flag requires every new map suite and the complete eight-map registry; the current incomplete tree must fail. `--controls` also runs the unchanged R13 air and lifecycle controls. Repeated `--route SPEC` arguments are sent to the strict complete-registry source replay command, and cannot be combined with `--core-only`. `--source worktree` is a labelled diagnostic including uncommitted files; the default checks committed HEAD.

The first development diagnostic on source650346af plus the wrapper passed the independent oracle, pure177, crouch95, clearance125, loop184, assets20, Breakwater1712, offline release23 and both R13 controls. The wrapper-only SIGINT and SIGTERM controls start a disposable fake engine and its child; both are stopped, and owned import/profile caches are removed. Those controls are process-cleanup evidence, not a native game run. Evidence: outer `checkpoints/spillway/r15/source-wrapper/`. The final wrapper revision also checks a fresh actual-main airborne crouch tape and the legacy geometries; its result must be read separately from that first diagnostic.

The second diagnostic runs the full source-check path. All built gates pass, including the new 256-tick actual-main air duck/stand replay, 20 corrupt-capture controls, Penstock1599 and Overflow's four geometry worlds. It exits 1 for exactly five missing map suites and the complete-registry refusal. The existing runtime is not labelled broken or released from that result. The latest wrapper also refuses absent/empty engine logs and records its engine executable hash and scope; four direct log fixtures plus both cancellation paths pass. Exact executed helper variants and source hash lists remain in the evidence; duplicate owned frozen source copies and caches were removed.
