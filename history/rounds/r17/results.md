# Spillway R17: paint and ink across every map

All eight playable maps have Look C. Final-source parity, exact-release Linux acceptance and desktop GPU verification pass. Linux and Windows ZIPs are built; Windows native execution remains unverified. Publication uses a normal fast-forward of the gameplay branch, recorded in `evidence/r17-promotion.json`.

Press **L** during play or pause to compare Look C with the original R16 presentation on the current map. Look C starts enabled. Use the existing Esc map menu to visit all eight maps. R16 movement, style points, automatic recordings and ghosts remain inherited; this round does not establish Mike's verdict on those features. Movement Lab still identifies itself as EXPERIMENTAL.

## What changed

Cream landing planes sit against darker sides, with fading ink on selected structural boundaries, flat toon bands and one static painted sky per map. Water uses a sea-glass palette. Existing map geometry, functional lamps and weather remain.

The visual review caught erased functional markings, thin lips, hidden collision ink and flat indoor values. The corrections preserve the original timing/edge/hazard-strip geometry, keep practice take-off pads distinct, and give independent orange jump lips a 30 cm top band plus a 14 cm face. Ink follows unions of drawn coplanar prisms rather than imported-model collision proxies. Walls, ceilings and housings have separate values, including Whiteout's area-scoped hangar/shed meshes. See REVIEW-R17.md and the parent response, REVIEW-R17-RESPONSE.md. The response is not another Opus approval.

| Map | Current treatment | Measured input-excerpt peak |
| --- | --- | ---: |
| Breakwater | Port decks and weathered teal sides | 355 u/s |
| Whiteout Relay | Cream routes, cool snow and separated indoor values | 331 u/s |
| Sunken Court | Cream landings, warmer muted stone and sunlit clouds | 370 u/s |
| Rainline | Pale roofs, slate sides, rain and stormy dusk | 393 u/s |
| Night Shift | Pale platforms, dark trains, city windows and indigo sky | 521 u/s |
| Penstock Yard | Practice blocks, distinct timing pads and orange nosing | 937 u/s |
| Overflow | Warm dam decks, sea-glass water and afternoon clouds | 320 u/s |
| Movement Lab | Separate room values and retained movement-surface markings | 594 u/s |

Seven new sky paintings were generated from retained text-only prompts. The original Breakwater panorama and painted wear remain. Asset hashes and provenance are in `assets/look/PROVENANCE.md` and `assets/look/r17/PROVENANCE.md` and their manifests. Private concept art was not an image input and is not committed or shipped. Existing third-party assets retain their licences.

## What is verified now

The runtime is frozen at **b406e2d2ad62e7353861b6aefdc9534702d1a4eb**. R16 merge baseline is 7261ba593; merge fc2d16bd6 preserves the delivered host. All 475 protected R16 runtime/asset files remain unchanged. The final source suite passes **1,873 checks**, including real L dispatch, collision/progress/live-state/identity snapshots, exact original material/environment/light restoration, title and HUD clearance, functional cue colours, an overlapping-deck/hidden-proxy ink fixture and five actual Whiteout indoor material bindings. See `evidence/r17-readability-fix/area-invariants/summary.json` and `evidence/r17-trail-self-audit-correction.json`.

There are **17 matched native 1296×736 old/new pairs**, covering entry and route cameras on every map plus the Breakwater concept angle. Camera/FOV match. Parent rechecked 2,072 captured source-file hashes and all eight AMD/display-cleanup receipts. `evidence/r17-views-final/PARENT-AUDIT.json` and SHA256SUMS bind the evidence. The comparison page uses smaller JPEG previews; the PNGs remain authoritative.

There are **eight silent native 1280×720, 60 fps run excerpts**, driven by retained input with the actual player camera and inherited HUD. Every input excerpt reaches 300+ u/s. Parent checked all eight opening frames and 64 motion samples: game footage, no splash or padded contact cells. The final Whiteout room values, practice timing pads, landing faces and quiet ink are visible in those samples. These are short excerpts, not complete clean-finish movies or a player taste verdict. Night Shift uses the retained F5 earned route. Overflow uses the delivered F4 Quake III preset because its retained F2 route reaches only about255u/s; the other clips use F2. See `evidence/r17-movies/{summary.json,PARENT-AUDIT.json,CONTACT-INDEX.json,SHA256SUMS}` and `r17-<map>.mp4`.

## Final acceptance

The final b406 proof passes **24 fresh R17 plays across all eight maps**, with old, new and actual moving-and-paused L modes. All **129,270 physics/live-ghost sample pairs** match exactly. **90,123 aligned recorded-input rows**, **846 host assertions**, **299 independent audit checks** and **104 mutation checks** pass. Sixteen R16 baseline plays were reused only after independent semantic and byte validation; all 246 baseline artifacts match before/after. Parent rehashed all 552 owned files and independently checked the audit. See `evidence/r17-b406-parity/{README.md,POSTFLIGHT.json,PARENT-AUDIT.json}`. This is headless Linux source evidence. The original full sixteen-route matrix (80 plays,492,325 samples) remains a broader historical proof on7c82e0877; it is not relabelled as a final b406 run.

