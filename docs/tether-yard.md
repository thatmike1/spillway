# Tether Yard movement and acquisition

The example measurements in this document are reported by the original R21 component notes, not new measurements from this handover. Current validation is described in the handover results.

Implementation: `scripts/movement/grapple_player.gd`; geometry: `scripts/maps/tether_yard.gd`. Historical resource aliases preserve recording identities.

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


## Verification

`python3 tools/test.py` runs `tests/tether_coefficients.gd` and `tests/tether_geometry.gd`: applied coefficients, acquisition, Arc reel floor, render-cadence stress, collision manifests and connected return ramps. The slow tier preserves original-map motion and recordings. Historical earned-route, native and packed delivery receipts are not retained in this repository or required for the current checks; the published r21 binaries retain their completed original acceptance.
