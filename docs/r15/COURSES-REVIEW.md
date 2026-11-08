# R15 last-three-course source review

No runtime defect confirmed on parent `f3f234525ea01d53c3cedf818530621d24dc0bd1`. Independent challenge of Sunken Court, Rainline and Night Shift: **273 checks pass across 31 selected fresh episodes and 108,758 observed ticks**. Eight finish clean and three finish practice. Twelve episodes are explicitly seeded diagnostics. This is source-mode collision/checkpoint/crouch evidence, not pack acceptance or a human feel verdict.

Evidence, outside Git:
`/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r15/courses-review/`

`CHECKS.json` names every selected episode, assertion, trace receipt and control. `HANDOFF.json` seals the owned files, source/helper hashes, storage and cleanup. No runtime, existing test, helper or delivery file was edited. No commit, push, export, child agent or native renderer was started.

## Fresh objections and outcomes

| objection / severity | actual repro and control | outcome |
|---|---|---|
| missed approaches strand a normal-spawn run | Sunken `arch_return` drops east of pavilion 1, crosses its actual arch void, circles the next pier and returns via the court ramp; `east_cistern` leaves the aqueduct approach and recovers on the previously untested east ramp | clean **73.6015625 / 54.046875 s**, zero respawns. These are state-aware recovery executions, not discovery or smooth lines |
| Night's throat catch or return corner is blocked | normal-spawn `throat_return` deliberately drops to the trackbed, approaches the return ramp from its foot and retries the cabinets | clean **63.6015625 s**, zero respawns; 6 side-normal ticks on the return ramp |
| early stand-up bypasses Rainline's duct ceiling | normal-spawn `duct_release`, Ctrl released in flight at tick 4034 inside the duct; standing-only approach is the negative control | **245 blocked ticks**, then stands at 4279, zero interior overlaps and clean **43.1796875 s**. Seventeen crouched landings. The standing control remains outside the duct |
| reverse duct corner traps a practice return | authored Signal runway practice, reverse through the duct into the lamp room, then release in the hood | physically returns and stands, 1,505 observed ticks, no respawn or progress regression; remains practice, no record. This is a checkpoint start, not normal spawn |
| Night's shutter allows unsafe stand-up during a crouch jump | normal-spawn `hatch_hold` vs `targeted05/hatch_release`; release at tick 3615 once the hull is under the shutter. A standing-only approach and an earlier release are negative controls | release refused for **17 ticks**, stands at 3632 after clearing the shutter; both positive routes finish clean **57.203125 s**, zero side contacts or interior overlaps |
| Sunken's crouch ledge is cosmetic or stand-up penetrates it | normal-spawn `causeway_hold` vs standing-only jump; extra `causeway_release` intentionally produces noisy press/release input near the apex | crouch control lands on the causeway and freely stands; clean **49.25 s**. Standing control hits its face and lands below. No interior overlaps. The noisy control also finishes 49.25 s; it is not a single-release proof |
| F/R can turn checkpoint practice into a clean record | reach stage 3 using normal-spawn input, press actual F and finish on each map; separately reach stage 1, F then actual R | all three F finishes are practice, with no clean/open best and **no profile written**. Practice times: Sunken **15.6015625**, Rainline **13.578125**, Night **29.8984375 s**. Each R immediately restores spawn, clean eligibility, zero timer/checkpoint and empty splits |
| wrong deck or air-crouch grants progress | labelled seeds below Sunken pavilion 1, on Rainline's plant-room roof, and on Night's lower platform beneath the flyover; separate airborne seeds over a real stage-1 deck, Ctrl down then up | wrong decks collect nothing. Airborne crouch collects nothing; each stage is collected only at the subsequent grounded landing |
| records bleed across maps or F5 | actual host map selections through all three maps, then actual F5/F2 key presses | three distinct map keys; map changes reset timer/progress/splits. F5 changes identity and F2 restores the original map key. Clean finishes persist integer-tick records only in their own isolated course sections |
| diagonal contacts discard tangential momentum | one clear airborne pose/velocity seed per map plus a matched open-space seed; no input or movement writes after setup | all three first contacts clip only the wall-normal component, as detailed below |

