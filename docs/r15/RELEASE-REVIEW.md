# R15 release verifier review

Reviewed commit `406640de38a041c86471ab69172e74f2b38f7e84`. Two reproducible visibility gaps and one recheck-cleanup gap remain. The final component run meets **91/91 fixed expectations**, including expectations that reproduce these gaps. This is not a release pass.

The review read the project instructions, BRIEF, INTERFACES, DELIVERY, DELIVERY-PLAN, REPLAY, PACK-OBSERVER-REVIEW and both production release helpers. Production files, existing tests, game content, packaging inputs and root evidence were not changed. No child agent, export, native rendering or desktop/display operation ran. Only the new review document and `tests/r15_release_review.py` / `.gd` belong to this work.

## Ranked findings

### 1. P2: transparent material still counts as a drawn walkable surface

Location: `tools/r15-pack-probe.gd:579`, `_scan()`, and `:669`, `_triangle_at()`.

`_scan()` checks the geometry node's visibility, transparency, shadow mode and camera layer. It then counts a surface's vertices without checking the active material's transparency. `_triangle_at()` accepts any triangle belonging to a node in that list. The frozen shader/texture identities do not include a standard material's albedo alpha.

Repro: the dedicated headless harness constructs a three-vertex floor with a `StandardMaterial3D`, `TRANSPARENCY_ALPHA` and albedo alpha **0**. The unchanged production `_drawn(world, true)` still returns `ReviewFloor: 3`; `_triangle_at()` still returns `ReviewFloor` for a point on it. The same observations occur with the opaque control. Hiding the node correctly removes it. Thus these predicates cannot distinguish a fully transparent floor from its opaque control. Physics and motion comparison do not establish material visibility.

The scratch repair control skips this fully transparent material. It rejects the transparent floor and its triangle while accepting the opaque control. This is a minimal demonstration, not a complete proposed implementation: a mesh with both opaque and transparent surfaces needs the same eligibility rule in the scan **and** in triangle selection. Reject known invisible standard materials per surface, retain evidence for the actual hit surface, and keep native frame inspection for shader-driven visibility and occlusion.

Evidence: `final/original.json`, `final/repair-control.json`, their engine logs and `final/component-repair.patch`. These are headless predicate observations, not a claim that the current maps have invisible floors or that an entire broken ZIP was accepted.

### 2. P2: a truncated or wholly clipped HUD label passes the visibility predicate

Location: `tools/r15-pack-probe.gd:466`, `_label_drawn()`, called by HUD and lab controls.

The predicate refuses zero visible characters but accepts a positive partial count. It checks the label's rectangle against the viewport without checking ancestor clipping. The separate HUD content checks read the full `text` property, including characters the label cannot display.

Repro on a 44-character identity label:

- `visible_characters = 1`: production returns **true**, although the preset/rate text is not included in the one-character display allowance.
- A `10 × 10` ancestor with `clip_contents = true`, wholly disjoint from the label at `(30, 30)`: production returns **true**. The engine reports that the parent and label rectangles do not intersect.
- Full text, zero characters, hidden and alpha-zero labels are controls. Production accepts the full label and correctly refuses the other three.

The scratch repair requires the complete character count and refuses the wholly clipped case. Both bad cases are refused and the valid full label still passes. Check the complete expected static text and effective ancestor clipping for essential labels; a viewport-sized rectangle and full backing string are insufficient. The control patch addresses these repros only, not arbitrary text layout or overlapping UI.

Evidence: the same original/repair JSON and logs. No rendered pixels were captured. These are engine layout/visibility-state counterexamples to the predicate, not a report that the current HUD is unreadable.

### 3. P3: failed or cancelled package recheck retains its transient source and import cache

Location: `tools/package-r15.py:1494`, `recheck_routes()`, and the `check` command at `:1473`.

`source-freeze` is removed only after import, every source route and both helper copies succeed. Import refusal or cancellation skips that removal. The caller also allocates `r15-check-*` before replay, with no enclosing `finally`; it never reaches `check_package()`'s work cleanup when replay raises.

Repro: call the unchanged `recheck_routes()` with a tiny synthetic archive. A controlled import creates a placeholder `.godot/imported` cache, then either raises `Rejected` or `KeyboardInterrupt`. In both cases the frozen source and cache remain. The successful-import control removes the frozen stage. No candidate archive or real engine was used in these three fixtures.

Place the temporary source lifetime inside `try/finally`, and cover the check command's work allocation similarly. Preserve logs and failure reports while removing owned source/import/profile scratch on refusal and cancellation. This is a storage-cleanup finding, **not** an engine-process leak: the separate real process controls below clean up correctly. The review removed all its deliberately retained fixture caches after recording them.

Evidence: `final/RECHECK-CLEANUP.json`. The component reproducer invokes the function directly; the extra caller allocation is identified by code inspection.

## Defences that held and excluded objections

