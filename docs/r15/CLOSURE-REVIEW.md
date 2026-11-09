# R15 closure review, 9 November 2026

Read-only cross-family audit of the promoted Spillway R15 package, its reports and the R15 decision trail. No engine, import, render, export, commit or push. Reviewer: Claude Opus 5.5 subagent. Owned outputs: this file and outer `checkpoints/spillway/r15/closure-review/` (about 0.6 MiB).

**Verdict: no runtime, packaging or report must-fix.** The accepted artifacts are the 8a254d16 export, every promoted number reconciles with the checker output, and the limits are disclosed honestly. One evidence gap had to be fixed. Two frames root cites as inspected had been curated out and survived only on tmpfs. This review preserved their exact bytes (see item 1). Everything else below is a should-fix or a flag.

## What I recomputed against live bytes

| Claim | Result |
| --- | --- |
| Linux ZIP `e7da4896bbe29888382fdf4b29886a811a5c29a4fd99a707c2b3d95d9c943418`, 108,368,032 B | matches SHA256SUMS, ACCEPTANCE, RESULTS, REPORT |
| Windows ZIP `b41646efd844728adbfa6df934f73b2573c3de6853bea8c1072f00b32336a450`, 118,096,292 B | same |
| Shared pack `4bd3b6cf9350adeebd1e7f3838da5984385884cccfc43ecaac0be7105b496373` | extracted from both ZIPs; equal |
| ZIP entries 23 / 24, licence files 19 each | equal; Windows' extra entry is the official `.console.exe` |
| VERIFICATION.json `b6927faf…c473`, BUILD.json `f6dbac7e…626b`, SHA256SUMS `8c4a0fae…1113` | equal to ACCEPTANCE and the run3 negative receipt |
| 304/304 top-level checks | 304 entries, all `ok` |
| 15 packed routes, 90,410 ticks | sum of `exact_reference.ticks` = 90,410; every route has zero position/velocity/yaw difference, no game-difference ticks, a passing input-order audit, `finished`/`clean`, 0 respawns, a saved record, `record_ticks.clean_best / 128 = elapsed`; reload shows `records loaded` with the same best; old-round profile hashes unchanged |
| Route times in RESULTS.md table | all 15 match VERIFICATION.json exactly |
| 746/746 controls | curated `check/runs/controls/probe.json.gz`: 746 checks, all ok, 0 failures |
| Exported source | BUILD `source_tree f03a6ab3…` equals `git rev-parse 8a254d16:projects/foldrunner`; 923 files |
| Nothing shipped changed after 8a | `git diff 8a254d16 9b330d4c` touches only `docs/` plus two new files (`tests/r15_breakwater_f5_probe.{gd,py}`); the six helper hashes at HEAD equal BUILD `helpers_sha256`; `scripts/r15_main.gd` and `r15_source_player.gd` equal at 8a and HEAD and match F5-BREACH.md's table |
| Discovery trial applies to the shipped game | `git diff 406640de 8a254d16` outside docs/tests/tools is empty |
| Curation | CURATION.json.gz `6b6568c0…9d78` matches ACCEPTANCE; all 2,199 retained files exist with matching hashes; all 388 gzip copies decompress to the original SHA-256; retained bytes 154,113,978 as recorded; the 105 omissions are all intermediate PNGs |
| OS smoke `final-os-8a254d16/` | source, pack, Linux runtime and ZIP hashes equal the accepted ones; scope states no observer/override; I viewed `air-crouch.jpg` (in the air, CROUCH, 250 u/s) and `map-menu.jpg` (8 cards, F1 absent) |
| Negatives run3 | 78 passed, 0 failed, source 8a, all four candidate hashes unchanged after; `helpers_equal_current: true` |
| Earlier downloads | R12, R13-final and R14 ZIPs all pass `sha256sum -c` |
| Decision trail | 41 R15 rows from 2026-11-08T19:39:59Z, all with 6 fields |
| Branch | HEAD `9b330d4c` equals `origin/feat/foldrunner-me-build` |

## What I only read (not re-executed)

- What each of the 304 checks and 746 controls asserts, the 255/255 boundary suite and the 78 negatives: I counted and hash-matched them; I did not judge each assertion.
- The approved-movement parity (16,356 ticks): read `crouch-harness/approved-routes/RESULTS.json` (source `367c57fc`, after the last runner change `693e1c7a`) and `last-modules-integration/PRESERVATION.json`. The packed Penstock and Overflow F2/F5 lines repeat the same tick counts and finish times (3,814 + 6,271 + 6,271 = 16,356).
- F5 breach: read F5-BREACH.md and the decision row only. It is a source-mode controller line, disclosed as separate from the 15 packed lines everywhere it appears.
- Discovery (60 decisions, 4 misses, unfinished): read the child report in the transcript and the decision row.
- Lab-combined: its checkpoint sequence runs through the slide lane, the wall chamber and the grapple gap. I did not confirm per tick that each move fired.
- Licence contents and per-asset provenance: counted, not read.

