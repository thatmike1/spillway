# R15 verifier repair recheck

Four actionable helper issues remain in `03d970bed5fac9ced3181b25fc2137203a052d3f`. The original repair suite passes independently, but the additional boundary tests reproduce HUD and floor false acceptance, one newly introduced floor false refusal, and incomplete SIGTERM cleanup. This is a component review, not release acceptance or evidence that a complete broken ZIP passed.

Reviewed on 9 November 2026. Read RELEASE-REVIEW.md, DELIVERY.md, BRIEF.md and INTERFACES.md, then inspected the actual Python caller, GDScript probe and repair fixtures. Only this document and the distinctly named `tests/test_r15_verifier_recheck.py` / `tests/r15_verifier_recheck.gd.in` were added. No existing file, game asset, active candidate, source/export stage or active evidence was changed. No commit or push was made.

## Findings

### 1. P2: alpha-scissor materials produce false acceptance and a new false refusal

`tools/r15-pack-probe.gd:615`, `_material_drawable()`.

The repair treats every enabled transparency mode as ordinary alpha blending and applies a fixed `0.05` albedo cutoff. Alpha scissor instead discards fragments below its own threshold and renders surviving fragments opaque, as described in the official [BaseMaterial3D reference](https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html#class-basematerial3d-property-alpha-scissor-threshold).

Two texture-free `StandardMaterial3D` floor fixtures expose both directions:

| Material state | Required floor result | Actual repaired predicate |
|---|---|---|
| Alpha scissor, albedo alpha `0.25`, threshold `0.5` | No drawn floor: all fragments discarded | `_triangle_at()` returns `Floor` |
| Alpha scissor, albedo alpha `0.01`, threshold `0.001` | Drawn floor: surviving fragments opaque | `_triangle_at()` returns an empty string |

The second case is a regression: the exact old `406640de` probe accepts this same floor. The new helper rejects it solely because `0.01 <= 0.05`. An above-threshold `0.75` control passes. Zero-alpha controls for all four enabled transparency modes are refused; disabled transparency with alpha zero remains drawable; opaque next passes remain accepted.

Use mode-specific known-invisibility rules, accounting for scissor thresholds and next passes. Keep general shader, texture-alpha and occlusion judgments outside this predicate's guarantee. These fixtures record engine material/mesh state and the actual helper result; they do not record rendered pixels.

Evidence: `final/GODOT.json`, `final/OLD-GODOT.json`, `final/OLD-CONTROL.json` and the two engine logs.

### 2. P2: an opaque same-name mesh validates a different invisible floor

`tools/r15-pack-probe.gd:607` and `:687`, `_scan()` / `_triangle_hit()`.

The new per-surface eligibility table is keyed by the node's bare name. Names are unique among siblings, not throughout a level subtree. A transparent `Floor` under the world and an opaque `Floor` under another branch, translated 20 metres away, are legal distinct nodes. The opaque mesh contributes `nodes.Floor = 3` and `surfaces.Floor = [0]`. `_triangle_hit()` borrows that entry when visiting the invisible mesh and returns `Floor` at its triangle.

The opaque sibling still passes at its own location. Renaming that sibling to `DistinctFloor` makes the invisible target correctly fail. This isolates the dictionary-key collision rather than a triangle-coordinate error. It bypasses the transparent-floor repair without a custom shader. The name-collision weakness predates this repair; the new surface table retains it.

Key live eligibility by a level-relative node path or object identity, and carry that identity through triangle selection. Bare names can remain human-readable report fields. No claim is made that a current authored route contains this pair of nodes.

Evidence: `final/GODOT.json`, including both node paths and the colliding scan table.

### 3. P2: label-internal truncation still passes the complete-label predicate

`tools/r15-pack-probe.gd:466`, `_label_drawn()`.

The repaired character-limit and clipping-ancestor checks work, including two nested clipping ancestors. They do not establish that the label itself displays its backing text:

- `clip_text = true`, width **1 pixel**, full identity string with measured font width **383 pixels**, `visible_characters = -1`: accepted.
- Two-line identity string with `max_lines_visible = 1`: accepted. The engine reports **2 total lines, 1 visible line**.

Both labels remain inside the viewport and enclosing ancestors. Restoring the complete layout passes. These controls show that ancestor enclosure and a complete character allowance do not cover internal text layout. Godot documents horizontal clipping and line limits in the [Label reference](https://docs.godotengine.org/en/stable/classes/class_label.html).

Validate the essential text's actual layout: horizontal clipping/overrun, skipped lines and line limits as applicable. Keep native inspection for overlap, contrast and final legibility. These are residual component gaps, not observations that the shipped HUD currently truncates its identity.

Evidence: `final/GODOT.json`, with actual widths, line counts and predicate results.

### 4. P3: SIGTERM outside engine scopes still retains recheck scratch

`tools/package-r15.py:1477` and `:1500`; signal scope at `:144` is entered by `run_engine()` and display ownership, not around the whole check/recheck lifetime.

The real `main()` check branch was run in four disposable subprocesses. Tiny archive bytes, Git responses and engine/route work were controlled. The real archive extraction and check/recheck `finally` blocks were retained. A readiness hook paused either immediately after extraction inside `extractall()`, or in route preparation after simulated successful import. The parent sent an actual signal to that subprocess and waited for it.

| Signal point | SIGINT | SIGTERM |
|---|---|---|
| Extracted source exists | Exit 130; freeze/work removed | Exit `-15`; freeze/work retained |
| Import complete; route preparation | Exit 130; freeze/profile/work removed; log retained | Exit `-15`; freeze/profile/work retained; log retained |

SIGTERM has its default terminating action outside the short engine/display scopes. It therefore never unwinds the new `finally` blocks. No real engine was running in these four signal fixtures, so this is a storage leak finding, not a demonstrated engine-process leak.

Cover the complete owned check/recheck lifetime with cancellation handling, including extraction and preparation between engine calls. Protect cleanup against a subsequent signal as appropriate. Preserve logs. Do not promise cleanup after SIGKILL.

Evidence: `final/SIGNALS.json` contains exact wrapper source/hash, signal point, exit and leftover observations; per-case logs are adjacent. The reviewer removed every deliberately retained fixture tree after recording it.

## Independent results and safeguards

| Executed test | Actual assertions | Result |
|---|---:|---|
| Existing `test_r15_verifier_fixes.py` and `.gd.in` | 69 | 69 met, 0 unmet; old failures reproduced and repaired cases checked |
| Existing `test_r15_release.py` | 23 | 23 passed, 0 failed |
| New focused boundary runner, final | 195 | 183 passed, 12 failed; four findings above |

The final boundary count includes 24 assertions from the repaired probe in a minimal headless engine project and two assertions for the old-helper regression control. Other raw observations in `OLD-GODOT.json` are not counted as old-helper acceptance tests. Seven of the 12 failures are exit/cleanup assertions from the two SIGTERM cases; five are the HUD/material/name-collision observations. Counts are assertions, not independent defects or played routes.

The resource checks cover **all 30 allowed map/preset pairs**, each in `play` and `reload`. They compare exact required sets against independently assembled host/HUD/stats/audio, selected level/shaders/textures and selected runner chains. Both modes preserve complete `pack_required` coverage. Default controls retain `loaded_at_start`; explicit `--require` survives; `<built-in>` is excluded while real selected shader/texture paths remain required. This is a specification-construction test using a retained identity, not a new runtime cache/startup proof.

The 69-case suite independently confirms the original transparent/mixed-surface, partial-character, ancestor-clipping, exact-tick and refusal/KeyboardInterrupt cleanup repairs. Additional tests confirm nested clipping, inherited/self alpha, partial visible ratio, multiple next passes, node transparency and shadow-only refusal. Archive-read failure, malformed archive, first helper-copy failure and second helper-copy failure remove their freeze/profile and preserve existing import logs. The 23 offline checks retain licence/resource coverage, trace/vector/tick refusal and required-course-proof admission. Unchanged source caller and hull-observer protections were inspected; their historical review counts were not relabelled as fresh execution here.

Earlier boundary trials are retained. `boundary-attempt1` and `boundary-confirmation` each recorded **181 passed / 11 failed of 192**. The confirmation repeated the same counterexamples. Final adds the low-alpha scissor regression and its old-helper control. There were no fixture crashes or setup failures in this review; exit 1 from the boundary runner reports the retained failing assertions.

## Identity, reproduction and limits

Reviewed project Git tree: `3aa013e73179466430f83da268ea2c06286ec8ff`. Checkout HEAD: `821213f0eef95e928fbf46eaa11427119148c3da`. All four executed helpers were copied directly from reviewed commit `03d970bed5fac9ced3181b25fc2137203a052d3f`; checkout equality was checked before and after execution.

| Executed helper | SHA-256 |
|---|---|
| `tools/package-r15.py` | `2ee37d894f0a44ebec2251cc62e801e16dad56c6f334b80965144f420d7c7369` |
| `tools/r15-pack-probe.gd` | `7aec7c8a14fa2312da9620a0a72fe174d9c2fd9a80d07ef9aca4b51ac733dc2f` |
| `tools/r14_native_display.py` | `7a6f6cae8c8d81532aba4746c8b0511cd4a46dd723f4e67f834428f71ae34b8e` |
| `tools/momentum-tape.py` | `4e0a994b3ca3f4ae069c353290332dad1da3026a6c828ae0fcda812c1c7b9be1` |

Pinned editor SHA-256 was checked against `8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e`. `final/SOURCES.json` records the executable, Python, identity and review-test hashes. `CHECKOUT.json` additionally records game-script and original-fixture hashes. No game script was changed or executed by this review.

Evidence root: `/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r15/verifier-recheck`. `IDENTITY-ORIGIN.json` identifies the retained startup spec used only as component input. Root's active `/tmp/r15-candidate-03d970be` was not inspected or modified.

Executed from `projects/foldrunner`, with `E` below naming that evidence root:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -I tests/test_r15_verifier_fixes.py --out "$E/repair-suite" --identity "$E/IDENTITY.json"
python3 -B -I tests/test_r15_release.py --out "$E/OFFLINE.json"
python3 -B -I tests/test_r15_verifier_recheck.py --out "$E/final" --identity "$E/IDENTITY.json"
```

The boundary runner deliberately returns 1 while these counterexamples remain. Its exact expanded invocation and subprocess vectors are in `final/COMMANDS.json`. Output directories must be new when reproducing. `OWNED-SHA256.txt` receipts the three added files; `EVIDENCE-SHA256.txt` inventories retained evidence.

All scratch minimal projects, helper copies, imports and isolated profiles were under temporary directories and removed. All owned subprocesses were waited on; no desktop/display operation occurred. Evidence is below the 2 MiB cap. There was no export, new game import, source math run, long route, native frame capture, Windows execution, active-package wait or final package audit. Root's eight-startup and full source/packed route results remain root's responsibility; this review does not approve them or final release acceptance.

## Root repair after this review

The reviewed findings above remain pinned to03d970be and its original receipts. Root repaired the checker without changing any game resource: alpha-scissor uses its material threshold, live floor eligibility is keyed by object identity and reports the node path, essential labels check actual glyph bounds and complete lines, and the whole command owns terminal signals with deferred cleanup. The unchanged boundary fixture now meets195/195 expectations; the earlier69 and23 suites still pass. Eight official-runtime headless starts give488 assertions with no failure. Evidence: outer `checkpoints/spillway/r15/verifier-recheck-repair/`. These are component/startup checks, separate from fresh native package acceptance.

For reuse, root added only a `--commit` selection to the Python review runner: the default still freezes03d970be; `--commit worktree` explicitly snapshots and hashes current helpers, and `--commit HEAD` freezes the repaired committed helpers. The original195 expectations and Godot fixture are unchanged. The independent pre-repair runner hash remains in the review receipt.

The superseded native run also exposed a separate exact-title expectation error: the lab correctly adds ` · EXPERIMENTAL`, while the caller expected a course title. The caller now derives that suffix from the frozen `map_kind`. Root added60 positive/negative title-policy cases covering all30 allowed map/preset pairs; the combined boundary runner passes255/255. The actual old native lab title and both named refusals remain in `release-plan/package-03d970be.log`. The255 include the unchanged independent195 plus these60 root expectations. Both superseded processes exited130 and removed owned scratch/display scopes. A new complete export is required.
