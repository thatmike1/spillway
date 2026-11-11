# R21 Tether Yard

The new runner preserves the complete R20 Classic, Pendulum and Elastic force paths. Three single-axis Elastic variants and an independently selectable acquisition assist sit beside them.

The historical component packet pins player `67953a7e`: six clean configured-host model routes and exact sealed-input replays, 253 lifecycle/control/identity checks, separate-process preference reload and 373 dual-reader files. A later release-preview repair changed the player to `39e189c6`; its fresh evidence covers 78 component checks, six native/headless route pairs totaling 8,937 rows and 54 pause presentation checks. The historical packet does not certify the later player's full lifecycle/reload coverage. Final source and packed gates must earn that binding separately. Listening, physical latency, native Windows play and human feel remain unverified.

Research was published before implementation: outer `look/GRAPPLE-RESEARCH.md`, SHA256 `43c7ac2032ac9462b6aeab4e08a6d6b39754bcab4bbff018b23e9274d953b1bc`. The exact frozen replay baseline is `e6baa995da84d380abc8b8d6a3769b33e771945e`. Original R20 project files remain unchanged by this component.

## Laws and controls

`R21_MODELS` is ordered `classic`, `pendulum`, `elastic`, `elastic-soft`, `elastic-firm`, `elastic-arc`.

| Model | Change from its original law |
| --- | --- |
| Classic | None: radial catch, stiffness 30, capped 1300 u/s² pull, 3 s. |
| Pendulum | None: hard radial/excess-per-dt correction, no spring or added speed allowance, 5 s. |
| Elastic | None: stiffness 90, outward damping 10, capped 1800 u/s² pull, 5 s. |
| Elastic Soft | Elastic damping 6 instead of 10. |
| Elastic Firm | Elastic stiffness 120 instead of 90. |
| Elastic Arc | Elastic reel 180 instead of 260 u/s. |

All other values, the slack gate, quadratic allowance `max(incoming total speed,650)` for spring pulls, 96-u floor and release rules remain inherited. A force change precedes the ordinary motor, gravity and collision. The allowance preserves higher incoming speed; it is not a global 650-u/s speed ceiling. Classic/Pendulum and original Elastic dispatch through the frozen R20 implementation. Variants copy only the original Elastic expression with selected coefficients. No hard radial catch is added to Elastic.

LMB attaches and holds; release coasts. RMB reels while attached. Automatic reel remains independently selectable. E stays in the Movement Lab. Classic and Pendulum keep the original selector. Turning assist off restores the original R20 selector for every Elastic model, including its historical invalid-centred masking behavior, to keep the comparison exact.

Arc derives rest length from the value **before** inherited reeling, using `max(96,min(previous_rest,distance)-180*dt)`. Adding `80*dt` to an already clamped R20 result would be wrong. At dt=1/128, previous rest 97.5 and distance 100 u, inherited reeling gives 96 u; Arc gives 96.09375 u and an inward 2.74658203125-u/s velocity change, rather than 2.8125. Applied numerical probes retain the pre/post rest lengths and expected/actual force, including unsaturated and saturated cases, the 96-u floor and inside-radius ratchet.

## Authoritative acquisition

Assist is effective only for Elastic and its variants. The parent owns the separately persisted `tether_anchor_assist` preference, default true; Classic/Pendulum disable and ignore it.

Assisted eligibility requires all of: positive view depth, actual physics-view viewport projection, eye distance <=1181 u, acquisition angle <=18°, clear eye ray and clear hull-centre ray against layer 1, excluding the player. There is no 0.3 m endpoint blocker grace. Eligibility precedes ranking. No camera, body or velocity steering is involved.

Find the minimum eligible angle first. Only candidates within 0.1° of that minimum enter the tie window; choose shortest distance, then lexical stable ID. This avoids nontransitive pairwise epsilon sorting. Duplicate IDs are refused. The current target can retain out to 22° while still satisfying viewport/range/both LOS tests. A challenger must remain at least 3° better for six consecutive physics updates. Invalid targets drop immediately.

A fresh LMB press latches the prior published physics candidate ID. The next physics step revalidates that ID; an invalid press misses rather than silently taking a replacement. Holding LMB can retry a replacement after its full candidate update has been published. Readiness never depends on render frames. Pausing, resetting or changing a law/preference clears the candidate; inherited fresh-release guards prevent held-input reacquisition across boundaries and automatic breaks.

`grapple_target`, the world ring and the passive parent HUD read the same published candidate. The ring hides while not ready. Snapshot reads never raycast, choose a target, advance readiness or mutate gameplay. Attached observations keep the stable ID, name and anchor position.

The isolated transverse acquisition fixture measures full in-cone intervals at 300/650/1000 u/s: 219/100/66 physics ticks (1.7109375/0.78125/0.515625 s), zero missed valid ticks, one-tick opportunity-to-press latency and exact preview/attach ID agreement. The same ordered input/physics timeline matches with zero, one or three render calls between updates. This is a labelled kinematic acquisition stress fixture, not an earned movement route or a display-latency measurement.

## Platform cause and clearance

All complete raw event tapes from the three actual human recordings were replayed on the exact frozen R20 source/host, normal authored spawn, sensitivity 2.45, FOV 92, recorded Elastic/manual or automatic preference. Every original position, stored velocity, yaw and pitch sample matches exactly: 494 first-transfer, 1274 dispatch manual and 2039 dispatch automatic. Raw `screen_relative` counts were not rescaled; derived action rows stay in the extraction for audit. Events are injected before the physics sample bearing the same recorded tick.

