# Independent review of the original CARRY air challenger

**Two P2 issues deserve small fixes: a stale view-turn bank survives W changes, and sub-run-speed side input can brake or reverse travel despite the advertised neutral bend.** Neither establishes a reason to return to broad. The challenger is a defensible next playable policy after resolving those inconsistencies. This review does not promote the concurrent course or establish enjoyment.

Reviewed committed `f3e33ebf7e6bae17bace8d141bca9ff293305eb0`, with fixed base `fd38b1e9`, independently of the live course and product/HUD workers. Read AGENTS.md, BRIEF.md, BUILD.md, CARRY.md, AIR-CANDIDATE.md and the previous FLOW/controller and CARRY/contact reviews. No production file, existing test, existing document or course geometry was edited. No commits or children.

Evidence prefix **E** throughout:

`/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r13/air-review-sol/`

## 1. P2: “synchronized” gain can spend mouse history seconds later

Location: `scripts/momentum_carry_air_candidate.gd:75–87,106–114`.

The bank resets when the **side sign** changes. Pressing or releasing W while A stays down changes the steering wish but retains the bank. There is no age limit. This contradicts the document's broader “reset on a key change” description and permits a turn from a different steering phase to pay the new phase.

Minimal seeded characterization, using the committed tape executor:

- One initial placement at `(0,180,0)`, yaw 0, horizontal velocity of 13 m/s at heading **2 radians left**. No later state writes.
- Tick 0: press A and deliver relative mouse `[-136.363636,0]`, a 0.3 rad left look. The flight initially turns right toward the A wish, so the positive bank is not spent.
- Tick 360: press W while A stays held. Tick 420: release W. No further mouse events.
- At tick 419 the bank is still approximately **0.299995 rad**. Releasing W makes the flight turn left; it then receives **0.216918 m/s** of carve from the **3.5-second-old** mouse event.

Actual final horizontal travel is **13.2168 m/s**, against **13.0002 m/s** in the matched no-history control. Their endpoints differ by about **0.135 m**. The control starts with the same final view yaw 0.3 and uses the same A/W edges, but has no mouse event or bank. Waiting 30, 120 or 360 ticks before W produces approximately the same payout. This is observed displacement, not just `carve_total`.

Evidence: `runs/stale-bank-{30,120,360}/`, matched `nohistory-*`, and the final exported replays. These are long-fall **seeded fixtures**, not evidence that an ordinary Overflow line requires or exploits this maneuver. The bank remains bounded at 0.6 rad; this is a stale synchronization issue, not unbounded energy.

Resolve the intended lifetime and which changes end a carve. Clearing or rebasing on a changed steering wish and bounding history age are candidates for root; preserve the measured cadence tolerance when doing so. A side-key-only reset can instead be an explicit mechanic, but it must stop being described as synchronous key/view turning without this qualification.

## 2. P2: the 8.5 m/s floor changes A from neutral to opposing force

Location: `scripts/momentum_carry_air_candidate.gd:94–96`.

Below the floor, `air_low_push` adds a vector toward the wish **before** the speed-neutral rotation. When that wish opposes current travel, it removes speed. Above the floor, that force disappears abruptly. The limit prevents exceeding the floor; it does not prevent braking.

Minimal tape: press A at tick 0, release at 96, observe through tick 119. Initial yaw 0; one seeded horizontal velocity pointing right, heading `-PI/2`. No mouse, S, contact or subsequent state writes.

| Initial rightward speed | Actual speed after 0.8 s of A, then 0.2 s coasting | Observed direction |
| --- | --- | --- |
| 8.49 m/s | **3.68998 m/s** | still right |
| 8.51 m/s | **8.51006 m/s** | still right |
| 3.00 m/s | **1.80000 m/s** | reversed left |

The first two travel approximately **6.2975 m** and **9.2192 m** rightward including warmup, respectively. At 3 m/s the runner really passes through near-zero speed and reverses. The ledger correctly attributes the change to `air_low_push`; reporting is not hiding it.

The candidate newly applies this low push to side-only input. Original broad/narrow's W low push already has the opposing-force behavior, so the W-behind repro is an **inherited** concern, not a second independent regression. The candidate's A extension and the sharp floor boundary are the new problem. W+A at an oblique view also exercises the low-push regime; it retains lateral intent but does not obey a universal speed-neutral claim below run speed.

These are deliberately hostile **seeded** orientations. They do not prove a common route failure. They do refute the unqualified “keys bend and never brake” description, precisely where a poor landing or brake can put a player. Choose and document a coherent low-speed reversal policy, or make the low-speed push respect the intended non-braking rule. Do not conflate this floor discontinuity with the benign carve-gain ceiling.

Evidence: `low-speed-summary.json`, `runs/low-*`, and `final-repro-summary.json`.

