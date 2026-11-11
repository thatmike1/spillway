# R21 portable delivery preparation

Only engine-free preparation is implemented. There is no R21 export, native acceptance or final ZIP claim. `identity`, `package` and `check` parse the parent freeze, require clean committed project source, then refuse with the production integration still pending. Even a syntactically complete freeze cannot clear `PENDING_GATES`. The new GDScript probe extends the R20 observer and deliberately reports failure with nonzero exit; it has not been parsed or run by Godot during preparation.

The four new delivery files are `tools/package-r21.py`, `tools/r21-pack-probe.gd`, `tests/test_package_r21.py` and this document. Existing helpers, tests, runtime and deliveries are unchanged by this work. Other R21 components have independent ownership.

## Baseline and composition

The preservation baseline is **`e6baa995da84d380abc8b8d6a3769b33e771945e`**. The frozen R20 ZIPs in outer `delivery/spillway-r20` were built from **`7f8fb41b741c01455682ae0c6ee612d5d6fd1fc4`**. The later baseline changes exactly the Windows verifier, its tests and R20 delivery notes. Those are distinct provenance facts. R21 must descend from e6baa; it must not relabel the old ZIP source as e6baa.

The preparation helper pins the accepted R20 BUILD, VERIFICATION and SHA256SUMS receipts. It checks that both named ZIPs remain present and that receipt identities agree. This receipt check does not rehash or execute those old ZIPs. Final R21 ZIP hashing is a separate required gate.

R20 is loaded into a private module, which constructs its own R18/R16 instances. R19 helpers and the repaired Windows runner are retained in the helper inventory. Every inherited helper must equal its exact committed e6baa bytes and the working helper bytes. No shared R20/R19 module is modified. Tests load independent R19/R20 instances and check their constants, helper inventories, expectation dictionaries and probe references remain unchanged.

The R20 implementations remain available for composition: committed source archive/export, source trace generation, actual ordered key/mouse input, binary physics comparison, both strict recording readers, complete lifecycle/seals, per-tick style/stack reconciliation, earned ghosts and reload, real control tours, profile-write audit, export/ingest, four broken-pack startup negatives, official runtime/template pins, assets/licences, ZIP membership/modes/CRC/SHA and shared PCK checks. R18 interface checks stay inherited. These functions still assert R20 identities. Final integration must adapt the R21 observer and orchestration around the frozen contracts, without replacing identity strings blindly or exempting their failures.

The separate committed `tools/check-r21-preservation.py` owns all old-file permissions. The delivery helper executes that committed API and calls its inventories/comparison/settings check. It carries **no second old-path allowlist**. Every old project file remains protected, including all six F2 pins, `r16_style.gd`, stack panels, Through Line, Classic/Pendulum/R20 Elastic and shelved files. Only the preservation owner's exact reviewed scene/version and ghost-share-label hashes can permit its narrowly allowed old changes. Deletions, modes, stale approvals and protected edits still refuse. If that API has not been committed yet, preparation explicitly reports it pending; release never becomes available.

## Parent freeze contract

Use strict JSON without duplicate keys. `validate_freeze` requires the following. Values described as reviewed are external parent decisions, not defaults this helper invents.

| field | contract |
| --- | --- |
| `schema`, `runtime_frozen` | integer `1`, boolean `true` |
| `source_commit` | exact full 40-character final source commit |
| `identity_sha256` | independently reviewed canonical whole runtime identity SHA256 |
| `intentional_changes` | exact changed-old-path SHA256 dictionary, validated by the preservation owner |
| `required_maps` | ordered `breakwater`, `whiteout-relay`, `sunken-court`, `rainline`, `night-shift`, `practice`, `overflow`, `experiment`, `saltglass`, `tether-yard`, `through-line` |
| `experimental_maps` | exactly ordered `experiment`, `tether-yard`, `through-line` |
| `reached_items` | nonempty contiguous prefix of spec items `[1,2,3,4]`; complete release needs all four |
| `runtime` | explicit `build`, `version`, `main_scene`, `main_script`, `hud_script`; build/version end in `-r21` |
| `map_versions` | exactly `saltglass` and `tether-yard`, each with reviewed `level_id`, integer `level_version`, geometry SHA256 and `level_script` |
| `models.original` | ordered `classic`, `pendulum`, `elastic` mapped to reviewed canonical actual-rules SHA256 values |
| `models.elastic_variants` | exact approved ordered list of two or three `{id, base:"elastic", rules_sha256}` objects |

