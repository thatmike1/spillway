# Foldrunner to Spillway: source timeline

Collected 12 November 2026 for the handover. This is material for a later history book, not the book or a new design brief.

Unless explicitly marked **Mike words**, every description and verdict below is an **agent summary** of the cited records. Bead descriptions and agent-authored comments can preserve context but are not treated as verbatim Mike quotes. None of the inspected round-bead comments carries author `human:mike` or `michal.psencik`. The R21 FEEDBACK file supplies its direct quote; the desktop archive also supplies an explicitly dated human reboot-message excerpt, scoped to the preceding Foldrunner build. Missing verdicts stay missing. [SOURCES.json](SOURCES.json) indexes the copied briefs, results, reviews, playtest analyses, feedback and issue snapshots under sources/. Recorded play counts and scripted passes do not imply enjoyment.

Dates use Europe/Prague offsets from `git log --all --format=%H|%ad|%s --date=iso-strict -- projects/foldrunner`. Commit spans refer to the original ccChat-general hashes, before the handover's history rewrite. A span lists endpoints of relevant work, not a promise that every intervening commit is exclusive to that round. Later rounds reuse earlier beads: in particular `rowb` covers R12–R14 and the Look C work, while `epsz` covers both R20 and R21. Subjects, dates, package-source records and briefs disambiguate them.

R1–R11 are numbered Spillway delivery iterations, not the six reconstruction milestones or the two earlier Foldrunner rebuilds. Some numbered builds were validation/repair iterations within the same evening, not separately commissioned rounds. The first Foldrunner prototype and the work before the reboot are retained below as prehistory. R1–R11 were curated on the desktop archive drive and copied into this history, including their build manifests, commit lists and source snapshots.

R12–R20 delivery ZIPs were absent from this laptop when inspected. Mike deliberately deleted those packages during disk cleanup on 12 November, as the lead confirmed; no delivery folder was recreated. Retained source/native/package frames are labeled by their true provenance. Rebuilt frames are explicitly not the delivered ZIP. Breakwater first arrived in R15, so a Breakwater-start comparison for R12–R14 would be an anachronism; use Crest/Overflow/Penstock starts. The manifest records all coverage gaps.

## Before numbered Spillway rounds: first Foldrunner prototype

**Date:** 10 October 2026.

**Agent summary of the ask:** a first-person folding-city parkour prototype inspired by Control Resonant and Doctor Strange, a short rooftop route and browser feasibility, with no GPU use while Mike was gaming.

**Built:** initial Godot prototype, commit `8247c380d5a2cf51dbe1e3d8f327d7eda3047843`.

**Verdict:** no eligible direct Mike verdict was found in the inspected prototype bead. Later rebuilds establish dissatisfaction with the earlier feel but do not supply a verbatim October verdict.

**Key decision:** coherent city transformations and momentum were the starting premise. **Commit span:** that single prototype commit. **Sources:** bead ccChat-general-9mga description; original path-filtered git log.

## Before numbered Spillway rounds: two Foldrunner rebuilds

**Date:** 3 November 2026.

**Agent summary of the ask and built work:** rebuild around a visible hinge run, free look, arms and a second building-face bridge. The later build brief describes two variants: the Opus version as more polished but lacking momentum, and the GPT version as faster with Clustertruck-like momentum. These are recorded brief summaries, not quotes from Mike.

**Verdict:** both missed the intended feel according to BRIEF.md. **Key decision:** use the more polished branch as the base for a measured movement rebuild. **Commit span:** `305f2af3c976ffb4a103f548e66045dbdde8aa26^..8881e26e789144e7af89b8fdc610c6e9868d855d`, with a parallel rework at `c87f9a4322c76673cc449af6e66f590262b3a3a8`. Exact association of every parallel intermediate to a human play session remains uncertain. **Sources:** BRIEF.md; original git subjects/dates.

## Before numbered Spillway rounds: reconstruction and city milestones

**Date:** 5 November 2026, roughly 12:26–14:38 Prague by git.

**Agent summary of the ask:** build a 60–90 second folding city, move-set controllers, camera/body and runner vision from the provided movement specification, while keeping private reference material outside Git.

**Built:** distinct controllers, ground/jump traces, body contacts, camera response, runner vision, connected city folds and route hardware.

**Verdict:** agent summaries in rowb comments dated 5 November record Mike reporting slow startup, weak sprint sensation, floaty jumps, momentum-killing landings/vaults and a camera view behind the body. The visual review also considered it greybox. Reviewer scores are not Mike's verdict.

**Key decision:** passing static-derived numbers was insufficient; move to footage-led feel checks in an original dimensioned yard. **Commit span:** `4d488bde773cb0fbb567682dfc8f2cc2835b84fd^..dc6fa4c6dd2a7d519306786ce90878e4a35a5078`. **Sources:** BRIEF.md; checkpoints/1.md through 7.md; rowb comments; original git log. The private reverse-engineering specification and game material are not included here.

## Before numbered Spillway rounds: feel yard and direction reset

**Date:** 5 November 2026, roughly 14:54–15:47 Prague by git.

**Agent summary of the ask:** an original measurement yard, brisker jump, preserved velocity through handoffs, usable sprint cues and camera/body clearance before further city work.

**Built:** training yard, momentum handoff fixes, swept-movement sprint cues, smaller-flight route spacing and rate checks. The tests measured the chosen feel targets; they did not establish enjoyment.

**Verdict:** REBOOT-BRIEF.md records that Mike played and rejected the feel. **Key decision:** drop Mirror's Edge reconstruction and folding-world requirements, keep useful infrastructure, and build an original dam-descent movement game. **Commit span:** `eb557233ad01a07259bfc1535fcf3454484ffec1^..86bb26c754424f9cb0c36b5c5fff5f6a8fc94874`. **Sources:** FEEL-BRIEF.md; docs/FEEL-RESULTS.md; REBOOT-BRIEF.md; rowb comments.

