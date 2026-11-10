# R20 delivery helper preparation

Preparation only. No R20 export, candidate, source-editor acceptance, native display or engine run is claimed here. `prepare` is read-only and engine-free. It reads committed Git blobs, hashes the cached official runtimes/licences, and reports pending integration. Other authors' loose changes are not a freeze.

Verified preparation commands, from `projects/foldrunner`:

```bash
python3 -B tests/test_package_r20.py
python3 -B tests/test_package_r19.py
python3 -B tests/test_r20_preservation.py
python3 -B tools/package-r20.py prepare
python3 -B tools/package-r20.py --help
python3 -B tools/package-r20.py package --help
```

The owned files are `tools/package-r20.py`, `tools/r20-pack-probe.gd`, `tests/test_package_r20.py` and this document. No extra helper is owned. The R20 Python wrapper and probe retain the R19 implementations from `065f7b27993df7ae2511eb34eb665d271dded13c`, with R16 input/physics/recording/ghost machinery and R18 pack/runtime/asset machinery. Imported R18/R16 modules are private instances; a test proves loading R20 does not mutate a separately loaded R19 gate. The inherited profile audit is unchanged except requiring the R20 recording build and additionally comparing the complete header between both readers. Legacy style-v1 validation remains strict.

## Exact R19 boundary

`065f7b27993df7ae2511eb34eb665d271dded13c` is the preservation baseline. All 1,309 tracked files, including shelved source/assets, are protected. Only these old paths may differ, each with the exact parent-reviewed SHA256:

- `project.godot`
- `scripts/r16_style.gd`
- `scripts/r16_style_panel.gd`
- `scripts/r18_style_panel.gd`
- `scripts/r19_ghost_share.gd`

No deletion is allowed, including deletion of an allowed path. There is no Breakwater exception, no motor/map permission, and no inherited R19 six-file allowlist. The tests independently challenge every protected path and compare this boundary to the parent's `tools/check-r20-preservation.py`; that tool remains parent-owned.

The helper pins outer `look/evidence/r20-baseline/TRACKED.json`, `SOURCE.json` and delivered `delivery/spillway-r19/{BUILD,VERIFICATION}.json`. TRACKED must equal a fresh hash inventory from exact baseline Git blobs. SOURCE's tracked entries must also match. Its 214 additional generated `.import` entries are explicitly counted as untracked metadata, not added to or substituted for the tracked inventory. No other unknown SOURCE entries are accepted. The six original F2 source paths are explicitly enumerated and independently checked against exact baseline Git and SOURCE hashes. Source inventory always runs from the repository root against the explicit project subtree. The nested-cwd empty-inventory regression remains tested.

Every original eight-map identity and every original available preset must equal delivered R19, including geometry, overlay, record key, time, hull, mechanics and law. Registry presets/families/order/timing remain exact. New-map F2 must exist; advertised preset, clock, fingerprint and hull must agree with the original preset. Saltglass and Tether Yard cannot retain stale R19 record identities. Map aliases and extra/missing/duplicate/shelved catalog IDs fail even with a newly reviewed identity hash.

## Parent freeze

Commit all final source before runtime probing. Dirty and untracked project files refuse identity, checking and packaging. The parent must explicitly confirm runtime authors are finished, then capture identity on that exact commit. The future identity command is implemented but has not been run:

```bash
python3 -B tools/package-r20.py identity \
  --runtime-frozen --source-commit "$(git rev-parse HEAD)" \
  --evidence /tmp/r20-package-helpers/final-identity
```

That command imports a committed scratch snapshot with the pinned editor. It is a runtime operation, outside preparation. It does not establish native/packed acceptance. Identity hash collection precedes the external final freeze JSON. Review the entire identity, then supply:

| field | required value |
| --- | --- |
| `schema` | integer `1` |
| `runtime_frozen` | boolean `true` |
| `source_commit` | exact full 40-character observed commit |
| `identity_sha256` | parent-reviewed canonical full identity SHA256 |
| `new_maps` | `["saltglass", "tether-yard", "through-line"]` |
| `required_maps` | `["breakwater", "whiteout-relay", "sunken-court", "rainline", "night-shift", "practice", "overflow", "experiment", "saltglass", "tether-yard", "through-line"]` |
| `experimental_maps` | `["experiment", "tether-yard", "through-line"]` |
| `reached_items` | explicit contiguous priority prefix, targeting `[1,2,3,4,5,6]` |
| `intentional_changes` | exact changed-old-path to reviewed SHA256 dictionary |

A partial reached prefix records progress but cannot pass complete delivery. The wrapper requires all six for assembly. Do not reduce the spec to obtain a green result. Movement Lab's original `experiment` card remains independent; Line Drive and Fall Line are absent from runtime selection and the menu while their original files remain protected. R19's three-to-five-new-experiments gate does not apply. Freeze keys granting a Breakwater exception are rejected.

## Final integration seams, all pending

