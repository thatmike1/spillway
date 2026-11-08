# R14 screenshot-only readability playtest

The new cues were usable for entering stage practice, learning A/D plus matching mouse turns, and traversing the first four opening gaps. Stage 3 was visited through the ordinary menu, not earned through the course. A separate clean F2 restart reached stage 1 Stop logs and landed on four blocks. There was no finish of either kind. This is source-mode discovery evidence, not pack acceptance or a verdict on CS feel.

## Identity and boundaries

- Both native launches reported prepared commit `5484f10d1c1ef009fd22de76651431db7e1e065e`.
- The default application main scene was instantiated without map or preset overrides. Screenshots identify Penstock Yard, F2 CS:GO bhop server, 128 Hz, AA 100. Final menu shows build `spillway-2026.11.08-r14`, record key `89e7fe14`, and records off.
- Root committed concurrently. Final HEAD was `e7dcd6e341aae6205872bd82d5affe67bd3f25a8`; a filename-only diff from the prepared commit showed only `tests/test_r14_delivery.py`. No production content was inspected for this comparison.
- Ordinary raw key, mouse-motion and menu-click events only. No player/camera/velocity writes, coordinate controllers, route tapes, evaluator steering or hidden player-state observations. The adapter reads the main-scene setting, input requests and framebuffer only.
- 58 numbered decisions total, conservatively including menu setup and final inspection: 6 in the failed first adapter session and 52 after repair. Of these, 44 were movement/observation batches and 14 carried explicit menu, restart or preset/practice events. No decision exceeded 90 rendered frames at fixed 30 fps. Two initial views and two process shutdowns are setup/inspection overhead.
- The existing visual-play helper was inspected before use. Its pose, velocity, yaw, pitch, motor, progress and timing reads were removed entirely from the dedicated adapter. Responses contain only an input identifier and JPEG path. HUD values below were read from screenshots.
- Protocol deviation: the documentation read included `PLAYABLE.md` lines 23–115 (Playing, Switching, Look settings and HUD definitions), exceeding the requested controls-only portion. No proof/results sections, movement/map source, prior discovery reports or route information were read. Switching semantics and HUD definitions therefore were not discovered solely from play. This limits a strict controls-only claim; steering itself used screenshots.

## What the cues communicated

The initial backed hint plainly said to release W, hold A or D and turn the mouse the same way, then release keys to coast. The preset header made the active family, rate and key obvious. F1 replaced the hold-Space instruction with a fresh-press instruction; F3 replaced the Source instruction with its own flight-bending description.

Esc exposed a discoverable stage picker with numbered names. Selecting `3 Penstock straight` and clicking `Practise here` produced an explicit practice banner and a zero-speed start facing the runway. The lower instruction explained building speed and the 16 m wall-mark spacing. The wall numbers and transverse yellow stripes made forward travel visible without coordinates. They were usable even though the course is visually repetitive.

At the default opening, the red pad, yellow lip and metres/u labels identified launch surfaces and increasing gap lengths. The broad red pad initially encouraged an early takeoff: the first attempt hit the next block's front face. Moving farther toward its yellow far edge made the following attempt work. The cue teaches where to prepare, but does not by itself guarantee that jumping anywhere on the red area succeeds. An explicit “jump near the yellow edge” instruction would have reduced that first timing mistake. This is a readability observation, not a requested production edit.

The grounded/airborne label and takeoff/landing/contact HUD distinguished apparent arrival from an actual landing. An input note before decision 36 mistakenly called the first block landed; the previous view still said airborne, and the next view disproved it. That mistake is retained in the journal rather than silently corrected. The lower contextual hint became faint during later practice resets; the top control backing remained readable while present.

## Observable movement comparison

These are brief input trials, not a controlled physics benchmark. Mouse counts were the same for the initial comparison, but F3's visible view turn was larger, so identical input counts are not identical view-angle tests.

| Preset | Screenshot observations on the straight |
| --- | --- |
| F2 default | W run showed 250 u/s. Matching A-left and D-right with W released showed 254, 261 and 267 u/s, then 281 u/s with a broader turn. Completed hops showed +9, +8 and +15 u/s; sync mostly 95–100%; contact ±0. |
| F1 | W run showed 250 u/s and the first left hop 255 u/s. Holding Space through landing left the player grounded at 193 u/s, with the completed hop +8 and contact ±0. A release and fresh press jumped again. That late jump showed 59 u/s and −116 since takeoff; this bounded test does not identify why. |
| F3 | W run showed 335 u/s. The comparable left/right batches showed 343 then 362 u/s, last hop +20 and contact ±0. Its camera/turn response was visibly stronger for the same mouse counts. |

F2's no-input airborne batch kept the heading and forward travel while the HUD stayed around 282 u/s. F3's equivalent batch kept traveling at roughly 364 u/s. This supports the visible “release keys to coast” instruction over those short intervals; it is not a long-flight precision measurement. F4 and F5 were not played. Satisfaction and whether this feels like Mike's intended CS:GO strafing remain Mike's verdict.

## Reached stages, events and failures