| Challenge | Observed result |
|---|---|
| Requested external reference has changed position, velocity or final finish kind | The real `source_route()` caller refuses each synthetic fixture. The identical reference passes. No ignored-verdict finding. |
| Supervisor returns zero but nested `evaluator/godot.log` contains `SCRIPT ERROR:` | Refused. A missing nested engine log is also refused; the clean nested log passes. |
| False rate, delivery, order or cleanup verdict; nonempty integrity flags | Each is refused by `source_route()`. These are caller fixtures, not route play. |
| Missing any course's F2 proof, or missing the F5 comparison | Each is refused before preflight/export. The complete set reaches the preflight sentinel. No export occurs. |
| Float/duplicate/missing ticks, shortened vector, top-level NaN velocity, wrong steady crouch height | Refused by the current packed audit on the retained real air-crouch capture. The untouched 256-tick capture passes. |
| Changed hull observer supplied with the committed observer digest | Refused. This does not repeat the repaired unrecorded-helper finding. |
| Exact saved tick comparison: float/bool tick, truncated array, changed final element | The actual GDScript `_same_ticks()` refuses all four; the complete integer array passes. Full save/reload execution remains root's packed gate. |
| Owned process succeeds, reaches its deadline, or receives wrapper-only SIGINT/SIGTERM | The exact `run_engine()` releases its disposable engine and child in all four cases. The success case includes a surviving child after its leader exits. |

The standalone `packed_input_audit()` accepts NaN in `audit.mouse.yaw_after` or `pitch_after`: `abs(NaN - expected) > tolerance` is false. Finite wrong values and infinity are refused. **Excluded as a release false-acceptance finding:** the enclosing `shipped_trace_match()` parses the entire JSON strictly and rejects these exact nested NaN fixtures before aggregate acceptance. The raw malformed trials are retained as compressed traces, with controls in `final/INPUT-AUDIT.json`. No wholly forged capture threat is asserted.

Code inspection confirms the production controls call the lab coroutine, including F3/F4 refusal, keys 1/2/3, menu grapple toggle, default-versus-disabled record keys, F5 loadout preservation, pre-timer purity and course/runner restoration. No new omission was established. This review did not rerun or relabel the earlier 273 course checks, 102 lab checks, 37-observation coroutine or three lab mutations. The repaired checkpoint wording and restart toast are not findings here. Clean packed-route admission still excludes respawn recovery, as DELIVERY-PLAN states.

## Artifact inspection and acceptance boundary

At the one natural candidate inspection, `/tmp/r15-candidate-406640de` contained only `evidence/`. No finished `BUILD.json`, `SHA256SUMS`, ZIPs or `VERIFICATION.json` were available for a package audit. **Pack hash/verification audit pending.** There was no wait or candidate polling loop.

The source output initially contained partial suite artifacts and an `identity-routes` directory. A subsequent attempt to read its top-level receipts found those files unavailable; the review did not chase the run or infer completion. `ARTIFACT-INSPECTION.json` records this boundary and the exact read-only release-plan commands, route plan and their hashes. Root's active artifacts were never modified, deleted, restarted or waited on.

This review cannot certify the full 15-route source gate, final packed Linux behavior, Windows execution, actual OS input, blocked-standing in a final pack, native material/HUD drawing, human discovery or feel. The older rejected diagnostic remains rejected. A component result does not upgrade partial artifacts into acceptance.

## Reproduction and receipts

Executed from the repository root:

```sh
python3 -I projects/foldrunner/tests/r15_release_review.py --out /home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r15/release-review/final
```

The runner copies four helpers directly from the pinned commit, verifies their hashes against the checkout, and executes the copied Python helper plus the unchanged copied GDScript probe. The tiny headless project has no game assets or source import. It uses the pinned editor whose executable digest is checked. Repair controls affect only a disposable probe copy. All scratch projects and profiles are removed, and the copied helpers and retained input hashes are checked unchanged at the end.

Evidence root: `/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r15/release-review/`.

- `final/RESULTS.json`: 91 met expectations, zero unmet; scratch removed.
- `final/EXECUTED-SOURCES.json`: full reviewed commit, executed helper/test hashes and editor identity.
- `final/COMMANDS.json`: exact invocation and subprocess command vectors.
- `final/PROCESS-CONTROLS.json`: disposable actor commands, wrapper source/hashes and Python executable hash.
- `final/RETAINED-INPUTS.json`: identities of the older real observer capture, tape and recorded input settings, used only as component fixtures.
- `OWNED-SHA256.txt`: receipt for the three new owned repository files.
- `EVIDENCE-SHA256.txt`: inventory of retained review evidence, excluding itself.

All earlier trials are retained. `attempt1` has 78/79 met expectations: the complete-route control accidentally used Git from an external non-repository helper path, so it did not reach the intended sentinel. The harness was corrected to supply the repository location and verify the precise missing-proof refusal. `attempt2` meets 81/81, `attempt3` meets 85/85, and `attempt4` adds the cleanup controls for 91/91. `attempt5` adds disposable process-source receipts. `final` repeats 91/91 with automatic compression of the small synthetic caller traces as well. Earlier trials' traces were also compressed with their decompressed hashes retained. None of these counts denotes a released game.

No frames or movies were retained. Evidence is below 8 MiB; traces are gzip-compressed. No production file was repaired, and no commit or push was made.

Root integration note: the dedicated fixture is stored as `r15_release_review.gd.in` and copied to `review.gd` only in its minimal scratch project. Its virtual `res://probe.gd` dependency must not be parsed by the full game importer. Original executed fixture bytes and hashes remain in the review evidence. Root's repairs and fresh results are recorded separately in DELIVERY.md; the 91-expectation historical review is not relabelled a repaired release pass.
