# R06: Close gaps and give recovery a cost

Date: 2026-11-05 (source commit author date, Europe/Prague offset in Git: 2026-11-05T20:36:12+01:00). Build: `spillway-2026.11.05-r6`. Runtime source: `6068c61b93d484f62877eefb227722073ed42ca8`. Engine: `4.7.2.stable.official.ed1daf0bf`.

Unless expressly attributed as recorded words, every paragraph below is an **agent summary** of the cited sources. R1–R11 are numbered Spillway deliveries following the Foldrunner reboot, not the older reconstruction milestones. See ../../TIMELINE.md for the complete chronology.

## What was asked

Address review-reproduced route admission, housing slots, open basin edges and weak recovery consequence. No separate human round request was found.

## What was built

Broader yard-entry admission, a capsule-clear housing-to-roof transition, a real apron guard and then a diagonal junction closure made ordinary approaches work. Wading slowed to 3.4 m/s, with no water slides. Finish staging moved back and basin-ramp hardware gained ochre nosing.

## Mike’s verdict and recorded words

No round-specific verbatim Mike verdict was found in the inspected sources. The inherited reboot request is documented for R1; review findings and agent test results are not his verdict.

## Key decisions

Keep mistakes playable but slower. Fix geometry and admission rather than tuning only the follower. A first rail left an east diagonal opening; final R6 closed it. The retained before-edge-closure BUILD names source 5efcbc83; final R6 names 6068c61b. These are two R6 revisions, not two different rounds.

## Commit range

`402e83a647eae5b86d23a00cba6fdd6df7c67f86..6068c61b93d484f62877eefb227722073ed42ca8` (exclusive baseline, inclusive delivered runtime source). [commits.txt](commits.txt) lists project commits in order. This is an archival delivery boundary, not a claim that each commit was a separate user-requested round. Documentation and verification commits can follow a frozen runtime source; the next range may include them.

## Selected frames and attribution

Selected from delivered-r6. Its per-route BUILD files are checked against the final R6 manifest during validation. The preliminary R6 build is documented but not silently substituted.

- [01.webp](frames/01.webp): Crest approach to the gate. (round-labelled archived capture).
- [02.webp](frames/02.webp): Housing-to-roof line beside the hillside. (round-labelled archived capture).
- [03.webp](frames/03.webp): Landing and covered approach among the Outflow supports. (round-labelled archived capture).
- [04.webp](frames/04.webp): Water-level view of the basin ramp and supporting piers. (round-labelled archived capture).
- [05.webp](frames/05.webp): Lower recovery passage underneath the gantries. (round-labelled archived capture).
- [06.webp](frames/06.webp): Wheel finish framed farther back with split results. (round-labelled archived capture).

## Evidence

- Archive manifest: `/mnt/ssdswag/foldrunner-archive/foldrunner-build-2026-11-05/delivery/spillway-r6/BUILD.json` (copied as [build.json](build.json)).
- Git: project log and commit diffs on fetched `origin/feat/foldrunner-me-build`; range above.
- [Reboot contract](../../sources/reboot-BRIEF.md), [dated decisions](../../sources/reboot-decisions.tsv), [R10 checkpoint](../../sources/checkpoints-reboot-r10.md), [R11 checkpoint](../../sources/checkpoints-reboot.md) and [R11 results](../../sources/reboot-RESULTS.md). Source snapshots from Git use `02a4a3149`.
- Frame source paths, hashes, extraction times, conversion settings and attribution are in [the manifest](../../MANIFEST.json).
