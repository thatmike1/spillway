# R14 closure review

**Verdict: nothing in the runtime blocks promoting the exact `5484f10d` pack.** Four process items still block *closing* R14: the content/runtime/cancel negatives must finish green, the Sol verifier review must come back, the ZIPs must be promoted to `delivery/spillway-r14/` with the outer `REPORT.md` replaced, and the 20:00 Prague minimum must pass. Feel stays unverified and is Mike's call. Nothing below approves it.

Read-only review, 8 Nov 2026, about 18:05 UTC. Source HEAD `6d4c2de8`, runtime/export `5484f10d`. From the export to HEAD, no file under `scripts/`, `scenes/`, `assets/` or `project.godot` changed (7 files: docs, tests, discovery tools, decisions). `origin/feat/foldrunner-me-build` equals HEAD. All 48 commits dated 8 Nov carry a conventional prefix and the `(ccChat-general-rowb)` suffix. Compact evidence: outer `checkpoints/spillway/r14/closure-review/evidence.json`. This review ran no native operation, changed no source and touched no active evidence or process.

## What was checked directly

- `sha256sum -c SHA256SUMS` passes for both ZIPs. The hashes equal those in RESULTS.md. `VERIFICATION.json` holds 204 checks with 0 failures, `ok: true`, and states "Windows static only".
- ZIP listings: Linux has runtime, pack, README, BUILD and licences only. Windows adds `SpillwayR14.console.exe`, which its README explains. Both READMEs name every preset, the launch and the records path.
- Motor source (`scripts/r14_source_motion.gd`) against the public Source2013 rules:
  - ground `Accelerate` uses the uncapped wishspeed budget
  - `Friction` uses `max(speed, stopspeed)`
  - `AirAccelerate` caps the projection at 30 u while the budget uses the uncapped wishspeed
  - jump runs before friction, with a half gravity step on each side
  - the CS:GO cvars are accel 5.5, friction 5.2, stopspeed 80, gravity 800, jump 301.993377, 1 u = 0.0254 m
  - the vanilla jump clamp is 1.1 × 250 = 275

  All match the SDK flow cited in SOURCE-REFERENCE.md.
- Independent recomputation: the optimal tick from 250 u/s is `sqrt(250²+30²)` = 251.793566. The five-hop maximum at 96 air updates per hop is `sqrt(250² + 5·96·900)` = 703.206940. Both equal the documented figures.
- The packed advanced route's HUD reports 251→367 (95 ticks, sync 75/82) and 728→784 (95 ticks, sync 90/94). The per-hop bound `sqrt(v²+95·900)` is 385.4 and 784.5, so the route never exceeds the Source maximum. The packed trace equals the source trace with 0.0 m position difference over 3,814 ticks.
- Frames viewed: controls 001/004/006/013/021, advanced play 030/050, Overflow F1 finish and reload pause. They show:
  - the preset header on every frame
  - an F4 header that reads "not Quake"
  - the stage picker
  - a "practice (preset switched mid-run)" banner after a cross-family switch
  - the F1 Overflow finish with splits and "First clean run with this preset"
  - the reload restoring "Best 00:46.52, records loaded"
- Negatives log at 18:04 UTC: 21/21 delivery content controls PASS. The runtime and cancel variants were still importing. STATE.md records an earlier run killed by SIGTERM 143 at repack, cause unresolved.

## Requirement by requirement

