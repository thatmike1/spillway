# R14 delivered-pack screenshot-only discovery

Stopped after **54 play decisions, no finish**. The only named stage visibly earned was **Stop logs**, with the clean-run split **00:04.05**. No later stage message or finish appeared. Individual practice jumps clearly reached the top of the pad marked **4.0 m / 157 u**; the attempt across that gap hit the far platform face. Final state was Stop logs practice, grounded against that face. No clean or practice finish is claimed.

## Identity and isolation

- Actual outer delivery: `delivery/spillway-r14/spillway-2026.11.08-r14-linux-x86_64-65d205be.zip`, source identifier **65d205be** supplied with the task. ZIP SHA-256: `9e96522880918c28fc04f82df0fa2587eb1fcefc4467010407bb8d4b01785a80`.
- The extracted `SpillwayR14.pck` was hashed before launch and matched **fc77461baa5387549ce7ec2b5c2796d656b83aaf2a8fd1e8674d614a7b0b0067**. No delivery files were changed.
- **Editor-hosted packed play**, not release-runtime acceptance: pinned Godot 4.7.2 editor, `--main-pack` plus external SceneTree screenshot adapter, launched with cwd in RAM outside the checkout. Engine SHA-256: `8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e`. No loose source fallback or export.
- Read only the permitted driving helpers. No map, motor, gameplay source, old discovery report, tape, diagram, evaluator, hidden pose/view/velocity/progress or test count was read. Scene loading uses the pack's configured main scene. Adapter responses contain only JPEG path and input ID. Inputs were selected from screenshots and the inputs already chosen in this run.
- Default F2 remained active throughout. Normal spawn at start and both R restarts. No menu, preset, click, stage picker, teleport, player/camera state write, coordinate controller or OS input. Mouse deltas are ordinary parsed look events.
- 54 decisions of the 80 bound; **1,136 requested input frames**, maximum batch 90. Approach batches in the later manual sequence were 3–8 frames near lips. Four 90-frame batches replayed previously observed run-up/straight sections (22, 24, 29, 31); they meet the cap but give poorer intermediate visibility than the smaller discovery batches. No later claim depends on unseen intermediate landing certainty. Screenshots are rendered at 1280×720, fixed 30 rendered frames/s; the game's visible header says 128 Hz.
- Two R restarts (21, 28), three F uses (11, 16, 34). No automatic respawn was observed. No explicit actor Esc input; the helper uses ordinary Esc to pause/resume between observations. Visible movement, timer progression, R and F responses verified basic operation; no menu-stuck failed play action occurred. This does not certify that pauses have zero effect on engine/input timing.

## What the new runner could read

The initial route is obvious: a straight corridor of concrete tops, red takeoff bands, yellow hazard lips, and gap lengths in metres and units. The on-screen instruction to run in before jumping was sufficient to start. Holding Space after a 250 u/s run-up produced several successive hops and the Stop logs split. The practice banner clearly distinguishes F exploration, and R visibly clears it.

The first sticking point was maintaining a valid takeoff/landing rhythm as the straight gaps widened. A level camera view shows the next platform and its text, but makes remaining pad length and a top landing hard to judge. I initially treated ground HUD text as proof of a top landing; it can also describe being on the lower channel floor. Decisions 26 and 32 are therefore **uncertain top landings**, not progress evidence. Looking down made the hazard lip and top surfaces much easier to distinguish.

The red region tells me where to prepare, but jumping from its near edge was too early in practice. A new runner can follow the correct route yet hit a far face without knowing whether to move takeoff later or build more speed. A/D sync reached 95–100% in my turn tests while speed gains were only about 3–6 u/s. That is useful directional feedback, but it did not establish sufficient speed for the gap. I did not mistake it for efficiency in the final assessment.

Curved red bands and alternating smaller platforms were visible beyond the 4.0 m section. They suggest the next route changes direction, but I never earned or landed in that section and cannot assess its navigation or the finish cues. The initial hint about stage 3's long runway did not help with the immediate missed landing.

## Failures and collision interpretation

