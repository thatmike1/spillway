# Overflow R13 results

7 November 2026. Current portable source **d8fe109fbf8965c73ecc2965ae32b0a67d165165**, geometry
`3a04610b4cbf3ff7596ac864f3d31e5bfed36fa3fa4d94c80ab904468f12b99e`, course key
`c61d8696bcbffc59`. Pack SHA-256 `b087e6dcb3530138fce83ad87c08c42304f50d66837c39b88474e44a19fe082d`.
The outer workspace's REPORT.md is the play entry point. The final packages are under
`delivery/spillway-r13-final/`; `delivery/spillway-r13/` is the immutable pre-finish-fix
baseline, and `delivery/spillway-r12/` is the retained older game. Later docs-only commits
do not identify different package bytes.

## Chosen game

All behavior, tuning and layout are P game choices. This is an original downhill momentum
game, not a reconstruction of CS, VHOLUME or Mirror's Edge. Height supplies speed; hops
retain it; held keys bend a flight without a steering tax; synchronized side-key carving
adds a bounded optional reward. No input keeps the ballistic line. Opposing input brakes.
A full ordinary route, worthwhile bay jump and lower ramps provide distinct approaches.
Surf, slide, mantle and automatic crest boosts were deliberately removed from this course.

## Contract evidence

| Requirement | Evidence and actual scope |
| --- | --- |
| Research multiple approaches | `research/classic-movement.md`, `vholume-and-peers.md`, `ai-game-testing.md`; primary citations and footage observations, no invented reference constants |
| Compare playable movement policies | `CARRY.md`, `AIR-CANDIDATE.md`, `research/controller-lab.md`, `COUNCIL.md`, `BUILD.md`; R12, corrected FLOW, broad/narrow controls and original challenger retained |
| Ordinary handling and mastery | `research/overflow-casual-review-sol.md`: W + held Space and two turns clean 22.667 s; candidate/holdout comparisons and named failed approaches retained |
| Height, hops, turning, contact and braking | motor/review regressions, explicit motion ledger and actual displacement checks; stale support and stale carve credit repaired rather than hiding reported speed |
| Meaningful route and physical recovery | `OVERFLOW.md`; ordinary 24.892 s, tight ordinary 24.458, mastery 22.475, bay miss 25.592, pool miss 27.767 and slot miss 28.650, ordered with no respawns |
| Current rendered route evidence | outer `checkpoints/spillway/r13/overflow-revision/final-275c477b/render/` has four complete native input movies; `overflow-art/` has four paired full before/after movies with exactly equal movement; `presentation-fix-opus/` verifies the final two-file correction on ordinary and held-hop routes |
| Discoverability | outer `checkpoints/spillway/r13/discovery-r13/REVIEW.md`: first-run clean 31.167 s, opening miss and real ramp recovery, 30 route decisions plus one payoff inspection; candidate source predates only presentation/checker fixes; it is not the final portable run |
| Restart, practice, pause and records | `PLAYABLE.md`, lifecycle suite, deliberate-break controls and final exact-pack save/reload; only the R13 profile is written |
| Redistributable assets | `assets/momentum/MANIFEST.json`, CC0 notices and `ART.md`; four Poly Haven sets, modified-source hashes, original procedural art/railings |
| Engine reconsidered | two-family council, explicit backend/lip comparisons and private AMD runs; Godot retained provisionally, no backend switch bundled into the motor |
| Linux and Windows delivery | final BUILD.json, SHA256SUMS and VERIFICATION.json: 36/36 checks, official release runtimes, same PCK, actual Linux play and separate reload; Windows static only |
| Source and rendered equality | final packed ordinary route matches all 3372 source positions at tolerance 0.0 m; latest presentation root check compares all body/game fields on three 3372-tick runs, excluding the render-interpolated camera transform |

Evidence folders are outside Git in the build workspace. Committed tests and docs link to
them, preserving failed trials and source hashes. Exact-state physics, imperfect tapes,
view-only discovery, GPU presentation and human feel are separate claims.

## Comparisons and failed attempts

The first 16 s prototype had a cheap diagonal and poor recovery. It was revised rather
than accepted from its test count. The final earned shortcut beats tight ordinary by
1.98 s. Its ordinary route works without learning synchronized strafes. The old broad
projection profile punished ordinary faster turns; narrow reward varied with mouse
cadence. FLOW remained a useful forgiving control but bundled camera-led steering with
other changes. The original candidate uses CARRY's shared ground/contact body with a
bounded air rule; it is the product's single movement policy, not a motor-selection UI.

The frozen neutral/holdout block matrix finishes 43/45. Two misses stop at a 15 cm side
face of a holdout ramp. On the final course, the original recorded open-loop tapes finish
30/42; holding W beyond their recorded stopping time finishes 42/42. Those are distinct
experiments, not a repaired count. The complete mixed matrix is 102/120. Casual exploration
has 23 clean finishes and 12 unfinished episodes out of 35. A missed west-berm approach
stalls physically; a brief D correction recovers. These are not independent human trials,
and all routes/tapes are unblinded except the separate view-only discovery.

## Presentation and practical limits

The material kit and art pass retain route collision and progress. Root compares all
14034 non-wall-clock rows across four art before/after routes; all 105 collision bodies
and shapes remain unchanged. The current spray warm-up shifts first-use compilation to
startup; private AMD final repeats have worst finish intervals 18.214 ms at 720p and
17.600 ms at 1080p versus 133.4/125.9 ms before. Normal median is about 16.7 ms. One sample
per build shows about 170 ms longer before the first image. It does not alter the run
clock. Distant groove patterns are filtered, and the overflow sheet retains highlight
detail. See ART-PASS.md and outer presentation-fix-opus/REPORT.md plus ROOT-CHECK.json.

An intermittent native GPU shutdown hang remains unresolved: one unmodified-source
diagnostic was terminated at its limit; the next 16 native runs and current portable
verification exited normally. The original Sky radiance leaks were separately fixed and
do not recur. Initialization timing can choose trajectories differing by at most 1.70 cm
at a two-deck seam, with identical tested times, splits and respawns. Render phase was
not established as the cause; strict same-setup packed equality remains required.

Windows execution, physical display/input latency, gamepad use, audio audition and human
satisfaction are unverified. Most full movies use llvmpipe; AMD evidence uses a private
virtual compositor. The tail race is broad, trees are faceted, and the visible sluice
overflow is stylised above the hidden physical channel. Free view-only discovery uses
paused planning and engine-injected inputs; it does not measure uninterrupted human play.

## Trail and review

Canonical decisions are append-only in `../reboot/decisions.tsv`. Root's self-audit,
transcript index and original line references are under outer
`checkpoints/spillway/r13/self-audit/`. The final different-family artifact/trail review is
pending; no final-review verdict is claimed here yet. Earlier Sol release-checker findings
are repaired with retained red/green controls in delivery-review-sol/root-fix/ROOT-FIX.md.
