# Spillway R16 player guide

This guide accompanies accepted source 67e608a0. The outer REPORT.md supplies the final portable download links; [RESULTS.md](RESULTS.md) records the exact bytes and verification scope.

R16 adds style points, local recordings and a ghost to the bhop and maps from R15. F2 remains the default. F5, all five themed courses, Penstock Yard and Overflow remain available. R15's downloads stay separate for comparison.

## Start playing

Run up with **W**, hold **Space** to bhop, and release W in the air. Strafe with **A and a left mouse turn**, or **D and a right turn**. Release movement keys to keep the current line. **Ctrl or C** crouches on the ground and in the air. Jump first, then crouch for a raised landing or a low opening.

**Esc** opens the map grid and checkpoint picker. **R** restarts the map clean. **F** retries the last checkpoint as practice. A fall returns to the checkpoint and marks the attempt practice. Practice still earns visible points and is recorded, but cannot save a time or style best.

**F2** is the approved AA100 bhop-server preset at 128 Hz. **F5** is AA1000 at the same rate. They can agree on the same inputs because both use the 30 u air wish cap; F5 has more acceleration available during sharper or poorly aligned turns. F3 and F4 remain under Advanced comparisons. Switching a used preset or lab loadout makes the attempt practice; R starts clean.

## Style points

The compact panel shows your total, combo multiplier and one brief callout. It uses actual movement and collision geometry. The numbers are new tuning choices for this round.

| Move | What earns points | Base award, before the combo |
| --- | --- | --- |
| Speed | Cover a new 32 m stretch at 400 u/s or faster. | 20–80 |
| Clean strafe | Finish a hop with at least 80% eligible sync, enough turning samples, at least 8 u/s of real air gain and positive total gain. | 15 + 1.5 × air gain, capped at 150 |
| Gap | Clear at least 1.5 m of measured unsupported space and land across it, no more than 1.25 m below takeoff. This conservative rule excludes deep falls and some legitimate drop jumps; shallow trenches also do not qualify. | 25 × gap width in metres to the power 1.5, capped at 900 |
| Edge landing | Land across a gap or onto a raised ledge with no more than 8 u, about 20 cm, of landing margin along your flight line. | 50–300 |
| Near miss | Pass within about 20 cm of a side or overhead obstacle at 380 u/s or faster, without touching it. Enter and leave clear space; a long wall hug does not count. | Clearance and speed determine it; threading both sides pays more. |
| Crouch save | Actually pass an obstacle that the standing collision box would have hit. It pays after you clear it, not when you press crouch. | 600–1500, including an airborne bonus |

Chain moves within **2.5 seconds** to raise the multiplier by 0.25, up to **×3**. Speed earns at the current multiplier but does not extend the chain. Slowing below 150 u/s for 0.75 s, a fall or another movement discontinuity ends it. Repeating the same obstacle, gap or landing does not farm points; speed needs new ground. A high sync number alone does not score without real gain.

Sync still means that your turn direction matched the held A or D key on eligible air ticks. Holding a key without turning is not an eligible sample, and 100% does not mean the turn rate was optimal.

The final captured finish step can still score. Nothing afterwards does.

Time best and style best are separate. Only a clean whole-map finish saves them, and each map/preset/loadout has its own identity. A future scoring change can start a fresh style best without discarding the time best or ghost.

The existing maps keep their original lines. Optional additions sit beside those lines: a **CROUCH** frame and narrow **STYLE** passage on Breakwater's runway, plus a **CROUCH** frame on Whiteout's apron. The open deck beside each remains available. Jump, then crouch through the raised frame; approach the narrow passage with earned strafe speed. Other low roofs and raised lips can score from their real geometry too.

## Recordings and ghost

Every attempt gets a compact local file, including restarts, falls and practice. It contains every sampled physics tick, delivered inputs and mouse motion, view, position, velocity, map/preset/checkpoints, style events and outcome. Pauses are events rather than extra physics samples. A finished run seals at the finish; exploring afterwards is not another timed run.

Default folders:

- **Linux:** `~/.local/share/godot/app_userdata/Spillway/r16_runs/`
- **Windows:** `%APPDATA%\Godot\app_userdata\Spillway\r16_runs\`

The menu also shows the actual path. Copy the **whole `r16_runs` folder** back when you want a review of where speed was lost, where you fell or restarted, which lines you took and what scored. You do not need an analysis tool installed on the desktop. The agent tool accepts a folder of copied files; the [format and analysis guide](RECORDINGS.md) documents it.

Completed attempts end in `.r16run`. A crash or failed write can leave `.r16run.part`; an aborted attempt can end in `.r16run.aborted`. Keep those too. The analyzer labels recovered prefixes, and they never become best-run ghosts. If writing fails, the game reports it and play continues.

The ghost is your **fastest clean recorded run**, independent of your highest style score. **G**, or the menu switch, hides or shows it. It only races a matching map, preset, geometry and mechanics/loadout. It has no collision or progress effects, fades near the camera and stays hidden during later-checkpoint practice. A missing or damaged recording is refused instead of being used as a ghost.

Settings and bests live in `spillway_r16.cfg` beside that folder. R15's config and recordings stay separate. The first R16 launch can copy R15's look settings read-only. `--no-run-recordings` disables attempt files; `--no-records` disables config writes and does not stop recordings. Files stay local; nothing is uploaded automatically.

## Movement Lab

The lab stays separate from the approved course runner. F2/F5 work there, and **1/2/3** or the menu toggle slide, wall jump and grapple. The screen labels it experimental.

**Wall jump:** while airborne near a wall, release and tap **Space**. You can still hold A or D at the kick; W is not required. You get **two wall jumps per landing**, with each wall plane usable once per flight. Separate pieces of the same flat wall count as one wall. A real landing refills the budget. There is a 0.25 s cooldown and brief protection against your held strafe key cancelling the outward kick. Continue the strafe away from the wall afterwards; the protection expires. Holding Space or scrolling does not repeatedly wall-jump.

**Bhop into slide:** on the descent, press and hold **Shift**. The landing enters the slide at its landing speed, even if Space was held for the bhop. Release Space, then press it again, or scroll, to hop out. The slide uses low friction, so it gradually loses speed. Shift is separate from ordinary Ctrl/C crouch jumps. Arming too early on a long fall expires; a fresh Shift press just after landing also works. A wall jump cancels a pending slide.

**Grapple:** aim at a marked ring and hold **E**, then release E to let go. Its tuning and law are unchanged from R15.

## What was verified and what remains open

The official Linux release passed 354/354 package checks, 771 native menu/control assertions and 16 clean play/save/reload cycles. All 98,465 packed trace ticks match fresh source exactly, including the 14 retained R15 course lines. The new Whiteout run finishes with a 900-point airborne crouch save; the new lab run chains landing slide, hop, two A/D-held wall kicks and the unchanged grapple. Both restore their time/style bests and fastest-run ghost after relaunch.

All 96 broken-package controls pass, including actual broken exported games and cancellation cleanup. A separate normal Linux launch passes synthetic OS-input checks with default recordings, no game probe and a clean Quit. Another focused OS-keyboard test completes the landing-slide-hop chain and two A/D-held wall kicks with a read-only observer. Native images of style, passages, lab and ghosts were inspected. R15's downloads and guide remain separate; the R16 map additions are optional and approved motion is unchanged.

The scoring weights and lab protections are new game choices. Some valid drop jumps do not get a gap reward, and the sync percentage is directional matching rather than a quality grade. The original map roughness remains, including Rainline's slower duct and tight shortcut landings. Two instrumented native source runs produced small ObjectDB shutdown warnings; a repeat and the final packed/normal runs exited cleanly. Their unresolved cause is tracked separately. If an actual window remains after Quit, end the process; finish records are saved before Quit.

Windows has only static package checks. Physical keyboard/mouse latency, audio listening, gamepad, cross-machine replay and your verdict on the new scoring and moves remain unverified. [Detailed results and retained failures](RESULTS.md) separate those limits from the scripted proofs.