- Startup attempt 00 ended on stdin EOF after its initial screenshot, **zero play decisions**. It was fully shut down and retained under `startup-00/`. The successful interactive launch is the run below. No failure is discarded.
- Decisions 08–10: the continuous Space chain approached a face low, lost all 250 u/s, and ended on the lower ground facing concrete. The exact preceding top landing is uncertain.
- Decisions 14–15: jumping early in the red practice band with small left/right turns ended below a face. HUD reported contact loss. This was a mistimed takeoff attempt.
- Decisions 18–20: the alternate strafe practice chain gained little speed and again hit a face. This is not evidence that same-direction mouse strafing is broken.
- Decisions 26–27 and 32–33: attempts to delay the next jump walked into an airborne state without a takeoff sample or ended against a face. These were input/timing errors; intended top landings remain uncertain.
- Decisions 51–54: the clearly observed 4.0 m attempt started at 250 u/s, was still airborne above the gap at 52, then lost speed at the far lip and fell against the face. Final HUD: last hop -250 u/s, air +870/contact -1120, wall 30 ticks. W was pressed again during descent, so repeated pushing into the face contaminates those large split values. They are visible HUD observations, not a motor diagnosis.

**No reproducible collision defect established.** There were several repeatable face-contact failure patterns, but I did not reproduce a contact with an independently verified valid trajectory. The best-supported explanation is insufficient speed or early takeoff. This run does not establish route completion, finish behavior, later-stage readability, record persistence, or release-runtime behavior.

## Exact play journal

`inputs.jsonl` in the evidence directory is the lossless adapter journal. Each row below is one counted decision. Keys stay held for the listed batch; empty keys releases movement/Space. Mouse values are total relative deltas spread over that batch. F/R are ordinary key taps.

