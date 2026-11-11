# R21 portable delivery orchestration

The reusable `identity`, `package`, `check` and separate `wine` paths are implemented around private frozen R20/R18/R16 helpers. This phase uses Python/Git only. No R21 probe parse, import, engine, export, native acceptance, Wine execution or final candidate is claimed.

The three `COMPONENTS` adapters are installed by `tools/r21-delivery-components.py`. `integration_ready` requires their exact committed input hashes in the existing shared `delivery_components` freeze field. Before any runtime operation, `review_inputs` also requires the parent’s final reviewed parity contract, whole identity and complete raw proof. Missing or stale artifacts refuse even though adapter code exists. `--execute-frozen-runtime` remains a separate required execution switch. This implementation does not supply that authorization.

## Frozen inheritance and identity

Preservation/verifier baseline: `e6baa995da84d380abc8b8d6a3769b33e771945e`. Accepted R20 artifact source: `7f8fb41b741c01455682ae0c6ee612d5d6fd1fc4`. These are distinct. `baseline_delivery` pins the accepted BUILD/VERIFICATION/SHA256SUMS receipts and ZIP membership; it does not rehash or run the old ZIPs. Final R21 ZIPs are independently hashed by the static checker.

Every inherited helper must equal both its exact e6baa Git blob and working bytes. R20 constructs private R18/R16 module instances. `configure` changes only those private objects: release filenames, host/scene/title/probe, recording build/version, inventory and explicit orchestration callbacks. The behavioral R16 build, profile namespace, engine/runtime/licence pins and physical assertions remain unchanged. Independent R19/R20 loads retain their original state.

The original R20 `native_checks`, `audit_profile`, `audit_style_stream`, `run_export_profile_audit`, `static_check`, `pack_negatives` and Through Line generator function implementations remain intact. The R21 checker composes these, including:

- startup and actual GUI/keyboard/mouse control tours over all eleven maps, preset switching, L, stage practice, lab, crouch, focus and Quit;
- backwards/sideways stack banks/losses and live style reconciliation, buffered export/ingest/duplicate/broken bundles, friend export/import/wrong version, nonphysical ghost interpolation;
- sealed recordings through both strict readers, raw ordered inputs and binary columns, earned source-to-pack trace equality, best promotion and separate-process reload without config rewrite;
- isolated profile-write inventories, official runtime hashes/headers, asset/licence provenance, safe complete ZIP membership, Unix modes, CRC, SHA256SUMS and a common PCK;
- four nonzero broken-pack controls: missing PCK, malformed PCK, missing critical sky in each look. Logging an assertion and exiting zero fails.

The typed `tether_model` loadout-boundary observer admits only the independently frozen additional model IDs, retaining the original event/tick/map/from/to requirements. The additional `tether_anchor_assist` boundary requires actual `loadout`/`event`, matching integer tick, Tether map, unequal boolean `from`/`to` values and the existing `tether_settings` reason. Supplemental profile, effective-settings and recording-event checks admit exactly the existing keys plus this boolean; unknown keys refuse. No old control failure is waived and no check-count target is lowered. The R21 probe extends R20 and overrides only identity-bearing observers. Its base identity checks are copied exactly from R16 before adding R21 host/HUD/service checks. Friend controls are copied exactly with only the expected build operand changed; scoring identity remains `r20-style-stack-1` with its frozen rules digest. The original surf judge, physical/input observer, stack, Tether reference controls, Through Line controls, rendering, lifecycle, record, ghost and reload methods remain inherited. Failed observer checks take a nonzero end path.

`_r21_saltglass_controls` inspects the packed production geometry. `_r21_tether_controls` follows every inherited control with six model routes and four effective assist-off routes selected through the actual UI. A separate passive observer requires ready prior-ID attachment agreement and exact HUD observations; it does not override inherited early/late physics or input observers. Additional labelled packed-runner fixtures exercise range, view, cone, endpoint occlusion and zero/one/three render-call cadence. Actual host restart, pause, practice, respawn, model/reel/assist/preset/map boundaries, ghost separation and original-map isolation stay required. None of these new methods has been parsed by Godot in this assignment.

