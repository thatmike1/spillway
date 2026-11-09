# R16 actual-host review

Root resolution, 9 November: all three retained findings below are repaired. `r16-style-2` cancels an open crouch save on a later blocking wall or ceiling contact with its obstacle; legitimate walkable landing support is allowed. The first recorded finish sample now scores once before sealing, and subsequent samples cannot score. R15's movement and finish-clock convention stay unchanged. The session continues calling the stopped recorder to count its uncaptured tail. A fresh run of this review passes 115 assertions, including one added check that the finish reward reaches the actual style best and sealed file; 52 copied attempts and the selected 5,777-tick R15 tape still pass. The original 60 scoring checks pass too. Evidence is `checkpoints/spillway/r16/host-repair-final/` and `style-repair/`. The original report and red evidence remain below as the record of what was found, not the current verdict.

Two scoring concerns and one recording diagnostic failure remain reproducible on the frozen host. No P1 was demonstrated. This is a targeted headless review, not release approval.

## What changed

Added only `tests/r16_host_review.py`, `tests/r16_host_review.gd`, `tests/r16_host_review_fixture.gd` and the two script UIDs. Production and existing tests were not edited. No commits, pushes, child agents, native renders or exports were made.

The Python driver freezes the project in private `/dev/shm/r16-host-review-*` scratch, imports only that copy, and isolates HOME and every XDG directory. The imported copy measured 173,121,997 bytes, about 165.1 MiB. New tests reuse the existing loop's input helpers and six existing host groups, then add independent input-attribution, input-burst, disk-failure, corrupt-pointer, geometry and finish reductions. All gameplay input enters through engine `Input` events or the existing viewport menu clicks. Fixture geometry, fault injection and seeded profile files are labelled in the tests. A shadow style calculation changes only a copied sample for diagnosis; production receives its original sample.

Read the requested BRIEF, INTERFACES, PLAYABLE, STYLE, RECORDINGS and LAB documents, the actual host/session/style/reader/recorder/ghost implementations, and the reused tests. Backlog lookup identified round `ccChat-general-41fq`; review findings are handed to root here rather than changing its tracking or production ownership.

## Does it work

The executed engine suite has 114 assertions, with three retained failures below. The copied-folder and tape driver has 52 checks with no failure. Those counts describe these reductions only.

- Session priority 999 attributes a key and mouse event injected at priority 1000 to the next motor sample. Pending preset replacement preserves the new body's first hop and does not relabel an old motor step.
- R/F input bursts retain their terminating edge and preceding inputs in the old attempt. Existing host groups also exercised preset, loadout, map, quit, pause, respawn, clean/practice, overlay and identity boundaries. Continuous travel checks agree with the motor; the copied analyzer reports no unexplained teleports.
- An actual gap measures 4.5365 m, within 0.002 m of the authored collision void. Edge slack measures 3.002 u for an authored 3 u landing. A shallow trench pays neither. A second crossing after a real fall/respawn does not repay the same gap. Repeated one-tick Ctrl taps on flat ground produce no gap, edge or crouch-save reward.
- A clean grounded beam passage earns one 600-point crouch save. Actual strafe-hop calibration earns high-gain sync. The collision-negative exception is finding 1 below.
- A recording write failure does not stop a clean finish or replace/alter the earlier valid ghost. Missing and corrupt stored pointers recover the older valid recording during actual host startup, even beside a failed `.part` and a truncated neighbor. The repaired reader accepts the host's dense clean recording. Ghost shown/hidden/absent motion and identity separation pass the reused host group.
- The analyzer independently reads 52 copied attempts: 50 complete and two deliberately partial files, the failed write and truncated neighbor. All 50 sealed style totals equal the event sums. Adding an empty recording and a text file leaves all existing reports unchanged.
- One accepted R15 Breakwater tape was replayed through the actual R16 host plain and recorded: 5,777 ticks each, zero position, velocity, yaw or game-state differences against the accepted R15 reference. Recorded inputs and samples also match the executor trace. No full rerun of the claimed 31 plays was needed.
- The priority-998/1000 comparison detects no motor-state writes by the production session/style observation.

### Finding 1: P2, a crouch passage pays after hitting its own obstacle

**Observed:** `engine/crouch_scrape.json` records a save opening on `review_beam` at attempt tick 345. The actual duck hull makes a blocking ceiling contact with that same piece at tick 347, normal `[0,-1,0]`. At tick 366 production awards 900 points, explicitly recording `m.duck_contact: true`, entry 250 u/s and progress 1.042 m. The host and copied-folder analyzer both retain this reward.

**Expected:** a crouch save should establish that the actual duck hull avoided the collision. A later hit on the candidate obstacle should invalidate that candidate, rather than merely be included in the reward's measurements. This follows the review brief's explicit collision-negative priority and the counterfactual requirement in INTERFACES.

**Reproduction:** `crouch_challenges()` in the dedicated test. On flat fixture ground, hold W, press Space after z < -10, press Ctrl four ticks later. A separate unmodified calibration places a horizontal beam just ahead of the rising duck hull, with its bottom 5 cm above that calibration pose's duck head. Replay exactly those inputs. The hull first fits, subsequently bonks the underside while rising, and continues forward. The setup is real collision geometry, not fabricated style samples or a production motor change.

**Scope and cause:** `scripts/r16_style.gd:781` sets `_save.duck_contact` on later contact. `_pay_save()` at line 806 never rejects it and emits the positive award at line 824. The concrete reproduction is a labelled fixture, not a claim that a named shipped route currently farms it. Cancel the candidate on contact and retain the positive untouched passage control. Changing detection rules should also change the scoring identity.