## R01: A reboot into a purposeful dam descent

**Date and delivered identity:** Date: 2026-11-05 (source commit author date, Europe/Prague offset in Git: 2026-11-05T19:12:18+01:00). Build: `spillway-2026.11.05-r1`. Runtime source: `f527b353204ac38d45fa3c972a38f5d66abc4a6a`. Engine: `4.7.2.stable.official.ed1daf0bf`.

**What Mike asked for, archival agent summary:** Replace the unsatisfying reconstruction with satisfying movement, fun gameplay and appealing visuals. The adopted agent design was one complete dam level, with safe and fast lines and forgiving recovery.

**What was built, archival agent summary:** A velocity motor replaced the active contextual move stack. Crest, Sluice yard and Outflow became a complete downhill course. Immediate running, buffered/coyote jumps, slide momentum, optional cancellable mantle, shallow-water recovery, practice and clean-run records supported replay. Pale concrete, blue-green water, brick housings, forested terrain and a large wheel established a new setting. Integrity fixes addressed player control and honest records.

**His verdict and attribution:** Recorded words from Mike before the reboot (public-runtime-transcript.txt, 2026-11-05T15:23:31.128Z): “Make it have actually Satisfying movement, fun gameplay and be visually appealing.” He also wrote “i played it on my linux desktop, still dissapointed.” These concern the preceding Foldrunner build, not acceptance of R1. No R1 post-delivery human verdict was found.

**Key decisions, archival agent summary:** Keep Godot 4.7.2 and Compatibility. Retire the folding city and reconstruction fidelity contract. Hide distracting running arms. Use continuous ramp collision beneath visual stairs. Label new tuning as game choices; scripted completion does not prove enjoyment.

**Original commit range:** `86bb26c754424f9cb0c36b5c5fff5f6a8fc94874..f527b353204ac38d45fa3c972a38f5d66abc4a6a` (exclusive baseline, inclusive delivered runtime source). [commits.txt](rounds/r01/commits.txt) lists project commits in order. This is an archival delivery boundary, not a claim that each commit was a separate user-requested round. Documentation and verification commits can follow a frozen runtime source; the next range may include them.

**Sources and frame qualifications:** [round notes](rounds/r01/notes.md), [copied build manifest](rounds/r01/build.json), SOURCES.json and the source snapshots under sources/. Desktop archive original: /mnt/ssdswag/foldrunner-archive/foldrunner-build-2026-11-05. Original source frames were verified on the desktop; this laptop verifies the copied outputs and available Git identities.

## R02: Ground the forest

**Date and delivered identity:** Date: 2026-11-05 (source commit author date, Europe/Prague offset in Git: 2026-11-05T19:17:26+01:00). Build: `spillway-2026.11.05-r2`. Runtime source: `36aaaad442ba4806a09a89ed6e6d740e3f741f8a`. Engine: `4.7.2.stable.official.ed1daf0bf`.

**What Mike asked for, archival agent summary:** Continue the reboot contract; fix unsupported tree crowns observed in native views. No separate human round request was found.

**What was built, archival agent summary:** Terrain-sampled trunks anchored the low-poly crowns. R2 advanced the delivery before canonical capture. Its delivered capture then aborted after eight startup frames because the packed-game evidence-path guard rejected the output directory.

**His verdict and attribution:** No round-specific verbatim Mike verdict was found in the inspected sources. The inherited reboot request is documented for R1; review findings and agent test results are not his verdict.

**Key decisions, archival agent summary:** Correct visible support rather than adding unrelated scenery. Treat a failed capture as failed evidence, not a failed game or a completed route.

**Original commit range:** `f527b353204ac38d45fa3c972a38f5d66abc4a6a..36aaaad442ba4806a09a89ed6e6d740e3f741f8a` (exclusive baseline, inclusive delivered runtime source). [commits.txt](rounds/r02/commits.txt) lists project commits in order. This is an archival delivery boundary, not a claim that each commit was a separate user-requested round. Documentation and verification commits can follow a frozen runtime source; the next range may include them.

**Sources and frame qualifications:** [round notes](rounds/r02/notes.md), [copied build manifest](rounds/r02/build.json), SOURCES.json and the source snapshots under sources/. Desktop archive original: /mnt/ssdswag/foldrunner-archive/foldrunner-build-2026-11-05. Original source frames were verified on the desktop; this laptop verifies the copied outputs and available Git identities.

## R03: Make portable gameplay capturable

**Date and delivered identity:** Date: 2026-11-05 (source commit author date, Europe/Prague offset in Git: 2026-11-05T19:22:02+01:00). Build: `spillway-2026.11.05-r3`. Runtime source: `9957eea2254739e40020092f2860c2113ccf6bd3`. Engine: `4.7.2.stable.official.ed1daf0bf`.

**What Mike asked for, archival agent summary:** Repair portable route evidence under the existing reboot contract. No separate human round request was found.

**What was built, archival agent summary:** The route driver stopped treating an empty packed res:// root as a prefix of every absolute output path. It rejected virtual paths and Git ancestors instead. This enabled actual packed route playback and retained safe, fast and recovery captures.

**His verdict and attribution:** No round-specific verbatim Mike verdict was found in the inspected sources. The inherited reboot request is documented for R1; review findings and agent test results are not his verdict.

**Key decisions, archival agent summary:** Fix the evidence harness while retaining the playable level. Keep packed execution distinct from source execution.

**Original commit range:** `36aaaad442ba4806a09a89ed6e6d740e3f741f8a..9957eea2254739e40020092f2860c2113ccf6bd3` (exclusive baseline, inclusive delivered runtime source). [commits.txt](rounds/r03/commits.txt) lists project commits in order. This is an archival delivery boundary, not a claim that each commit was a separate user-requested round. Documentation and verification commits can follow a frozen runtime source; the next range may include them.