Variant IDs, rules, host paths, build identity and geometry hashes are intentionally not supplied as a fake final freeze. The fixture values in Python tests are synthetic gate tests only.

`identity_boundary` requires the complete original registry and startup identity to match R20. All original eight map identities and every preset key remain exactly equal, and Through Line receives the same complete equality checks. Revised maps need new geometry, a greater level version and a new module, with changed course/record identities that bind the frozen version/geometry. Source preset, clock, fingerprint, hull, timing and overlay/style identity remain exact. Saltglass additionally retains its exact runner chain and mechanics. Tether's new mechanics require the independent actual-model observations checked by `model_boundary`: original model rule objects remain equal, and every variant's actual rules must hash to its approved value. Labels alone cannot satisfy that gate.

No `pending`, `skip_gates`, `allow_failures` or Breakwater exemption can be added to the freeze. Dirty or untracked project files are reported during preparation and refused for later runtime operations. Preparation reads committed snapshots while sibling workers continue; it does not stage or clean their files.

## Production work still required

These are release requirements, not preparation passes. The explicit pending list keeps every release command closed until implementation and review of these seams:

1. Bind the new host/HUD/scene/build identities and preserve the complete R20 host behavior, R18 interface, eleven-map old/new L toggle, labels, telemetry/F9, settings, focus, ghost folder/sharing, export and actual Quit. Preserve Through Line's exact scene/player/session/attempt/clock behavior and all six R20 features.
2. Generate fresh input-earned Saltglass routes on the final production geometry. Measure lowered and spaced exit heights/speeds, high fin entries, flat landings and optional hard outside lines. Prove no safety catch/free skip, failed-line checkpoint recovery and 40–70 seconds F2. Keep generic geometry-backed scoring; no hand-placed route bonus.
3. Drive acquisition at speed, preview before pressing, and blocked/occluded anchor refusals. Exercise actual earned routes for every new Elastic variant, independently read their sealed recordings and replay exact inputs/physics against the source traces. Compare unchanged Classic/Pendulum/R20 Elastic, E versus LMB/RMB, manual/automatic reel, fresh-press/release rules and real platform clearance. A rules-hash receipt alone is insufficient.
4. Use committed archive snapshots for every import/export. Validate committed bytes before/after import and retain the generated inventory before cleanup. Generated UID sidecars must pair with committed `.gd`/`.gdshader` files and contain one `uid://` identifier of 1–13 lowercase alphanumeric characters plus a newline. `.import` sidecars must pair with committed `.png`, `.jpg`, `.hdr`, `.gltf`, `.glb` or `.ttf` assets and start with `[remap]`. The 65,536-byte bound, UID pattern and asset suffix list match committed R20 `check-r20-candidate-parity.py:import_metadata_guard`. Unknown code, missing files, changed hashes, oversized/unpaired metadata and symlinks refuse. The prepared `generated_sidecars` validator must be wired into the future assembly; it has not checked an actual R21 import.
5. Execute the exact packed release from an empty cwd with no loose source/probes available through resource fallback. Keep the actual OS-input control tour over all eleven maps, both readers, sealed-record/live-source actual trace parity, old/new look and clean ghost reload. Preserve full original-eight physical/input parity separately. Require four nonzero broken-pack refusals: missing PCK, malformed PCK, missing critical sky in new and old look. An assertion followed by exit zero fails.
6. Verify both final ZIPs, CRC, modes, complete source/helper/resource/asset/licence manifests, official runtimes and identical PCK; emit BUILD, VERIFICATION and SHA256SUMS bound to the exact source and ZIP bytes. Run the pinned Wine checker separately against the exact final Windows ZIP on all eleven maps. Its repaired `--log-file` must stay outside user data, preserving the default-engine-log fix while rejecting real game-data writes. Do not claim native Windows play from PE/Wine startup, or enjoyment/listening/latency from automated checks.

