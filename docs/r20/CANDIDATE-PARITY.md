# Final original-eight-map checker preparation

The new entry point is `tools/check-r20-candidate-parity.py`. Preparation is engine-free. No final runtime, 48-play capture, GDScript parse, packed build, native rendering, Windows execution or enjoyment acceptance is claimed. The retained baseline, its helpers and `PARITY.md` are unchanged.

The future matrix is exactly the established sixteen tapes, each against the actual configured `scenes/r20.tscn` / `scripts/r20_main.gd`, in `old`, `new`, and `toggle` order. Every play starts with that route's actual R19 clean golden recording already present. This is **48 fresh candidate plays**, in addition to the immutable 32-play R19 proof. There is no route subset or smoke acceptance option.

## Explicit inputs and review

The checker takes no working-tree candidate and has no default contracts. Future capture or independent re-audit requires all of:

- `--candidate`: exact lowercase full 40-character committed source ID.
- `--baseline-dir /tmp/r20-parity-baseline`: the retained exact proof, not another delivery or a regenerated baseline.
- `--runtime-freeze`: the same final schema-1 freeze used by `DELIVERY.md`.
- `--runtime-identity`: the complete identity JSON whose canonical SHA256 is in that freeze.
- `--scoring-contract` and `--scoring-contract-sha256`: the parent's explicitly reviewed scoring/source/helper contract and hash.
- `--identity-contract` and `--identity-contract-sha256`: the parent's reviewed original-map policy and hash.
- `--out /tmp/r20-candidate-parity`: a new directory for capture. Re-audit uses that existing directory.

The project must be committed and clean. Every executing helper must equal its blob in the explicit candidate commit. The checker recursively inventories the private imported Python modules as well as the new verification files and complete inherited GDScript executor chain. Helper drift refuses preflight and postflight. An old accepted component host hash is never used as the final host's hash.

The freeze has **exactly** these keys; unknown keys fail:

```json
{
  "schema": 1,
  "runtime_frozen": true,
  "source_commit": "<full40 final commit>",
  "identity_sha256": "<reviewed canonical full identity SHA256>",
  "new_maps": ["saltglass", "tether-yard", "through-line"],
  "required_maps": ["breakwater", "whiteout-relay", "sunken-court", "rainline", "night-shift", "practice", "overflow", "experiment", "saltglass", "tether-yard", "through-line"],
  "experimental_maps": ["experiment", "tether-yard", "through-line"],
  "reached_items": [1, 2, 3, 4, 5, 6],
  "intentional_changes": {"<changed approved old path>": "<its reviewed SHA256>"}
}
```

The placeholders above describe the schema, not usable review values. `intentional_changes` must be exactly the changed subset of `project.godot`, `scripts/r16_style.gd`, `scripts/r16_style_panel.gd`, `scripts/r18_style_panel.gd`, and `scripts/r19_ghost_share.gd`. No old path can disappear. All 1,309 baseline Git files, including shelved files and original maps/motors, remain protected. Partial reached-item prefixes cannot pass final parity. The existing delivery preservation and complete identity boundary are also invoked read-only.

Both reviewed contracts require integer `schema=1`, their exact `kind`, `status="REVIEWED"`, a nonempty `reviewed_by`, and `baseline_manifest_sha256`. The command-line hash pins the entire document. Setting a review flag without the parent's actual review is not an approval workflow.

The identity contract has exactly `schema`, `kind`, `status`, `reviewed_by`, `baseline_manifest_sha256`, `policy`. Its kind is `r20-original-map-identity`. `policy` contains:

- `header_fields`: the complete 11-field raw header vocabulary.
- `metadata_fields`: the complete 28-field metadata vocabulary.
- `motion_fields`: the ten original motion identity fields.
- `identities`: every observed original map/preset identity, keyed `map/preset`, derived from **both** retained plays and all lifecycle records. There are sixteen entries across eight maps.
- `original_identity`: the full delivered R19 `maps`, `keys` and `registry` objects for the independent delivery identity boundary.

The entire policy must equal fresh read-only derivation from the retained headers and pinned delivered identity. Missing maps, presets, identity fields or metadata vocabulary fail. Breakwater has no revision normalization or exception. Known header wall-clock/run-ID labels and the seal end wall clock retain the existing R17 canonicalization. Complete raw headers, physical byte offsets and raw recording hashes remain checked and retained.

The scoring contract has exactly `schema`, `kind`, `status`, `reviewed_by`, `baseline_manifest_sha256`, `component_sha256`, `candidate_commit`, `runtime_sources`, `verification_helpers`, `old_metadata`, `new_metadata`. Its kind is `r20-direction-stack-parity`.