### Finding 2: P2 contract mismatch, finish-sample style is suppressed

**Observed:** `finish_calibration` earns a 33-point sync event at attempt tick 200: 94 eligible ticks, 100% sync, +12.03 u/s air gain, 250 to 262.03 u/s. A labelled finish volume placed around the prior motor pose makes the actual host declare a clean finish on that same tick 200. The landing still occurs, but production saves style score 0 and no sync event. The final sample is recorded and the recording is accepted as the clean ghost. A diagnostic shadow fed the same real samples, with only the copied `finished` flag suppressed, emits the same 33-point event.

**Expected by this review brief:** score and record the finish sample before saving the style best. **Documented alternative:** STYLE and the existing tape helper intentionally exclude events on the finished sample. Under frozen host bookkeeping the line is detected from the preceding motor pose, so this reproduction's landing physically happens after that detected pose. This is a demonstrated semantic mismatch, not evidence that an event strictly before the physical finish line was lost.

**Reproduction:** `finish_challenge()`, retaining `engine/finish_calibration.json` and `engine/finish_scoring.json`. W from spawn, Space at controller tick 95; in the air release W, alternate A/D with four mouse counts per tick. Calibration picks the first real sync event and places a small finish AABB around the immediately preceding pose. Nothing writes the player, clock or finish flag.

**Scope and cause:** `scripts/r16_style.gd:201` requires `not _finished`, so the session's final call to `style.step()` cannot score. `scripts/r16_run_session.gd:253` does capture that final sample before sealing. Resolve the requested meaning of the finish sample explicitly, preserving the accepted R15 motor/timer convention. Do not blindly pay for arbitrary untimed post-finish movement. This assertion remains red to make the disagreement reviewable.

### Finding 3: P3, stopped recordings report zero dropped ticks

**Observed:** after a valid clean run becomes the ghost, the next actual attempt uses the recorder's labelled `fail_after_bytes = 0` hook. Its first pending chunk fails; play continues through another clean finish. The host's final failure result is `{status: disk-error, kind: finish, dropped_ticks: 0}` despite later samples not being recorded. The older ghost stays loaded and its file hash is unchanged.

**Expected:** count the uncaptured tail while continuing play and preserving the older ghost. The file already remains correctly labelled `.part`; this is a diagnostic/counting defect, not promotion of an incomplete ghost.

**Reproduction:** `disk_failure()` in the dedicated test; `engine/summary.json` retains `notes.disk` with the result and old file hash. `scripts/r16_run_session.gd:255` calls `capture()` only while the recorder is open. The recorder's `capture()` branch that increments `dropped_ticks` after `disk-error` therefore never executes on later host samples. Exercise this path without repeatedly warning every tick.

## What I decide

Return these findings to root without modifying production. Finding 1 needs a scoring correction. Finding 2 needs an explicit decision on the review brief versus the currently documented finish convention. Finding 3 can be corrected as a small diagnostic integration fix. No broader release verdict follows from the passing reductions.

The earlier seal-only ghost defect is not reopened: this execution uses the repaired reader from pushed `8aa99cad` and confirms valid actual-host promotion and corrupt-neighbor recovery. Its separate claimed 79 mutation checks and 59+38 component checks were not independently rerun here. Full per-map preservation beyond the selected Breakwater line, actual lab A/D wall-jump native proof, slide native proof, visual acceptance, final package acceptance, real OS disk refusal, human feel and Windows behavior remain unverified by this review. The lab host group did run the production R16 runner, loadout boundary and landing slide/hop headlessly. No assertions about feel or Windows are made.

## Where

From `/home/thatmike1/foldrunner-build-2026-11-05/wt`, reproduce with:

```sh
python3 -I projects/foldrunner/tests/r16_host_review.py --out /home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r16/host-review
```

Exit 1 is expected on this frozen production source because the three assertions above stay red. The driver regenerates only its own `engine`, `copied` and `mixed` outputs. Evidence is about 9.53 MiB, below the 20 MiB limit. Entry points are `engine/summary.json`, `driver.json`, `analysis.json`, `mixed-analysis.json`, `tape-summary.json` and `engine.log`; exact commands are in `driver.json`. There is one deliberate recorder error plus its host warning in the engine log, and no unexpected engine/script error.

Executed SHA-256 values:

| source | SHA-256 |
|---|---|
| `scripts/r16_main.gd` | `6937de6761530c41b0e018d69f373fff948b186197ddd262c290baa18ae315ce` |
| `scripts/r16_run_session.gd` | `9b4da799a2021a7def40d6138c7583f710615116d6e8da58990bee2fc0b10578` |
| `scripts/r16_hud.gd` | `0876b4fd576fd56979a413686183ddd3d59291f83150036b372419a8eab8ccc0` |
| `scripts/r16_style.gd` | `833e02db5cb42a8b467f88f26c9a30c52126032076161443342fcf942dc066fd` |
| `scripts/r16_run_reader.gd` | `76f2f2b728d006e19ba11c1fbb99ad8b018526a8b838f954f8672278c1602d5f` |
| `scripts/r16_run_recorder.gd` | `97e35bd0bcde350c2d59eda87ae25d5a068bf34257e9520fc8815f18234e114b` |
| `scripts/r16_ghost.gd` | `f9d48346f1784a075e38588b074b96057f5de4ba65e712831b5d0663ce1e8567` |
| Godot 4.7.2 Linux | `8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e` |

`SOURCE-HASHES.json` includes every copied source file. The imported RAM copy and private HOME/XDG profiles were removed after execution; the final recorded scratch path no longer exists, and process inspection found no remaining review process. Only the assigned new review files and bounded evidence remain.
