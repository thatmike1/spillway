# R20 delivery and verification

All six runtime items and their behavioral gates are implemented. Full frozen-candidate verification remains required before publishing ZIPs. `prepare` is read-only and engine-free; it reads committed Git blobs and hashes cached official runtimes/licences. The component and partial-release receipts below retain their original scope; none substitutes for final acceptance.

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

## Required final behavioral gates

`PENDING_FEATURES` is now empty because every feature has executable probes. Setting a future pending entry still refuses assembly before extraction/export. Complete controls acceptance separately requires every ordered map and positive directional, Tether, Through Line, export/ingest and persisted-profile receipt; missing, false or numeric substitutes for boolean acceptance fail. Play mode retains its clean recorded route, R20 identity, exact input/physics comparison and real ghost reload. No single preparation flag can turn those gates green.

1. **Saltglass route.** Earn the rebuilt route with real input, prove the obvious spawn skip is removed or skill-gated, top-fin entries and rising connector, flat landings, falls/checkpoint recovery without safety platforms, and 40–70 s F2. Compare surfing and bail-out lines. Geometry/string presence alone is not gameplay evidence.
2. **Directional stack.** Observe actual HUD pending stack, continued eligible backwards hops, banking at chain end and loss on stall. Check smaller sideways growth, anti-farm and invalid transitions. Extend `strict_style` only for an explicitly versioned directional event schema. Retain exact legacy event validation, event order/tick attribution, live-event equality, total/by-kind equality, complete seals and both readers. Do not raise old v1 limits to admit new events.
3. **Tether controls.** Drive actual held/released LMB/RMB, both-buttons comparison to inherited E, ground reel/jump, the real automatic-reel setting and 2–3 alternative models. Observe release and every automatic-detach visible/audible cue and its rule. Extend raw mouse-button recording observations in the probe and Python audit together; compare complete ordered input columns with both readers. Existing key/mouse-motion input checks and physics traces remain mandatory.
4. **Through Line.** Enter/finish the two-segment chain with real controls; observe launch feedback, trajectory cue, velocity and horizontal carry through an actual next-segment landing. Report whether transition feels seamless separately from numeric continuity. Never modify original-map finishes to make this pass.
5. **Export my runs.** Click the actual pause-menu control. Check the filesystem ZIP contains every local attempt, including restart/quit attempts and settings, with the clear player-facing name. Inspect bytes/CRC and settings against the isolated profile. Exercise the delivered ingest script into per-player folders and analysis, including malformed/path-traversal/duplicate ZIP cases. Only intercept the external folder opener, never the export operation. Extend the exact profile-write allowlist with observed files; do not wildcard user data. Ghost exchange remains separate.

The copied R19 probe already retains actual GUI clicks, name-field focus, select-all and typed input. R20 adds a typed `RFLG release probe` pass before the canonical export name, so old letter shortcuts are exercised without assigning `LineEdit.text`. It retains clean best export/import/selection, incompatible-version refusal, interpolation/noncollision and restored local-best selection. Final integration must additionally prove imported selection persistence across a fresh process while preserving the earned local-best reload check. The verified inheritance chain is `r20_hud` → `r19_hud` → `r18_hud`; all inherited interface checks remain.

The independent raw-input observer and Python audit now include mouse-button rows alongside keys and mouse motion. Button index, pressed/double-click flags, float32 factor, tick, lifecycle tails and order use the existing exact comparison. The remaining audit AST is compared with R19 after these explicit additions, the full-header comparison and extraction of scored-event accounting into `audit_style_stream`. A serializer-only fixture verified five actual original-recorder rows and all nine input columns through both readers; `look/evidence/r20-release-input-prep/MOUSE-ROWS.json` records its scope. This is preparation, not a Tether gameplay or packed-release pass.

Keep exact source/packed ordered input and physics trace comparison from the earned Breakwater route, full recording coverage and both strict readers, actual ghost reload, clean isolated profile/cwd and normal uninstrumented startup/Quit. Every final map must receive F9 telemetry/Look-label visibility, paused L gameplay invariance and original material/environment/light reference restoration. R20 scene, actual host, title/build, default F2 and EXPERIMENTAL suffix are required. No source-editor fixture against unfinished runtime is acceptance.

