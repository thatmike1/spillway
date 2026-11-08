# R14 validation and delivery candidate

8 November 2026. Current source has five live presets, the original Penstock Yard,
Overflow, a strafe HUD and stage practice. The exact portable candidate has passed its package checks; independent review and promotion remain pending. This document records measured behavior, not a claim that Mike likes the result.

The root diagnostic source wrapper passes every active gate, all three exact retained
failure sets and the R13 controls. All five current Overflow replays match their
actual-R14-main references exactly on position, view and progress. The committed delivery refusal/ownership tests pass 43/43, and the later verifier-hardening regressions pass 43/43. The final source run is preserved in outer `checkpoints/spillway/r14/source-final-5484f10d/`.

## Source movement

The original implementation uses Source units internally, with **1 u = 0.0254 m** at the
Godot collision boundary. Ground acceleration, stopspeed friction, the 30 u air projection
cap, acceleration from uncapped wishspeed, gravity 800 and jump impulse 301.993377 are
checked separately against public rules and an independent Python oracle. At 250 u/s,
a full-cap optimal update reaches 251.793566 u/s. The ideal AA100/128 Hz five-hop model
predicts 703.20694 u/s after a W run-up from rest. These are calculated public-rule
references, not measurements from a CS:GO binary. The real adapter's landing probe changes
some air-tick counts; its corresponding flat prediction is checked separately.

See [SOURCE-REFERENCE.md](SOURCE-REFERENCE.md),
[SOURCE-IMPLEMENTATION.md](SOURCE-IMPLEMENTATION.md) and
[CONTACT-GUARD.md](CONTACT-GUARD.md) for equations, conversions, collision chronology,
input-release checks, failed experiments and fidelity limits. Vanilla stamina and its
speed clamps remain visibly labelled reconstructions. The default F2 has neither.

## Actual game, normal-spawn input runs

| Penstock Yard line | Outcome |
| --- | --- |
| F2 basic | clean 56.3515625 s |
| F2 advanced, speed earned by strafing | clean 28.609375 s |
| F1 basic | clean 57.78125 s |
| F2 final-gap miss and return | clean 67.03125 s |
| F1 final-gap miss and return | clean 68.40625 s |
| F3 basic | clean 42.875 s |

All six visit stages in order with zero respawns. Complete native movies of the first
three equal their headless position, velocity and yaw on every tick. The native preset
tour reaches the runway through real menu inputs and exercises F1–F5. Directional sync
is deliberately separate from strafe efficiency; the basic W-only tapes have no eligible
samples. See [NATIVE-ACCEPTANCE.md](NATIVE-ACCEPTANCE.md).

| Overflow preset | Current clean line, zero respawns |
| --- | ---: |
| F1 vanilla | 46.515625 s |
| F2 server AA100 | 45.9609375 s |
| F3 original R13 | 24.891666666665895 s |
| F4 Quake III-inspired | 35.8671875 s |
| F5 server AA1000 | 45.9609375 s |

These are execution proofs with preset-specific authored inputs, not comparative racing
ceilings or discovery. The old Source-2 tape fails after the support repair and is retained;
current Source-3 lines were recorded and replayed without pose or velocity rescue. F3's
old product control has equal velocity/view and finish time but up to 1.697 cm position
difference. No exact-position equivalence with that older run is claimed. See
[OVERFLOW-ACCEPTANCE.md](OVERFLOW-ACCEPTANCE.md).

## Feedback and records

The native advanced run shows air gain, contact loss, jump gain and directional sync.
F1/F2/F5 explicitly teach releasing W for A/D air strafing; F4 teaches W+A/D. The opening
hint is backed against bright sky, checked in a native before/after pair. Preset identity
stays visible, and switching a used attempt makes it practice. Stage practice never saves.

Records now use exact integer physics ticks, preserving complete best/split/segment
values across processes and preventing equal runs from becoming false new bests after
ConfigFile rounding. Isolated R12/R13 sentinel files stay unchanged. See
[RECORD-PRECISION.md](RECORD-PRECISION.md) and the independent
[record/display review](RECORD-DISPLAY-REVIEW.md).

