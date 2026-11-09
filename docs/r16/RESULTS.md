# Spillway R16 release results

R16's accepted game and delivery helpers are commit **67e608a0f2b9dbb31b31ff8f63bdc3fd8491a1e3** on `feat/foldrunner-me-build`. Later commits contain tests, reports and the decision trail. The round is bead **ccChat-general-41fq**. The approved course runner, Source law, five themed base maps, their art/assets and the retained maps remain the R15 reference. Optional R16 passages have their own overlay identity.

The final official Linux release runtime passed **354/354 package checks**, including **771/771 native menu/control assertions** and 16 clean play/save/reload cycles. All **98,465 packed trace ticks** match the fresh source executor in position, velocity, yaw, pitch, timing and progress, with no tolerance or tick exception. Fourteen routes also match the retained R15 inputs/references. The two new routes exercise the R16 style passage and changed lab rules. Trace counts include their captured setup/finish tails; recorded attempts seal at the finish.

This establishes the listed scripted behavior and exact delivered bytes. Mike decides how the new scoring and moves feel. Windows has not been executed.

## Artifacts and provenance

Portable downloads, BUILD.json, unchanged VERIFICATION.json, SHA256SUMS and root's ACCEPTANCE.json are in outer `delivery/spillway-r16/`. Each ZIP includes its official release runtime, shared game pack, README, embedded BUILD and licences/provenance. The Linux executable mode is preserved. Neither ZIP contains the probe override, loose game scripts or the editor.

| Item | SHA-256 |
| --- | --- |
| Linux ZIP | `f8ae42da4c55d9675056033a462310642519bba194001ecfa92c03058a841320` |
| Windows ZIP | `e7892c682a43be0ec627b3a8b35aacb5a92092b9f535650a4cec59198ce20801` |
| Shared pack | `845d727694efee6bbbf143d770db7a9971ecd2e69124949064945265701493f1` |
| Linux release runtime | `d9f79ab89b5ae369aeed11c6052d402e8218cd503bf85b4a235f9c30c46a7c63` |
| Executed packager | `734c7364f453b70bc3c8c9d7834181844aca3513e43880b61c0a9808807bcf9e` |
| Executed probe | `1a9e1ce7a55f446b49cb33587f073932a7d89bc934387eb810759a9a2a8322fe` |

The Linux checks run from an external empty working directory. An isolated harness hard-links the extracted runtime/pack and adds only a test autoload; shipped directories stay unchanged. Separate normal-release OS input runs without that autoload. Source, archive, project file list, licences, helper hashes and embedded/external manifests reconcile against Git and independently pinned official Godot 4.7.2 runtime digests. The two ZIPs contain the same pack. Re-exporting the same source is not byte-reproducible, so the checksums identify these particular downloads.

## Packed play results

Each row is input-only through the real shipped R16 main, on private AMD/X11 at its declared rate. Every row finishes clean with zero respawns, ordered checkpoints, exact input/order/hull-origin coverage, a sealed recording validated by both readers, saved integer time/splits/style and a fastest-run ghost restored in a separate launch. Reload does not rewrite config. Old-round profiles remain unchanged. All runs exit 0 and the private display is released.

| Route | Preset | Time (s) | Style | Exact trace ticks |
| --- | --- | ---: | ---: | ---: |
| Breakwater ordinary | F2 | 44.6015625 | 937 | 5,777 |
| Whiteout ordinary | F2 | 62.296875 | 890 | 8,037 |
| Sunken Court ordinary | F2 | 47.53125 | 2,527 | 6,137 |
| Rainline ordinary | F2 | 38.21875 | 566 | 4,949 |
| Night Shift ordinary | F2 | 57.546875 | 124 | 7,430 |
| Penstock advanced | F2 | 28.609375 | 11,013 | 3,814 |
| Overflow | F2 | 45.9609375 | 294 | 6,271 |
| Overflow | F5 | 45.9609375 | 294 | 6,271 |
| Whiteout gantry crouch | F2 | 61.984375 | 1,790 | 7,997 |
| Sunken causeway hop | F2 | 47.0390625 | 3,615 | 6,074 |
| Rainline duct | F2 | 43.1796875 | 731 | 5,611 |
| Night Shift shutter | F2 | 57.203125 | 1,370 | 7,385 |
| Night Shift earned | F5 | 42.6796875 | 590 | 5,527 |
| Breakwater physical miss and return | F2 | 55.4765625 | 805 | 7,169 |
| New Whiteout apron crouch-save line | F2 | 63.3671875 | 1,790 | 8,138 |
| New lab flow | F2 | 14.4609375 | 1,631 | 1,878 |

