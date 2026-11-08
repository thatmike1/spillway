# R14 delivered: Source movement and live comparisons

8 November 2026. The portable Linux and Windows ZIPs are promoted in outer
`delivery/spillway-r14/`. Export/source commit **65d205be**, unchanged gameplay since
5484f10d, with repaired acceptance helpers. [Play guide](REPORT.md).

The exact Linux release passes **204/204** checks, including ten clean ordered runs,
zero respawns, complete integer-record save/reload, live presets and both maps,
stage practice, drawn HUD values and error-free Quit. Its traces equal fresh source
traces on all **52,916** ticks. Windows has static package acceptance only. No human
movement-feel or enjoyment verdict is claimed.

## Exact delivery

- [Linux ZIP](../../../../../delivery/spillway-r14/spillway-2026.11.08-r14-linux-x86_64-65d205be.zip)
- [Windows ZIP](../../../../../delivery/spillway-r14/spillway-2026.11.08-r14-windows-x86_64-65d205be.zip)
- [Build/source identity](../../../../../delivery/spillway-r14/BUILD.json), [checksums](../../../../../delivery/spillway-r14/SHA256SUMS)
- [Runtime verification](../../../../../delivery/spillway-r14/VERIFICATION.json), [promotion](../../../../../delivery/spillway-r14/PROMOTION.json), [verified retention](../../../../../delivery/spillway-r14/RETENTION.json)

Both ZIPs contain pack `fc77461baa5387549ce7ec2b5c2796d656b83aaf2a8fd1e8674d614a7b0b0067`
and official Godot 4.7.2 release templates, with licences and material provenance.
Linux SHA256: `9e96522880918c28fc04f82df0fa2587eb1fcefc4467010407bb8d4b01785a80`.
Windows SHA256: `869807eb95ee9d1bda21c6ff9cc2f97eaa14f0d01a84e66f2e9d63be32b44eac`.
The copied ZIPs pass their checksums; every retained file equals the completed run.
Later commits record documentation, test helpers and lowercase comment style. The frozen
export remains 65d205be; the style pass preserves every non-comment line and line count,
as recorded in outer `checkpoints/spillway/r14/delivery-takeover/comment-style-audit.json`.
Execution paths inside original JSON refer to the RAM staging root. RETENTION.json
maps that root to the permanent delivery; the original observations were not rewritten.

## Public Source baseline

The movement is an original implementation of public acceleration, friction and
collision rules, not copied engine code. **1 u = 0.0254 m** at the collision boundary.
The math uses Source units internally: ground acceleration 5.5, friction 5.2,
stopspeed 80, run wish 250, air projection cap 30 with acceleration budget from the
uncapped wishspeed, gravity 800 and jump impulse 301.993377. F1 uses AA12 at 64 Hz;
default F2 uses AA100 at 128 Hz, autohop and no stamina/takeoff clamp. There is no
bounded W/mouse steering assist in the Source family.

The independent oracle checks closed forms against the game, including an optimal
full-cap update from 250 to 251.793566 u/s and an ideal AA100/128 Hz five-hop speed of
703.20694 u/s after a W run-up from rest. These are calculated public-rule numbers,
not CS:GO runtime measurements. The real adapter’s 95/96 air-update counts are
checked against their own flat-plane prediction, not forced to match an ideal
96-update flight. Exact vanilla N-hop maxima remain unresolved.

[SOURCE-REFERENCE.md](SOURCE-REFERENCE.md),
[SOURCE-IMPLEMENTATION.md](SOURCE-IMPLEMENTATION.md),
[SOURCE-REVIEW.md](SOURCE-REVIEW.md) and [CONTACT-GUARD.md](CONTACT-GUARD.md)
record equations, primary references, conversions, negative experiments and the
chronological-contact repair. Vanilla stamina, takeoff clamp and grounded restriction
are visibly labelled reconstructions. Source has no crouched hull, crouch jump,
ladder or faithful water model. The conservative guard repairs certain missed
walkable contacts, not all thin/steep collision cases.

