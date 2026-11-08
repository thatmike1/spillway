# R15 portable release tools: integration in progress

No R15 package has been accepted. All eight maps are integrated. The first actual release-runtime diagnostic was rejected; its failure and the restart-notice repair are recorded below. The remaining release gates are in DELIVERY-PLAN.md.

`tools/package-r15.py` has `package`, `check`, `source` and owned-child `engine` commands. `tools/check-r15-pack.sh` wraps `check`. The package tool freezes committed source outside Git, pins the official Godot 4.7.2 editor and Linux/Windows release templates, imports/exports the R15 preset and verifies published ZIPs with the shipped Linux runtime. Dirty source is refused. Source mode reads identities and replays tapes from an already imported external snapshot. `tools/check-r15.sh` creates and imports its own frozen snapshot outside Git before running the current R15 source suites.

The fixed identity is R15 Breakwater / F2, `scenes/r15.tscn`, `scripts/r15_main.gd`, `user://spillway_r15.cfg` and `R15 Pack`. The map set must contain all five new courses, both retained courses and the movement lab. Non-diagnostic packaging requires F2 play proofs on all seven courses and an F5 comparison; startup-only output cannot be a release candidate. An incomplete map set is refused.

The new probe reads the R15 runtime registry, actual motor version, hull/mechanics identities and R15's integer-tick record format. Recursive licence collection preserves complete asset paths, including the new nested kits and their notices. Resource coverage includes raw bounds JSON and imported HDR skies. Both source and packed trace comparators require complete finite three-component position and velocity vectors, sequential unique ticks, exact velocity/position agreement and the existing clock/progress checks. The inherited ownership, alpha/text visibility, nested error-log, manifest-reconciliation and external-reference protections remain.

## Earlier development evidence

Outer `checkpoints/spillway/r15/delivery-port/` holds a frozen diagnostic using the real R15 scene and motor, with the uncommitted initial helper bytes recorded in `identity/executed-probe.gd` and its logs. The identity probe runs without errors: all three current maps and all four presets produce 12 identities, and every Source-derived preset reports motor version 2. The enclosing source-identity gate then refuses the five missing modules. This is intentional incomplete-build rejection, not final source acceptance.

`tests/test_r15_release.py --out RESULT.json` currently passes 23 offline checks: nested licence/notice paths, JSON/HDR coverage, retained R14 profile identity, fixed map/rate/startup policy, complete trace controls, velocity-only lies, malformed traces and package refusal before output when course proofs are absent. These checks use synthetic traces and disposable scratch; they do not run a release runtime or export a pack.

## Still required

- Rerun the full eight-map source and route gate on the final committed source. All map/lab contracts passed the earlier integration snapshot.
- Exercise the probe on an exported release runtime, including the new map grid, crouch/blocked standing, F2/F5 switching, checkpoint practice, record purity, exact save/reload and Quit.
- Rerun the corrected checkpoint/restart controls in the release runtime. The first diagnostic already executed the lab toggles and runner-restoration controls successfully.
- Challenge the tools independently, including cancellation and deliberate broken packages, then rerun the repaired helpers on a fresh candidate.
- Promote only the accepted immutable Linux/Windows ZIPs and their provenance/evidence into outer `delivery/spillway-r15/`; replace the outer REPORT then.

The published command shapes are available from `python3 tools/package-r15.py --help`. No completed source-suite, portable-package, Windows-native, latency or feel acceptance is claimed here.

## Source wrapper

`tools/check-r15.sh --out DIR` freezes committed HEAD outside Git. It checks the actual R15 default scene, independent Source calculations, the shared pure law, real crouch/parity and the independent clearance/settings challenge, the R15 lifecycle/records, a fresh airborne crouch tape through the actual main, external asset placements, both legacy geometries and the map-specific suites. All child engines are owned by the checked process-group runner. The loop's five exact intentional refusal messages are counted individually; any extra error fails. The tape's nested engine log is checked as well as the wrapper log.

`--core-only` is an explicit development scope. Missing map suites are printed as pending and the complete registry gate is skipped. Its final line says it is not release acceptance. Omitting that flag requires every new map suite and the complete eight-map registry; the current incomplete tree must fail. `--controls` also runs the unchanged R13 air and lifecycle controls. Repeated `--route SPEC` arguments are sent to the strict complete-registry source replay command, and cannot be combined with `--core-only`. `--source worktree` is a labelled diagnostic including uncommitted files; the default checks committed HEAD.

The first development diagnostic on source650346af plus the wrapper passed the independent oracle, pure177, crouch95, clearance125, loop184, assets20, Breakwater1712, offline release23 and both R13 controls. The wrapper-only SIGINT and SIGTERM controls start a disposable fake engine and its child; both are stopped, and owned import/profile caches are removed. Those controls are process-cleanup evidence, not a native game run. Evidence: outer `checkpoints/spillway/r15/source-wrapper/`. The final wrapper revision also checks a fresh actual-main airborne crouch tape and the legacy geometries; its result must be read separately from that first diagnostic.

The second diagnostic runs the full source-check path. All built gates pass, including the new 256-tick actual-main air duck/stand replay, 20 corrupt-capture controls, Penstock1599 and Overflow's four geometry worlds. It exits 1 for exactly five missing map suites and the complete-registry refusal. The existing runtime is not labelled broken or released from that result. The latest wrapper also refuses absent/empty engine logs and records its engine executable hash and scope; four direct log fixtures plus both cancellation paths pass. Exact executed helper variants and source hash lists remain in the evidence; duplicate owned frozen source copies and caches were removed.

