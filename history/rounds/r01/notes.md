# R01: A reboot into a purposeful dam descent

Date: 2026-11-05 (source commit author date, Europe/Prague offset in Git: 2026-11-05T19:12:18+01:00). Build: `spillway-2026.11.05-r1`. Runtime source: `f527b353204ac38d45fa3c972a38f5d66abc4a6a`. Engine: `4.7.2.stable.official.ed1daf0bf`.

Unless expressly attributed as recorded words, every paragraph below is an **agent summary** of the cited sources. R1–R11 are numbered Spillway deliveries following the Foldrunner reboot, not the older reconstruction milestones. See ../../TIMELINE.md for the complete chronology.

## What was asked

Replace the unsatisfying reconstruction with satisfying movement, fun gameplay and appealing visuals. The adopted agent design was one complete dam level, with safe and fast lines and forgiving recovery.

## What was built

A velocity motor replaced the active contextual move stack. Crest, Sluice yard and Outflow became a complete downhill course. Immediate running, buffered/coyote jumps, slide momentum, optional cancellable mantle, shallow-water recovery, practice and clean-run records supported replay. Pale concrete, blue-green water, brick housings, forested terrain and a large wheel established a new setting. Integrity fixes addressed player control and honest records.

## Mike’s verdict and recorded words

Recorded words from Mike before the reboot (public-runtime-transcript.txt, 2026-11-05T15:23:31.128Z): “Make it have actually Satisfying movement, fun gameplay and be visually appealing.” He also wrote “i played it on my linux desktop, still dissapointed.” These concern the preceding Foldrunner build, not acceptance of R1. No R1 post-delivery human verdict was found.

## Key decisions

Keep Godot 4.7.2 and Compatibility. Retire the folding city and reconstruction fidelity contract. Hide distracting running arms. Use continuous ramp collision beneath visual stairs. Label new tuning as game choices; scripted completion does not prove enjoyment.

## Commit range

`86bb26c754424f9cb0c36b5c5fff5f6a8fc94874..f527b353204ac38d45fa3c972a38f5d66abc4a6a` (exclusive baseline, inclusive delivered runtime source). [commits.txt](commits.txt) lists project commits in order. This is an archival delivery boundary, not a claim that each commit was a separate user-requested round. Documentation and verification commits can follow a frozen runtime source; the next range may include them.

## Selected frames and attribution

One R1-labelled development startup still plus four development-source route views. The R1 build label was reused during development; the early startup still is not asserted to match the final delivery manifest. The public action export places final-render capture in the pre-R2 build interval. Those captures ran against a mutable source checkout, not the sealed R1 pack, so exact source identity for each frame is not established. They are R1 development evidence, not exact-pack proof.

- [01.webp](frames/01.webp): The new sunlit dam complex and distant pump tower at startup. (round-labelled archived capture).
- [02.webp](frames/02.webp): Approach to the half-open ochre gate. (R1 development source capture, not exact delivered-pack proof; see notes.md).
- [03.webp](frames/03.webp): Brick valve housing and forested hillside along the yard. (R1 development source capture, not exact delivered-pack proof; see notes.md).
- [04.webp](frames/04.webp): Diagonal Outflow supports and the basin below. (R1 development source capture, not exact delivered-pack proof; see notes.md).
- [05.webp](frames/05.webp): Safe railed gantry above the water. (R1 development source capture, not exact delivered-pack proof; see notes.md).

## Evidence

- Archive manifest: `/mnt/ssdswag/foldrunner-archive/foldrunner-build-2026-11-05/delivery/spillway-r1/BUILD.json` (copied as [build.json](build.json)).
- Git: project log and commit diffs on fetched `origin/feat/foldrunner-me-build`; range above.
- [Reboot contract](../../sources/reboot-BRIEF.md), [dated decisions](../../sources/reboot-decisions.tsv), [R10 checkpoint](../../sources/checkpoints-reboot-r10.md), [R11 checkpoint](../../sources/checkpoints-reboot.md) and [R11 results](../../sources/reboot-RESULTS.md). Source snapshots from Git use `02a4a3149`.
- Frame source paths, hashes, extraction times, conversion settings and attribution are in [the manifest](../../MANIFEST.json).
- [Recorded reboot request](../../sources/mike-reboot-message.txt), copied from the public source export with its timestamp.