`identity_boundary` protects the entire original registry/startup, each original eight map/preset identity and Through Line exactly. Revised Saltglass/Tether require new modules, greater versions, changed geometry and changed record/course keys. F2 source law, clock, hull, timing and style identity stay exact. Saltglass retains its exact motor chain. `model_boundary` compares actual original rule/control objects with an independent frozen R20 runner and hashes all observed variants against the reviewed freeze. The identity observer uses current production `configure_tether`, `model`, `auto_reel` and `tether_identity`; its rules projection contains `classic`, `alternative`, `controls` and `effective_reel_ups`, excluding selection/version labels. Reel rate comes from an explicit model declaration, then the alternative declaration, then the inherited classic default. This binds the slow-reel axis even when declared outside the spring object. Component force/rest-length probes must separately establish that the runtime applies the declared values. The component adapter separately checks the actual applied law projections against these freeze hashes, requires at least the existing 75 component checks and 12 applied Arc probes, and exercises assist in real production routes.

The preservation owner's **committed** `tools/check-r21-preservation.py` API owns all old-file permissions, including all six F2 pins. This helper has no second allowlist. Reviewed old-path changes must match exact hashes; deletions, modes, stale approvals and protected source changes refuse.

## Parent freeze and adapter seam

Strict JSON rejects duplicate keys. Required fields remain:

| field | requirement |
| --- | --- |
| `schema`, `runtime_frozen` | integer `1`, boolean `true` |
| `source_commit`, `identity_sha256` | full final commit and independently reviewed canonical runtime identity digest |
| `intentional_changes` | exact old-path SHA256 approvals consumed by preservation owner |
| `required_maps` | ordered original eight, `saltglass`, `tether-yard`, `through-line` |
| `experimental_maps` | ordered `experiment`, `tether-yard`, `through-line` |
| `reached_items` | contiguous spec prefix; execution requires `[1,2,3,4]` |
| `runtime` | explicit `build`, `version`, `main_scene`, `main_script`, `hud_script`; build/version end `-r21` |
| `map_versions` | Saltglass and Tether each declare `level_id`, greater integer `level_version`, geometry SHA256, new `level_script` |
| `models` | original Classic/Pendulum/Elastic actual rule hashes and exact ordered two or three `{id, base:"elastic", rules_sha256}` variants |
| `delivery_components` | exact `saltglass`, `tether`, `parity` dictionaries of each installed adapter's committed input paths to SHA256 |

No exemptions, default variant IDs, geometry, fixture hashes or expected feature outcomes are invented. Test identities and byte fixtures are explicitly synthetic.

`ComponentGate(paths, source, packed)` is a **delivery-owned integration seam**, not a claim about an unfinished component API. Parent installs its adapters in this file once actual production contracts exist:

1. `paths` names all committed fixture/generator/validator inputs. `integration_ready` requires a nonempty exact path set, matching freeze hashes and committed manifest, plus both callable validators. Runtime/level resources must exist in that same commit.
2. `source(source, evidence, identity, freeze)` earns and independently validates actual production fixtures. It returns nonempty named successful `checks`, a nonempty relative-path `proof` SHA256 inventory under its evidence directory, and `binding = evidence_binding(component, "source", freeze)`.
3. `packed(folder, build, args, all_evidence, evidence, routes)` validates the exact delivered runtime using those fixtures. It returns the same evidence envelope with stage `"packed"`. Empty, boolean/no-op, wrong-stage/source/identity or missing/mutated proof responses refuse.
4. Saltglass source supplies nonempty `routes` from the actual configured host. These run through the inherited strict source/packed/play/reload pipeline. Tether supplies nonempty recording-derived `feature_tapes.tether` for **every** frozen original and variant model. Its adapter must prove exact raw-input/source/packed replays and both readers; it may add ordinary compatible play routes. Through Line tapes always use its unchanged R20 generator/reader. Parity must bind the actual final original-eight proof, without tolerances or scoring exemptions.

Each ordinary play route needs a nonempty tape/finite ordered trace, correct F2 rate, positive duration, complete clean source finish, ordered progress, delivery/order/rate/cleanup receipts and no integrity flags or game-difference exemption. The component validators own additional real model/assist fixtures; the generic envelope is not a substitute for those checks.

