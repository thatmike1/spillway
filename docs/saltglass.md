# Saltglass: low exits and a working salt quay

The example measurements in this document are reported by the original R21 component notes, not new measurements from this handover. Current validation is described in the handover results.

R21 keeps the F2 runner and the two high-entry fins, lowers both first flat decks from 14 m to 7 m, and puts five metres of open water between each fin end and its deck. A normal-spawn input line finishes the configured `r21.tscn` course in **64.4765625 s**, without a fall, respawn, state correction, clock padding or artificial low speed target. This is one headless existence proof, not a fastest line or a feel verdict.

## Why the exits changed

The completed human R20 attempt `104057_050_d1951cf9` contains both exits. West loses approximately 1112→503 u/s while rising 13.371 m; east loses 1193→670 while rising 13.215 m. The fin-end crossings are about 509 and 675 u/s at y=16.424 and 16.576 m. Neither rising interval contains a grounded sample, land event or single-tick loss of at least 100 u/s. Those recordings support a costly climb, not a proven platform impact. Full evidence and the distinction between physical and reference feet are in the outer `playtest-r20/ANALYSIS.md` and `r21-analysis.json`.

The new geometry permits a lower line instead of requiring that climb. Development with a 13 m setback missed the 7 m deck: the low trajectory had already fallen below it. The accepted 5 m setback catches that actual trajectory. The controlled fixtures use the same high entry, unchanged motor and explicit high/low steering targets. They compare real supports rather than a speed value sampled somewhere above a platform.

| Matched fixture | R20 high line, 14 m support | R21 same high line, 7 m support | R21 low line, 7 m support |
|---|---:|---:|---:|
| west horizontal speed | 781.73 u/s | 783.44 u/s | 987.65 u/s |
| east horizontal speed | 780.62 u/s | 782.32 u/s | 985.31 u/s |

The same low steering fails to find a usable R20 exit support on both fins. Same-high steering changes support speed very little. The substantial gain therefore belongs to a **low line enabled by the lower deck**, not a claim that moving a platform alone changes the surf law. These controlled entries start near 252 u/s and are not replays of Mike's faster human approach. East fixtures start at the authored east headrace, with the R20 fixture translated into the same world coordinates to avoid translation-dependent float drift; the whole-course proof starts at the normal west spawn.

## Dimensions and choices

All new dimensions are game design choices, not Source motor tuning.

- Both fins remain 168 m long, eight 21 m convex prisms each, an 18 m crest and a 56.31 degree face. The inherited 2 cm downhill relief at each join remains physical geometry. Both actual first feet and contact points must exceed 14.4 m. The normal line contacts at approximately 15.27 m.
- West landing: x=-16..20, z=-197..-173, top y=7. East landing: x=112..148, z=5..29, top y=7. Their first support normals are vertical. Neither has an inclined mouth.
- The east fin moves to a 132 m centre separation, from 84 m. Nine compact pans climb 7.9→15.1 m in 0.9 m rises. Each is 11.5 m across the direction of travel with a 1.5 m gap. The last pan joins the 15.5 m east headrace. Landing position and the next jump matter throughout this ascent.
- The quay has nine 16 m pans at 19 m spacing, tops 6.5→4.1 m. Inland necks occupy z=32..44. The outside edge is z=54, with water beyond. The final neck joins the salt house at x=300..322, y=4. The inherited open finish rule remains.
- The solid store occupies x=215..220, z=40..54, y=5.3..11.3. Inland travel goes around its north face. An outside curve clears its south face over water and must land on a 3×5 m receiving lip at x=220..223, z=49..54, y=5, before hopping onto the next pan. No location reward or hidden route trigger exists.
- There are no walkable supports beneath either fin and no spawn turnaround connection. The nearest stage-3 solid is 102.3 m from spawn in plan view. Controlled reverse and diagonal attempts fall and respawn; this is not a proof against every earned high-speed cut.

The pans, pump housings, salt-store louvres, mooring posts and salt-house canopy use original primitives. Decorative meshes have no collision. LookC supplies the existing pale decks, dark sides, ink and painted practice sky; L changes presentation only. Native visibility and whether the dressing feels calm remain parent checks.

## Physical outside choice

`r21_surf_skill.gd` starts at rest on an actual quay pan. The same earned input prefix reaches the fork, then the inland and outside policies diverge. The outside policy positions an approach landing and next takeoff, curves beside the real store below its roof, lands on `outside_lip_0_0`, jumps again and lands on the receiving pan. A straight inside attempt contacts the store.

The outside fixture reaches its first receiving landing 1.5234375 s after the fork; the inland fixture reaches its landing in 3.765625 s. At a common downstream x=225 plane they take 1.9921875 and 3.1875 s respectively. These are two measured local lines, not a fastest-route claim. Existing gap scoring recognizes the airborne void; a sufficiently close clean pass can also earn the existing near-miss reward. [the local-line notes](../history/rounds/r21/outside-lines.md) separates that result from Mike's wider Breakwater line.


## Verification

`python3 tools/test.py` runs `tests/saltglass_registration.gd`, including actual production registration, map revision separation, original identities and collision/look checks. The slow tier verifies all original maps without differences. Historical surf route/native delivery verifiers and their external receipts remain in Git history and the original build workspace.

## R22 presentation contract

Saltglass is a coastal salt works where seawater is lifted into two long feed races before concentrating in rising evaporation pans.
The runner follows the maintenance decks along these feed races, then crosses the crystallising pans to the shipping quay.
A supported pump header serves the pans, so machinery belongs to the process rather than floating beside it.
The salt store above the quay is the single tall landmark, with a loading canopy at the finish and mooring piles below.
From the west entry the pale running face descends toward the sea, the pan sequence crosses the horizon and the salt-store tower stands beyond.

The map-local `saltglass_surface.gdshader` classifies the 56.31 degree running faces by their upward normal (approximately 0.555), using a 0.35–0.52 transition. The common Look C shader's 0.65–0.92 transition classifies those faces as sides. Local mesh names opt these surfaces out of the common material swap, keeping slope/underside contrast in both L modes. Short orange edge bands identify low exits and the outside takeoff/receiver. No collision is added by these cues.

`tests/saltglass_art.gd` pins the delivered R21 geometry hash and compares actual solid transforms and convex points before/after both look states. The existing registration test remains untouched. Visual acceptance still requires matched first-person frames and Mike's playtest; headless passing does not establish readability or enjoyment.