The actual collision adapter confirms blocking +Z normals:

| Recording | First confirmed front contact | Body |
| --- | --- | --- |
| 10:43:00, manual | 371 | `transfer_1_0_0`, front z=-16 |
| 10:42:45, manual | 1146 | `transfer_3_0_0`, front z=-76 |
| 10:47:15, automatic | 1528 | `transfer_3_0_0`, front z=-76 |

The new map lowers the first transfer from y=4 to 3 and dispatch from y=4 to 2.25. The spawn and second transfer remain y=4; anchors and horizontal deck extents remain exact. Connected return-ramp tops, flat return landings, checkpoint poses/volumes, lip art and finish bounds follow the changed heights. The catch court remains y=-5. The geometry identity is `r21-tether-yard`, version 2; its digest changes and old ghosts must refuse.

The first full-input corrected replay stays exact through tick 370, diverges at the formerly blocking tick 371 and has no offending front contacts in the selected window. For each dispatch recording, a labelled **dispatch-support-only geometry fixture in the frozen host** keeps every physical sample exact until 1146/1528 and removes that front contact. These fixtures isolate the cause; they are not whole revised-course route proofs. Complete inputs on the fully revised course also remove the selected front contacts, but earlier changed landings alter later approaches. The automatic original input does not become a clean revised route merely because its front collision disappears. The distinct above-deck 10:46:15 climb is not presented as the same collision.

## APIs and verification

Parent integration calls:

- `configure_tether(model: String, automatic: bool)`
- `configure_anchor_assist(on: bool)`
- `r21_assist_active() -> bool`
- `r21_acquisition_snapshot() -> Dictionary`: `state,id,name,position,distance_m,serial,ready,attached,assist`
- `tether_identity() -> Dictionary`: effective law, controls, reel and acquisition identity
- `r21_law_rules()`, `r21_law_sha256()`, `r21_rules_sha256()`: observed rule projection and Godot canonical-JSON digests; the complete rules digest includes effective assist

The delivery observer's Python-canonical `effective_reel_ups` projection has its own digest. It must be computed from the actual identity, not confused with the Godot `reel_ups` projection above. Compact evidence publishes both projections where available.

From the project root, `python3 -B tests/r21_tether_check.py --out /tmp/r21-tether-proof --label LABEL --script r21_tether_component.gd` runs a labelled isolated fixture. Output labels must be new. The runner snapshots frozen source from Git, overlays owned modules, creates private HOME/XDG/imports and holds `fcntl.flock('/tmp/spillway-r21-engine.lock')` for each complete engine lifetime. A busy lock launches no engine. It checks total all-prefix scratch <=350 MiB, HOME >=15,000,000,000 bytes, global TMP >=1 GB and MemAvailable >=3 GB before/during execution. It never edits the live `.godot` link.

`tests/r21_tether_route.gd` uses actual input edges and mouse counts from normal spawn. Without `--production=1`, its R20-derived adapter is explicitly component-only. `--frozen-r20=1 --human=1` runs exact original input tapes with no finish requirement; matching requires the separate binary audit. `--production=1` loads the real configured R21 scene and requires model selection in its actual pause UI. Closed-loop finding is labelled; saved raw recordings replay open loop, comparing every physical and input column, including derived actions. Neither route path writes body, view, velocity, progress or score after setup. The separately labelled dispatch-only contact scenario changes initial geometry, never movement state.

`tests/r21_tether_component.gd` evaluates exact original/reference laws, single-axis variants, applied Arc reeling, eligibility/ties/duplicates/hysteresis/occlusion/viewport/range, snapshot purity, held guards and render-cadence stress. `tests/r21_tether_geometry.gd` verifies heights, flat deck/return landings and connected ramp endpoints. `tests/r21_tether_audit.py` independently compares original binary recordings, contacts, clean routes and complete saved raw/action replay columns. Deliberate private soft/arc/cone mutations must exit nonzero. Both original strict readers are retained unchanged.

The actual production boundary suite is `tests/r21_tether_boundaries.gd`: every inherited R20 component control/physics/lifecycle/identity check plus actual six-model UI, independent assist persistence/identity, passive readout agreement, live boundaries and matching/wrong-reel/wrong-assist/old-geometry ghost checks. `tests/r21_tether_reload.gd` is a separate-process production preference reload. The production suite passed using the parent integration and earned production recording manifest. Only its two inherited literal R20 resource-path expectations are adapted to the exact R21 runner/HUD paths; every inherited physical/control assertion remains. Extra automatic Arc and assist-off Elastic routes also finish cleanly and replay their complete binary input/physics columns exactly. The reload process leaves the saved profile bytes unchanged. Component-only evidence cannot clear these gates.

`tests/r21_tether_native.gd` forces the real production scene, accepts `--tape=ABS_RECORDED_TAPE` and saves earned moving/release frames on a parent-owned private display. It never poses the body or view. Native appearance, cue listening, human feel, package adapters, exact packed replays and promotion remain parent work. No native Windows play is claimed.

The canonical compact packet is outer `look/evidence/r21-tether-component/CONTRACT.json`, with `ACCEPTANCE`, `SOURCE`, `AUDIT`, `READERS`, `CLEANUP` and exact raw-proof inventories. Its production gate must remain false until actual host/UI and recordings pass after wiring. Failures and source hashes remain in owned raw proof under `/tmp/r21-tether*`; source/import/profile caches are removed after proof.
