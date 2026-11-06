# R12 input matrix

Run `python3 tools/stress-spillway.py --pack=/absolute/path/spillway.pck --output=/absolute/empty/evidence/directory`. Omit --pack only for a source diagnostic while nobody changes runtime files. The runner records its hash, exact pack or all active source hashes, case list, command, isolated profile, every trace/log and final denominator. Engine processes are bounded at45 host seconds. Packed preflight runs outside the source tree before attempts begin.

r12-bhop-surf-1 has42 fixed cases. Thirty baseline cases cover safe, fast, recovery, brake, safe_corner and wet with seeds0–4. Twelve more cover safe and fast with early/late80ms takeoffs,2° aim range and seeds1–3. Ordinary routes perturb every scheduled jump and per-waypoint aim. The surf controller perturbs initial Crest takeoff and one fixed run-wide aim bias; automatic landing hops remain automatic. This is an input controller, not human timing data.

The retired R11 apron-hop/housing-turn junctions are documented in ROUTES.md. Its historical41-case results remain unchanged. The R12 list adds the wet line and safe takeoff perturbations rather than silently dropping failed cases.

A case succeeds only with one trace/result, no engine errors, clean provenance, no respawn and ordered stages0,1,2. Fast surf-contact and large speed-loss flags are separate from completion. They cannot be represented as proof that a clean finish held every bank. The surf driver checks matching bank metadata across every manifold contact, and traces identify the sections actually touched.

The first frozen development matrix in outer checkpoints/spillway/r12/matrix-dev-bd48 completes37/42. All beginner/alternate cases and safe timing variations finish. Fast aim/timing variants expose Yard entry/apron collisions and misses. It uses bd48 plus record changes, before the active recovery pass; it is not final acceptance. The exact-bank observer audit in driver-contact-audit preserves the13.658s canonical line and13/13 checks, with contact counts314/160/52/31. Final delivered-pack matrix remains required.