**Sources and frame qualifications:** [round notes](rounds/r03/notes.md), [copied build manifest](rounds/r03/build.json), SOURCES.json and the source snapshots under sources/. Desktop archive original: /mnt/ssdswag/foldrunner-archive/foldrunner-build-2026-11-05. Original source frames were verified on the desktop; this laptop verifies the copied outputs and available Git identities.

## R04: Make segment practice time honest

**Date and delivered identity:** Date: 2026-11-05 (source commit author date, Europe/Prague offset in Git: 2026-11-05T19:39:18+01:00). Build: `spillway-2026.11.05-r4`. Runtime source: `da2f5219d9ac83408eab360e38ab0797eeb35a50`. Engine: `4.7.2.stable.official.ed1daf0bf`.

**What Mike asked for, archival agent summary:** Fix stale timing on F segment practice under the reboot contract. No separate human round request was found.

**What was built, archival agent summary:** Segment practice restarted its clock, beginning when movement resumed. Fall respawns continued to cost time. Captures retain the same dam course and its safe, fast and recovery routes.

**His verdict and attribution:** No round-specific verbatim Mike verdict was found in the inspected sources. The inherited reboot request is documented for R1; review findings and agent test results are not his verdict.

**Key decisions, archival agent summary:** Separate practice from clean full-run records. Do not erase the time cost of falling by applying the practice restart rule to every respawn.

**Original commit range:** `9957eea2254739e40020092f2860c2113ccf6bd3..da2f5219d9ac83408eab360e38ab0797eeb35a50` (exclusive baseline, inclusive delivered runtime source). [commits.txt](rounds/r04/commits.txt) lists project commits in order. This is an archival delivery boundary, not a claim that each commit was a separate user-requested round. Documentation and verification commits can follow a frozen runtime source; the next range may include them.

**Sources and frame qualifications:** [round notes](rounds/r04/notes.md), [copied build manifest](rounds/r04/build.json), SOURCES.json and the source snapshots under sources/. Desktop archive original: /mnt/ssdswag/foldrunner-archive/foldrunner-build-2026-11-05. Original source frames were verified on the desktop; this laptop verifies the copied outputs and available Git identities.

## R05: Accept the usable roof as a route

**Date and delivered identity:** Date: 2026-11-05 (source commit author date, Europe/Prague offset in Git: 2026-11-05T19:50:04+01:00). Build: `spillway-2026.11.05-r5`. Runtime source: `402e83a647eae5b86d23a00cba6fdd6df7c67f86`. Engine: `4.7.2.stable.official.ed1daf0bf`.

**What Mike asked for, archival agent summary:** Fix ordinary east-side housing/roof approaches that reached the finale without entering a small checkpoint sphere. No separate human round request was found.

**What was built, archival agent summary:** Outflow admission expanded to the usable filter-house roof bounds. Ordered roof passage counted; the yard below did not. This allowed a legitimate east approach to finish cleanly.

**His verdict and attribution:** No round-specific verbatim Mike verdict was found in the inspected sources. The inherited reboot request is documented for R1; review findings and agent test results are not his verdict.

**Key decisions, archival agent summary:** Use actual usable roof area rather than a tiny invisible centre trigger. The decision trail later corrected its earlier description: the quoted east approach had mantle_count=0 and was a jumping housing route, not proof of a mantle. Real mantle coverage existed separately.

**Original commit range:** `da2f5219d9ac83408eab360e38ab0797eeb35a50..402e83a647eae5b86d23a00cba6fdd6df7c67f86` (exclusive baseline, inclusive delivered runtime source). [commits.txt](rounds/r05/commits.txt) lists project commits in order. This is an archival delivery boundary, not a claim that each commit was a separate user-requested round. Documentation and verification commits can follow a frozen runtime source; the next range may include them.

**Sources and frame qualifications:** [round notes](rounds/r05/notes.md), [copied build manifest](rounds/r05/build.json), SOURCES.json and the source snapshots under sources/. Desktop archive original: /mnt/ssdswag/foldrunner-archive/foldrunner-build-2026-11-05. Original source frames were verified on the desktop; this laptop verifies the copied outputs and available Git identities.

## R06: Close gaps and give recovery a cost

**Date and delivered identity:** Date: 2026-11-05 (source commit author date, Europe/Prague offset in Git: 2026-11-05T20:36:12+01:00). Build: `spillway-2026.11.05-r6`. Runtime source: `6068c61b93d484f62877eefb227722073ed42ca8`. Engine: `4.7.2.stable.official.ed1daf0bf`.

**What Mike asked for, archival agent summary:** Address review-reproduced route admission, housing slots, open basin edges and weak recovery consequence. No separate human round request was found.

**What was built, archival agent summary:** Broader yard-entry admission, a capsule-clear housing-to-roof transition, a real apron guard and then a diagonal junction closure made ordinary approaches work. Wading slowed to 3.4 m/s, with no water slides. Finish staging moved back and basin-ramp hardware gained ochre nosing.

**His verdict and attribution:** No round-specific verbatim Mike verdict was found in the inspected sources. The inherited reboot request is documented for R1; review findings and agent test results are not his verdict.

**Key decisions, archival agent summary:** Keep mistakes playable but slower. Fix geometry and admission rather than tuning only the follower. A first rail left an east diagonal opening; final R6 closed it. The retained before-edge-closure BUILD names source 5efcbc83; final R6 names 6068c61b. These are two R6 revisions, not two different rounds.

**Original commit range:** `402e83a647eae5b86d23a00cba6fdd6df7c67f86..6068c61b93d484f62877eefb227722073ed42ca8` (exclusive baseline, inclusive delivered runtime source). [commits.txt](rounds/r06/commits.txt) lists project commits in order. This is an archival delivery boundary, not a claim that each commit was a separate user-requested round. Documentation and verification commits can follow a frozen runtime source; the next range may include them.