## Cadence and causal phases

Physics stayed at **120 Hz**. The independent matrix has 126 seeded episodes: candidate/broad/narrow, entry 13/20 m/s, the same 1 rad smooth mouse stroke over 0.8 s, **120/60/30 mouse events/s in every polling phase**, with A pressed/released three ticks early, on time or three ticks late. Mouse events integrate motion since the previous poll; key edges stay fixed when cadence changes. Tapes contain real relative mouse and key edges, delivered by the existing counter-verified executor.

For identical on-time key edges:

| Entry / policy | Actual speed change across all event rates/phases | Heading spread | Endpoint spread |
| --- | --- | --- | --- |
| 13, candidate | +0.31860 to +0.32866 m/s | 0.138° | 0.0238 m |
| 13, broad | −1.01562 to −0.97019 | 0.063° | 0.0340 m |
| 13, narrow | +0.42493 to +0.67876 | 0.771° | 0.3050 m |
| 20, candidate | approximately zero, within 0.00014 m/s | 0.104° | 0.0218 m |
| 20, broad | −1.11379 to −1.06975 | 0.051° | 0.0340 m |
| 20, narrow | +0.24635 to +0.62835 | 0.772° | 0.4918 m |

Changing key timing as well widens the candidate's gain range to **0.30979–0.33508** at 13 m/s and heading range to **27.87–28.51°**. That includes an actual change in the held-key interval; it is not pure cadence error. The candidate's narrow cadence spread is supported here. It does not mean every line is cadence invariant, nor does it test device polling, OS delivery, latency or GPU pacing.

Evidence: `cadence-summary.json` and `tapes/cadence-*`.

## Frozen Overflow and the original holdouts

The comparison used the original committed block, never the live course revision. Geometry hashes reported by the actual built levels:

| World | SHA-256 |
| --- | --- |
| block | `a6030e6e46091098696fd5cd088b914145cf18f5163abd08705dfc062a7c55d3` |
| mirrored block | `a203695fea97e30145e38d587ebe8a0bc72c9aaa0b85c8fa764826124fed3457` |
| offset block | `bc84378864a318329c25649dc669d4815c3f08413650f845b174cc73f498a13e` |

The dedicated review factory changes only player selection and presentation to neutral materials. The original driver was extended in the new review test to select `player_script`; its control algorithm and route nodes are inherited unchanged. Driver runs are explicitly **closed-loop execution proofs**, not ordinary play. Their recorded events are then replayed open loop through the existing executor. Mirroring flips mouse x and A/D; the offset holdout receives the unchanged neutral tape, without offset-aware correction.

**108 matched block replays** cover the broad-recorded ordinary and miss tapes plus two independently authored imperfect tapes. A further **36 matched replays** use an independently authored approximate ordinary line: early jump at tick 380 rather than the driver's 384, a sustained side correction, eight ticks of A/D overlap, a broad timed 90° hand stroke, then a delayed W release/S press. Its timings were fixed before candidate results and use no candidate recovery coordinates. It is not closed-loop steering.

All three policies finish that ordinary tape in all four mouse schedules on all three layouts. Completion alone conceals the differences. On the neutral block at 120 events/s:

| Policy | Position at tick 500, x / z | Position at tick 900, x / z | Travel heading at 900 | Final x / z after braking |
| --- | --- | --- | --- | --- |
| candidate | 1.297 / −37.738 | −20.500 / −52.439 | 90.0° | −40.597 / −52.439 |
| broad | 1.405 / −37.751 | −20.362 / −52.534 | 90.0° | −40.489 / −52.534 |
| narrow | 1.230 / −37.693 | −20.503 / −52.186 | 90.0° | −40.499 / −52.186 |

Candidate/broad/narrow first finish at ticks **994/995/994**. These differences are small and do not establish candidate superiority. The candidate's maximum final-position spread across mouse schedules is **0.241 m** on neutral, **0.242 m** mirrored and **0.583 m** on the offset holdout. Broad's offset spread is **0.726 m**, narrow's **0.688 m**. All have zero respawns. `slices.json` and `spread.json` retain the other endpoints, moving headings and schedules. A stopped final vector has no useful heading and is not treated as a turn result.

The W-only recorded ordinary line also finishes every layout/schedule in every policy, with identical policy paths at each schedule. That is inherited usable placement, not a new challenger advantage.

**Poor approaches and recovery remain weaker.** The earlier independent rough tape jumps too early and cuts toward the bay; it fails to finish for every policy. Another independent no-jump/right-turn attempt hits the runout guard, misses the slot and stalls against the landing face. These failures are retained, not tuned away. The broad-authored miss tape physically uses the bay and return ramp and finishes neutral with broad/narrow, but the candidate falls back off the deck and stops near `(-19.70,1.50,-46.70)`. On the mirrored and offset holdouts that same tape fails for all three. This reverses the candidate author's recovery advantage without creating a valid fairness verdict in the opposite direction.

