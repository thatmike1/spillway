# Original eight-map preservation

The baseline is **065f7b27993df7ae2511eb34eb665d271dded13c**, the requested
R19 source commit. The portable runtime commit 5dcc94967 is an ancestor, not a
substitute. No retired raw archive is restored and no old play is accepted as a
fresh baseline. The sixteen existing R16 delivery tapes supply input only.

From `projects/foldrunner`:

```sh
python3 -B tests/r20_parity_audit.py --self-test
python3 -B tools/check-r20-parity.py --out /tmp/r20-parity-baseline
python3 -B tests/r20_parity_verify.py /tmp/r20-parity-baseline
```

The post-capture verifier runs transport finalization, the complete independent
audit, actual-data mutations and provenance checks as bounded sequential Python
processes. Its logs and resource measurements are retained in the proof tree.

The source capture requires a fresh directory. `--routes` is a smoke test, never
full acceptance, and the full run will refuse that existing directory. Preserve
compact proof externally before removing an existing capture.

## What the baseline proves

`git archive` supplies the complete committed project. Its SHA256, every
archived/executed source hash, the injected adapter, inherited executor, Python
reader/expander and executed helper hashes are retained. The parent inventory
corroborates committed runtime hashes; its generated `.import` entries are listed
separately, never mistaken for committed source. The independent provenance
check reconstructs the complete project archive directly from Git.

The adapter instantiates the actual configured `scenes/r19.tscn` and asserts its
root script is `scripts/r19_main.gd`. It does not instantiate a candidate's
inherited class. Before ready it sets only the selected map, preset, sensitivity,
persistence and isolated recordings directory. No tape teleports the body or
writes velocity, progress, view, hull, physics or finish.

Each of all sixteen established routes executes twice, without a startup ghost
and with its own actual clean recording present from startup. Every tape tick
runs, including ticks after the earned finish. All eight maps are mandatory:
Breakwater, Whiteout Relay, Sunken Court, Rainline, Night Shift, practice,
Overflow and Movement Lab. The lab's established slide, fresh hop, A/D wall
jumps without W, and grapple sequence remain explicit acceptance checks.

The retained manifest's actual inventory is sixteen tapes, with varying counts
per map. Each tape gets both fresh baseline plays; no extra route is invented.

| Map | Established tapes |
| --- | --- |
| Breakwater | `breakwater-basic`, `breakwater-return` |
| Whiteout Relay | `whiteout-basic`, `whiteout-crouch`, `r16-whiteout-apron` |
| Sunken Court | `sunken-basic`, `sunken-crouch` |
| Rainline | `rainline-basic`, `rainline-duct` |
| Night Shift | `night-basic`, `night-crouch`, `night-f5-earned` |
| Practice | `penstock-advanced` |
| Overflow | `overflow-f2`, `overflow-f5` |
| Movement Lab | `r16-lab-flow` |


The R19 adapter and R17 executor keep their full existing coverage: physical and
reference position, actual/stored velocity, ordered input, view/FOV, live hull,
duck state, motor/stats, timing/progress, complete motion identity, clean finish,
R/G/F/F5/F2, actual map menu control, pause/resume, ghost poses and lifecycle.
Every attempt is independently decoded by both readers and checked against every
actual post-step observation. Packed sample/input hashes, full header, events,
seal, physical pre-seal byte offset and independent score tally remain checked.
Godot's decimal-parser reference handles its documented parser arithmetic, never
a numeric tolerance. No recording field is removed to make a baseline pass.

The existing R19 comparator unit mutations are retained as historical helper
coverage. Their Breakwater-normalization positive tests do not authorize that
exception in R20. This checker never invokes geometry normalization or an R19
scoring allowlist for acceptance.