**Sources and frame qualifications:** [round notes](rounds/r06/notes.md), [copied build manifest](rounds/r06/build.json), SOURCES.json and the source snapshots under sources/. Desktop archive original: /mnt/ssdswag/foldrunner-archive/foldrunner-build-2026-11-05. Original source frames were verified on the desktop; this laptop verifies the copied outputs and available Git identities.

## R07: Let either side of the wheel finish

**Date and delivered identity:** Date: 2026-11-05 (source commit author date, Europe/Prague offset in Git: 2026-11-05T21:16:59+01:00). Build: `spillway-2026.11.05-r7`. Runtime source: `70d4c2fd2bed69aa4fdedfbb0c4d390eae5db692`. Engine: `4.7.2.stable.official.ed1daf0bf`.

**What Mike asked for, archival agent summary:** Fix legitimate direct wheel approaches after the R6 framing change made the front trigger bypassable. No separate human round request was found.

**What was built, archival agent summary:** Finish admission covered the actual wheel approaches from either side. An added direct-wheel whole-route variant exercised the change. The movement tuning stayed unchanged.

**His verdict and attribution:** No round-specific verbatim Mike verdict was found in the inspected sources. The inherited reboot request is documented for R1; review findings and agent test results are not his verdict.

**Key decisions, archival agent summary:** Arrival should count where a player naturally reaches the goal. Preserve the 35/36 matrix result with its one elevated-marker follower failure, rather than replacing failures with a success fixture.

**Original commit range:** `6068c61b93d484f62877eefb227722073ed42ca8..70d4c2fd2bed69aa4fdedfbb0c4d390eae5db692` (exclusive baseline, inclusive delivered runtime source). [commits.txt](rounds/r07/commits.txt) lists project commits in order. This is an archival delivery boundary, not a claim that each commit was a separate user-requested round. Documentation and verification commits can follow a frozen runtime source; the next range may include them.

**Sources and frame qualifications:** [round notes](rounds/r07/notes.md), [copied build manifest](rounds/r07/build.json), SOURCES.json and the source snapshots under sources/. Desktop archive original: /mnt/ssdswag/foldrunner-archive/foldrunner-build-2026-11-05. Original source frames were verified on the desktop; this laptop verifies the copied outputs and available Git identities.

## R08: Guard the recovery perimeter

**Date and delivered identity:** Date: 2026-11-05 (source commit author date, Europe/Prague offset in Git: 2026-11-05T21:44:11+01:00). Build: `spillway-2026.11.05-r8`. Runtime source: `44039ea3f8ad1cd32de9d719db96e25b71b9da47`. Engine: `4.7.2.stable.official.ed1daf0bf`.

**What Mike asked for, archival agent summary:** Fix off-line recovery gaps and the east housing/roof bridge turn found in closure review. No separate human round request was found.

**What was built, archival agent summary:** Perimeter retaining faces and edge guards were extended across Crest and basin corner cases. Roof access admitted the east turn. Finished results survived later exploration falls. Baseline finish approaches aimed directly at the wheel.

**His verdict and attribution:** No round-specific verbatim Mike verdict was found in the inspected sources. The inherited reboot request is documented for R1; review findings and agent test results are not his verdict.

**Key decisions, archival agent summary:** Preserve a finished result during post-finish exploration. Keep F as an explicit transition to practice. Distinguish a late-miss follower stall from physical impossibility of recovery.

**Original commit range:** `70d4c2fd2bed69aa4fdedfbb0c4d390eae5db692..44039ea3f8ad1cd32de9d719db96e25b71b9da47` (exclusive baseline, inclusive delivered runtime source). [commits.txt](rounds/r08/commits.txt) lists project commits in order. This is an archival delivery boundary, not a claim that each commit was a separate user-requested round. Documentation and verification commits can follow a frozen runtime source; the next range may include them.

**Sources and frame qualifications:** [round notes](rounds/r08/notes.md), [copied build manifest](rounds/r08/build.json), SOURCES.json and the source snapshots under sources/. Desktop archive original: /mnt/ssdswag/foldrunner-archive/foldrunner-build-2026-11-05. Original source frames were verified on the desktop; this laptop verifies the copied outputs and available Git identities.

## R09: Make the existing basin exit visible

**Date and delivered identity:** Date: 2026-11-05 (source commit author date, Europe/Prague offset in Git: 2026-11-05T21:52:43+01:00). Build: `spillway-2026.11.05-r9`. Runtime source: `c55ed52e358c0e3709dd3f92ed619b1bd80ae59b`. Engine: `4.7.2.stable.official.ed1daf0bf`.

**What Mike asked for, archival agent summary:** Improve the dark basin ramp revealed in matched R8 views. No separate human round request was found.

**What was built, archival agent summary:** Ochre physical handrails marked the existing recovery ramp. A new input continuation approached its open foot after the actual late miss; a previous diagonal approach hit the honest rail. Native canonical routes retained a visible finished moment.

**His verdict and attribution:** No round-specific verbatim Mike verdict was found in the inspected sources. The inherited reboot request is documented for R1; review findings and agent test results are not his verdict.

**Key decisions, archival agent summary:** Improve ramp legibility with physical hardware, not a second ramp or a floating sign. No motor change. Keep the failed continuation and the original 35/36 matrix result distinct from the successful revised recovery.

**Original commit range:** `44039ea3f8ad1cd32de9d719db96e25b71b9da47..c55ed52e358c0e3709dd3f92ed619b1bd80ae59b` (exclusive baseline, inclusive delivered runtime source). [commits.txt](rounds/r09/commits.txt) lists project commits in order. This is an archival delivery boundary, not a claim that each commit was a separate user-requested round. Documentation and verification commits can follow a frozen runtime source; the next range may include them.