The **exact exported Linux release passes 1,670 committed native checks**: controls1,382, clean play190 and reload98. Its 5,777 packed/source/input trace ticks match exactly, with a clean **44.6015625s / style937** Breakwater finish and real ghost reload. Both independent recording readers pass128 recordings/8,734 ticks. An additive observer passes2,360 checks in total, including690 label checks across138 frames. Independent ordinary-release OS input passes13/13 fast-key and19/19 held-key checks. These totals overlap; they are not added together. All475 protected files and30 supported identities match R16. Missing/malformed packs refuse with nonzero exit; missing critical sky exits3 before host startup, including `--look=old`. Parent independently rehashed799 retained evidence files and reran static package acceptance. See `../delivery/spillway-r17/VERIFICATION.json` and `evidence/r17-final-package-parent-audit.json`.

Two L screenshot comparisons failed on an earlier917 candidate, followed by successful repetitions. Their cause remains **unexplained**; no diagnosis or confirmed fix is claimed. Those rejected attempts and later diagnostic observations remain retained. The final b406 ordinary-release fast/held checks passed independently. Packaging also found and fixed the missing EXPERIMENTAL title and a release-stripped sky assertion before this accepted candidate.

Both ZIPs pass SHA256, CRC, source/build identity, official release-runtime, PCK and31-licence checks. Linux was executed natively. **Windows was verified statically, not executed on Windows.** No Windows environment was available; Linux results do not establish Windows startup, rendering or input.

## Desktop GPU cost

The exact delivered PCK was measured with the official Linux release executable on **RTX2070SUPER / NVIDIA595.99.02**, outside source. All16 map/resolution runs pass: **16,320 samples**,17views, two alternating look orders,40warmup and120measured frames per look/view/order, vsync off. Actual720p/1440p viewport dimensions and all136 camera/FOV records match the final native views. Parent rehashed123 transferred files, matched every CSV sample to raw performance JSON, and independently recomputed all GPU/CPU/frame medians,p95,deltas and ratios.

New-look GPU median andp95 are lower in **33/34 view/resolution groups**. The one increase is **Rainline route at720p: median0.831→0.837ms (+0.006ms, +0.72%); p950.839→0.845ms (+0.006ms, +0.72%)**. This reports the measured difference without a statistical-significance claim. Every CPU/frame increase and each separate order is retained in the full report. Fixed paused views do not establish moving frame pacing or physical input/display latency. The earlier5e1004fd benchmark remains historical, not substituted for this release.

Route-camera GPU medians in milliseconds:

| Map | 1280×720 old → new | 2560×1440 old → new |
| --- | ---: | ---: |
| Breakwater | 0.914 → 0.534 | 2.204 → 1.017 |
| Whiteout Relay | 0.569 → 0.352 | 1.569 → 0.777 |
| Sunken Court | 0.366 → 0.294 | 0.798 → 0.583 |
| Rainline | 0.831 → 0.837 | 2.234 → 2.053 |
| Night Shift | 0.625 → 0.415 | 1.609 → 0.892 |
| Penstock Yard | 0.387 → 0.308 | 0.963 → 0.665 |
| Overflow | 0.446 → 0.371 | 1.326 → 0.786 |
| Movement Lab | 0.485 → 0.315 | 1.617 → 0.703 |

Full evidence: `evidence/r17-desktop-gpu-final/{report.md,analysis.json,raw-samples.csv,round-comparisons.csv,PARENT-AUDIT.json}`. Private displays/scratch were removed and main applications and monitor configuration preserved. Three transient PID exits are recorded without attributing their cause.

## Delivery

Frozen runtime source: `b406e2d2ad62e7353861b6aefdc9534702d1a4eb`. Subsequent verification-tool and documentation commits leave the shipped runtime unchanged; a final manifest check binds them to this runtime. Linux and Windows portable ZIPs, `BUILD.json`, `VERIFICATION.json` and `SHA256SUMS` are in `../delivery/spillway-r17/`. The desktop also has a clean executable Linux extraction at `../delivery/spillway-r17/playable/SpillwayR17-linux-x86_64/SpillwayR17.x86_64`.

```text
Linux   c31111bec348b1181477ef36a6eb128cb60db07c97f86e53a49221ed5e65fb34
Windows 2cff94459dba1d54020576c8877da7321e69fd2a0a8f78a92253d5604cfbeb47
PCK     23b31ec47e32af8031f854a1f18143a5ce861904d70bc8694a85ebda518ffeb2
```

## What Mike decides and what remains

Mike decides whether the shared language and landing-edge reading hold up while he plays, especially Sunken Court's warmer stone and Rainline's stormy dusk. The implementation and model review make no claim that it looks good. R16 feedback remains a separate question.

The container yard is largely one teal family, and Overflow has the busiest sky. Detailed chipped paint, landmark reconstruction, authored water glints, higher-resolution panoramas, hands and characters are not included. Other maps now have the shared rendering layer, so further art can be tuned per palette/material role without changing their collision or movement contracts.

`decisions.tsv` records choices, rejected approaches, review corrections and resource cleanup. `REVIEW-R17-RESPONSE.md` distinguishes the original review from the later fixes. The final requirement audit and branch-promotion receipt bind the published source to the tested runtime. Visual taste and R16 feedback remain Mike's, not automated acceptance claims.