## Limits carried into release review

- No CS:GO binary measurement, native Windows play, physical latency or human enjoyment
  verdict. Software captures prove rendered content, not performance. The private AMD
  source replay proves actual GPU use and exact motion, not desktop frame pacing.
- Source has no crouched hull, crouch jump, ladder or faithful water model. F4 is a labelled
  Quake III-inspired projection on Source contacts, not Quake or CPMA.
- Some advanced landings are tight. The late return improves from 24/42 to 40/42 tested
  approaches; two pre-existing inward-angle stalls still need a sideways escape. The
  independent guard review records its disjoint-contact diagnostic limitation.
- Forced private Wayland can hang in engine teardown. Private X11 is used for later GPU
  checks. Finished records are saved before Quit. The earlier repaired desktop-socket
  incident and the temporary X0 symlink are documented in [QUIT-REVIEW.md](QUIT-REVIEW.md).
- The first screenshot-only discovery did not finish in 60 decisions. Its best clean attempt
  crossed four opening gaps, then hit the 4.0 m landing face. No collision defect was
  confirmed; takeoff placement and distinguishing landing tops from faces were the
  main problems. The visual-only response is integrated in source/export commit `5484f10d`. A second 58-decision screenshot test compared F1/F2/F3 in stage practice and landed four opening gaps, with no finish. It retained an initial pause-helper failure and disclosed reading more documentation than controls only. See [DISCOVERY-READABILITY.md](DISCOVERY-READABILITY.md). This failure remains
  recorded in outer `checkpoints/spillway/r14/discovery-source/REVIEW.md`.
- The final independent release/trail review and promotion remain pending.

## Exact portable candidate

Source/export commit `5484f10d1c1ef009fd22de76651431db7e1e065e`. Both ZIPs carry pack
`4e6446043e8f17c07673cead946e06e4c1f9e3473e73604bdef81cc5cf0654a8` and official
release templates, with licences and external material provenance. Outer
`delivery/work/r14-candidate-5484f10d/VERIFICATION.json` passes **204/204** checks.

The Linux release starts from an empty working directory, switches all five presets
and both maps, selects stage practice, shows identity/speed/jump/sync after drawing,
keeps mixed attempts unrecorded and quits without engine errors. Ten normal-spawn
input routes finish clean in order with zero respawns: five practice routes (F2 basic,
advanced and final-gap recovery; F1 basic; F3 basic) and all five Overflow presets.
Every packed trace equals its fresh source trace with zero position/view/game-state
differences. Each route saves the full integer record and a second process restores it
without rewriting the profile. The Linux runtime renders through verified amdgpu
`renderD128` on a private X11 display; Windows is static acceptance only.

All runtime checks run outside the source checkout. The embedded diagnostic harness
is confined to a temporary copy; shipped folders contain no override or loose source.
The Linux ZIP hash is `b849ce5ebb177b95a7b1c1a7683869d87e515142048542b41b2579d85593c7b4`;
Windows is `7a39d10362966254e502c7a7254325e221f77234957f4cbfbf7b3b8c28b8f108`.
The new report draft is [REPORT-DRAFT.md](REPORT-DRAFT.md). Contents/runtime/cancel
negative controls and independent reviews are still pending at this snapshot.

## Independent closure challenges

The whole-contract review found no runtime must-fix in5484f10d; its process and report
corrections remain [CLOSURE-REVIEW.md](CLOSURE-REVIEW.md). The separate verifier review
found two remaining helper gaps, not actual candidate faults: an error confined to the
source evaluator's Godot log could pass, and zero-glyph HUD Labels could pass. Both are
repaired with the original observations preserved and new asserting gates. See
[VERIFIER-CLOSURE-REVIEW.md](VERIFIER-CLOSURE-REVIEW.md). A new helper-pinned export is
pending. The completed old candidate's21 contents/runtime/cancel refusal assertions
are retained in outer `checkpoints/spillway/r14/delivery-negative-final/summary.json`;
its earlier interrupted run is separately labelled and never counted as success.
