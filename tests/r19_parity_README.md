# R19 source parity and executed R18 baseline

The baseline is delivered R18 commit `640d06e6539b53da752f03bfddb64fb46310abb7`,
its configured `scenes/r17.tscn` with `scripts/r17_main.gd` and the R18 HUD.
The retained R16 delivery supplies all 16 full input routes, not the baseline host.
Old R17 evidence is not consumed. This suite makes no packaged, native rendering,
Windows execution or enjoyment claim.

Run from the project directory:

```sh
python3 tests/r19_parity_audit.py --self-test
python3 tools/check-r19-parity.py --out /tmp/r19-parity-baseline-v2
python3 tests/r19_parity_audit.py /tmp/r19-parity-baseline-v2
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

The final candidate requires `--scoring-contract PATH` with exact baseline and
candidate style source SHA256s and `fixture_evidence: {path, sha256}`. The reviewed
fixture wrapper binds the raw summary, every raw fixture file, executed test and
baseline sources, all 25 named checks, and at least 2,000 exact forward samples.
The raw summary must have `failed: 0`; an empty `ok` flag is insufficient.

The candidate archive must match every file/hash and the complete runtime file
set in outer `look/evidence/r19-final-contracts/RUNTIME-FREEZE.json`. The Git diff
from that frozen commit may contain only verification/tests/docs. A changed,
added or deleted runtime file fails provenance and requires the parent to reopen
the freeze. Six protected F2 sources also match the original R18 pin.

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

The targeted Breakwater revision requires `--map-revisions PATH`, keyed only by
`breakwater`. Its exact keys are `baseline_identity`, `candidate_identity`,
`routes`, `off_line_routes`, `presets`, and `evidence: {path, sha256}`. Both route
lists must be `breakwater-basic` and `breakwater-return`. These retained lines
are off the changed gate and require full exact physical parity.

The proof is the passing before/after collision-query JSON, including both exact
supplied identities and `presets` captured from each host for `server128` and
`server128_aa1000`. The contract's `presets` has `baseline` and `candidate` maps
of those captures. Each capture contains `metadata` and `identity_text`.
`tests/r19_course_contacts.gd` produces them. The reviewed proof adds `ok` from
its 45 actual checks and keeps its raw failed count, source binding and results.
Unknown schemas, stale hashes or unrelated identities fail.

Only the exact geometry/overlay/course-key revision fields normalize. The actual
13-entry recording identity retains timing, map identity (including level
version/variant), stage titles, preset, family, motor, runner, rate, physics,
hull and mechanics. Opportunities normalize only version/reason/hash/base
geometry after checking the complete exact old/new metadata. Applied/passages,
all other metadata and unknown fields remain strict. Every actual recording's
captured Godot identity text must hash to its own header's course key and agree
with all readable header identity fields. F5 uses its own key. Only actual
Breakwater records normalize; the later Movement Lab records remain strict.
Lifecycle tours from other routes that switch into Breakwater use the same rule.

Raw motion/recording/control differences remain in `result.json`, marked
informational. The normalized complete physical traces, complete recordings,
controls, detector events and ghost probes must pass without exceptions or
tolerances. The `old` variant explicitly refuses the incompatible R18 ghost;
its live ghost difference is retained. It then loads its own clean candidate
record for pose probes. `new` and `toggle` start with the candidate record and
must match every original ghost pose. No physical or scoring mismatch is
accepted merely because geometry changed. New-map/experiment input tests,
packaging, rendered/native checks and enjoyment stay separate.

The independent audit repeats the normalized physical, complete recording,
existing-detector, lifecycle and live ghost comparisons from raw evidence.
`--self-test` includes targeted revision mutations, unknown schema/metadata,
map identity/version/variant/titles, opportunities, laws/hull/preset, clocks,
FOV, physical ULPs, ordered inputs, F5 keys and strict unrevised-map records.

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

A resource-only resume uses `--resume --out /tmp/r19-parity-baseline-v2`. It requires
`preflight/check-r19-parity-before-streaming.py` and the prior report/source
manifests. All archived engine source hashes and the injected adapter must match;
acceptance functions must have identical Python ASTs. Only process/output resource
plumbing and the main resume path may differ. Every reused recording, both
readers, source observation, ordered tape, trace/controls/ghost probes and
retained physical reference are audited again. Per-run metadata preserves the
original executed helper hashes, and the report records the old/new wrapper
hashes. Failed/incomplete routes are never reused.