## Actual packed routes

All lines start at normal spawn and use key/mouse input only, with no velocity or
position rescue. Each saves exact best/split/segment ticks, and a new process reloads
them without rewriting the profile. These are authored execution proofs, not racing
ceilings or evidence of forgiving discovery.

| Map and preset | Line | Clean time |
| --- | --- | ---: |
| Penstock F2 | basic |56.3515625s|
| Penstock F2 | earned-speed advanced |28.609375s|
| Penstock F2 | final-gap miss and physical return |67.03125s|
| Penstock F1 | basic |57.78125s|
| Penstock F3 | basic |42.875s|
| Overflow F1 | ordinary |46.515625s|
| Overflow F2 | ordinary |45.9609375s|
| Overflow F3 | original R13 control |24.891666666665895s|
| Overflow F4 | Quake III-inspired |35.8671875s|
| Overflow F5 | AA1000 comparison |45.9609375s|

Packed reports, selected frames, sparse MP4s and compressed traces are under
`delivery/spillway-r14/evidence/check/runs/`; fresh source goldens are under its
`evidence/source-routes/`. No loose source or override ships inside either ZIP.
The verifier's override exists only in a temporary copy of the exact runtime/pack.
The native backend proves amdgpu renderD128 use and kernel graphics work, and records
private-display cleanup. It does not measure physical input latency or desktop pacing.

The unchanged inherited F3 motor files were compared directly with delivered R13:
[r13-player-equivalence.json](../../../../../checkpoints/spillway/r14/delivery-takeover/r13-player-equivalence.json).
The old R13 product differs from its R14 host by up to 1.697 cm in position with equal
velocity/view/finish, an unresolved initialization effect. Current R14 packed/source
references are exact; no older-product position equivalence is claimed.

## UI, input and records

All five presets switch in one process with the active label, air rule and rate on
screen. Used attempts become practice, including early hops before the timer starts.
Stage practice never records; R restarts cleanly. Hull changes wait if they cannot fit.
The HUD measures travel and separates air/contact/ground loss. Sync counts agreement
between A/D and the mouse turn on eligible air ticks, not turn-rate efficiency.
100% sync is not optimal strafing. [PLAYABLE.md](PLAYABLE.md),
[STAGE-PRACTICE.md](STAGE-PRACTICE.md), [QUAKE.md](QUAKE.md), [WIDE.md](WIDE.md).

The exact 65d205be pack also passes **22/22 OS-input checks** on private AMD/X11:
manual Space, held autohop, wheel, all preset keys/rates, stage picker, mouse calibration,
both A/D strafes, short no-key coast and Quit. The 100-pixel delivered mouse delta
turns 5.5 degrees at sensitivity 2.5. Both strafes build 250 to 255.0593 u/s; the 0.1796875 s
coast has zero horizontal-velocity drift. This is XTest synthetic OS input, not a
physical-device, whole-route or feel claim. [OS-INPUT.md](OS-INPUT.md),
[final analysis](../../../../../checkpoints/spillway/r14/os-input-final/analysis.json).

Records rank by exact integer ticks, avoiding ConfigFile's rounded float summaries.
Full records survive new processes; equal ticks stay equal. R12/R13 sentinel files
are unchanged. [RECORD-PRECISION.md](RECORD-PRECISION.md) and
[RECORD-DISPLAY-REVIEW.md](RECORD-DISPLAY-REVIEW.md).

## Source gates and independent challenges

[Final source results](../../../../../checkpoints/spillway/r14/source-final-65d205be/RESULTS.txt)
pass every active gate, all five external Overflow references, exact retained failure
sets and the unchanged R13 controls. Active suites include math 177, live collision 63, repair 135, guard 43, loop 166,
F4 84, stage practice 107, precision 66, independent records 46 and geometry 1599.
Three explicitly retained negative/repro sets remain: 10 unsuccessful two-plane
approaches in559 assertions, one deliberate manual-wheel negative in52, and its one
reduction in24. The wrapper requires those exact names and exits, never arbitrary failures.

