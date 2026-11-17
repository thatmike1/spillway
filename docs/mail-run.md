# Mail Run

The postal quay carries dispatches across a tidal sorting works.
Its landmark is a single large sorting arch at the far end of the seawall.
From spawn the runner sees pale quay tops, the first numbered mailbox off the right-hand side and the arch beyond.
The runner hops along the quay, throws an envelope out toward a mailbox and bends its flight through the slot.
The view returns to the same hop, with momentum intact, and the runner chooses between another delivery and the direct dispatch line.

## Prototype choices

These are implementation choices for Mike to judge, not playtest findings.

- Default: held body, envelope camera, deliver all three before Dispatch. Holding the body preserves its position, velocity, gravity and hop state. The next ordinary motor tick resumes that state. Global engine time is unchanged. The normal speedometer truthfully reads zero actual travel while held; the mail ticket shows kept momentum.
- B switches to `run`: the unchanged F2 motor keeps running at full speed with the held keyboard inputs while mouse motion steers the envelope. This is a comparison variant, not global slow motion. Release W while airborne as in ordinary F2; the cost of steering is losing mouse air-strafe control. Both body modes keep the same motor law and timestep.
- V compares the camera just behind the envelope against the runner's eyes. No homing or automatic target selection. Steering sensitivity follows the player's normal look sensitivity, with a fixed envelope gain of 3.25 before the flight turn-rate law.
- LMB launches along the current look direction. Mouse bends its fixed-speed flight (24 metres/second). Hit, wall, the 1.6-second limit (rounded to 205 ticks at 128 Hz), or RMB recall ends it. A mailbox can count once per attempt. The swept contact must cross the opening's front plane; a wall blocks anything behind it. Post 02 faces back toward Dispatch and is marked REAR SLOT.
- The default delivery goal requires 3/3 before finishing. N selects optional-mail timing instead. This is a separate record identity, so a zero-mail sprint cannot own the delivery-goal best. Optional mode displays mail and misses but has no separate persistent mail leaderboard or time-credit formula.
- A miss increments the miss count and permits a retry. A held-body miss costs the elapsed steering window; a running-body miss also competes for control while the body keeps travelling. There is no extra numerical time penalty. The host attempt clock always continues during flight.
- Every view/body/goal change closes the old attempt and restarts with a new identity; changing a menu selector keeps the menu paused. V/B/N work only in this runner. CLI initial choices are `--mail-view=body`, `--mail-body=run`, `--mail-goal=optional`.
- F practises a reached checkpoint and clears mail. Stage practice requires only the posts remaining after that checkpoint and cannot set a clean best. R starts the full three-post goal again. Falling clears mail and uses the existing dirty-attempt respawn behavior.

## Review responses

The fresh mechanic review found that body hold removes the control trade-off, optional mail has no timing payoff, and centre-line walking tapes did not prove route choice or momentum at speed. The run-body comparison addresses the first. A required-delivery goal with a separate optional category addresses the second. A rear-facing opening, sensitivity scaling, a side-court route tape, and an input-earned 600 u/s motor tape address the third. Human aiming difficulty, the generous openings and which body mode to keep remain playtest decisions.

## Verification

For a fresh worktree, import resources once with `python3 tools/play.py --headless --editor --import --quit`. Then `python3 tools/play.py --headless --audio-driver Dummy --fixed-fps 128 --script res://tests/mail_tape.gd` runs the deterministic lane tape. `python3 tools/test.py --out /tmp/r22-mail-run/fast-N` runs the shared component gate. Additional focused executors are `tests/mail_flight.gd` (occlusion, opening direction and sensitivity), `tests/mail_motor.gd` (earned high-speed hold/run and resume) and `tests/mail_courts.gd` (all three supported court approaches). Run them through the pinned wrapper:

```sh
python3 tools/play.py --headless --audio-driver Dummy --fixed-fps 128 --script res://tests/mail_flight.gd
python3 tools/play.py --headless --audio-driver Dummy --fixed-fps 128 --script res://tests/mail_motor.gd
python3 tools/play.py --headless --audio-driver Dummy --fixed-fps 128 --script res://tests/mail_courts.gd
```
Slow original-map parity belongs to the integrator for this run.

Original art is procedural geometry and painted-concrete materials in `scripts/maps/mail_run.gd`; no reference or generated concept image is a runtime asset.

## Presentation and route pass

The numbered postal buildings and arch piers have actual collision, not just visible shells. Their foundations meet the seawall and waterline. Four checkpoint bands divide the run. The middle quay is a direct 12-metre-wide speed line; the three side courts alternate east/west/east, letting the runner shorten envelope flight at the cost of extra lateral travel. This is deliberately a generous first experiment, not a precision-hop course. The real-map research sheet was read for scale and checkpoint organization; no imported map geometry or assets are used.

The held-body interval uses the style service's suspension API; the seeded-combo regression verifies that a 205-tick hold and the first resumed sample preserve the chain. This is scoped to Mail Run and does not alter the inherited F2 motor.

An envelope line trail makes the arc visible from the body view. Steering adds a local low hum; a delivery plays a higher rising cue and a miss a lower cue. These are generated PCM and the project's original Through Line cue, with no third-party audio. Pause suspends the sounds; restart stops and clears them. No global audio bus or engine time setting changes.

The inherited practice presentation supplies the painted sky and outline pass. Mail buildings use the project's painted-concrete shader with pale tops and weathered dark sides; orange is confined to mailbox lips and collection-apron edges. The private concept was generated with the built-in imagegen tool and stays outside the repository at the run folder's `concept/11-mail-run/concept.png`.
