# R19 source parity and executed R18 baseline

The baseline is delivered R18 commit `640d06e6539b53da752f03bfddb64fb46310abb7`,
its configured `scenes/r17.tscn` with `scripts/r17_main.gd` and the R18 HUD.
The retained R16 delivery supplies all 16 full input routes, not the baseline host.
Old R17 evidence is not consumed. This suite makes no packaged, native rendering,
Windows execution or enjoyment claim.

Run from the project directory:

```sh
python3 tests/r19_parity_audit.py --self-test
python3 tools/check-r19-parity.py --out /tmp/r19-parity-baseline
python3 tests/r19_parity_audit.py /tmp/r19-parity-baseline
```

`--routes breakwater-basic` selects a bounded smoke test in a different, new
output directory. Existing evidence is never overwritten. Baseline-only work
leaves `r19_final_gate: pending`. The final matrix must wait for the parent's
frozen runtime commit. It accepts an explicit commit with `--candidate`, the
captured evidence with `--baseline-dir`, and a new RAM directory with `--out`.
`--host-scene=res://scenes/r19.tscn` can select a future scene; otherwise it loads
`application/run/main_scene` from that commit's `project.godot`.
`--host-script=res://scripts/r19_main.gd` optionally asserts the root script.
The scene is instantiated normally, with only test configuration set before ready.

The final candidate also requires `--scoring-contract PATH`, containing
`baseline_style_sha256`, `candidate_style_sha256` (the exact `scripts/r16_style.gd`
source hashes) and `fixture_evidence: {path, sha256}`. That JSON evidence must
have `ok: true` and cover the new awards, sustained hops, speed thresholds,
standing/tiny-speed farming, reset/discontinuity boundaries and neutral forward
behavior. The harness validates the referenced bytes. The parent must inspect
the fixture's coverage; a file named evidence is not proof by itself.

Each baseline route runs twice: normal authored spawn without a ghost, then
with that route's actual clean recording present from startup. Each candidate
runs with original presentation, current presentation, and actual moving/paused
L dispatch. The same recorded R18 bytes provide live ghost comparison.
Every route continues for the entire retained tape, even after its earned finish.
R, G, pause/resume, F, F5, F2, the real map menu button and quit exercise the
subsequent recording lifecycle. No adapter writes the body, view, progress,
physics, preset laws, checkpoint or finish after authored spawn.

The inherited accepted executor and strict recording checks are reused.
Position, velocity, view, hull/duck, full motor/stats, held and ordered discrete
inputs, clock/progress, physics/preset and complete motion identity compare
exactly. Only the top-level style snapshot is separated into scoring reporting.
Scoring metadata remains outside motion identity as the existing contract says.
No format, map, motor, geometry, preset or compatibility-version key is discarded.
Each actual motion identity field is separately challenged against ghost loading.

Every recording from every lifecycle attempt is independently decoded by Godot
and Python. All tick and input columns must have identical byte hashes; the
entire header, events and seal must agree. JSON numbers are additionally decoded
with an independent implementation of Godot String.to_float (its published
18-digit mantissa algorithm), since that parser differs from Python strtod.
This is an exact parser-reference comparison, with no numeric tolerance. Packed
physics/input columns and recording-to-actual-source event comparisons remain
exact with the ordinary independent reader. Every decoded sample, input and style
event must align with that attempt's actual post-step observation, including
warmup and lifecycle samples. An independent tally checks score/by-kind totals.
Original tape key/mouse order is checked without sorting the observed input.
The inherited physical pre-seal byte-offset check stays intact.

Cross-version comparisons separately report scoring identity, events, score and
build-label changes. They compare every remaining header/column/input/event/
outcome field. Removing capture events renumbers their sequence indices only in
the comparison view, after original sequences and counts have been validated.
Byte offsets and event counts are validated against the actual stream and
reported separately because a new style event changes compressed payload size.
Existing detector tick, kind, geometry, measurements, base, label and combo must
still agree. Only explicit `backward_bhop`/`sideways_bhop` awards and directional
multipliers are separate. Forward awards with multiplier one retain exact points.
Unknown detector/schema changes fail. New award eligibility itself requires the
separate style fixture suite; retained route tapes do not establish anti-farming.

Geometry exceptions require `--map-revisions PATH`, a JSON object keyed by exact
map id. Each value contains exact `baseline_identity`, `candidate_identity`,
`routes` (explicit retained route names), optional `off_line_routes` (still exact),
and `evidence: {path, sha256}` for passing targeted before/after JSON proof.
Unknown maps, unlisted routes, stale proof bytes or identities fail. Listed
changed routes retain every raw difference in the report and are labelled
geometry exceptions, never exact parity. They must still earn complete clean
finishes, pass observation/reader/input checks, reject the old revision ghost
with an explicit error, and load their own new clean ghost. No exception permits
changes to the six parent-pinned F2 motor/law/preset sources. New map and
experiment earned-input tests remain separate from this retained-route suite.

All source, import, isolated HOME/XDG profiles and evidence live under the new
`/tmp` or `/dev/shm` output directory. Only the project subtree is archived.
The archive SHA256, exact commit, all archived file hashes, injected adapter
hash and all executed helper hashes are retained. All 346 parent-pinned R18
source hashes are checked. The live `.godot` symlink and Mike's userdata are
never used. A 15,000,000,000-byte HOME gate runs before and during work.
All owned RAM evidence/import/source/profile files are capped at 600 MiB,
matching the inherited scratch-bound contract. Engine RSS and anonymous memory
are measured separately; the 600 MiB scratch cap does not cap engine memory.
Traces stream continuously into gzip through regular temporary files. Consumed
tmpfs blocks are reclaimed only after compression; the decompressed stream hash
must equal the pre-reclamation raw hash before transport files are removed. RAM
footprint uses allocated blocks, including every ordinary source/import/evidence
file. Godot rejects FIFO paths, so no pipe-backed FileAccess is used. Source/import/profile copies
are removed in `finally`. Retained compact raw observations and recordings stay
in RAM for the parent's final proof and subsequent external preservation.

A resource-only resume uses `--resume --out /tmp/r19-parity-baseline`. It requires
`preflight/check-r19-parity-before-streaming.py` and the prior report/source
manifests. All archived engine source hashes and the injected adapter must match;
acceptance functions must have identical Python ASTs. Only process/output resource
plumbing and the main resume path may differ. Every reused recording, both
readers, source observation, ordered tape, trace/controls/ghost probes and
retained physical reference are audited again. Per-run metadata preserves the
original executed helper hashes, and the report records the old/new wrapper
hashes. Failed/incomplete routes are never reused.