The release route list now retains Breakwater and adds Saltglass. `saltglass_route_freeze` generates an earned input tape from the frozen production scene and reruns it through the unchanged source executor. Its closing neutral releases are retained by adding one explicit cleanup tick; no original edge is removed. Preparation on committed item 1 passed 7,969 ticks, clean 62.046875 seconds, exact rate/order checks and normal cleanup. The native probe compiles and observes actual fin contacts and first flat landings. These additions have not yet run against a packed release, so `saltglass-route` remains pending.

Separate `strict_stack_style` and `strict_direction` validators implement the v2 bank and non-scored diagnostic schemas. They check the triangular formula, distinct backwards/sideways units, unamplified banks, chronological hop bounds and explicit non-scored fields. Their mutation tests include the 30,400-point backwards bank, above the legacy ceiling, and the smaller 9,500-point sideways bank. `strict_legacy_style` retains the original R19 checker exactly; ordinary R20 events additionally require direction multiplier one and exclude immediate directional awards.

`audit_style_stream` retains per-tick live scored-event equality, score totals and seal/by-kind reconciliation. The observer also reads the live direction snapshot, simulation clock and detector verdict. Dense diagnostic serials must reconstruct the observed pending state, and each positive terminal bank must match its eligible hop history, reason, formula and actual recorded speed. Bank labels must match their category. Speed is reproduced from the float32 recorded components using the pinned Godot vector arithmetic before division by 0.0254; ordinary double-precision `hypot` differs from that engine calculation. Only the existing JSON text comparison applies to its reported measurement. Binary physical and input comparisons remain exact.

A first flight may name its direction before its first zero-point eligible landing. Capture diagnostics and pre-seal lifecycle losses are processed on their respective sides of the physical observation; queued settings/respawn losses may refer to an earlier payload tick. Lifecycle losses require a matching recorded host boundary. Non-scored diagnostics cannot inflate score or the scored event tally. Synthetic bank, stall, queued-settings and quit fixtures plus mutations test these paths. The helper suite has 32 tests.

`tests/r20_release_style_observer.gd` independently reads the actual scorer at priority 1000, after its step and before the fixture can seal or replace its host. It extends the earned item2 fixture without changing motion, score or recording behavior. A fresh frozen-db8d060bf run passed all 265 fixture checks and collected 45,031 independent live samples. `python3 -I tools/check-r20-style-events.py --run /tmp/r20-style-release-observer/run` reconciled all 65 episode recordings against these scored-event and pending-state observations, both readers' headers/events/seals, and dense event order. Ten mutations of real earned data were refused. This is source-observer acceptance, not packed-release or all-map physical parity. Raw proof and source hashes are in outer `look/evidence/r20-style-release-observer`; the exact-pack directional feature gate remains closed until it runs there.

## Final assembly is parent work

The implemented future package/check entry points retain official Godot 4.7.2 Linux/Windows runtime pins, shared PCK, source/archive/resource/helper completeness, metadata, CRC, modes, licences/asset provenance, explicit free-display/desktop guards and hardware GPU verification. Playable ZIPs exclude tools/probes/tests/private look concepts and fixtures. Missing/malformed PCK and missing critical painted sky, including `--look=old`, require nonzero exit before the R20 startup identity. An error/assert followed by exit zero fails. Preparation tests simulate these refusals; they are not real pack-negative results.

Only outer `delivery/spillway-r20` can be an output, and it must be new/empty. Older deliveries are immutable. Preparation evidence stays under `/tmp/r20-package-helpers`, initially at most 100 MiB, with at least 15,000,000,000 HOME bytes free. Final identity/assembly must reserve their bounded RAM source/archive/import/work space separately before running, plus explicit HOME ZIP/evidence reserve above the floor. The inherited assembly requires at least 2.2 GB scratch and at least 400 MB HOME output reserve. Do not consume either during preparation.