## Packed input observer

The play probe now records actions, physical keys, press/release edges, actual relative and screen-relative mouse fields and immediate view response. Samples bracket the motor with its counter, physics frame and interpolation origins. For R15 it also observes the real box dimensions and centre before and after the step, separately from the motor's duck report. Python checks every sample against the expanded tape and the independently captured source sensitivity. A raw previous-origin mismatch is accepted only by the same narrow, independently challenged hull-origin rule used by the standard source executor. No motor reset or missing step is accepted in a clean packed route. Motion equality and record checks remain separate gates.

The release controls additionally press C on the floor and Ctrl in the air, inspect the real 54/72 u box, switch F2 to F5 while crouched, restore standing and a clean restart, and verify that F1 only explains the retired mode. These actions will run on the actual default course. Blocked standing is proven on a labelled source fixture until a final packed low-duct route supplies that evidence.

`python3 -I tests/test_r15_pack_observer.py --out DIR` freezes the current working project outside Git and exercises the exact probe capture/injection/control methods under the pinned editor. The result is explicitly source-only. `--course-tape` takes an expanded Whiteout gantry tape, and `--course-reference` compares it against the full standard-executor trace. Evidence is in outer `checkpoints/spillway/r15/packed-observer/`: F2/F5 airborne duck, a low-roof release with deferred standing, a normal Breakwater hop, R13 at 120 Hz, and a complete 7,997-tick Whiteout gantry run. Fifteen corrupt-capture controls reject dropped keys/edges, missing physical input, wrong mouse fields/view, skipped steps and dishonest hull/origin metadata. The Whiteout position, velocity, yaw, clock and progress match the retained standard trace exactly. Source crouch UI controls pass; headless label observations are not rendered-image proof.

No export or native capture was made for these component checks. Actual release-runtime execution and a fresh complete-map package remain required; neither this observer result nor the older 23 offline checks certifies an R15 ZIP.

### Packed-observer review and repair (9 November)

The independent review of f023d40e met all 377 fixed expectations: real delivery regressions and 113 corrupt captures were refused, while 253 real crouch cases were accepted. It found two low gaps, retained in PACK-OBSERVER-REVIEW.md. The current audit now checks the actual box against crouch state on every Source tick and requires a held Ctrl to produce crouch, including steady flight. Production exports and rechecks copy the hull observer from the frozen source, require its SHA-256 to equal the package helper manifest, execute those exact hashed bytes, and record that digest in each result.

The fresh source component run passes 44/44 aggregate controls, including steady-box, ignored-crouch, missing-hull and changed-helper refusals; the 14 actual crouch UI assertions and the 7997-tick Whiteout comparison also pass. Evidence: `r15/observer-repair-final/`. The first attempt supplied the unexpanded course tape to a test requiring an expanded plan; that refusal is retained under `observer-repair/`. The component test reads sensitivity back from its own source game. The production caller independently captures it from the fresh source executor. Neither is exported acceptance.

Map/preset admission now follows the final host: four comparisons on each normal map, F2/F5 only in the lab. The probe accepts the version-2 Shift/E keys and records their real action/physical states. New final packed lab toggle/runner-restoration controls and exported execution remain required. Respawning recovery tapes are not admitted by the clean-route observer.

### Lab controls in the release probe

The actual release coroutine now checks F3/F4 refusal in the lab, visible experiment labels, keys1/2/3, the pause-menu grapple switch, per-loadout record keys, loadout preservation under F5, and practice after changing a move following even pre-timer motion. It leaves the lab through the real map button, checks the approved runner and empty lab state, holds Shift/E on the normal course, and re-enters from F3 to verify the explicit F2 restriction. No pose, velocity, progress or record setter is used.

`tests/test_r15_pack_lab.py --out DIR` runs that exact coroutine on an external frozen source copy: 37/37 observations pass. Three deliberately broken runtimes are refused for their intended failures: dead toggle keys, a lab body sticking on a course, and a hidden experiment label. Source hashes are restored and scratch removed. Evidence: `checkpoints/spillway/r15/packed-lab-controls/attempt1/`. Headless label/layout state is not proof of drawing; the forthcoming exported diagnostic must execute the same coroutine on the release runtime.

### First exported diagnostic and restart correction

Committed `40b8ee9b` exported both official-runtime ZIPs and ran the actual Linux release runtime on the private AMD/X11 backend. Static/startup, real titles, old-profile preservation, Quit and process/display cleanup passed. The aggregate was **33/34**, with **730/738** probe assertions passing. All eight failures expected the old words “stage practice”; the actual HUD correctly said “checkpoint practice from <authored title>”. The probe now requires that current title-specific wording and a drawn practice label.

The native frames also revealed a real UI defect: R restored a clean run but left the previous practice notification visible. `r15_hud.run_started()` now clears it. The new empty-notification assertion fails against the old HUD and passes against the repaired HUD. The exact lab coroutine passes 37/37 again, and its three runtime mutations remain refused. The release probe now also requires an empty notice after every map's checkpoint-practice restart.

Evidence is under `checkpoints/spillway/r15/packed-lab-controls/`: `rejected-40b8ee9b/`, `stale-toast-red/` and `stale-toast-green/`. The rejected build played no routes and is explicitly startup-only diagnostic output. A fresh export must execute the corrected helpers before any promotion.
