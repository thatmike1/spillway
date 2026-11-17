# Mail Run

The postal quay carries dispatches across a tidal sorting works.
Its landmark is a single large sorting arch at the far end of the seawall.
From spawn the runner sees pale quay tops, the first numbered mailbox off the right-hand side and the arch beyond.
The runner hops along the quay, throws an envelope out toward a mailbox and bends its flight through the slot.
The view returns to the same hop, with momentum intact, and the runner chooses between another delivery and the direct dispatch line.

## Prototype choices

These are implementation choices for Mike to judge, not playtest findings.

- Body freezes during steering, including its velocity, gravity and hop state. This replaces the initial moving-slowly proposal: retaining the exact F2 timestep avoids introducing a second bhop law. The next ordinary motor tick resumes the held hop. Global engine time is unchanged.
- Default view follows the envelope from just behind. Variant `body` keeps the runner's eyes. V switches the view, closes the old attempt and restarts, giving each view a separate motor identity. `--mail-view=body` also selects it at launch.
- LMB launches along the current look direction. Mouse bends the flight at fixed speed (24 metres/second). The steering window is at most 1.6 real simulation seconds. Hit, wall, timeout or RMB recall ends it. No homing, no automatic target selection.
- A swept segment tests mailbox volumes before wall collisions in distance order. A wall blocks a delivery behind it. A mailbox can score once per attempt. An already delivered mailbox cannot consume another delivery.
- Deliveries are optional score, displayed as 0 to 3. Misses are counted separately. A miss costs only elapsed run time, with unlimited retries. Finish is reaching Dispatch; a zero-mail speed run remains valid.
- The host's attempt clock keeps running during body hold. Mail counts are prototype feedback; they do not replace the existing style score or create a persistent mail leaderboard.
- F practises a reached checkpoint; restart/practice clears mail count. Checkpoint courts are broad enough to keep a hop. The centre is the direct finish line; side courts shorten the diagonal delivery angle and flight time.

## Verification

`python3 tools/play.py --headless --script res://tests/mail_tape.gd` runs the deterministic lane tape. `python3 tools/test.py --out /tmp/r22-mail-run/fast-N` runs the shared component gate. Slow original-map parity belongs to the integrator for this run.

Original art is procedural geometry and flat materials in `scripts/maps/mail_run.gd`; no reference or generated concept image is a runtime asset.

## Presentation and route pass

The numbered postal buildings and arch piers have actual collision, not just visible shells. Their foundations meet the seawall and waterline. Four checkpoint bands divide the run. The middle quay is a direct 12-metre-wide speed line; the three side courts alternate east/west/east, letting the runner shorten envelope flight at the cost of extra lateral travel. This is deliberately a generous first experiment, not a precision-hop course. The real-map research sheet was read for scale and checkpoint organization; no imported map geometry or assets are used.

An envelope line trail makes the arc visible from the body view. Steering adds a local low hum; a delivery plays a higher rising cue and a miss a lower cue. These are generated PCM and the project's original Through Line cue, with no third-party audio. Pause suspends the sounds; restart stops and clears them. No global audio bus or engine time setting changes.

The inherited practice presentation supplies the painted sky and outline pass. Mail buildings use the project's painted-concrete shader with pale tops and weathered dark sides; orange is confined to the mailbox lips. The private concept was generated with the built-in imagegen tool and stays outside the repository at the run folder's `concept/11-mail-run/concept.png`.