[DELIVERY-REVIEW.md](DELIVERY-REVIEW.md) and
[VERIFIER-CLOSURE-REVIEW.md](VERIFIER-CLOSURE-REVIEW.md) retain the independently
reproduced acceptance gaps. They were fixed before promotion: strict complete finite
traces, delivery/order/rate/cleanup verdicts, requested external references, owned
cancellation, actual evaluator-log scans and drawn-label checks including font alpha
and visible characters. Root hardening 45/45 and the independent recheck 12/12 plus 99/99
pass. [VERIFIER-RECHECK.md](VERIFIER-RECHECK.md).

The final package refusal tests pass **21/21**: 13 content variants, four broken-source
exports and four native cancellation/cleanup assertions.
[Results](../../../../../checkpoints/spillway/r14/delivery-negative-65d205be/summary.json).
The earlier unexplained SIGTERM143 run is separately retained and never counted as success.
The completed final export executes the repaired helper hashes, rather than borrowing
an older package's verdict. [DELIVERY.md](DELIVERY.md) describes the protocol.

The whole-contract [closure review](CLOSURE-REVIEW.md) found no runtime must-fix in the
previous candidate. The final pack changes only helper/export provenance; game scripts,
scenes, assets, shaders and export settings remain identical. It now independently
passes the same ten plays and stricter checks. The earlier candidate ZIPs were retired
with hashes after promotion; their logs, traces, frames and manifests remain.

## Discovery, weaknesses and storage

The first screenshot-driven attempt did not finish within 60 decisions. Its best clean
run crossed four gaps and hit the 4.0 m landing face. The visual-only response added dark
faces/pits, pale landing noses and run-speed takeoff pads, and corrected yellow strips
that had extended beyond the solid deck. Six tapes remained identical.
[READABILITY.md](READABILITY.md).

The second 58-decision comparison used F1/F2/F3 practice and then landed four opening
gaps after a clean restart, with no finish. Its pause-helper failure and broader-than-
allowed documentation read are disclosed. [DISCOVERY-READABILITY.md](DISCOVERY-READABILITY.md).
The final delivered-pack attempt stopped after 54 decisions without a finish. It earned
Stop logs, then clearly cleared the 3.5 m gap in practice and hit the 4.0 m far face.
It used screenshots only, with no hidden-state steering or documentation overread.
This was editor-hosted packed play, not release-runtime acceptance. No collision defect
was established. [DISCOVERY-DELIVERED.md](DISCOVERY-DELIVERED.md). The play guide now
explains releasing Space between slow basic jumps to approach each far edge, since
held autohop can take off too early. Scripted finishes do not prove easy discovery.

Some advanced landings are tight. F1 cannot take the advanced line at its clamps;
F4/F5 have no full Penstock route proof, and the pump notch is unproven. The tapered
return passes 40/42 approaches versus 24/42, with two pre-existing inward-angle stalls
that need sideways escape. Independent [practice](PRACTICE-REVIEW.md) and
[contact-guard review](CONTACT-GUARD-REVIEW.md) preserve these limits.

Forced private Wayland can hang during engine teardown; final AMD checks use X11 and
all tested Quit calls exit cleanly. This is not a universal desktop guarantee.
Finished records save before Quit. [QUIT-REVIEW.md](QUIT-REVIEW.md).
Windows execution, physical gamepad use, audio audition, physical latency and Mike's
enjoyment remain unverified.

Storage steering is in [BRIEF.md](BRIEF.md). Every large render/export checks 15 GiB
free on /home. Final R12/R13 ZIPs still pass their original checksums. Current traces,
source movies, selected frames and final packed evidence remain. Rebuildable caches,
three superseded stand-in/Quake videos and duplicate old candidate ZIPs were retired
with per-file hashes in outer `checkpoints/spillway/r14/storage/`. No historical game
folder was recreated. Earlier R12/R13 game records remain unchanged. The private-display incident and its repair are documented in QUIT-REVIEW.md; no desktop configuration was edited.