The original closed-loop miss route finds a physical candidate recovery on the **mirrored** block (finish tick 1641, no respawn), but fails neutral and offset within its budget. Actual walkability and a perfect state-aware route are therefore insufficient evidence for forgiving recovery. Root's concurrent course revision still needs its own ordinary, off-line recovery acceptance. I did not retune its geometry.

## Earned speed, contacts and disproved suspicions

The separate input-earned 12 m descent reaches approximately **21.35 m/s** before launch. An imperfect mouse/side/overlap sequence launches at **20.69 m/s**, misses the narrow offset target and reaches the catch floor without a state write. Thirty ticks of S lower takeoff from **20.57 to 12.57 m/s** and reduce final forward travel by about **23 m**. Steering authority does not guarantee the poor approach reaches the intended deck. These are adversarial fixture episodes, not Overflow route claims.

The real side-wall variant records actual wall, target and return contacts. The candidate loses obstructed motion and later moves along the wall; it does not report a preserved airborne speed that the body fails to travel. A landing/contact tick can have different next-command and just-travelled velocities; those are not interchangeable measurements. The motion report's entire actual-velocity vector matches independent finite differences in every audited tick.

At 13/20 m/s, W+A and S+A retain lateral intent. S slows forward travel without reversing it. W+S cancels forward input and therefore cancels braking, identically in all controls; W+A+D leaves W. No unexpected overspeed reversal was demonstrated. The below-floor exception is finding 2.

A released-input glance, including a prior side-key hold, preserves the flight line. The earned straight/glance trajectories also agree to floating-point noise despite looking 0.9 rad away and back while W is released. A W-held glance is deliberately a steering command and was never counted as free look.

Pause/reset bookkeeping was **source-audited, not exercised as an Esc/R lifecycle tape**. Reset clears the bank, side, air tick and previous view; disabled input rejects mouse motion, and the candidate updates previous view after the shared motor returns. I found no independent stale-yaw payout path there. This bounded negative finding does not replace product pause/restart testing. The old full contact/departure suites were not rerun.

## Design tradeoffs, separately from defects

- **The 16 m/s carve ceiling is intentional and benign.** At earned 20 m/s this policy still bends but pays no extra air gain. Height and approach remain valuable; a player seeking endless CS-style acceleration receives less reward. That is a game choice, not a failed ceiling test.
- **Alternating side-key/mouse weaving can still farm bounded speed.** From rest on a flat fixture: W for 120 ticks, release W, hold Space, then swap A/D every 48 ticks while the mouse sweeps +0.3/−0.3 rad. Candidate reaches **15.54 m/s** after 21 s, broad **8.15**, narrow **18.72**. Candidate's carved gain totals about 7.04 m/s. This uses no downhill energy and needs no purposeful course turn. The view oscillates rather than turning continuously; this particular 49-half-stroke tape ends 0.3 rad away and drifts sideways, so it is not an exact zero-net-heading or corridor exploit. A matched seeded long fall also rises 10 → 15.65. The gain is real but bounded. Decide whether oscillatory technique is welcome; the author's single-held-D wiggle check does not exclude it.
- Fixed-view A has more useful lateral authority than narrow, with no above-floor speed gain. It can also spend landing clearance faster. This review's ordinary/offset line remains playable with a held correction; an arbitrary poor approach is not rescued automatically.

## Bias audit of the candidate evidence

The 42 gates are useful policy characterizations, not independent selection criteria. Most air claims use seeded 10–13 m/s flights, ample height and no real wall. Fixed-view lateral distance and the cadence threshold are chosen around the proposed policy; rejection by narrow/broad shows discrimination, not that the thresholds make a better game. The sub-floor boundary and W-preserved bank were not covered. The fixed-key wiggle and unsynced diagnostic do not exclude alternating-key banking.

The candidate documentation correctly discloses non-discriminating W/no-input/S checks and that W placement inside 45° is inherited. Its poor-landing tape was tuned against the candidate. Broad's pre-fix **0/5** is not evidence of unfair or unrecoverable broad movement. The 105 pre-fix tape runs also cannot substitute for post-fix native comparison or holdout testing. This review keeps old-base diagnostics, frozen fixed-base runs, and native evidence separate.

## Native evidence and provenance

Native captures use **private Xvfb :162**, Dummy audio, isolated XDG directories, Godot movie writer at 30 fps and 120 Hz physics. No desktop or speaker interaction. The neutral flat-colour decks are overbright in these captures; this limits landing-edge contrast and is not an evaluation of the live material/product work. I read the recorded contact sheets and selected full frames. This is software-rendered evidence, with no performance, latency, real mouse, Windows or enjoyment claim.