`runtime_sources` is the full exact final-commit hash dictionary for all assets, scripts, shaders, scenes, `project.godot` and `export_presets.cfg`. It explicitly includes the final R20 host/scene. `verification_helpers` is the complete exact helper inventory. Both dictionaries must equal independent current derivation; omitted and extra entries fail. The three accepted changed style sources must equal their hashes in the accepted component contract. Its historical item-2 host hash grants no exception to this final-runtime binding.

`old_metadata` and `new_metadata` each contain complete `scoring`, `build` and `build_label` values. Old values come from the strict Python reader of actual R19 bytes; Godot JSON header numeric tags are not substituted. The new values are exactly:

```json
{
  "build": "spillway-2026.11.10-r20",
  "build_label": "Spillway R20",
  "scoring": {
    "style": {
      "event_format": 2,
      "rules_sha256": "b133b80f118247cf944f1c48bbe9f1a65e2b71653adff52d41563904be661688",
      "version": "r20-style-stack-1"
    },
    "style_key": "r20-style-stack-1/2/b133b80f118247cf9",
    "timing": "r16-timing-1"
  }
}
```

This metadata is separated for comparison, never deleted from the retained evidence. No other metadata or lifecycle difference is allowed.

## Engine-free preparation commands

From `projects/foldrunner`:

```bash
python3 -B tests/r20_candidate_check.py
python3 -B tools/check-r20-candidate-parity.py --help
python3 -B tools/check-r20-candidate-parity.py --prepare-templates
```

Template mode emits `IDENTITY-UNFINALIZED.json`, `SCORING-UNFINALIZED.json`, and `RUNTIME-UNFINALIZED.json` under `/tmp/r20-candidate-prep`. It refuses to overwrite them. Templates remain unreviewed and cannot pass preflight. The generic templates have no candidate or runtime source hash guess.

After all authors finish and commit the full runtime, the parent can explicitly name that full commit to generate another unreviewed set with its complete source/helper inventories:

```bash
python3 -B tools/check-r20-candidate-parity.py --prepare-templates \
  --template-commit "$R20_FINAL_COMMIT"
```

That set goes under `/tmp/r20-candidate-prep/$R20_FINAL_COMMIT/`. It still says `UNFINALIZED` and `runtime_frozen=false`. The parent supplies the separately observed runtime identity, reviews the contracts and freeze, and records the two reviewed contract hashes. Future source or helper edits require a new explicit review.

## Physical, input, lifecycle and ghost checks

`tests/r20_candidate_parity.gd` extends the unchanged R19 observational adapter, which extends the unchanged R17 executor. It does not override tape delivery, the finish path, lifecycle tour or controls. It adds post-step scoring observations and asserts the actual configured initial look. The inherited executor completes every declared tape tick, including post-finish ticks. Moving L and paused L remain actual key dispatches, with immediate gameplay invariance checks.

Every physical/input/view/hull/progress/timing/map/law/motion field is compared exactly against `r19-ghost`. The full observation streams also compare every warmup and lifecycle sample, not just the main tape. Unknown physical fields survive into the comparison and fail. All binary sample/input columns, complete ordered input rows, actual versus recorded samples, both readers' full headers/events/seals and physical pre-seal offsets remain checked. Existing Godot JSON parser arithmetic remains its exact reference; no physical tolerance is added.

Every original lifecycle recording must exist in matching order with matching map/preset/attempt/start/end context. Actual R, F, F2/F5, G, pause/resume, map-menu and quit behavior stay in the full tour comparison. Lab explicitly requires slide, a fresh hop, at least two wall jumps with A/D held and no W, then grapple. The original ghost must load from startup, stay live on the actual course clock, and match poses independently reconstructed from the original strict-reader recording. All interpolation probes, rendered ghost-body poses, fades, noncollision checks and every original identity refusal stay exact through the inherited executor and complete summary/ghost comparisons.

Every trace mismatch is emitted to deterministic gzip JSONL without a first-four cap. Scoring snapshot differences are explicitly tagged separately. Raw captures are never rewritten to make a comparison pass. Complete physical record differences and separate old/new scoring/build/storage values are retained in `record-comparison.json.gz`.

## Tagged scoring and the ordinary detector reference

The accepted component contract is pinned to SHA256 `30d9b5faca12505430f874a6aee7824ea5c42cb14cd517cede936138fdd45105`. Its eligibility/anti-farm proof and the fresh source-observer evidence described in `DELIVERY.md` establish the accepted schema, not final-matrix acceptance.

Only `s=capture,k=style` is scored. `k=direction,record_kind=direction` is an explicitly non-scored diagnostic. Capture and pre-seal lifecycle diagnostics are retained with their dense serials and envelope order. Queued loss payloads may refer to earlier sample ticks. The existing independently exercised delivery auditor reconciles bank amounts, once-only triangular formula, units 160/50, all multipliers one/combo zero, pending exclusion, actual float32 source-speed measurements, losses, live direction state, scored events, score totals and complete seal/by-kind tallies. The original JSON measurement serialization comparison is retained for that auditor; binary physical/input fields and old/new physical comparisons remain exact.