**Sources and frame qualifications:** [round notes](rounds/r09/notes.md), [copied build manifest](rounds/r09/build.json), SOURCES.json and the source snapshots under sources/. Desktop archive original: /mnt/ssdswag/foldrunner-archive/foldrunner-build-2026-11-05. Original source frames were verified on the desktop; this laptop verifies the copied outputs and available Git identities.

## R10: Count legitimate parkour progress

**Date and delivered identity:** Date: 2026-11-05 (source commit author date, Europe/Prague offset in Git: 2026-11-05T22:57:22+01:00). Build: `spillway-2026.11.05-r10`. Runtime source: `5a8cf81e5b1cea3b7d09a6a1ba6fdf759fb72d7e`. Engine: `4.7.2.stable.official.ed1daf0bf`.

**What Mike asked for, archival agent summary:** An independent R9 rail hop reached the run-up and wheel but was refused a valid finish. Fix that class of false rejection under the reboot contract.

**What was built, archival agent summary:** Actual grounded stage decks admitted progress; wheel arrival always finished. Skipped stages produced an unrecorded exploration result. Catch surfaces did not grant Outflow. Native evidence included an ordinary rail hop, basin miss and recovery to an ordered clean finish.

**His verdict and attribution:** No round-specific verbatim Mike verdict was found in the inspected sources. The inherited reboot request is documented for R1; review findings and agent test results are not his verdict.

**Key decisions, archival agent summary:** Reject side contacts, distant airborne proximity and stale reset contacts. No motor or art retuning. Retain the disclosed decorative wheel collision limitation after the result is saved.

**Original commit range:** `c55ed52e358c0e3709dd3f92ed619b1bd80ae59b..5a8cf81e5b1cea3b7d09a6a1ba6fdf759fb72d7e` (exclusive baseline, inclusive delivered runtime source). [commits.txt](rounds/r10/commits.txt) lists project commits in order. This is an archival delivery boundary, not a claim that each commit was a separate user-requested round. Documentation and verification commits can follow a frozen runtime source; the next range may include them.

**Sources and frame qualifications:** [round notes](rounds/r10/notes.md), [copied build manifest](rounds/r10/build.json), SOURCES.json and the source snapshots under sources/. Desktop archive original: /mnt/ssdswag/foldrunner-archive/foldrunner-build-2026-11-05. Original source frames were verified on the desktop; this laptop verifies the copied outputs and available Git identities.

## R11: A working pump hall, then a change of movement direction

**Date and delivered identity:** Date: 2026-11-06 (source commit author date, Europe/Prague offset in Git: 2026-11-06T08:39:22+01:00). Build: `spillway-2026.11.06-r11`. Runtime source: `52a66297bafb6bd401b0c519c2a1ef0f9e7a9cc6`. Engine: `4.7.2.stable.official.ed1daf0bf`.

**What Mike asked for, archival agent summary:** Continue the meaningful game work overnight through at least 08:00 Prague on 6 November, preserving R10 as a stable checkpoint. After delivery, Mike played R11 and requested the bhop/surf direction that became R12.

**What was built, archival agent summary:** Backward braking became at least as firm as release. Late-duck eye clearance and audio loops were repaired; reachable hardware gained collision, the finish gained guards and front arrival, and the terrace was screened to lead toward the yard. A working bucketed wheel, gate, flume, tailrace and concrete pours improved the finish. The basin ramp was cleared and widened, and batching preserved screen shadow settings.

**His verdict and attribution:** Agent-recorded summary, not a verbatim quote: SURF-BRIEF.md says Mike found plain running boring, sliding fun and accidental bunny hopping the best part. Turning while hopping lost speed; the left stair route became a long walk. It records his wish to lean into Counter-Strike-style bhop/surf. playtest-r11/README.md records wheel snagging, the non-solid gate beam, water stalling slides, a floating rail and the reservoir edge. These documents attribute the feedback to Mike, but do not preserve a verbatim message. No invented direct quote is supplied.

**Key decisions, archival agent summary:** Keep forgiving recovery while disclosing its weak Outflow risk tradeoff. Isolate export tests so loose source cannot hide missing packed resources. Resume after disk exhaustion without claiming uninterrupted overnight work. Preserve limitations: two follower stalls, no independent full R11 discovery finish, and no proof of enjoyment from automated checks.

**Original commit range:** `5a8cf81e5b1cea3b7d09a6a1ba6fdf759fb72d7e..52a66297bafb6bd401b0c519c2a1ef0f9e7a9cc6` (exclusive baseline, inclusive delivered runtime source). [commits.txt](rounds/r11/commits.txt) lists project commits in order. This is an archival delivery boundary, not a claim that each commit was a separate user-requested round. Documentation and verification commits can follow a frozen runtime source; the next range may include them.

**Sources and frame qualifications:** [round notes](rounds/r11/notes.md), [copied build manifest](rounds/r11/build.json), SOURCES.json and the source snapshots under sources/. Desktop archive original: /mnt/ssdswag/foldrunner-archive/foldrunner-build-2026-11-05. Original source frames were verified on the desktop; this laptop verifies the copied outputs and available Git identities.

## R12: Bhop and surf at the dam

**Date:** 6 November 2026.

**What Mike asked for, agent summary:** Agent summary: lean into CS bhop/surf, fix air-strafe speed loss, stop long plain-run stretches and repair the five R11 bugs.

**What was built, agent summary:** Projection-limited air acceleration, autohop before friction, three curved surf stages, wet-slide momentum and beginner lines. The runtime is f84e175d; the retained result reports a 13.700 s scripted fast route, not human enjoyment.

**His verdict and attribution:** Agent summary from the momentum brief and rowb history: Mike still found momentum unsatisfying and named VHOLUME as something he enjoyed. Surf became optional, and broader movement research was authorized. No eligible direct quote was found.