| Requirement | Status | Weakness or missing evidence |
| --- | --- | --- |
| Original Source ground accel, friction/stopspeed, 30 u air cap with uncapped budget, gravity 800, CS:GO jump, written unit conversion | **Met.** Independent implementation matches the public rules. | Based on the Source2013 SDK, not CS:GO's source. Rising-air surface friction 0.25 ("deadstrafe") is on for F1 and F2. At AA 100 it cannot bind an optimal strafe (budget 48.8 > 30), but at AA 12 it does. |
| Checked against known CS numbers, not only internal targets | **Met with a disclosed limit.** The oracle is separate from the motor, and the inputs come from GOKZ, shavit, MovementAPI and zer0k-z. | The gain and N-hop figures are **derived from public rules, not measured** on a CS:GO server. The exact vanilla N-hop maximum is unresolved (the oracle returns null). The docs say so. |
| A/D with a matching mouse turn builds and keeps speed; no input coasts | **Met in the real game, with scripted input.** The packed advanced route earns 250→1,100 u/s. The native tour gains on every F2 hop. Releasing all keys gives 0.000000 u/s drift in the motor fixture. Discovery saw F2 and F3 coast. | F1 tapping in the tour gains in the air but falls from 250 to 161 overall, because of the reconstructed landing stamina and friction. That is plausible for CS:GO matchmaking but unverified. Discovery saw an unexplained F1 drop to 59 u/s. Likely causes are ground friction after W was released, plus AA 12's 46.9 u/s per-tick budget against the velocity, but this is not established. |
| F1 vanilla AA 12, F2 AA 100 autohop with no stamina, F3 unchanged R13, live switching, active preset on the HUD; F4/F5 optional | **Met.** Every frame shows the active preset, and live switches appear in the controls run. | F3 is exact against the current R14 reference, but differs from the retained R13 product by up to 1.697 cm in position (velocity, view and finish are equal). The cause is unexplained and disclosed. F1's stamina and clamps are labelled reconstructions. |
| Strafe HUD with speed, hop gain and sync | **Met.** Speed, last-hop gain split into air, contact and ground, live and per-hop sync. | The sync shown is directional sync. A tick counts only when one of A/D is held **and** the view turned. Holding a key without turning is not counted. This is close to shavit's CalcSync but not identical, and is disclosed. |
| Original practice map with blocks, corners, speed gaps and a long straight | **Met.** Penstock Yard has stop logs, two bends, weir gauges (an outside gap of 6.4 m needs about 360 u/s), and a 128 m runway. It is original. | Clean packed routes exist only for F1, F2 and F3. F4 and F5 on Penstock are unproven. The vanilla advanced line is impossible by design. The pump-bend notch line is unproven. Two inward-angle return stalls are known. Discovery never finished the map: four opening gaps, two attempts. |
| Overflow playable under every preset | **Met.** All five preset routes finish clean in the pack, with zero respawns, an exact source match, and records saved and restored. | These are authored execution proofs, not evidence that the routes are easy for a human to find. |
| Portable Linux and Windows ZIPs in `delivery/spillway-r14/` | **Not yet.** The candidate is complete and verified in `delivery/work/r14-candidate-5484f10d/`. | Not promoted. Windows is static acceptance only. When promoting, put `VERIFICATION.json` beside the ZIPs, because the README tells players to look for it there. |
| Honest scripted and native evidence outside the source checkout | **Met.** Every run happens from a temporary copy or the extracted ZIP, on private AMD/X11 hardware. | The negatives are still in progress, and the earlier SIGTERM 143 is unexplained. |
| Coherent pushed branch with the suffix | **Met.** | The final promotion and doc commits are still to come. |
| REPORT.md with player instructions | **Not yet.** REPORT-DRAFT.md is accurate and readable. | Outer `REPORT.md` is still the R13 report. |
| Work until 20:00 Prague | **Not yet** at review time (19:05 Prague). | Root is still active. |

## Must-fixes

**Runtime:** none found. No source change is justified by this review.

**Process, all required before closure:**

1. The negatives log must finish with zero failures. If the SIGTERM 143 recurs, it must be explained, not rerun until it passes.
2. Reconcile the findings of the Sol verifier review.
3. Promote the exact bytes to `delivery/spillway-r14/`, with `SHA256SUMS`, `VERIFICATION.json` and evidence beside them. Then rerun `sha256sum -c` on the promoted copy.
4. Replace the outer `REPORT.md`, and change "pending" in REPORT-DRAFT.md and RESULTS.md to the actual state.

## Doc corrections (REPORT-DRAFT.md)

1. **F1 speed decay.** Tell Mike that F1 loses speed on any hop that is not jumped on the landing tick, and quote the tour figure (250→161 over six tapped hops, despite positive air gain per hop). Add that this comes from the reconstructed stamina model, so it may not match matchmaking. Without this, a decaying F1 reads as a broken preset.
2. **Sync definition.** Define "eligible": an air tick with exactly one of A/D held and a nonzero view turn. Holding D without turning does not count.
3. **Sensitivity.** Say that 2.5 turns less than half as fast per mouse count as R13 did, and that 5.73 matches R13. Mike will otherwise compare F2 at an unfamiliar turn rate.
4. **Red pads.** Change the hint to "jump near the pad's far (yellow) edge". Both discovery attempts hit a front face after jumping early from the broad pad.
5. **Optional.** Mention that rising-air surface friction (deadstrafe) is modelled on the Source presets and lowers gain at AA 12. Mention that no vanilla N-hop reference number exists. Note that F4 and F5 have no Penstock route proof.

Disclosures that are already adequate:

- the screenshot discovery that failed or did not finish, including the pause failure and the over-read of documentation
- that reference numbers are calculated, not binary measurements
- the vanilla reconstructions
- the 1.697 cm difference from R13
- the Wayland teardown hang. The game defaults to X11, so it should not affect Mike on Hyprland with XWayland. That is reasoned from the source, not run on his desktop.
- Windows, latency and feel are unverified

## Scope limits of this review

- No CS:GO binary, no native Windows run and no human play. Nothing here says the presets feel like CS:GO.
- No rerun of routes or verifiers. This review trusts the probe JSON for any frame it did not view, and it viewed 9 of the controls and route frames.
- The verifier's hardening and refusal logic is the Sol review's scope.
- The cause of the F1 59 u/s drop in discovery, and of the F3 1.697 cm difference, were not investigated.
