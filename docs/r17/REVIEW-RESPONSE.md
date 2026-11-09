# R17 response to the visual review

Parent response, not a second Opus approval. The original review assessed runtime `9170857f1` and earlier stills. The changes below are in frozen runtime `b406e2d2a`. Mike still decides visual taste.

| Finding | Change and current evidence |
| --- | --- |
| Functional markings erased | The inherited strips keep their original geometry and width. Yellow/hazard/lip markings use the lip colour; practice timing pads use a distinct muted warm value, with bright start bars and orange landing nosing. `scripts/r17_look.gd`; `evidence/r17-views-final/practice/route-new.png`. |
| Ten-centimetre flat jump lips | Independent jump lips now have a 30 cm top band and a 14 cm vertical face. They remain visual meshes only. `scripts/r17_contours.gd`; `tests/r17_visual_invariants.gd`. |
| Floating ink and landing seams | Ink now uses the union of visible flat prisms. Imported-model collision proxies are excluded. The original merged-mesh maps use their directly drawn manifest pieces. A synthetic overlap/hidden-proxy fixture checks that only four outer boundaries remain. `evidence/r17-readability-fix/area-invariants/summary.json`; `evidence/r17-views-final/sunken-court/{spawn,route}-new.png`. |
| Indoor navy collapse | Walls, ceilings and housings use distinct values and directional normal bands. The first fix missed Whiteout's area-suffixed mesh names; native motion exposed that, and the corrected matcher is tested against five actual hangar/shed meshes. `whiteout-area-miss.log` and `area-invariants/summary.json` under `evidence/r17-readability-fix`; final Whiteout spawn still. |
| Night Shift splash | The native clip helper trims from the first actual game draw. All eight final-source clips pass the hash/backend/speed/dimension checks. Their opening frames show game footage, including Night Shift; the motion contact sheets contain eight actual frames without padding. |
| Wrong still dimensions | The actual PNGs are 1296×736. Movies are 1280×720 at 60 fps. `evidence/r17-views-final/PARENT-AUDIT.json` checks every pair's dimensions, identical camera/FOV, backend, source hashes and cleanup. |
| False transcript milestones | `evidence/r17-trail-self-audit-correction.json` supersedes the substring search with successful structured tool outputs and call IDs. The old matches included shader constants and base64; they were not milestone proof. |
| Untracked parity helpers | All four original helpers were rehashed against the completed proof and committed without changes in `eece4e649`. |

The original floating-ink fix was incomplete, and removing functional markings was not a decorative cleanup. Both are corrected in the append-only decision trail. The earlier review and rejected evidence are retained as history, not presented as final-source proof.

The final source suite passes 1,873 checks, including geometry/live-state/reference restoration and actual indoor material bindings. All 475 protected R16 runtime/asset files remain unchanged. The separate final gates now pass: b406 all-map replay/ghost parity, exact-release Linux portable acceptance, and the paired desktop GPU run. Parent hash/statistics audits are in `evidence/r17-b406-parity/PARENT-AUDIT.json`, `evidence/r17-final-package-parent-audit.json` and `evidence/r17-desktop-gpu-final/PARENT-AUDIT.json`. Windows remains static-only. Two earlier L screenshot failures remain unexplained; the final independent no-probe fast/held checks pass.

Remaining artistic gaps: the container yard is largely one teal family, the ruins use a simpler material treatment than the painted reference, Rainline reads as stormy dusk, and Overflow has the busiest sky. Detailed chipped paint, authored water glints, landmark reconstruction, higher-resolution panoramas, hands and characters are outside this rollout. The comparison and motion evidence are for Mike's judgment, not a model claim that the result looks good.