Actual-data negative controls rebuild valid recording hash chains while changing
every sample/input column, then challenge observation alignment, input order,
physical ULP drift, motion versions, header identities, stream hashes and seals.
The provenance challenge reconstructs every queried ghost pose directly from
the independent recording reader at the actual tick clock. It adds wrong
source/host, source/fixture/map/law hashes,
incomplete/substituted plays, every actual identity field, unknown physical
fields and ghost pose drift. Mutated data stays in isolated copies.

## Final R20 matrix is pending

Baseline success does **not** accept R20. `--candidate` fails closed in this
revision. The parent must supply a frozen runtime and reviewed scoring and
identity contracts before that path is enabled. The CLI reserves explicit
`--runtime-freeze`, `--scoring-contract`, and `--identity-contract` inputs;
there is no default contract or inferred working-tree candidate.

The preservation boundary for the next stage is fixed:

- physical state, time, ordered inputs, view/hull, progress and all original map,
  geometry, law and motion-compatibility identities compare exactly;
- F2 source pins come directly from 065f7b2;
- Breakwater has no geometry exception;
- old look, new look and actual moving/paused L dispatch execute on all sixteen
  routes, with full recordings, lifecycle controls and every-tick live ghosts;
- explicitly reviewed scoring/build metadata can have a separate comparison,
  retaining both complete values and binding exact source/fixture evidence;
- unknown versions, unreviewed fields, mismatched identities, dropped detector
  events and incomplete plays fail. A changed award is never permission to hide
  physical or lifecycle drift.

The scoring contract format is deliberately not guessed from R19's different
award model. Parent review must specify the R20 stack events, outcomes and any
new metadata, including their anti-farm fixture evidence. Final matrix
implementation must validate those concrete contracts before executing a
candidate, and independently audit all raw comparisons afterward.

## Storage and execution

Only the pinned Godot 4.7.2 runs, headless with dummy audio, sequentially, with
isolated HOME/XDG profiles. All source/import/profile scratch and compact raw
proof live under `/tmp/r20-parity-baseline`. HOME free space must stay at least
15,000,000,000 bytes. Owned allocated scratch is capped at 600 MiB; engine RSS and
anonymous memory are measured separately.

Regular trace files stream into gzip with zero mtime and no stored filename.
After capture, the transport finalizer removes timing-dependent intermediate
zlib flushes, verifies the raw hash again and tests identical compressed bytes
with different input chunk sizes. Original capture reports/results and every
streamed hash remain retained alongside the final transport receipts. Consumed blocks are reclaimed after compression. The decompressed
SHA256 and length must match the incoming stream before the sparse transport
file is removed. Compression failure preserves transport files. No FIFOs,
desktop display, detached process or player profile is used. Source/import/profile
copies are removed on exit; compact observations, recordings, manifests and raw
proof remain for parent archival. `MANIFEST.json` inventories that retained tree.

This is source/headless proof. It makes no native rendering, delivery, Windows
play or enjoyment claim.

## Verified baseline capture

The 10 November 2026 capture passed 32 fresh plays covering all 16 established
tapes and all 8 original maps. The retained proof has 284 sealed lifecycle
recordings, 197,146 actual observed samples, 143,348 ordered input rows and
238 style events.
The independent audit passed 551 checks; actual-data corruption controls passed 56;
source/host/map/preset/completeness/ghost provenance passed 169. All 96 compressed
trace streams passed lossless and deterministic transport checks.

Capture peak owned scratch was 469,639,168 bytes, below 629,145,600. Minimum HOME
free space was 15,799,316,480 bytes. Engine peak RSS was 1,100,054,528 bytes and
anonymous memory 1,006,399,488 bytes, measured separately from scratch.
Source/import/profile cleanup passed. The final compact proof remains in
`/tmp/r20-parity-baseline`, with `REPORT.json`, `source-r19.json`, `AUDIT.json`,
`TRANSPORT.json`, `negative-controls/SUMMARY.json`, `PROVENANCE.json`,
`VERIFICATION-STAGES.json` and the complete `MANIFEST.json` for parent archival.
The final R20 matrix remains pending.