The Saltglass adapter runs the actual `r21_surf_route.gd` production scene and requires clean 40–70 s F2, the unchanged R15 Source runner, all sixteen fin contacts, zero steep grounding and matching final geometry. Its tape retains the closing neutral edge through the inherited `include_cleanup_tick` and complete `source_route` pipeline. It reruns integration, full geometry negatives, open-loop and L-off replay, both bail cases, both turnaround cases, all safe/outside/late skill fixtures, all eight old/new exit comparisons and old/new ghost separation. The unchanged full `r21_surf_audit.py` and `r21_surf_matches.py` judge their real output. Local skill fixtures are explicitly not normal-spawn routes. A final-source hash seam and nonempty inherited preservation inventory replace reliance on the historical zero-count receipt; the independent preservation owner still checks the whole committed tree.

Tether requires the actual ordered `classic`, `pendulum`, `elastic`, `elastic-soft`, `elastic-firm`, `elastic-arc` interface, level `r21-tether-yard` version 2 and deck heights 4/3/4/2.25. It earns ten production routes, derives raw tapes from the unchanged strict reader, then replays each with the same model/manual-reel/assist state. Every binary physics and raw/action input column plus the complete observed motion/style trace must match between source plays. The actual production boundary suite retains at least 253 checks, and the separate-process reload suite run with the earned recording manifest. Both original readers then compare every generated recording, including lifecycle attempts.

Packed Tether compares each complete physical trace and every independently decoded binary physical column to its source recording. The inherited independent input audit checks delivered raw input, including public restart/menu boundaries, against the packed recording. The original four Tether controls and Through Line controls still run in full. Source evidence envelopes are rehashed at packed acceptance, rather than accepted by their success flag.

Parity requires `/tmp/r21-candidate-parity`, the exact final candidate, shared freeze, identity, runtime/helper inventories, sixteen routes, 48 plays, 144 streams, original 56 controls and actual candidate negatives. The installed adapter reruns the unchanged final pure auditor in a separate process. Its unchanged raw guard is also called at source and packed read-back, including raw/gzip transport hashes. A source parity pass is composed with actual complete all-map Linux native controls, earned packed/source trace/input checks and reloads; it cannot establish native Windows parity.

## Snapshot, execution and reports

`preflight` requires this exact R21 branch/HEAD, clean committed project source, all helper hashes, scene persistence/recording, inherited host chain, export exclusions, asset/runtime pins and preservation approvals. It writes no source or output. Parent dirty integration files remain untouched and block execution.

Every operation extracts an explicit Git archive to owned assembly scratch, rejects special entries, checks every committed hash and compares executed helpers. `import_snapshot` checks before and after import, inventories the engine cache separately and records `IMPORT.json` before cleanup. `generated_sidecars` retains R20's exact policy: bounded 65,536-byte paired `.gd`/`.gdshader` UID with `uid://[a-z0-9]{1,13}` plus newline, or paired `.png/.jpg/.hdr/.gltf/.glb/.ttf` `.import` beginning `[remap]`. Unknown code, symlinks, missing/changed committed files, unpaired or malformed metadata refuse. `snapshot_guard` repeats the exact inventory comparison after identity, export and fixture generation. The `.godot` cache is moved outside the source inventory during checks, never silently treated as committed source; injected `.gd`, `.gdshader` or `.py` cache source also refuses.

`package` imports, observes identity/model rules, exports one PCK, earns source fixtures, assembles both official runtimes and deterministic ZIPs, removes its loose source before exact-package execution, and runs all static/native/component gates. It publishes ZIPs only after successful checks. BUILD, VERIFICATION and SHA256SUMS bind source/tree/archive/manifest/helpers/assets/runtime/PCK/ZIP bytes. Failure records `FAILURE.json`, preserves raw proof and returns nonzero. A pure synthetic assembly test exercises success/failure sequencing; it is not an exported game.

`check` independently rebuilds source fixtures from the same committed archive and checks the exact supplied pair again. `identity` uses the same archive/import/guard/observer path without exporting. Neither command can bypass readiness by accepting empty fixtures.