The new Whiteout line earns a real 900-point airborne apron save plus five gap rewards. The lab line chains bhops, a held-Space landing slide, a fresh hop, two chamber kicks with A/D held and the inherited E grapple. The old R15 combined lab tape intentionally diverges when the new wall budget refuses an old extra kick; the old lab runner inside the R16 host remains an exact control. This is an intentional lab-rule change, not an approved-course regression.

The complete positive probe also checks all eight maps and 30 supported map/preset identities, checkpoint practice, clean eligibility, crouch/standing clearance, switches, time/style separation, lab loadouts, recording lifecycle, G/menu ghost controls, corrupt/wrong-identity ghost refusal, full plain-label glyph layout and renderable map surfaces. Its 771 assertions are nested within the 354 outer package checks, not 771 extra independent package runs.

## Source, scoring and preservation

Outer `checkpoints/spillway/r16/final-source-67e608a0/RESULTS.json` passes all nine source steps. `FINAL-SOURCE-AUDIT.json` independently totals 16 routes and 98,465 exact ticks. The gates include 456 frozen-R15 preservation checks, the actual R16 feature probe, 60 real-collision style assertions, 199 actual-host lab assertions, 118 loop checks plus 13 copied-folder driver checks, the 59 Godot/38 Python recording suites and 49 focused delivery negatives.

The style suite uses actual collision and independent authored dimensions: 4.000 u crouch room, 4.5365 m measured gap against 4.5367 m, 3.002 u edge slack and 2.969 u near-miss clearance against 3 u. A thread differs from its designed width by 2.4 mm, not yet isolated. Negative controls include idle, crawling, roomy gaps, bonk-then-duck, scraped obstacles, repeated routes and 100% sync with no gain. A later host review found a crouched beam hit could still pay; repaired `r16-style-2` pays zero after that hit while a clean passage still pays. The first finish sample scores once, with a 33-point finish-hop reward reaching the best and recording, then scoring seals.

Source files for the R15 base maps and movement are unchanged. Three optional ordinary solid passages are appended separately: two on Breakwater and one on Whiteout. Base geometry and overlay identities remain separate in time/style/recording/ghost keys. Builder comparisons preserve movement across 93,848 samples; ten pre-existing floor-seam contact-report rows differ without movement differences. The final 14 retained course routes remain exact. No existing line was moved to make the new passages mandatory.

Scoring weights, the 1.25 m maximum gap landing drop, combo rules and lab protections are labelled game choices. Some genuine larger drop jumps deliberately do not receive a gap reward. Side-edge landings, long wall hugs and wall-jump/grapple-specific style bonuses are outside the detectors. Speed points can occur before a later fall; the fall makes the attempt ineligible for clean bests.

## Recordings, analysis and ghosts

Every timed attempt, restart, practice, map/preset/loadout boundary, fall and Quit is covered by lifecycle tests. Pauses are events. After a finish the sealed file stops, so untimed exploration is excluded. The recorder samples after the actual motor and stats. Source and packed audits independently reconcile every recorded motion/view/clock/input field, live style event and sealed total. The Godot and Python readers agree on binary columns and input order. A folder containing 39 source recordings passes copied-folder checks; the actual normal-release OS recordings also pass the folder CLI and both readers.

The format is documented in [RECORDINGS.md](RECORDINGS.md), with corruption/partial recovery and a standard-library folder analyzer. Hash chains detect accidental damage, not forgery. Partial recordings can lose their unflushed tail, up to two seconds, and are never ghost/best candidates. Real write refusal is exercised; the host reports the error, counts continued dropped ticks and keeps playing. The ghost fully validates a sealed clean run of the exact motion identity, independent of scoring version; it is nonphysical and hides near the camera or during later-stage practice.

The root repair reduction passes 79 integrity/ghost controls, including malformed counts, duplicate/missing ticks and invented zero-time bests. The original 59+38 suites remain green. The independent verifier review's altered mouse and impossible-style counterexamples are repaired and rechecked at 42/42, with 28 existing delivery and 79 integrity controls. Delivery observation protocol 2 compares raw input and live score events independently; player format stays version 1. Neither generic reader claims to authenticate a forged file.