R20 production fixture paths cannot simply be reused for a changed geometry/model and declared valid. Parent components may supply new seams and fixtures after runtime review. Those integrations remain pending here, including actual parsing of `r21-pack-probe.gd`.

## Storage and publication

Laptop HOME has only about 325 MB above the required **15,000,000,000-byte floor** at task entry. The full R20 output was about 632 MB; writing a comparable R21 output directly to HOME is unsupported. Never delete old deliveries, private inputs, worktrees or another worker's evidence.

`storage_plan()` exposes the supported full-output route `/tmp/r21-package-helpers/export/spillway-r21`, separate from bounded assembly scratch `/tmp/r21-package-helpers/assembly`. Reserve the inherited 2.2 GB assembly budget plus at most 700 MB output/evidence on tmpfs before the future run. The current R20 size is an estimate for planning, not a guarantee of R21 peak size. The parent must measure all owned scratch and output together, refuse if they exceed the budget, keep HOME above its floor throughout, and arrange headroom rather than increasing the budget silently. No export directory is created by preparation.

After exact ZIP acceptance, the parent archives raw evidence **losslessly to the existing trusted backup**, with a complete per-file size/SHA256 manifest and verified remote archive SHA256/restoration evidence. Retain that compact archive receipt and restoration manifest locally. Only after checking the backup against every source file may the parent remove its owned TMP intermediates. No raw gate proof may be omitted to save space. This helper performs no archival, transfer or deletion.

The parent then keeps the exact verified pair of ZIPs, about 245 MB at R20 size, plus compact BUILD/VERIFICATION/SHA256SUMS, licenses/manifests and archive pointers in outer `delivery/spillway-r21`. Recheck actual bytes against HOME headroom before copying; fail if they cross the floor. The final receipts must bind the same exact ZIPs and PCK that passed runtime acceptance, with the raw-proof archive location/hash. Parent owns final publication and any desktop copy.

Preparation uses pure Python/Git and cache hashing only, with owned TMP limited to 30 MiB and durable preparation files limited to 5 MiB. No editor, native display, export, package or gameplay process is authorized in this phase.

Preparation commands, from `projects/foldrunner`:

```sh
python3 -B tests/test_package_r21.py
python3 -B tests/test_package_r20.py
python3 -B tests/test_package_r19.py
python3 -B tests/test_r20_windows_release.py
python3 -B tools/package-r21.py prepare
python3 -B tools/package-r21.py --help
python3 -B tools/package-r21.py package --help
```

The unmodified R20 suite's preparation test requires the literal branch `feat/spillway-r20`. On the shared R21 branch that one test refuses as designed. For the complete baseline suite, preparation used a disposable sparse Git view at exact e6baa with that branch name, borrowing existing objects and materializing only tools/tests. All 36 tests passed without editing helpers/tests or switching the shared checkout; its peak file size was 8,324,675 bytes, then that owned view was removed. The direct R21-branch run's refusal is retained as a scoped result, not a passing R21 preflight.

Successful `prepare` prints `prepared:true`, `release_ready:false`, `runtime_checked:false`, `candidate_exported:false` and all remaining gates. It is never a final green claim. Runtime integration, freeze review, GDScript parse, production fixtures, import/export, exact packed/native checks, parity, Windows startup, archival and final publication remain parent work.