- Initial process: decisions 01–04 used Esc, selector, stage 3 selection and `Practise here`. Decisions 05–06 attempted an F2 run/hop. The engine-level SceneTree pause failed to freeze this scene between decisions: the clock advanced from 00:00.50 to 00:16.13. Exclude that movement sequence from physics conclusions. The process was stopped and its profile removed.
- Repaired process: decisions 07–10 repeated the ordinary stage-3 menu path. Decisions 11–16 played F2 there. Decision 17 sent F1 then F, returning visibly to Penstock straight in practice. Decisions 18–22 played F1. Decision 23 sent F3 then F, again visibly returning to the straight in practice. Decisions 24–27 played F3.
- Decision 28 sent F2 then R together. Spawn reset was visible, but a preset-switch practice toast remained, so cleanliness was treated as uncertain. Decision 29 was a short approach only. Decision 30 sent R separately after the preset had settled; timer reset to zero and no practice banner appeared.
- Decisions 31–37: first opening attempt. The 2.0 m / 79 u gap label was readable. Early takeoff led to first-block front-face contact; decision 36 showed 14 u/s and last-hop −222, air +126, contact −348, wall 10 ticks. Space at decision 37 produced an upward view but 0 horizontal speed, without forward input. This does not show a non-responsive jump or a geometry defect.
- Decision 38 sent the third R event and began the successful opening attempt. Decisions 39–43 approached later, jumped with A/D turns, then coasted. Decision 43 showed grounded, `Stop logs 00:04.08`, last hop +7 and contact ±0.
- Decisions 44–48 crossed the 2.5 m / 98 u gap and confirmed grounded on the second block, last hop +7, contact ±0. Decisions 49–52 crossed the 3.0 m / 118 u gap and confirmed grounded on the third, again +7/contact ±0. Decisions 53–56 crossed the 3.5 m / 138 u gap and confirmed grounded on the fourth, +11/contact ±0. The next visible gap was 4.0 m / 157 u; it was not attempted.
- Decision 57 was a final grounded coast. Decision 58 opened Esc for inspection. It showed `Practice Stop logs F`, selector `1 Stop logs`, records off and no clean finish yet. No F practice input occurred during this final clean attempt. No stage 2, 4, 5 or 6 was reached by traversal; stage 3 was menu practice only.

Explicit preset switches: F1 once (17), F3 once (23), F2 once (28). Explicit F practice: twice (17, 23). R: three times (28, 30, 38). Menu stage-practice launches: twice (04, 10). Explicit Esc menu opens: three (01, 07, 58). Stage-picker clicks: four selector/selection clicks and two practice-button clicks across the two setups. No auto-respawn was visibly observed. No clean or practice finish occurred.

For observation pauses, the repaired adapter used 49 automatic ordinary Esc pause/resume pairs, including the initial view. Menu state was tracked from issued inputs, not read from the game. Captures occurred before the automatic pause; the next batch resumed before issuing its inputs. These repeated pauses, 30 fps batching and imperfect lip timing limit continuous-play and feel conclusions. There were no screenshot-response timeouts or unexplained missing command responses. The first pause failure and the unsuccessful opening action remain in the evidence.

## Evidence and cleanup

Evidence root: `/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/discovery-readability/`.

32 selected JPEGs plus request journals, per-decision observations, identity, native-display/GPU logs and dedicated adapter copies total 4,857,599 bytes before this report. No video or PNG dump was produced. `journal.jsonl` preserves every numbered input and marks which screenshots were selected. The initial helper-failure images remain under `views/`; repaired-session images are under `views2/`.

Useful images: `views/06.jpg` (invalid pause); `views2/10.jpg` (stage practice and wall cues); `15.jpg`/`16.jpg` (F2 gain/coast); `20.jpg`/`22.jpg` (F1 manual hop); `26.jpg`/`27.jpg` (F3); `36.jpg` (front contact); `40.jpg` (later lip); `43.jpg` (Stop logs); `56.jpg` (fourth landing); `58.jpg` (final menu).

SHA-256:

- `SHA256SUMS`: `130cecf5668ddde2aabccc71e449e5f3d9978dc1c54e5c03f2546fda2d7e2f75`
- `journal.jsonl`: `80e29f0b68cee6cf2834aedef3d2b24e7f7b91d8222bed63e76714ed30524a6d`
- `identity.json`: `445e5ade873d58d11e8b6612240166a085534644ab78f23b9c4828443ae57e73`
- `views2/43.jpg`: `8dbaf757dd294b90e19c4e85c3ddae70544647011d7840bea78bead3bcb09bc4`
- `views2/56.jpg`: `116b65064b67a6def5fdc75db14463ab9f05c8a03cbf51de5719b384cb3dec34`
- `views2/58.jpg`: `e6bc51332c984481206d5afed3d9b283718e8eb915ec5ab231ab3b7f99d71048`

Before launch, the native-display status reported 15.35 GiB free on /home. Both sessions owned private AMD/X11 display `:191`; occupied `:190` was left alone. Both renderer checks identified AMD and both GPU watches recorded render-node graphics work. Both native contexts report clean teardown, no owned processes or sockets remaining, removed runtime directories and desktop `:0` answering before and after. Isolated data/config/cache profiles were deleted. The final independent `xdpyinfo -display :0` also answered. No root check process or file was signaled or altered. Only this new report and the two new dedicated adapter files are task-owned repository additions; no production edits or commits were made.
