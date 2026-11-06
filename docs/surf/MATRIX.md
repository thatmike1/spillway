# R12 input matrix

Run `python3 tools/stress-spillway.py --pack=/absolute/path/spillway.pck --output=/absolute/empty/evidence/directory`. Omit --pack only for a source diagnostic while nobody changes runtime files. The runner records its hash, exact pack or all active source hashes, case list, command, isolated profile, every trace/log and final denominator. Engine processes are bounded at 45 host seconds. Packed preflight runs outside the source tree before attempts begin.

`r12-bhop-surf-1` has 42 fixed cases. Thirty baseline cases cover safe, fast, recovery, brake, safe_corner and wet with seeds 0–4. Twelve more cover safe and fast with early/late 80 ms takeoffs, 2° aim range and seeds 1–3. Ordinary routes perturb every scheduled jump and per-waypoint aim. The surf controller perturbs initial Crest takeoff and one fixed run-wide aim bias; automatic landing hops remain automatic. This is an input controller, not human timing data.

The retired R11 apron-hop/housing-turn junctions are documented in ROUTES.md. Its historical 41-case results remain unchanged. The R12 list adds the wet line and safe takeoff perturbations rather than silently dropping failed cases.

A case succeeds only with one trace/result, no engine errors, clean provenance, no respawn and ordered stages 0,1,2. Fast surf-contact and large speed-loss flags are separate from completion. They cannot be represented as proof that a clean finish held every bank. The surf driver checks matching bank metadata across every manifold contact, and traces identify the sections actually touched.

The first frozen development matrix in outer checkpoints/spillway/r12/matrix-dev-bd48 completes 37/42. All beginner/alternate cases and safe timing variations finish. Fast aim/timing variants expose Yard entry/apron collisions and misses. It uses bd48 plus record changes, before the active recovery pass; it is not final acceptance. The exact-bank observer audit in driver-contact-audit preserves the 13.658 s canonical line and 13/13 checks, with contact counts 314/160/52/31. Final delivered-pack matrix is complete at `checkpoints/spillway/r12/matrix-final/matrix-results.json` in the outer build directory.

## Final runtime f84e175d

All 42 cases ran against immutable delivered PCK 206baad9. All 31 ordinary cases finish: safe 11/11 and recovery, brake, safe_corner, wet 5/5 each. Fast finishes 8/11, six without quality flags; two of those six recover after a miss. Four ride the full unassisted line. Two other finishes are flagged for Outflow speed loss or insufficient Yard contact. Three fail before a clean finish. Overall 39/42 is not a substitute for the fast 8/11 figure.

All failures and engine logs remain. The process exits 1 when any case fails; the complete result is not a timeout or interrupted matrix. No failed cases were silently dropped. The broader exploratory Yard-only 16/40 sweep remains historical and was not rerun as final acceptance.