### Contact evidence uses actual normals and travel

At the first diagonal wall contact, the requested horizontal velocity is `(300, -400)` u/s in x/z. The actual normals are `[-1, 0, 0]`: Sunken `s0_side_e_b` and Rainline `s2_tower_s` at tick 11, Night `s0_train_e_08` at tick 14. Post-contact x/z is `(0, -400)` u/s in all three. The matched open controls have no contact on that tick and retain both components. Tangential error is **1.53e-7 m/s** against the requested velocity. The contact tick still travels some x before impact; its nonzero finite-difference x velocity is expected.

Across every selected row, finite-difference displacement agrees with the reported motor travel after subtracting the explicit duck-origin shift. Worst error is **2.52e-8 m**. Host reset rows are excluded and listed. Delivered physical-key states equal the recorded held states. Actual velocity also equals displacement divided by the actual 1/128 s delta. No sampled hull overlaps geometry after shrinking each face by 6 mm; shallower or within-tick penetration is not excluded.

The new Sunken recovery lines have **163 / 315** side-contact ticks, not 163 / 315 motor stalls. The arch return contacts columns, a pavilion pier and the side of the court ramp. The east-cistern approach scrapes the aqueduct's parapets/merlons before reaching the east ramp. These are imperfect controller approaches with real collision, not evidence that those solids are invisible or that the motor loses unconstrained momentum. The older role-tag counter is retained only as a labelled inherited metric. This does not reopen MAPS-REVIEW.md's already documented role-counter limitation or its out-of-scope Breakwater F5 breach gap.

## Failed trials and review-tool corrections

All failed evidence is retained.

- `attempt01`: launcher named a nonexistent review script. Import completed, no route ran. Corrected the dedicated filename; no production change.
- `probes02`: Sunken's first diagonal seed started at y 6.0 inside the y 6.8 step, then depenetrated. Excluded that pair. `routes04` seeds at y 7.4. Rainline's original airborne seed was over its authored checkpoint pose on a stage-0 terrace, so it correctly collected no stage; `routes04` moves x to 14.5 over the real stage-1 gantry deck. Neither original probe supports its intended positive claim.
- `routes03/arch_return`: waypoint aimed through pavilion 2's pier after successfully crossing pavilion 1's arch. W was delivered; blocking `[0,0,1]` normals and effectively zero z travel establish a real pier block. `routes04` goes around it and completes. This is a controller path error, not a closed arch void.
- `routes03/causeway_stand`: inherited missed-landing code calls `_end(tick + 1)` before another observation exists. The supervisor's row-count assertion exposed a review-summary bug. The final observer reports the actual row count and separately keeps `caller_end_tick`; `routes04` reruns the same negative control. No motor tolerance changed.
- `routes04/hatch_release`: release at tick 3603, before the standing hull overlaps the shutter, lowers the airborne feet enough to catch the splash wall. It has 17 side ticks and no blocked-standing tick. The later, independently labelled release in `targeted05` establishes the actual under-shutter refusal. The standing-only approach fails as expected.
- `routes04/duct_stand`: standing cannot enter the duct, but the controller keeps trying for its 16,000-tick budget. Its real hood contact normal is approximately `[0,-0.96,-0.28]`, a ceiling slope, so the side-normal counter correctly remains zero. Requested travel, delivered W and much smaller actual travel establish the block. Do not interpret zero side ticks as free passage. The controller also emits redundant same-tick Ctrl edges before forcing the key up; the motor always receives standing input.
- The first judge expected practice to leave a profile file. Practice makes no save at all here; the final judge checks absence for practice and checks retained CFG payloads for clean finishes. `CHECKS-first.json.gz` retains the failed assertion set.
- The initial per-batch storage assertion fired after `routes04` completed because raw summaries and repeated traces exceeded the ceiling. Final storage is below 15 MiB. Summaries/inputs/logs are gzipped; identical 512-row trace blocks are shared losslessly. Original and logical hashes are retained. No failed rows were sampled, rounded or discarded to meet the ceiling.

