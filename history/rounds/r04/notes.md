# R04: Make segment practice time honest

Date: 2026-11-05 (source commit author date, Europe/Prague offset in Git: 2026-11-05T19:39:18+01:00). Build: `spillway-2026.11.05-r4`. Runtime source: `da2f5219d9ac83408eab360e38ab0797eeb35a50`. Engine: `4.7.2.stable.official.ed1daf0bf`.

Unless expressly attributed as recorded words, every paragraph below is an **agent summary** of the cited sources. R1–R11 are numbered Spillway deliveries following the Foldrunner reboot, not the older reconstruction milestones. See ../../TIMELINE.md for the complete chronology.

## What was asked

Fix stale timing on F segment practice under the reboot contract. No separate human round request was found.

## What was built

Segment practice restarted its clock, beginning when movement resumed. Fall respawns continued to cost time. Captures retain the same dam course and its safe, fast and recovery routes.

## Mike’s verdict and recorded words

No round-specific verbatim Mike verdict was found in the inspected sources. The inherited reboot request is documented for R1; review findings and agent test results are not his verdict.

## Key decisions

Separate practice from clean full-run records. Do not erase the time cost of falling by applying the practice restart rule to every respawn.

## Commit range

`9957eea2254739e40020092f2860c2113ccf6bd3..da2f5219d9ac83408eab360e38ab0797eeb35a50` (exclusive baseline, inclusive delivered runtime source). [commits.txt](commits.txt) lists project commits in order. This is an archival delivery boundary, not a claim that each commit was a separate user-requested round. Documentation and verification commits can follow a frozen runtime source; the next range may include them.

## Selected frames and attribution

Selected from delivered-r4. This is a timing-policy round, with no claim of a new art pass.

- [01.webp](frames/01.webp): Whole-course view from the Crest start. (round-labelled archived capture).
- [02.webp](frames/02.webp): Player view underneath the raised gate. (round-labelled archived capture).
- [03.webp](frames/03.webp): Safe switchback stairs overlooking the yard. (round-labelled archived capture).
- [04.webp](frames/04.webp): Railed yard approach above water. (round-labelled archived capture).
- [05.webp](frames/05.webp): Safe-route finish and three displayed splits. (round-labelled archived capture).

## Evidence

- Archive manifest: `/mnt/ssdswag/foldrunner-archive/foldrunner-build-2026-11-05/delivery/spillway-r4/BUILD.json` (copied as [build.json](build.json)).
- Git: project log and commit diffs on fetched `origin/feat/foldrunner-me-build`; range above.
- [Reboot contract](../../sources/reboot-BRIEF.md), [dated decisions](../../sources/reboot-decisions.tsv), [R10 checkpoint](../../sources/checkpoints-reboot-r10.md), [R11 checkpoint](../../sources/checkpoints-reboot.md) and [R11 results](../../sources/reboot-RESULTS.md). Source snapshots from Git use `02a4a3149`.
- Frame source paths, hashes, extraction times, conversion settings and attribution are in [the manifest](../../MANIFEST.json).