- `native/independent-ordinary-human-{candidate,broad}/`: approach, early hop, side hold/overlap, pier turn, descent, braking and finish. Both native position traces match the corresponding headless traces **exactly**. Candidate finishes tick 994, broad 995. Review subtitle names the actual policy.
- `native/block-broad-authored-miss-{candidate,broad}/`: matched poor approach, real bay contact, return and diverging recovery. Both match headless positions exactly. Broad finishes; candidate returns briefly and falls back. The inherited subtitle in this first pair says broad even for the candidate; `run.json`, source/player selection and motion-state policy identify it correctly. The later ordinary captures fix this review-only label.
- `native/candidate-own-closed-loop-recovery-replay/`: retained attempted replay of the candidate's neutral closed-loop miss route; it does not finish. Its name is not a success claim.
- `native/physics-diagnostic-earned-rail-downlook-{fixed,old}/`: earned downhill rail departures, with one ordinary downward mouse look to expose the support and visual checkers for motion landmarks. Old base `280be87c…306a` exists only in `diagnostic-old-body/`. This is a **physics diagnostic, not course evidence**. This executor/warmup reproduction fires hops at 300/388/476 under both bodies and does **not** reproduce the previous stale-floor duplicate. The fixed and old paths agree here. That negative comparison cannot replace or refute root's already established reduced/earned regression. Earlier rail captures without the downward view are retained but visually poor.

`source-before.json` hashes the committed archive before review. `source-after.json` verifies those original files afterward. The fixed base motor remains SHA-256 `1c3a4f9d4687c62c53fc4ec10efbbf09cf31fc43ba34d3cc7850ff13011276b9`; runtime SHA-256 is `8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e`. No Git worktree was created. Per-run `run.json` retains source/helper/runtime manifests and copied source.

Reviewer fixtures evolved separately: v1 had an incorrectly signed diagnostic ramp; its 30 earned/wall trials are retained under `invalid-ramp-v1/` and excluded. v2 corrected it; v3 added neutral block selection/late progress observation; v4 used the original exact Basis construction and corrected review subtitles; v5 added visual checkers only. Copies and hashes are retained under `sources/` and `fixture-revisions.json`. Early batches did not individually snapshot the reviewer fixture, though the committed source was frozen; final exported repros and native runs retain the exact fixture and before/after hashes. Drop/flat physics was unchanged across those revisions. The `.godot` material/import cache was copied from the live project and refreshed once; it is explicitly **unhashed**, not a claimed source dependency proof.

`audit.json` records delivery/order/vector checks; `native-comparison.json` records native equality; `evidence-sha256.json` indexes retained evidence. The final completed audit covers **412 physical episodes and 272,446 counter-verified ticks**, with zero delivery, ordering or integrity violations, exact reported/measured actual vectors, and maximum ledger residual **5.96e-8**. Expected contact stops remain visible. This includes the five final exported minimal replays; they are repeatability checks, not extra acceptance gates.

## Reproduce the two findings

The new test exports minimal tapes without defining another input injector. From this frozen project or the corresponding source checkout, use the pinned runtime and an absolute scratch/evidence directory:

```sh
G=/home/thatmike1/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64
E=/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r13/air-review-sol
"$G" --headless --audio-driver Dummy --path "$E/frozen" \
  --script res://tests/test_carry_air_review.gd -- --export-review-tapes=/tmp/air-review-tapes
python3 "$E/frozen/tools/momentum-tape.py" run /tmp/air-review-tapes/stale-bank.json \
  --out /tmp/air-review-stale --headless --game-script res://tests/carry_air_review_fixture.gd \
  --game-class '' --motor candidate:drop:13:2
python3 "$E/frozen/tools/momentum-tape.py" run /tmp/air-review-tapes/opposed-a-8.49.json \
  --out /tmp/air-review-low --headless --game-script res://tests/carry_air_review_fixture.gd \
  --game-class '' --motor candidate:drop:8.49:-1.570796326794897
```

Each output directory must be fresh. `no-history.json` uses motor `candidate:drop:13:2:0.3`; `opposed-a-8.51.json` uses `candidate:drop:8.51:-1.570796326794897`. Read `post.disp_v` in `evaluator/trace.jsonl`; the seed/custom-game hook is labelled `normal_spawn` by the generic wrapper, which is **not applicable to these seeded reviewer fixtures**. `fixture_motor`, factory logs and the source make the setup explicit. The JSON tape does not write a trajectory.

Root should resolve the two P2 semantics, preserve the cadence and imperfect-line evidence when doing so, and verify the revised actual course's off-line recovery separately. No new engine/contact blocker was found. Final player enjoyment remains Mike's judgment.
