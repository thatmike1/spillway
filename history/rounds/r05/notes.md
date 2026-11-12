# R05: Accept the usable roof as a route

Date: 2026-11-05 (source commit author date, Europe/Prague offset in Git: 2026-11-05T19:50:04+01:00). Build: `spillway-2026.11.05-r5`. Runtime source: `402e83a647eae5b86d23a00cba6fdd6df7c67f86`. Engine: `4.7.2.stable.official.ed1daf0bf`.

Unless expressly attributed as recorded words, every paragraph below is an **agent summary** of the cited sources. R1–R11 are numbered Spillway deliveries following the Foldrunner reboot, not the older reconstruction milestones. See ../../TIMELINE.md for the complete chronology.

## What was asked

Fix ordinary east-side housing/roof approaches that reached the finale without entering a small checkpoint sphere. No separate human round request was found.

## What was built

Outflow admission expanded to the usable filter-house roof bounds. Ordered roof passage counted; the yard below did not. This allowed a legitimate east approach to finish cleanly.

## Mike’s verdict and recorded words

No round-specific verbatim Mike verdict was found in the inspected sources. The inherited reboot request is documented for R1; review findings and agent test results are not his verdict.

## Key decisions

Use actual usable roof area rather than a tiny invisible centre trigger. The decision trail later corrected its earlier description: the quoted east approach had mantle_count=0 and was a jumping housing route, not proof of a mantle. Real mantle coverage existed separately.

## Commit range

`da2f5219d9ac83408eab360e38ab0797eeb35a50..402e83a647eae5b86d23a00cba6fdd6df7c67f86` (exclusive baseline, inclusive delivered runtime source). [commits.txt](commits.txt) lists project commits in order. This is an archival delivery boundary, not a claim that each commit was a separate user-requested round. Documentation and verification commits can follow a frozen runtime source; the next range may include them.

## Selected frames and attribution

Selected from delivered-r5. Roof admission is a hidden logic change; the frames document the course it operated on, not direct proof of the trigger condition.

- [01.webp](frames/01.webp): Course overview from the Crest. (round-labelled archived capture).
- [02.webp](frames/02.webp): Long concrete terrace leading past the valve housings. (round-labelled archived capture).
- [03.webp](frames/03.webp): High approach to the pump tower and Outflow. (round-labelled archived capture).
- [04.webp](frames/04.webp): Wheel seen from the covered lower approach. (round-labelled archived capture).
- [05.webp](frames/05.webp): Completed recovery route and split results. (round-labelled archived capture).

## Evidence

- Archive manifest: `/mnt/ssdswag/foldrunner-archive/foldrunner-build-2026-11-05/delivery/spillway-r5/BUILD.json` (copied as [build.json](build.json)).
- Git: project log and commit diffs on fetched `origin/feat/foldrunner-me-build`; range above.
- [Reboot contract](../../sources/reboot-BRIEF.md), [dated decisions](../../sources/reboot-decisions.tsv), [R10 checkpoint](../../sources/checkpoints-reboot-r10.md), [R11 checkpoint](../../sources/checkpoints-reboot.md) and [R11 results](../../sources/reboot-RESULTS.md). Source snapshots from Git use `02a4a3149`.
- Frame source paths, hashes, extraction times, conversion settings and attribution are in [the manifest](../../MANIFEST.json).