**Key decisions, agent summary:** The first Source-style implementation was tuning chosen for this game. Passing its targets did not establish the feel Mike wanted.

**Original commit span:** `0d29e8273e37a883c5abef42d100ff7fe95ee0a7^..79487147e1858456eba1417767e5d9fbad3b8f44` (inclusive first `0d29e8273`, last `79487147e`)

**Package/source identity:** `f84e175d53a4a259330969c83edaa929d8d02f5c`.

**Sources:** /home/thatmike1/foldrunner-build-2026-11-05/SURF-BRIEF.md; /home/thatmike1/foldrunner-build-2026-11-05/look/wt/projects/foldrunner/docs/surf/RESULTS.md; /home/thatmike1/foldrunner-build-2026-11-05/look/wt/projects/foldrunner/docs/momentum/BRIEF.md.

## R13: Overflow movement experiment

**Date:** 7 November 2026.

**What Mike asked for, agent summary:** Agent summary: research more broadly, permit original movement, make surf optional and prioritize momentum that feels satisfying.

**What was built, agent summary:** Overflow supplied height-earned momentum, bounded W/mouse flight placement, optional side carving, recovery ramps and a CC0 material kit. The final portable source is d8fe109f; it supersedes an earlier R13 delivery.

**His verdict and attribution:** Agent summary recorded in the R14 brief and bead: Mike rejected bounded W/mouse steering and still wanted CS:GO A/D plus same-direction mouse strafing that holds and builds speed. He returned to actual CS bhop servers as the reference. No eligible direct quote was found.

**Key decisions, agent summary:** Keep Godot after the bounded presentation audit; retain R12 and R13 as distinct comparisons. R13 becomes a comparison rather than the intended default.

**Original commit span:** `4d034e52318e70604c307dd23e9c123d91a6019d^..5105369b38e1e76ca74649a22daa91c6f92fb754` (inclusive first `4d034e523`, last `5105369b3`)

**Package/source identity:** `d8fe109fbf8965c73ecc2965ae32b0a67d165165`.

**Sources:** /home/thatmike1/foldrunner-build-2026-11-05/look/wt/projects/foldrunner/docs/momentum/BRIEF.md; /home/thatmike1/foldrunner-build-2026-11-05/look/wt/projects/foldrunner/docs/momentum/RESULTS.md; /home/thatmike1/foldrunner-build-2026-11-05/look/wt/projects/foldrunner/docs/r14/BRIEF.md.

## R14: Source bhop and switchable comparisons

**Date:** 8 November 2026.

**What Mike asked for, agent summary:** Agent summary: implement public Source/CS movement rules independently, compare vanilla, bhop-server and R13 modes live, add speed/gain/sync HUD and an original practice map.

**What was built, agent summary:** Penstock Yard and retained Overflow supported five presets. Default F2 used AA100/128 Hz, F5 AA1000/128 Hz. Integer-tick records and focused practice were verified; delivered export source is 65d205be.

**His verdict and attribution:** Agent summary in the R15 brief and pb3f description: Mike liked both bhop-server F2 and AA1000 F5, and disliked vanilla64. The approval was tentative and specific to those profiles. No eligible direct quote was found.

**Key decisions, agent summary:** Preserve the enjoyed server movement; five-world expansion and real crouch come next. Extra traversal belongs in an isolated experiment, not a silent motor replacement.

**Original commit span:** `e9e59fcc4681d3a7d32714367a5bc042d2db95a7^..d029129243c070b1a213660b006c8111bef4bd78` (inclusive first `e9e59fcc4`, last `d02912924`)

**Package/source identity:** `65d205be85c884dc13295725a3eb26c3f46d9ca7`.

**Sources:** /home/thatmike1/foldrunner-build-2026-11-05/look/wt/projects/foldrunner/docs/r14/BRIEF.md; /home/thatmike1/foldrunner-build-2026-11-05/look/wt/projects/foldrunner/docs/r14/RESULTS.md; /home/thatmike1/foldrunner-build-2026-11-05/look/wt/projects/foldrunner/docs/r15/BRIEF.md; bead ccChat-general-rowb description/comments.

## R15: Five worlds, airborne crouch and Movement Lab

**Date:** 8–9 November 2026; delivered 9 November.

**What Mike asked for, agent summary:** Agent summary: preserve F2/F5, add five themed checkpoint maps with licensed external assets, real airborne crouch/crouch hops and a separate traversal lab.

**What was built, agent summary:** Breakwater, Whiteout Relay, Sunken Court, Rainline and Night Shift joined Penstock and Overflow. A real changing hull supports crouch jumps. Movement Lab isolates slide, wall jump and grapple. Export source 8a254d16; later commits retain test/docs evidence.

**His verdict and attribution:** Agent summary recorded in bead 41fq and the R16 brief: after Breakwater, Whiteout Relay, Sunken Court and Movement Lab, Mike said it was fun and wanted to keep playing. This does not cover every map. No eligible verbatim record was found.

**Key decisions, agent summary:** Freeze approved F2/F5. Retire vanilla64 from the primary menu. The five themes and exact traversal tuning were agent proposals.

**Original commit span:** `186780ee9318c47d2459d211af05f13d3b252e75^..d79ba16310ddfa4af1f02bf043d7bce4fb31887d` (inclusive first `186780ee9`, last `d79ba1631`)

**Package/source identity:** `8a254d16455d69cee6df8ca37f82c53d04e6ab4c`.

**Sources:** /home/thatmike1/foldrunner-build-2026-11-05/look/wt/projects/foldrunner/docs/r15/BRIEF.md; /home/thatmike1/foldrunner-build-2026-11-05/look/wt/projects/foldrunner/docs/r15/RESULTS.md; /home/thatmike1/foldrunner-build-2026-11-05/REPORT-R15.md; bead ccChat-general-pb3f and ccChat-general-41fq descriptions/comments.