## Transcript and trail reconciliation

The parent transcript was read from 2026-11-08T19:30:00Z only. Mike's single R15 message (19:36:32Z) matches BRIEF.md's requirements. Themes, the 45 s target and the slide-in-lab placement are correctly labelled as agent choices.

Superseded candidates match the docs. `40b8ee9b` was refused. `406640de` passed controls and was stopped. `03d970be` and `94dc47b1` were sent SIGTERM per `release-plan/SUPERSEDED-03-94.json`. The earlier OS smoke and the run2 negatives on `03d970be` were both redone on 8a (`final-os-8a254d16`, `run3-8a254d16`). No 03/94 artifact is cited as acceptance.

Every non-zero exit after 00:40Z is accounted for. The 00:46Z exit 130 was the deliberate cancellation. At 01:25Z an assertion failed on the single-`.exe` expectation, which DELIVERY.md discloses. The exits at 01:30Z and 01:35Z were bugs in root's own audit scripts (a list `.find` and a `KeyError: 'profile'`), and each was followed by a passing rerun. None hides a candidate failure.

Root told Mike at 01:33:18Z that R15 was "ready to try", before this review. The artifacts were already final, so nothing in that message needs to be withdrawn.

## Findings

1. **Fixed by this review: inspected frames preserved.** Root's transcript shows it viewed seven packed frames at 01:15Z and 01:22Z. Two of them, Breakwater `060_tick_03840.png` and Whiteout `084_tick_05376.png`, were curated out as intermediate frames, so they existed only in tmpfs `/tmp/r15-candidate-8a254d16`, which cleanup will delete. I copied their exact bytes, hashes `0c422b0f…5fed9` and `00b63b4b…bf74`, both equal to their CURATION entries, into `closure-review/inspected-frames/`. CURATION.json.gz and ACCEPTANCE stay unchanged. Root can now delete the candidate.
2. **Should-fix, doc only: BREAKWATER.md contradicts itself.** Line 162 still says "The F5 breach is unproven… shown on F2 only", and line 186 says "final packed acceptance remain pending". Both are superseded by line 208 and RESULTS.md. Mark them as superseded, or a later reader will cite them.
3. **Optional wording.** The outer REPORT says the OS smoke showed "an airborne crouch while hopping at 250 u/s"; it was the first jump from a run, HUD `last hop —`, and RESULTS.md's "airborne crouch at 250 u/s" is the accurate form. `delivery/spillway-r15/README.md` says "Linux was played on private AMD/X11"; "run with scripted input" avoids implying a human played it.
4. **Cosmetic runtime flags for a future round, not blocking.** The Movement Lab card repeats itself: "Experimental moves, not a course · Experiment · not a course" (packed HUD text and `map-menu.jpg`). `project.godot` still has `config/version="2026.11.08-r14"`, while the build identity is `-r15`. I did not check whether the Windows exe metadata shows it.
5. **Low: misleading negative-summary field.** `delivery-negatives/run*/summary.json` lists six of the suite's own logs under `scratch_left_at_end` on every run, while DELIVERY-NEGATIVES.md says scratch is removed. The run3 directory `/tmp/r15-negatives-mazi3o7z` no longer exists, so the field is a pre-removal snapshot. It is a hygiene label, not a leak.

## Storage at review time

- HOME had 16,171,573,248 B free, 15.06 GiB: only about 62 MiB above the 15 GiB floor. Any further render or export needs space freed first.
- `/tmp` is tmpfs (RAM). It holds about 1.4 GiB of R15 scratch that root's cleanup owns: `r15-candidate-{03d970be,406640de,8a254d16,94dc47b1}`, `r15-curated-8a254d16`, `r15-diagnostic-40b8ee9b`, `r15-negative-base-8a254d16` and about 20 small helper/bead files.
- No Godot, Spillway or Weston process was running.

## Flags for Mike

- The verdict on feel, map fun and the lab is yours; nothing here measures it. Windows has never been launched, and audio, gamepad and physical input latency are unverified.
- Sliding is only in the Movement Lab. Your message said sliding "could be good mechanic to introduce". If you meant it on the courses, say so.
- Weak spots to try first: Breakwater's earned breach (the F5 line is source-only, and a 60-decision playtest from the player's view never finished), Rainline's duct (slower than the normal route), the Sunken and Night Shift crouch options (save little), and Night Shift's earned landing (tight). Rainline (38 s) and Breakwater (44.6 s) also run shorter than the 45 s target the agent set itself.
- The grapple can exceed twice running speed by design. If Quit ever leaves the game running, close it: finish records are already saved.

## Evidence

Outer `checkpoints/spillway/r15/closure-review/`: `REVIEW-CHECKS.json` (recomputed values), `inspected-frames/` (two preserved PNGs) and `SHA256SUMS`.