`wine` is an explicit **later** command, never automatic during assembly. It requires the reviewed freeze, exact statically verified candidate and portable loader SHA256 `91dfdd714f2c9078f010341346196d426e81c633ca0865cf7cc678e2825562db`. It reuses the frozen runner's execution/budget/process helpers, boots all eleven maps from the official Windows PE, and validates stdout plus separate `--log-file` logs. Engine logs remain outside game user data, preserving the repaired R20 behavior. Extracted bytes and all Spillway profile writes remain audited. RESULT pins the actual ZIP/PCK/loader/source and each map's logs. This is Wine startup only, never native Windows play.

## Resources and handoff

This adapter assignment owns at most 30 MiB under `/tmp/r21-delivery-bindings` and 2 MiB of compact durable receipts under outer `look/evidence/r21-delivery-bindings`. No engine, GUI/native display, export, Wine, installs, caches, render or packages are authorized in this phase.

Future full execution reserves **2.2 GB assembly plus at most 700 MB output/evidence**, together 2.9 GB. Both available tmpfs space and `MemAvailable` are checked before execution. HOME must remain above **15,000,000,000 bytes**. Guards measure all owned scratch/output together and run before/after each inherited engine launch as well as assembly stages. Output stays `/tmp/r21-package-helpers/export/spillway-r21`; assembly stays `/tmp/r21-package-helpers/assembly`. Symlink traversal, overwriting existing evidence and output under source or HOME refuse. At this implementation phase's first sample, HOME had 15,297,294,336 bytes and tmpfs 2,769,264,640 bytes. **That tmpfs sample cannot support full assembly.** Parent must establish headroom first without deleting another worker's data.

Raw work remains on failure and after successful checking. Parent must archive **all raw proof losslessly** to the existing trusted backup with a complete per-file size/SHA inventory, verified archive hash and restoration evidence. Only then remove owned intermediates. Keep the exact accepted ZIP pair plus compact BUILD/VERIFICATION/SHA256SUMS, licence/manifests and archive receipts locally, rechecking HOME headroom before the final copy. Final publication, gameplay promotion and desktop copies remain parent work.

Pure verification commands from this directory:

```sh
python3 -B tests/test_package_r21.py
python3 -B tests/test_r21_delivery_components.py
python3 -B tests/test_package_r19.py
python3 -B tests/test_r20_windows_release.py
python3 -B tools/package-r21.py prepare
python3 -B tools/package-r21.py package --help
python3 -B tools/package-r21.py wine --help
```

The R20 preparation test requires literal branch `feat/spillway-r20`. Running that unchanged suite directly on R21 refuses that one branch check. Use a disposable sparse Git view at exact e6baa and that literal branch for its complete pure suite; never switch/reset the shared checkout or edit the baseline test. The Windows unit suite uses mocked processes and is not Wine execution.

`prepare` is read-only and reports missing preservation approvals as `preservation.ok=false`, with the rejection reason. It does not infer approval for committed old-file edits; runtime `preservation` still requires the parent’s exact approved hashes.

The parent’s final `tests/r21_surf_integration.gd` checks exact all-eleven catalog membership/order, exact revised SURF/TETHER entries, equality of all other entries, Through Line identity and Tether revision separation. The adapter runs this complete check without bypasses. Its final execution remains pending; the historical Salt-only catalog assertion cannot substitute for it.

After the parent reviews and commits the complete runtime and helper inventory, the execution order is final identity/freeze/contract review, the separate authorized 48-play parity capture and audit described in PARITY.md, then package verification. The shared freeze keeps the existing fields; there is no delivery-specific top-level extension. Parent-created absolute paths below must name the reviewed files, not templates:

```sh
python3 -B tools/package-r21.py package --freeze "$R21_FREEZE" \
  --parity-contract "$R21_PARITY_CONTRACT" \
  --parity-contract-sha256 "$R21_PARITY_CONTRACT_SHA256" \
  --parity-identity "$R21_IDENTITY" --execute-frozen-runtime
```

`identity`, `check` and `wine` accept the same three parity arguments and existing command-specific arguments shown by their `--help`. The contract SHA binds the exact parent-reviewed bytes; the adapter never writes a review or substitutes a fixture identity. Final Godot parse, source/native parity, complete packed controls/recordings/reloads/ghosts, Wine, raw-proof backup and final ZIP acceptance remain separate parent execution. No new candidate, package, promotion or native Windows claim is made here.