The player README includes current primary controls, manual `Export my runs` ZIP transfer and separate `.spillghost` exchange. Finalize model toggles/detach rules against actual runtime. Windows recordings are `%APPDATA%\Godot\app_userdata\Spillway\r16_runs\`, with `spillway_r16.cfg` beside that folder. Native Windows execution remains **unverified** unless run there. A later pinned-PE/Wine proof using cached `/tmp/r19-windows-proof` is separate evidence and must not be described as native Windows. Do not ship Wine or its fixtures.

Preparation receipts: `/tmp/r20-package-helpers/{PREPARE.json,tests.log,r19-tests.log,preservation-tests.log}`. They cover 25 R20 helper tests, 18 unchanged R19 helper tests and seven parent preservation tests. GDScript parsing, final runtime APIs/features, exact packed/native checks, parity, Windows proof, ZIP assembly and promotion remain pending for the parent.

## Authored-map directional release controls

The R20 controls probe now drives four real Penstock checkpoint-practice routes using `tools/r20-direction-driver.gd`: backwards/sideways normal banks and backwards/sideways stall losses. It selects the map and stage through actual pause controls, earns at least six eligible hops with movement input, checks the triangular bank/category and zero score on loss, and compares moving and paused L without changing gameplay state. The external probe copies this small driver beside itself; no test map or substituted collision world is shipped.

A private AMD/X11 rehearsal used the official release template and a PCK exported from frozen item4 runtime with the reviewed probe overlays. All 122 checks passed, including the native stage picker, four routes and actual Quit. This is partial-build probe verification, not acceptance of the final R20 candidate. The earlier source-editor attempt selected the wrong checkpoint because its popup did not open and was stopped; that failure is retained. The route now refuses to continue from a wrong stage. The rehearsal's isolated recording profile was cleaned, so it does not claim a cross-reader audit of those files; final package acceptance retains and audits its fresh recordings.

The runtime now uses `r20_hud.gd` extending R19 and R18. Source identity and packed inheritance checks require that complete chain. The final all-feature result remains unverified until the complete frozen candidate executes every controller and audit.

## Reader-derived Tether release controls

The controls probe replays the three input-earned Tether routes with ordered raw key, mouse-button and motion rows. It chooses Classic, Pendulum, Elastic and automatic reel through actual pause buttons, restarts through R, waits exactly 33 relative motor steps, and observes the real three-anchor clean finish. Automatic reel omits RMB from Classic's raw tape and must match the entire manual both-button physical trace exactly. Release-cue activation and PCM hashes are observed, without a listening claim. Final assembly generates fresh tapes from the frozen production host and original reader; its native result requires these controls and the Penstock checks to pass.

The partial official-release rehearsal passed 45 controls. Its 12 sealed recordings independently passed the original physical/input/profile audit: 6,369 ticks and 7,039 ordered input rows, both strict readers, exact binary column agreement and scored/diagnostic reconciliation. Its PCK/runtime hashes and raw proof are retained externally. This remains rehearsal evidence on frozen item4 runtime, not the final all-feature package.

Rejected probe iterations remain labelled. The first assumed the lifetime motor counter reset on R and requested an absent screenshot-state field. The second passed its controls but created a valid zero-sample loadout attempt by changing two settings while paused. Both strict readers accept that empty attempt; the inherited release audit requires sampled attempts and rejected it. The accepted probe resumes between those two changes and checks that no held input attaches. The old audit remains unchanged. The accepted rehearsal retains every recording for independent accounting; no attempt is filtered out.

### Through Line packed controller

The controls probe selects Through Line through the actual pause menu and replays two bounded, ordered raw-input tapes regenerated from frozen source recordings. It requires a clean finish at both entry speeds, actual second-segment ground support, exact horizontal velocity through launch and landing, a larger rise and range for the faster entry, active sound diagnostics, and continuous scene, level, player, session, attempt and clock identities. Every recording produced during these controls is audited by the original profile/input checks and both recording readers.

The preparation rehearsal at `look/evidence/r20-through-release-prep/` passed 22 official-release controls and independent accounting for six recordings, 3,797 ticks and 2,513 input rows. This used a partial frozen pack and does not replace the final complete-candidate run. The service, physics, visuals and human perception remain distinct claims.

## Frozen visual and route identity checks

`python3 -B tests/r20_visual_check.py --commit "$R20_FINAL_COMMIT" --out /tmp/r20-final-visual` runs the delivered R17 visual-invariant fixture against a committed R20 host on all eleven maps. It verifies the inherited fixture against its exact R19 Git blob, changes only the host preload in an isolated adapter, and retains every original assertion. The receipt binds the complete source, adapter, official editor and resource bounds. It checks ink/lips/functional markings, indoor bands, repeated real L dispatch, collision/identity/live-state invariance, material/environment/light restoration and practice labels. This is a future final-freeze gate, not a preparation pass or a native quality verdict.

Packed play mode also checks the earned route's current R20 build/style identity, unchanged F2, frozen map key, clean finish and retained Saltglass contact observations after friend sharing. It does not switch maps or replace the earned ghost at wrap-up. Full feature routes run separately in controls mode.

## Exact Windows startup under Wine

After package verification, `tools/check-r20-windows-release.py` takes the actual Windows ZIP, outer BUILD.json, SHA256SUMS, the pinned portable Wine64 loader and a new `/tmp` evidence directory. It verifies the ZIP, embedded metadata, official EXE/console/PCK hashes and its own committed helper provenance. It boots all eleven explicit maps from that unchanged Windows executable/PCK, with records off and no source or script overrides. Each startup must report the requested map, F2/128 Hz, R20 build and inherited real runner. Private prefix/profile/extraction are removed; commands, logs, hashes and limits remain. Six engine-free tests cover every-map iteration, hashes, traversal, embedded source, wrong runtime/pack and wrong-map startup.

Verified preparation commands:

```bash
python3 -B tests/test_r20_windows_release.py
python3 -B tools/check-r20-windows-release.py --help
```

This gate has not executed a final artifact yet. Successful Wine execution will still not establish native Windows, rendering, menu operation or feel. The old R19 helper is protected and unchanged.

## Export-controller preparation and review repairs

The packed direction controller now requests an export while a real backwards stack is paused and pending. It types the export name through GUI input, clicks the production button, checks every recording/settings member against the live source inventory and SHA256, and reads the flushed active tail as an honest partial. Physics, pending style, counts of ticks/inputs/events and the open attempt must stay unchanged; only flushed chunk/byte counts grow. Folder opening is intercepted and its failure must leave a visible selectable path. This controller compiles with the pinned editor; actual item-6 packed execution remains pending.

`run_export_profile_audit` permits only the exact observed ZIP path/hash. It preserves the original profile audit for everything else, compares the exported active prefix with its later sealed recording, invokes the real manual ingest script, requires every attempt and partial sample in its analysis, checks duplicate idempotence, and refuses mutations of that actual ZIP (traversal, changed member and truncated transport). No Mike playtest data enters these generated release fixtures.

Independent first-five review found two concrete auditor false rejections. Controls now admit only the same exact cfg path as play, with actual persisted-settings readback and a final cfg SHA receipt. Startup and reload remain read-only. A `tether_settings` directional loss matches only a same-tick event-source `loadout` on Tether Yard, with a real changed boolean reel preference or a changed known model pair. Generic or unmatched boundaries remain rejected; producer, scorer, recorder and motor bytes are unchanged. Two focused regressions, including eight negative boundary mutations, bring the helper suite to 34 passing tests. The actual retained component boundary pair also passes the narrow matcher.

Outer evidence: `look/REVIEW-R20-FIRST5.md`, `look/evidence/r20-review-repairs/`, and `look/evidence/r20-export-release-prep/`. The first compile attempt caught an unsupported PackedStringArray filter call; the corrected adapter explicitly converts to Array. That failed attempt remains labelled. Those preparation receipts predate the completed item-6 runtime. Final assembly is now enabled by complete executable gates, with actual candidate acceptance still required.

## Complete item-6 rehearsal and assembly readiness

The committed exporter has passed an official-release rehearsal on the actual paused Penstock stack. All 145 controls passed, including real GUI typing/clicking, complete live-file inventory, preserved pending/recording state and the selectable folder-failure path. All eleven sealed recordings independently passed both readers and the unchanged physical/input/profile audit: 4,148 ticks and 984 ordered inputs. The exported active prefix matches its eventual sealed file. Actual ingest preserved all three exported attempts, including its 975-sample partial; duplicate ingest changed nothing, and traversal, changed-member and truncated mutations were refused. This remains a rehearsal pack, not the final complete candidate.

The two new ingest helpers are now included in the frozen helper inventory. The suite has 35 release-helper tests and six Windows-startup gate tests. Assembly still requires the explicit final source/identity freeze, complete native Linux controls/play/reload checks and negative pack refusals. Native Windows remains unverified; exact Windows PE startup under Wine is a separate required reported scope.
