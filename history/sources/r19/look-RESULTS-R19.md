# Spillway R19

**R19 delivered: all five items reached, portable and full source checks passed.** The focused ghost-name/path repair passes 121 headless and 121 native Linux checks. The rebuilt Linux portable passes 1,980 exact-release checks, including actual name typing. Both ZIPs pass static verification; exact Windows PE/PCK startup passes under Wine. The earlier candidate is withdrawn and retained. The final 48-play matrix passes against exact R18; the feature and gameplay branches share the final documentation commit after normal fast-forward promotion.

## Try first

Open Esc and choose **Saltglass**, on F2. It is a two-fin surf course with descending bhop links. The earned scripted route finishes in 61.265625 seconds on the unchanged Source motor. That is a reference route, not a promised first-play time. Steer on the steep face, then use the cream decks between fins. The lower catches and ramps provide physical recovery, with partial coverage rather than a guarantee for every miss.

Then choose **Tether Yard**, **Line Drive** and **Fall Line** under Esc → Experiments. Each has its own experimental rules; the original maps retain their movement. R restarts, F returns to a checkpoint, L compares looks, and F9 shows telemetry. The original Movement Lab remains available.

## Mike's four asks

- Sustained backwards bhops at 300+ u/s earn a growing ×2–×4 direction award. Half-sideways chains earn ×1.2–×1.8. Real jumps, useful travel, brief ground contact and fresh landing spots are required. Standing, slow hopping and revisiting the same scoring spots do not qualify. Direction score has its own identity; time/movement identity remains separate. The R18-style HUD shows the award.
- Penstock and Overflow subtitles now describe the courses rather than development rounds.
- Mouse sliders are inside the pause menu's initially collapsed Advanced section. Their existing settings and bindings persist.
- The Look C label follows F9 telemetry. L still switches looks.

Earlier component checks: 25 new scoring checks, 60 inherited style checks and 2,008 exact forward-scoring observations. Exact release coverage is listed below.

## Changes supported by the playtest

All 32 recordings were read with the project's strict reader. Their actual presets are **29 F2 and three AA1000**, rather than 32 F2. There were no F2 respawns in this sample. Breakwater had the most attempts/restarts; Night Shift had the most recorded physics time. Neither proves enjoyment or frustration.

The only geometry change is Breakwater's optional RunwayThread opening: 1.05 m → 2.05 m, moving each wall out by 0.50 m. Two F2 attempts hit its opposite walls at 901.8 and 802.7 u/s. The faster east-side skip remains clear. Decks, checkpoints, finish and bounds are unchanged. The physical-query fixture passes 45 checks; it is not replay of Mike's input. The map/overlay revision is `r19-breakwater-flow-1`, and old ghosts show an older-map warning instead of racing this geometry.

No speculative change was made to the other original maps. The full per-map losses, stops, lines, style events and lifecycle counts are in [the analysis](/home/thatmike1/foldrunner-build-2026-11-05/playtest-r18/ANALYSIS.md).

## Race a friend

Finish a clean R19 run. In Esc, expand **Race a friend (ghost files)**, enter a player name and press **Export my clean best**. Send the resulting `.spillghost` file yourself. Your friend drops it into the visible **ghosts** folder beside the extracted executable, presses Refresh and selects the named time. Open ghosts folder opens that location; its path can also be selected and copied. Nothing uploads automatically.

One friend is selected at a time. Local PBs remain separate. Different builds, maps, movement identities and geometry revisions show compatibility notes. Existing compatible local ghosts remain usable; exporting requires an R19 clean recording. The release folder must be writable.

The actual official Windows executable ran under Wine, reporting Windows. Two real recording inputs passed 158 service/reader checks across Linux → Windows → Linux, preserving sealed bytes, Unicode name, identity and finish time. One input is a labelled earned loop fixture; the other is a completed Tether Yard recording. This is **Wine execution, not native Windows gameplay or feel verification**. The final Windows ZIP also passed exact PE/PCK startup under Wine, including direct launch of the extracted `SpillwayR19.exe` from an empty working directory. That startup check does not run the Windows friend menu.

## New courses

| Course | How to reach it | Pitch and model read |
| --- | --- | --- |
| Saltglass | Esc → maps | Steep surf fins linked by bhops. My hypothesis is that long fins teach sustained steering and the links let you keep speed; Mike decides whether the mix flows. |
| Tether Yard | Esc → Experiments | Three grapple transfers, catch courts and return ramps. My hypothesis is that choosing a release is the interesting part; anchor visibility and reach need human judgment. |
| Line Drive | Esc → Experiments | Three line-sensitive launch pads around a circuit. My hypothesis is that landing aligned makes speed feel earned; whether automatic launches are satisfying is untested. |
| Fall Line | Esc → Experiments | Seven contact-triggered decks drop after two seconds, with solid rests and a lower recovery route. My hypothesis is that the warning creates useful pressure; it could also feel rushed. |