## R16: Style, recorded runs and a ghost

**Date:** 9 November 2026.

**What Mike asked for, agent summary:** Agent summary: score geometry-backed skill, record every local attempt compactly, supply analysis and a fastest-clean-run ghost; then make wall jumps and bhop→landing-slide→bhop deliberate while preserving the liked courses.

**What was built, agent summary:** Geometry-derived speed, gap, edge, near-miss, strafe and crouch-save awards; compact .r16run attempts; strict readers and clean fastest ghost. The lab allows A/D-held wall kicks and a separate Shift landing slide. Delivered runtime 67e608a0; final docs head 7261ba593.

**His verdict and attribution:** No isolated R16 human verdict is established by the inspected sources. Later R18 play includes inherited R16 features but does not identify a separate judgement of every score/ghost/lab rule.

**Key decisions, agent summary:** Keep F2/F5 and base maps frozen. Separate style best from fastest clean ghost. Local hashes detect damage, not forgery, and scripted proof does not certify fun.

**Original commit span:** `8cf566f0b94a8461d54256f9e034e9a30422360e^..7261ba593ae75137adabc3af7e0e2a8bde4579fb` (inclusive first `8cf566f0b`, last `7261ba593`)

**Package/source identity:** `67e608a0f2b9dbb31b31ff8f63bdc3fd8491a1e3`.

**Sources:** /home/thatmike1/foldrunner-build-2026-11-05/look/wt/projects/foldrunner/docs/r16/BRIEF.md; /home/thatmike1/foldrunner-build-2026-11-05/look/wt/projects/foldrunner/docs/r16/RESULTS.md; /home/thatmike1/foldrunner-build-2026-11-05/REPORT.md; bead ccChat-general-41fq description/comments.

## R17: Blend C across the maps

**Date:** 9 November 2026.

**What Mike asked for, agent summary:** Agent summary from goal-r17 and the look records: extend the chosen pale landings, dark weathered sides, restrained orange lips, ink and painted sky language to all eight maps without changing R16 gameplay.

**What was built, agent summary:** A Breakwater-only look slice at 76c025fac preceded the all-map R17 rollout. Reversible L comparison, per-map skies, readability repairs and the all-map presentation layer shipped at b406e2d2; final evidence/docs head 7698806ef.

**His verdict and attribution:** The R17 goal records that Mike liked the preceding Breakwater look slice as a proof of concept, an agent-recorded summary. No isolated human approval of every R17 map is recorded. The following UI request says the existing menus/HUD/results were annoying, and R18 was later enjoyed. Do not turn either into a blanket R17 visual verdict.

**Key decisions, agent summary:** Keep movement and collision exact; presentation can toggle. Preserve timing/edge/hazard cues and distinguish indoor surfaces. Private concepts stay out of the game and this history.

**Original commit span:** `3e51d8ec209fdf6b505a5391b1d14c064434f54d^..7698806ef53dc025936c8a0e3464f24ffabc13ca` (inclusive first `3e51d8ec2`, last `7698806ef`)

**Package/source identity:** `b406e2d2ad62e7353861b6aefdc9534702d1a4eb`.

**Sources:** /home/thatmike1/foldrunner-build-2026-11-05/goal-r17.txt; /home/thatmike1/foldrunner-build-2026-11-05/look/RESULTS.md; /home/thatmike1/foldrunner-build-2026-11-05/look/RESULTS-R17.md; /home/thatmike1/foldrunner-build-2026-11-05/look/REVIEW-R17.md; bead ccChat-general-3wh8 description/comments.

## R18: Cream-and-ink interface

**Date:** 9 November 2026.

**What Mike asked for, agent summary:** Agent summary from bead 0zb1: redesign menus, HUD and finish screen because they felt like annoying debug overlays; follow Look C and preserve gameplay.

**What was built, agent summary:** Title card, cream/ink pause sheets, compact HUD, F9 telemetry and readable finish/teaching text. Final R18 branch/source identity is 640d06e65. The 32 recorded attempts later analyzed as R18 contain 29 F2 and three F5 attempts.

**His verdict and attribution:** Agent summary from the bead and R19 spec: Mike played R18, had fun and asked for a large backwards-bhop style reward. No eligible direct quote was found.

**Key decisions, agent summary:** The UI language becomes the baseline for later rounds; debug detail stays behind telemetry. A later pass moves legacy sliders and the Look label out of ordinary view.

**Original commit span:** `0eb2b443670451306158108c885bd10a1d4a513b^..640d06e6539b53da752f03bfddb64fb46310abb7` (inclusive first `0eb2b4436`, last `640d06e65`)

**Package/source identity:** `640d06e6539b53da752f03bfddb64fb46310abb7`.

**Sources:** git commit 640d06e6539b53da752f03bfddb64fb46310abb7; bead ccChat-general-0zb1 description/comments; /home/thatmike1/foldrunner-build-2026-11-05/R19-SPEC.md; /home/thatmike1/foldrunner-build-2026-11-05/playtest-r18/ANALYSIS.md.

## R19: Directional style, friend ghosts, surf and experiments

**Date:** 9–10 November 2026; overnight delivery.

**What Mike asked for, agent summary:** Agent summary: reward sustained backwards/sideways hops, fix four UI details, analyze real runs before map edits, share a ghost with a friend, add surf and ambitious isolated experiments.

**What was built, agent summary:** Saltglass surf/bhop, named .spillghost exchange, directional awards and Tether Yard, Line Drive and Fall Line. Only Breakwater RunwayThread widened, from 1.05 m to 2.05 m, based on observed wall hits. Shipped source 5dcc9496; final docs head 065f7b279.

**His verdict and attribution:** Agent summary from R20-SPEC.md: Saltglass and Tether Yard were fun. Line Drive lacked readable feedback/landing value and his own speed beat its pads; Fall Line lacked contact/drop feedback and its two-second delay was too slow for bhop. No eligible direct quote is used.