`PENDING_FEATURES` in `tools/package-r20.py` blocks package and check before extraction/export. `tools/r20-pack-probe.gd::_r20_features()` also fails closed. Implement the checks below against finalized controls, then remove the matching pending entry only with real exact-pack evidence. Removing the Python entries alone cannot turn the probe green. No runtime API name for these new features is assumed by preparation.

1. **Saltglass route.** Earn the rebuilt route with real input, prove the obvious spawn skip is removed or skill-gated, top-fin entries and rising connector, flat landings, falls/checkpoint recovery without safety platforms, and 40–70 s F2. Compare surfing and bail-out lines. Geometry/string presence alone is not gameplay evidence.
2. **Directional stack.** Observe actual HUD pending stack, continued eligible backwards hops, banking at chain end and loss on stall. Check smaller sideways growth, anti-farm and invalid transitions. Extend `strict_style` only for an explicitly versioned directional event schema. Retain exact legacy event validation, event order/tick attribution, live-event equality, total/by-kind equality, complete seals and both readers. Do not raise old v1 limits to admit new events.
3. **Tether controls.** Drive actual held/released LMB/RMB, both-buttons comparison to inherited E, ground reel/jump, the real automatic-reel setting and 2–3 alternative models. Observe release and every automatic-detach visible/audible cue and its rule. Extend raw mouse-button recording observations in the probe and Python audit together; compare complete ordered input columns with both readers. Existing key/mouse-motion input checks and physics traces remain mandatory.
4. **Through Line.** Enter/finish the two-segment chain with real controls; observe launch feedback, trajectory cue, velocity and horizontal carry through an actual next-segment landing. Report whether transition feels seamless separately from numeric continuity. Never modify original-map finishes to make this pass.
5. **Export my runs.** Click the actual pause-menu control. Check the filesystem ZIP contains every local attempt, including restart/quit attempts and settings, with the clear player-facing name. Inspect bytes/CRC and settings against the isolated profile. Exercise the delivered ingest script into per-player folders and analysis, including malformed/path-traversal/duplicate ZIP cases. Only intercept the external folder opener, never the export operation. Extend the exact profile-write allowlist with observed files; do not wildcard user data. Ghost exchange remains separate.

The copied R19 probe already retains actual GUI clicks, name-field focus, select-all and typed input. R20 adds a typed `RFLG release probe` pass before the canonical export name, so old letter shortcuts are exercised without assigning `LineEdit.text`. It retains clean best export/import/selection, incompatible-version refusal, interpolation/noncollision and restored local-best selection. Final integration must additionally prove imported selection persistence across a fresh process while preserving the earned local-best reload check. Current inherited HUD assumptions (`r19_hud` extending R18) must be reconciled explicitly if final R20 introduces a new HUD subclass; retain the R18 interface contract and old checks.

Keep exact source/packed ordered input and physics trace comparison from the earned Breakwater route, full recording coverage and both strict readers, actual ghost reload, clean isolated profile/cwd and normal uninstrumented startup/Quit. Every final map must receive F9 telemetry/Look-label visibility, paused L gameplay invariance and original material/environment/light reference restoration. R20 scene, actual host, title/build, default F2 and EXPERIMENTAL suffix are required. No source-editor fixture against unfinished runtime is acceptance.

## Final assembly is parent work

The implemented future package/check entry points retain official Godot 4.7.2 Linux/Windows runtime pins, shared PCK, source/archive/resource/helper completeness, metadata, CRC, modes, licences/asset provenance, explicit free-display/desktop guards and hardware GPU verification. Playable ZIPs exclude tools/probes/tests/private look concepts and fixtures. Missing/malformed PCK and missing critical painted sky, including `--look=old`, require nonzero exit before the R20 startup identity. An error/assert followed by exit zero fails. Preparation tests simulate these refusals; they are not real pack-negative results.

Only outer `delivery/spillway-r20` can be an output, and it must be new/empty. Older deliveries are immutable. Preparation evidence stays under `/tmp/r20-package-helpers`, initially at most 100 MiB, with at least 15,000,000,000 HOME bytes free. Final identity/assembly must reserve their bounded RAM source/archive/import/work space separately before running, plus explicit HOME ZIP/evidence reserve above the floor. The inherited assembly requires at least 2.2 GB scratch and at least 400 MB HOME output reserve. Do not consume either during preparation.

The player README includes current primary controls, manual `Export my runs` ZIP transfer and separate `.spillghost` exchange. Finalize model toggles/detach rules against actual runtime. Windows recordings are `%APPDATA%\Godot\app_userdata\Spillway\r16_runs\`, with `spillway_r16.cfg` beside that folder. Native Windows execution remains **unverified** unless run there. A later pinned-PE/Wine proof using cached `/tmp/r19-windows-proof` is separate evidence and must not be described as native Windows. Do not ship Wine or its fixtures.

Preparation receipts: `/tmp/r20-package-helpers/{PREPARE.json,tests.log,r19-tests.log,preservation-tests.log}`. They cover 25 R20 helper tests, 18 unchanged R19 helper tests and seven parent preservation tests. GDScript parsing, final runtime APIs/features, exact packed/native checks, parity, Windows proof, ZIP assembly and promotion remain pending for the parent.