## Native presentation and OS input

[NATIVE-ACCEPTANCE.md](NATIVE-ACCEPTANCE.md) records 15,793 exact moving source ticks across complete Breakwater, Whiteout and lab routes, plus 830 exact same-input ghost-overlap ticks. Actual player-camera images show the style panel/callouts, optional passages, finish bests, ghost near fade and G switching. Final HUD-only `34fb79a4` words are separately inspected; all three current-UI checks pass. That HUD is byte-identical in the final export. Root also inspected final packed Whiteout style/ghost-best and lab slide/finish frames; their retained paths are indexed in the final package evidence.

[RELEASE-OS-INPUT.md](RELEASE-OS-INPUT.md) covers an ordinary, uninstrumented Linux launch of these exact ZIP bytes: 12/12 synthetic XTest OS-input checks, 668 recorded ticks agreed by both readers, 22 airborne-crouch ticks, R, G, menu Quit and AMD graphics activity. No probe or fixed physics scheduling was added to that player launch. This is a short input smoke check, not a completed course or a physical-device latency measurement.

Two source-native instrumented runs logged ObjectDB warnings (four and six objects); the verbose lab repeat was clean. Cause is unresolved and tracked in **ccChat-general-77n3**. They are not erased by the final package's clean logs. The final packed controls, play/reload runs and normal OS smoke exited cleanly with no engine errors. Private rendering used X11; forced private Wayland's historical engine teardown race is not fixed here.

## Negative controls and retained failures

[PORTABLE-NEGATIVES.md](PORTABLE-NEGATIVES.md): all 96 controls pass on the exact final ZIP/helper bytes. These include static/provenance/preflight lies, five actually exported broken games on AMD, disabled or false recordings, a hidden style label, wrong records/key and wrapper-only SIGTERM cleanup. All expected refusals were declared before execution; no unrelated baseline failure counts as a pass.

Earlier attempts remain labelled: a26 export ended SIGTERM 143 before acceptance (cause unknown); its retry was rejected for an unnecessary startup module requirement and a lab test that restarted at the hub instead of remaining at the chamber. The first final-byte negative invocation damaged only its own negative baseline because its test callback targeted the wrong directory. Root verified the separate positive export unchanged, restored the baseline, fixed the harness and reran all 96 controls, including real hard-link isolation. Normal OS attempts one through three retain a bad test ZIP, a stdout-readiness/cleanup-order error and controls sent before sustained physics; the fourth waits for actual ticks and passes. No production change was made to hide those harness failures.

## Evidence and limits

Outer `checkpoints/spillway/r16/final-package-67e608a0/README.txt` indexes the complete final package evidence. `ROOT-AUDIT.json` reconciles routes, checks and byte identities. `CURATION.json.gz` maps every original evidence file to its identical or verified lossless-gzip copy; `ALL-FILES.sha256` covers the kept tree. Selected PNGs, sparse movies, complete recordings, profile configs, probe observations and source/reference traces remain. Historical absolute `/tmp/r16-candidate-67e608a0/evidence/` paths map to that retained directory. Transient source/import/shader caches and owned scratch are removed. HOME was checked above 15 GiB before each large export/native run.

Other retained evidence: `style/`, `host-review/`, `host-repair-final/`, `record-integrity/`, `verifier-review/`, `verifier-repair-recheck/`, `player-routes/`, `native-acceptance/`, `release-os-smoke4/` and `portable-negatives/final2-67e608a0/`. Reports preserve their original failure scope rather than treating earlier source checks as exported acceptance.

The three complete source-gate runs also have `LOSSLESS-RETENTION.json`: large diagnostic text was verified, gzipped and compared byte-for-byte before its raw copy was removed. Small entrypoint summaries remain at their original paths. Use the manifest when a cited large JSON is now stored as `.json.gz`; this changes retention only, not an executed verdict.

The final R12–R15 downloads remain unchanged and R15's guide is preserved as outer `REPORT-R15.md`. R16 writes only its own config/recording namespace, apart from read-only look-setting seeding. Native Windows, physical-device latency, audio listening, gamepad use, cross-machine deterministic replay and Mike's verdict on the new work remain unverified. The separate Blend C look experiment is not part of this build.