All four are playable source-course prototypes with earned clean finishes and fixed-input replays. No human enjoyment verdict is claimed. Saltglass uses the unchanged F2 body; Tether and Line Drive have explicit map-specific runner identities. Fall Line changes its world on a deterministic paused-aware clock while retaining the F2 body. Returning to the main maps restores their runner and laws.

Production/native evidence: Saltglass 21 checks / 7,868 samples; Tether 25 checks / 1,695 samples; Fall Line 35 checks / 3,042 samples; Line Drive 36 checks plus 96 geometry checks / 1,705 samples. Old/new native captures match their headless replay fields exactly. Those course captures are **1296×736**. All 12 maps passed 2,203 inherited visual invariants. Staged directional-HUD frames passed 12 layout checks at each of 720p and 1080p; they prove presentation, while the separate earned-hop fixtures prove the awards. These are scripted verification facts, not performance, latency or player-feel claims.

## Final acceptance

| Gate | Current status |
| --- | --- |
| Protected F2 sources | Six source hashes equal R18; all 1,203 pre-existing project files checked against the six exact allowed presentation/scoring edits |
| Existing-map parity | All 48 fresh plays across 16 routes / eight original maps pass. Independent audits: 940 candidate, 523 baseline and 311 postflight checks. All 240 raw streams rehash; zero physical tolerances or exceptions |
| Independent review | Bounded GPT runtime and delivery reviews complete; selectable folder path, actual-name input and strict three-to-five experiment gate fixed; exact portable acceptance and full source matrix passed |
| Exact Linux package | Passed 1,980 native checks: startup 80, controls 1,598, play 203, reload 99. All 5,777 trace/input ticks match exactly; 164 recordings / 9,343 ticks audited. Four broken-pack/sky cases exit nonzero |
| Windows ZIP | Hashes, CRC, official runtime, licenses and shared PCK verified. Exact PE/PCK startup under Wine passed, including direct extracted basename; native Windows unverified |
| ZIP checksums / branch promotion | Both SHA256 checks pass; feature and gameplay branches converge through normal fast-forward. The receipt records the exact promoted head |

## Five taste calls

1. Is Saltglass's fin length and bhop/surf balance worth extending?
2. Is the backwards bonus large enough, and is the smaller sideways bonus proportionate?
3. Keep Tether Yard? Judge grapple reach, release timing and target visibility.
4. Keep Line Drive? Judge the alignment windows and the automatic launch reward.
5. Keep Fall Line? Judge the two-second warning and countdown position.

All five spec items were reached. Three experiments were chosen, within the requested three-to-five range; no fourth or fifth experiment was started. No spec item was left unreached. Remaining feedback is Mike's play judgement. Directional surf seam relief and the limited sampled recovery coverage are disclosed in the course documentation. No desktop GPU performance claim or native Windows execution claim is made for R19.

Full source parity additionally audits 426 lifecycle recordings, 295,719 observed ticks and 215,022 ordered input rows, including ghosts and moving/paused L dispatch. The two retained Breakwater tapes avoid the edited gate, so they need no geometry exception. Exact separate-source contact queries cover that intentional edit. Raw parity proof is durably archived with per-file verification; [the report](/home/thatmike1/foldrunner-build-2026-11-05/look/evidence/r19-final-parity/REPORT.md) and [archive receipt](/home/thatmike1/foldrunner-build-2026-11-05/look/evidence/r19-final-parity-archive/ARCHIVE.json) retain provenance and reproduction. [Promotion receipt](/home/thatmike1/foldrunner-build-2026-11-05/look/evidence/r19-promotion.json) identifies the final branch head. Later commits change verification or documentation only, preserving all 554 frozen runtime files.

Decision trail: `decisions.tsv`. Independent review: [REVIEW-R19.md](/home/thatmike1/foldrunner-build-2026-11-05/look/REVIEW-R19.md), by gpt-6.1-terra, explicitly a same-family GPT review under the GPT-only instruction.

Portable source: `5dcc94967c19cf1333797ce8fc26f36a8f860ce5`. Both ZIPs use PCK `0e64ec5ec069d28007f5e9b62332220f6a51d04e6105c2e358a3c48726ff4eb7`. [Linux ZIP](/home/thatmike1/foldrunner-build-2026-11-05/delivery/spillway-r19/spillway-2026.11.09-r19-linux-x86_64-5dcc9496.zip), [Windows ZIP](/home/thatmike1/foldrunner-build-2026-11-05/delivery/spillway-r19/spillway-2026.11.09-r19-windows-x86_64-5dcc9496.zip), [checksums](/home/thatmike1/foldrunner-build-2026-11-05/delivery/spillway-r19/SHA256SUMS), [portable verification](/home/thatmike1/foldrunner-build-2026-11-05/delivery/spillway-r19/VERIFICATION.json), [Windows Wine scope](/home/thatmike1/foldrunner-build-2026-11-05/delivery/spillway-r19/WINDOWS-WINE.json).
