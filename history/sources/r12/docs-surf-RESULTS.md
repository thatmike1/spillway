# Spillway r12 evidence

Runtime revision `f84e175d53a4a259330969c83edaa929d8d02f5c`, PCK SHA-256 `206baad942f7e41a36ad09d043e33b19aa7ce52427575c3188ebb4f7cafcd074`. Later documentation commits do not change the delivered runtime. Canonical artifacts live in the outer build directory, `checkpoints/spillway/r12/`. Final Opus 5.5 closure review found no material blocker. The seven doc-only findings are resolved in outer `closure-review/ROOT-RESPONSE.md`; the delivered runtime is unchanged.

## Movement and course

All values are P / game choices, independently implemented projection-based air acceleration. Run 8.5 m/s; gravity 20 m/s²; jump 7.2 m/s; air wish projection cap 0.75 m/s and acceleration 12; horizontal cap 30 m/s; floor threshold 46°; ground overspeed decay 8 m/s². Autohop is enabled by default and runs before landing friction. Sliding water adds only 0.25 m/s² drag. The 16 m/s slide limit caps downhill additions, preserving earned hop speed. Held autohop cannot steal a mantle; a fresh press can catch below 10 m/s.

Exact-pack input-only fixture proof is in `final-verification/test_spillway_surf/motor-proof.jsonl` and `motor-proof-summary.json`:

- First five completed strafe-hop arcs: 8.50 → 14.10 m/s. The full fixture includes an initial launch plus five rehops, six arcs, ending at 15.16. `hop-arc-audit.json` is root post-analysis of the raw trace, not an output produced by the suite, and retains the count correction. One arc logs adjacent jump events on two ticks; its apex remains the same 1.328 m as the others. This is a retained event-count quirk, not evidence of an extra jump height.
- 90.028° airborne bhop turn: 8.50 → 9.551 m/s, 112% retained.
- W alone, or W+D without a matching turn, gains no air speed. Looking with no keys changes velocity by 0.000 m/s.
- Held 60° surf: 10.432 → 16.968 m/s, 724/724 contact ticks, no floor ownership. Four curved-face fixtures also hold and gain speed.
- Actual authored wet chute: 14.752 m/s versus dry 15.106, 97.655% retention. `native-final/wet-chute/comparison.json` contains the ratio. Its `wet/summary.json` and `dry/summary.json` describe the matched run-up and pack path; `native-final/BUILD.json` records the pack hash. Fixed-position fixture illustration is separate from the full route.

`native-final-2/fast/fast.mp4` shows the three curved stage banks and Outflow S on one uninterrupted normal-spawn input run. HUD stage times are 6.633, 10.192 and 13.700 s. The controller reads authored geometry and exact physics; its keys/mouse are executable proof, not human skill or discoverability data. All 16 course checks pass.

## Actual delivery checks

`final-verification/verification.json` passes both archive CRCs, hashes, x86-64 headers and licences, eleven isolated suites loaded from the delivered PCK, and six nominal clean ordered routes. Suites: audio 24, motor 104, surf 58, course 16, geometry 480, flow 107, access 121, boundaries 92, recovery 3, Yard 17, basin 14. No source-tree fallback is used.

`native-final-2/` contains uninterrupted fast 13.700 s, recovery 30.433 s and safe 43.433 s HUD finishes, with raw inputs, 20 Hz route state, exact video-frame checks and post-finish physics. The fast run's actual saved best and splits survive a separate normal-load process. F/R checks at both later stages pass. `native-final/default-config/` is the unoverridden configured launcher; `native-final-2/keyboard-controls/` verifies paused W stays still and resumed W moves. Pause visibly names r12.

The five required before/after pairs are `native-final-2/bug-pairs/01-valve.jpg` through `05-reservoir.jpg`. They compare immutable R11 and the exact final R12 pack. Gate/valve frames use a physical drop; water uses the labelled matched fixture; reservoir banks also have a crest view. Sibling fixes include basin retaining walls, solid reachable penstocks/caps, supported rails, the Yard bank/roof join and a visible walkable basin exit. Collision probes accompany the images; a still picture alone does not prove collision.

Safe's strict longest plain-running interval is 3.65 s; recovery 3.45, brake/safe_corner/wet 3.70 s. Turns and stops still count as plain running; only executed jumps, slides, surf or mantle interrupt it. Files `final-verification/route-*/plain-running.json` include sampling uncertainty of ±0.10 s. A slower beginner may exceed four seconds.

## Robustness and limits

`matrix-final/matrix-results.json`: 42/42 attempts complete, 39 finish. Safe 11/11; recovery, brake, safe_corner and wet 5/5 each. Fast 8/11: four fully ridden unassisted lines, two recovered unflagged finishes, two flagged finishes and three failures. The flags are a 6.95 m/s Outflow lead speed loss and only 20 Yard contacts. The failures are one Crest miss, one basin stall after the Yard drop, and one Outflow respawn. These are fixed initial-takeoff and aim perturbations, not a human timing survey. Earlier exploratory Yard sweep 16/40 remains in its original folder, not final acceptance.

The fast recording now releases its final hop and uses the apron runout. Its optional post-finish head turn is logged ordinary mouse input, solely to show the wheel payoff. Human camera control is unchanged. A person aiming directly at machinery can still collide with it.

Fresh native view-only discovery reached all three stages and a PRACTICE FINISH after 72 decisions, three F uses and one respawn. It did not establish a clean first clear or a discovered surf line. The fence suggested jumping into the wheel enclosure; an approach beside the roof ramp needed a hop; the safe route climbs the ramp without jumping. See outer `discovery-final/REVIEW.md`.

All native frames use Compatibility/llvmpipe on Linux. Five profile views record draw counts and software host frame times, not desktop GPU performance. Audio movies contain nonzero, unclipped samples; listening quality is unverified. Native Windows, physical controllers and human enjoyment/comfort are unverified. The bundled full official Godot runtime puts `(DEBUG)` in the title.

## Reproduce

From the project, `tools/check-spillway.sh --play-routes` runs the integrated checks. `python3 tools/verify-delivery.py --help`, `python3 tools/stress-spillway.py --help` and `python3 tools/analyze-running.py --help` describe exact-package and trace checks. Use a fresh evidence directory to retain prior failures. Archive/source identity and all failed trials are preserved outside Git; source tools and this result are pushed with the branch.