Ordinary v1 event fields are closed. Kind, tick, time, geometry, position, base, combo, measurements and labels must match the original detector event exactly. Only removing the old direction product can justify changed `mult`/`direction_mult` and points. Unknown events or measures, missing detectors, or changes to ordinary combo semantics fail. Legacy v1 limits remain unchanged; new triangular banks use their separate v2 schema.

The recorded `base` is rounded, while `_award` uses an unrounded float. Recomputing points from recorded base would be incorrect. Therefore a **separate observational R19 scorer** receives each same actual production sample. Its byte-exact parent source is retained as the new verification-only `tests/r20_candidate_r19_style.gd`, checked against the pinned R19 Git blob. Keeping this copy committed makes every preload resolvable during the separate release helper's normal import as well as the parity import. `tests/r20_candidate_reference.gd` suppresses only the two obsolete immediate directional awards and temporarily neutralizes `_direction_mult` inside that reference's inherited `_award`. It retains the original unrounded arithmetic, geometry queries, ordinary combo and rounding. It never replaces or writes the production scorer, player or host.

Every ordinary live R20 award must exactly equal this reference's returned award, in addition to the baseline event comparison. Full ordinary combo/state/detector diagnostics are compared to the reference. Actual scored `recent`, `last`, score and by-kind snapshots are reconstructed independently from actual scored events. Unknown snapshot fields fail. Reference samples and lifecycle discontinuities must be complete; a lost discontinuity prefix fails rather than guessing.

The retained sixteen routes contain 119 ordinary scored events per baseline pass and no immediate directional awards. This is a read of their actual reader dumps. New banks/diagnostics are audited and challenged if they actually occur; the checker does not fabricate a bank to claim matrix coverage. Synthetic bank/stall/queued/quit tests cover the new accounting branches separately. The accepted source observer's 65 recordings, 10 banks and 226 diagnostics remain separate evidence.

## Future capture and independent re-audit

Only once the parent supplies reviewed values, this is the future command. Each shell variable is an explicit parent-provided input; none is inferred by the checker:

```bash
python3 -B tools/check-r20-candidate-parity.py --execute \
  --candidate "$R20_FINAL_COMMIT" \
  --baseline-dir /tmp/r20-parity-baseline \
  --runtime-freeze "$R20_RUNTIME_FREEZE" \
  --runtime-identity "$R20_RUNTIME_IDENTITY" \
  --scoring-contract "$R20_SCORING_CONTRACT" \
  --scoring-contract-sha256 "$R20_SCORING_REVIEW_SHA256" \
  --identity-contract "$R20_IDENTITY_CONTRACT" \
  --identity-contract-sha256 "$R20_IDENTITY_REVIEW_SHA256" \
  --out /tmp/r20-candidate-parity
```

Use exactly those inputs with `--preflight` for read-only, engine-free validation, or replace `--execute` with `--audit` to independently re-audit an existing capture. A current unfinished HEAD never becomes final acceptance. Failed captures remain pending; reusing a partial directory cannot make the matrix complete.

The final run imports only its committed private snapshot, uses the pinned baseline Godot 4.7.2 binary, dummy audio and isolated HOME/XDG profiles, and executes sequentially. It reserves 600 MiB of tmpfs space, enforces the inherited 600 MiB owned scratch cap and the 15,000,000,000-byte HOME floor, and reports engine RSS/anonymous memory separately. Committed source and the unchanged baseline adapter injection, generated import metadata and all helpers are checked again before private source/import/profile cleanup. The live `.godot` is never used.

All 144 trace streams keep their streamed raw hashes/lengths and original capture reports/results. Canonical transport verifies zero header time/name, losslessness and identical compressed bytes with different chunk sizes. Independent re-audit reconstructs the complete source archive from Git and verifies raw/canonical transport receipts without changing baseline evidence. Original 56 actual-data negatives run unchanged into the new evidence tree. Additional candidate controls rebuild valid recording chains for every binary sample/input column and challenge every metadata/identity field plus actually present scored/diagnostic/live-state cases. Successful source parity still grants no packaging, native, Windows or promotion acceptance.

Preparation receipts live only in `/tmp/r20-candidate-prep`: unit logs, the private rerun of original 56 actual-data negatives, resource stages and unreviewed templates. The immutable baseline manifest SHA256 is `f939eba5f2fbbcb13f6833f3f1067e961795685fbac1c6987dfb6a7bedb7fffb`; its verified remote raw archive SHA256 is `b8019e3d36c8826977d85275a2aaee5ad7f0ebc9a4004dd6e3805c20a7412e88`. No baseline bug was established during this preparation.