| ID | Held keys; tap; mouse | Frames | Screenshot observation and reason for next action |
|---|---|---:|---|
| 01 | w | 45 | run up from normal spawn; visible forward movement and 250 u/s confirm pause/resume |
| 02 | w | 60 | reach opening red band at 250 u/s; choose first jump |
| 03 | space | 20 | coast with Space; next distance band visible; landing not yet confirmed |
| 04 | space | 30 | Stop logs split 00:04.05; last hop zero loss; continue straight |
| 05 | space | 30 | 3.5 m label visible ahead; continue the established line |
| 06 | space | 30 | 4.0 m label visible ahead; still 250 u/s airborne |
| 07 | space | 30 | curved red band and offset pads visible farther ahead; still airborne |
| 08 | space | 20 | approach a platform face at low eye height; landing uncertain |
| 09 | space | 20 | speed drops to zero while airborne; likely far-face contact |
| 10 | none | 45 | on ground facing a wall; HUD contact -250, wall 1 tick; first failed run |
| 11 | none; tap f | 1 | F use 1: explicit practice from earned Stop logs; reset to its first red pad |
| 12 | w | 15 | run toward first practice pad; 238 u/s |
| 13 | w | 8 | continue closer to lip; 250 u/s |
| 14 | space+a; mouse [-30.0, 0.0] | 16 | A plus left mouse test: 100% directional sync, only +3 u/s |
| 15 | space+d; mouse [90.0, 0.0] | 16 | D plus right mouse; now below a face, last hop contact -218; failed early takeoff |
| 16 | none; tap f | 1 | F use 2: repeat Stop logs practice |
| 17 | w | 32 | longer run-up; 250 u/s, band near bottom of level view |
| 18 | space+a; mouse [-100.0, 0.0] | 16 | A/left turn at takeoff; 254 u/s airborne |
| 19 | space+d; mouse [100.0, 0.0] | 16 | D/right turn; 257 u/s and last hop +6; intermediate landing occurred |
| 20 | space+a; mouse [-200.0, 0.0] | 20 | A/left turn continuation ends at a face, 184 u/s; failed practice chain |
| 21 | none; tap r | 1 | R restart 1: normal spawn, zero timer, practice banner gone |
| 22 | w | 90 | repeat normal run-up over known safe ground to opening band |
| 23 | w | 15 | smaller approach to first lip; 250 u/s |
| 24 | space | 90 | repeat known straight Space chain; Stop logs split visible; 3.5 m band nearby |
| 25 | none | 12 | release Space to avoid the next automatic takeoff; airborne, landing uncertain |
| 26 | w | 10 | W to retain run after landing; HUD says ground, intended top landing uncertain |
| 27 | w | 15 | continued W ends low against face without a takeoff sample; walked off or was on lower floor |
| 28 | none; tap r | 1 | R restart 2: normal spawn, zero timer, practice banner gone |
| 29 | w | 90 | repeat known normal run-up |
| 30 | w | 15 | smaller approach to opening lip |
| 31 | space | 90 | repeat known Space chain to the 3.5 m area |
| 32 | w | 22 | release Space and hold W through expected landing; ground HUD, top landing uncertain |
| 33 | w; mouse [0.0, 150.0] | 3 | three more W frames and downward mouse look; airborne without takeoff sample, 231 u/s; failed delay |
| 34 | none; tap f; mouse [0.0, 700.0] | 1 | F use 3: explicit Stop logs practice; look down to expose pad tops and lips |
| 35 | w | 32 | run toward first red pad; ground, 250 u/s |
| 36 | w | 5 | five-frame lip approach; hazard stripe now low in the image |
| 37 | space | 15 | jump 2.0 m gap, release W; next 2.5 m band beneath view, still airborne |
| 38 | none | 10 | release Space before landing; visible top landing on 2.5 m takeoff pad, 205 u/s |
| 39 | w | 6 | six W frames toward next lip; 213 u/s |
| 40 | space | 15 | jump 2.5 m gap; next 3.0 m platform top visible, 226 u/s |
| 41 | w | 10 | W as landing approaches; visible top landing on 3.0 m pad, 232 u/s |
| 42 | w | 7 | run closer to red band, reach 250 u/s |
| 43 | w | 5 | five-frame lip approach; choose jump from lower hazard stripe |
| 44 | space | 15 | jump 3.0 m gap; next 3.5 m pad top below view, airborne at 250 u/s |
| 45 | w | 10 | W on landing; clear top landing on 3.5 m pad, 250 u/s |
| 46 | w | 8 | eight-frame run across that pad toward stripe |
| 47 | w | 3 | three-frame lip approach; 231 u/s shown, still grounded; choose jump |
| 48 | space | 15 | jump 3.5 m gap; next 4.0 m pad visible below view, airborne at 250 u/s |
| 49 | w | 10 | W on landing; clear top landing on 4.0 m pad, 250 u/s |
| 50 | w | 8 | eight-frame run toward its red band |
| 51 | w | 4 | four-frame lip approach; 250 u/s; jump before walking off |
| 52 | space | 15 | jump 4.0 m gap; next curved 2.5 m band visible on far platform; landing unconfirmed |
| 53 | w | 10 | speed 83 u/s and -250 since takeoff beside front lip; failed far-face landing |
| 54 | w | 7 | seven more W frames ends grounded against face at zero; last hop -250, air +870/contact -1120, wall 30 ticks; stop in practice |

## Evidence and cleanup

Evidence: `/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/discovery-delivered/`. Selected JPEGs, full inputs, identity, rendering/GPU receipt, startup failure receipt and journal; no PNGs or movies. Selection includes every failed attempt's end and the manual landing sequence. Unselected intermediate JPEGs were deleted with RAM scratch, but every action remains in the input journal.

Both launches used NativeDisplay's explicitly checked free **:190**, private AMD/X11 through headless Weston and Xwayland. Godot reported AMD Radeon Graphics (radeonsi, renoir), Compatibility/OpenGL; GPU receipt passed. HOME free before the interactive launch: **16,184,393,728 bytes (15.07 GiB)**. Scratch, extracted pack, external adapter copy, profile and all caches stayed in RAM. `--no-records` was set.

Game exited through ordinary helper quit; both NativeDisplay cleanup receipts say clean, no owned process/session members left, no private X files/listeners left, runtime removed. Both RAM scratch paths were confirmed absent. Desktop **:0** answered before and after both launches with the same X.Org identity and 1920×1080 dimensions. No desktop input was sent. Test adapters and this report are the only new checkout files; no production edit, commit or export.