**Key decisions, agent summary:** Keep emergent earned shortcuts. Ground changes in actual play, not restart-count psychology. Cross-platform ghost checks under Wine are not native Windows play.

**Original commit span:** `d1f25d992b73201264b894270123a948215f7faf^..065f7b27993df7ae2511eb34eb665d271dded13c` (inclusive first `d1f25d992`, last `065f7b279`)

**Package/source identity:** `5dcc94967c19cf1333797ce8fc26f36a8f860ce5`.

**Sources:** /home/thatmike1/foldrunner-build-2026-11-05/R19-SPEC.md; /home/thatmike1/foldrunner-build-2026-11-05/look/RESULTS-R19.md; /home/thatmike1/foldrunner-build-2026-11-05/look/REVIEW-R19.md; /home/thatmike1/foldrunner-build-2026-11-05/playtest-r18/ANALYSIS.md; /home/thatmike1/foldrunner-build-2026-11-05/playtest-r19/ANALYSIS.md; /home/thatmike1/foldrunner-build-2026-11-05/R20-SPEC.md; bead ccChat-general-nrbo description/comments.

## R20: Higher surf entries, growing stacks and mouse grapple

**Date:** 10–11 November 2026; gameplay commits 10 November, final verifier/docs commit 11 November.

**What Mike asked for, agent summary:** Agent summary: remove the free Saltglass reverse-start skip, enter fins high, use flat exits without safety nets, grow directional stacks, move tether controls to mouse with alternative ropes, shelve weak experiments, prototype Through Line and export every local run.

**What was built, agent summary:** Saltglass was rebuilt with high fin entries and climbing links. Pending backwards/sideways stacks bank on a fast end and disappear on stall. Tether Yard adds Classic/Pendulum/Elastic and LMB attach/RMB reel. Through Line transfers momentum between two physical segments. Local run ZIP export/ingestion ships. Runtime 7f8fb41b7; e6baa995d repairs verification/docs only.

**His verdict and attribution:** Agent summary from R21-SPEC.md: Saltglass was fun but empty; high exits spent too much surf speed climbing. The backwards stack seemed about right but was not deeply tested. Mike liked the hard Breakwater outside-container line and preferred Elastic, while acquisition and platform clips still needed work. Through Line remained untested. No eligible direct quote is used.

**Key decisions, agent summary:** Shelve Line Drive/Fall Line while preserving code and reasons. Preserve original eight-map/F2 parity. Trials and replay counts must be separated from human feel.

**Original commit span:** `2f6249513fc81f187deee4f37595a35592f5c0c1^..e6baa995da84d380abc8b8d6a3769b33e771945e` (inclusive first `2f6249513`, last `e6baa995d`)

**Package/source identity:** `7f8fb41b741c01455682ae0c6ee612d5d6fd1fc4`.

**Sources:** /home/thatmike1/foldrunner-build-2026-11-05/R20-SPEC.md; /home/thatmike1/foldrunner-build-2026-11-05/look/RESULTS-R20.md; /home/thatmike1/foldrunner-build-2026-11-05/playtest-r19/ANALYSIS.md; /home/thatmike1/foldrunner-build-2026-11-05/playtest-r20/ANALYSIS.md; /home/thatmike1/foldrunner-build-2026-11-05/R21-SPEC.md; bead ccChat-general-epsz description/comments.

## R21: Lower surf exits and tuned Elastic variants

**Date:** 11–12 November 2026; final source commit 12 November, Mike playtest 12 November.

**What Mike asked for, agent summary:** Agent summary: carry surf speed through lower/farther exits, fill Saltglass with skill-bearing lines and place identity, describe Breakwater's outside line without changing it, research grapples, ease anchor acquisition and clear platform clips.

**What was built, agent summary:** Saltglass exits lowered 14→7 m, a quay outside option and set dressing were added. Breakwater/scoring stayed unchanged after existing gap awards were confirmed. Soft/Firm/Arc tune Elastic, with a visible next-anchor preview and acquisition cone. Exact published source dee210165; Linux ZIP SHA256 749c2030233610068b3f465a87a644cd594665f1be7d367dba6370b211066ec5.

**His verdict and attribution:** Mike words recorded in playtest-r21/FEEDBACK.md: the scenery feels like the agent thought "throw more shapes into the map to make it seem like I filled it with life". The same feedback file summarizes that the lower exits carry speed, ramp shapes blend with dark platform undersides, unsupported boxes remain, and he could not find the fast quay outside route. Arc felt best immediately, needed more testing, and made him want more swinging-map experiments. The record likens it to Spider-Man; that comparison is a recorded summary, not a fabricated direct quote.

**Key decisions, agent summary:** The surf-exit functional fix worked according to the human feedback; visual fullness/readability is still unresolved. Further swing experiments are promising to Mike. Through Line, backwards stack and anchor readout received no new verdict.

**Original commit span:** `24c67e432f8433cff36f4004925a0d1a6e713770^..dee210165b6f169b2433b3043712c5855c37d3b6` (inclusive first `24c67e432`, last `dee210165`)

**Package/source identity:** `dee210165b6f169b2433b3043712c5855c37d3b6`.

**Sources:** /home/thatmike1/foldrunner-build-2026-11-05/R21-SPEC.md; /home/thatmike1/foldrunner-build-2026-11-05/look/RESULTS-R21.md; /home/thatmike1/foldrunner-build-2026-11-05/playtest-r20/ANALYSIS.md; /home/thatmike1/foldrunner-build-2026-11-05/playtest-r21/FEEDBACK.md; /home/thatmike1/foldrunner-build-2026-11-05/delivery/spillway-r21/PUBLICATION.json; bead ccChat-general-epsz description/comments.
