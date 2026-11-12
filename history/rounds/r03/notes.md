# R03: Make portable gameplay capturable

Date: 2026-11-05 (source commit author date, Europe/Prague offset in Git: 2026-11-05T19:22:02+01:00). Build: `spillway-2026.11.05-r3`. Runtime source: `9957eea2254739e40020092f2860c2113ccf6bd3`. Engine: `4.7.2.stable.official.ed1daf0bf`.

Unless expressly attributed as recorded words, every paragraph below is an **agent summary** of the cited sources. R1–R11 are numbered Spillway deliveries following the Foldrunner reboot, not the older reconstruction milestones. See ../../TIMELINE.md for the complete chronology.

## What was asked

Repair portable route evidence under the existing reboot contract. No separate human round request was found.

## What was built

The route driver stopped treating an empty packed res:// root as a prefix of every absolute output path. It rejected virtual paths and Git ancestors instead. This enabled actual packed route playback and retained safe, fast and recovery captures.

## Mike’s verdict and recorded words

No round-specific verbatim Mike verdict was found in the inspected sources. The inherited reboot request is documented for R1; review findings and agent test results are not his verdict.

## Key decisions

Fix the evidence harness while retaining the playable level. Keep packed execution distinct from source execution.

## Commit range

`36aaaad442ba4806a09a89ed6e6d740e3f741f8a..9957eea2254739e40020092f2860c2113ccf6bd3` (exclusive baseline, inclusive delivered runtime source). [commits.txt](commits.txt) lists project commits in order. This is an archival delivery boundary, not a claim that each commit was a separate user-requested round. Documentation and verification commits can follow a frozen runtime source; the next range may include them.

## Selected frames and attribution

Selected from delivered-r3 native stills. The change is largely invisible in a screenshot; the important advance is trustworthy portable capture, not a new visual world.

- [01.webp](frames/01.webp): Delivered startup with pale concrete, brick tower and ochre gate. (round-labelled archived capture).
- [02.webp](frames/02.webp): Terrace beside brick machinery housings. (round-labelled archived capture).
- [03.webp](frames/03.webp): Filter-house roof, pump tower and Outflow supports. (round-labelled archived capture).
- [04.webp](frames/04.webp): Recovery route approaching the gate from the chute. (round-labelled archived capture).
- [05.webp](frames/05.webp): Wheel at the end of the safe route. (round-labelled archived capture).

## Evidence

- Archive manifest: `/mnt/ssdswag/foldrunner-archive/foldrunner-build-2026-11-05/delivery/spillway-r3/BUILD.json` (copied as [build.json](build.json)).
- Git: project log and commit diffs on fetched `origin/feat/foldrunner-me-build`; range above.
- [Reboot contract](../../sources/reboot-BRIEF.md), [dated decisions](../../sources/reboot-decisions.tsv), [R10 checkpoint](../../sources/checkpoints-reboot-r10.md), [R11 checkpoint](../../sources/checkpoints-reboot.md) and [R11 results](../../sources/reboot-RESULTS.md). Source snapshots from Git use `02a4a3149`.
- Frame source paths, hashes, extraction times, conversion settings and attribution are in [the manifest](../../MANIFEST.json).