## Reproduction and receipts

Run from `projects/foldrunner`, using a new empty output directory outside Git. The supervisor freezes all tracked project files plus these dedicated review files, imports with the pinned Godot 4.7.2 editor, isolates every XDG path, and uses the unchanged `tools/package-r15.py::run_engine` for owned process groups and deadlines.

```bash
python3 -I tests/r15_courses_review_run.py --out /absolute/external/courses-review/targeted05 --only hatch_release
python3 -I tests/r15_courses_review_check.py --evidence /absolute/external/courses-review
```

The checker expects the retained `probes02`, `routes03`, `routes04` and `targeted05` batches for this particular report. A lone targeted reproduction is not the full 273-check set. Omitting `--only` runs all dedicated cases; separate isolated output roots avoid replacing existing receipts. Fresh locomotion uses physical-key and relative-mouse events through Godot's input system at 128 Hz, sensitivity 2.5. Controls read coordinates. They are execution/recovery evidence, not human play. Utility/menu/setup events are labelled; `input.json.gz` is not a strict standard-executor tape, and no strict neutral-tail guarantee is claimed for this observer.

For a trace with `trace-index.json`, `r15_courses_review_store.py::read_trace(case_directory)` reconstructs the exact original JSONL bytes from `trace-blocks/*.jsonl.gz` and checks each block plus the whole logical SHA-256. Smaller traces remain standalone gzip files. `LOSSLESS-COMPRESSION.json.gz` bridges the first gzip hashes to losslessly recompressed content. Results contain exact before/after source and actor/helper hashes. **All 897 pre-existing tracked project files match before/after every batch.**

| executed source | SHA-256 |
|---|---|
| pinned Godot 4.7.2 | `8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e` |
| `r15_main.gd` | `7335c615a6cdaf4b94a5f006598735e50934cb5c5899a3fa4aa02b971c96687c` |
| `r15_source_player.gd` | `e06a545d610da0c3bb35f61d14d8f3f24d9ddf4e36e1b87743060a5c48157019` |
| `r15_sunken_level.gd` | `95d93e735152c6b09749ef38df085bcacee20baffa376089b8046be789c8acbd` |
| `r15_rainline_level.gd` | `2e66f8b38c5f5208b38b8a8bc8877abb9314fe9fecbe2db285ccf01a87ad062e` |
| `r15_nightshift_level.gd` | `3e5301c86448e47cafa2283e1b0c93de334ecb53aae0bcda22b5383d0bd2f388` |

## Limits left intact

These new episodes exercise F2. F5's existing strict route evidence remains the lead's evidence; the fresh F5 check here concerns identity only. Existing fall/kill-return tapes, approved legacy parity, complete-registry/loop gates and source/native audits were not counted again. No pack, native Windows, performance, hardware-input latency or feel conclusion follows.

Known disclosures remain unchanged: Rainline's 38.2 s ordinary route is below a proposed duration target, its duct is about 5 s slower and duct-to-earned failed; dark scaffold/apex lamp and 47 lights/~1,400 models have unmeasured frame cost. Sunken's crouch-hop saves 0.49 s, taught stopped crouch is slower, causeway-chain failed, and the 2.9 m tower chord is a speed line. The previously measured 39 court / 67 cistern normal-based side ticks are contacts, not necessarily stalls. Night's crouch saves 0.34 s and its earned bridge touchdown is a legal but fragile hull-edge landing with centre 0.22 m short. F2/F5 equality is specific to the tested capped inputs. Rounded native driver samples are not full-precision parity.

Readability inspection here used only existing Sunken `native/views/04-court-floor.jpg`, Rainline `native/movie-duct/frame-030.0s.jpg` and Night `native/server128-crouch/frame-027.8s.jpg`. They help locate the return ramp, duct and hatch; they are not a screenshot-only playtest. No screenshot discovery or human play of these three maps was added. Weston at `r14/hardware-render/weston`, the desktop display and other workers' processes were left untouched. Owned scratch, import caches, test profiles and local Python cache files are removed; final checks are in `HANDOFF.json`.
