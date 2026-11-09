# Breakwater look C experiment

A separate, switchable presentation experiment on the unchanged R15 course runner. Starts on Breakwater. **L** swaps the original and painted looks during play or pause without resetting the attempt. Other maps retain their original look. Records and settings stay session-only.

Source branch: `feat/spillway-look-c`. Frozen base: `1fe1d7a8c`. Packaged runtime source: `76c025facc6e0a937fb2f31dd763dcc5438aa2b5`. This is beside the active R16 build and has not been merged into it. The R16 checkout was not edited or messaged.

## Delivery and evidence

Local artifacts live under `/home/thatmike1/foldrunner-build-2026-11-05/look/`:

- [Portable Linux ZIP](/home/thatmike1/foldrunner-build-2026-11-05/look/delivery/SpillwayLookC-linux-x86_64.zip), 109,648,354 bytes. Extract the whole folder and run `./play.sh`.
- `comparison-concept.png`: original left, experiment right, at the same native camera pose and FOV. This approximates the supplied concept composition; generated art changes perspective and geometry, so it is not a pixel registration.
- `comparison-breakwater.png`, `comparison-box-rows.png`, `comparison-breach.png`: further paired route views.
- `bhop-look-c.mp4`: 22 seconds from a native clean F2 run in the final look, with the HUD and actual player camera. Silent capture.
- `bhop-fast-aa1000.mp4`: 11 seconds from an input-only AA1000 attempt that reaches 899 u/s. It is an unfinished speed sample, not a clean finish. The complete scripted line later falls at the breach.
- `evidence/native-clean-final/` and `evidence/native-fast-final/`: full native movies, inputs, compact physics traces, source hashes and AMD GPU receipts.
- `evidence/exact-zip-final/`: the extracted final ZIP running from an empty directory. OS L key presses visibly switch new → old → restored. The release executable and pack hashes match the delivery receipt. The capture harness terminates the process after collecting frames; clean normal startup/quit is checked separately in `delivery/packed-startup.log`.
- `comparison.html`: paired view and desktop GPU chart. `evidence/desktop-gpu/`: desktop measurements, hardware and package identity, reproduction helpers, failure logs and cleanup receipts. A committed copy is in `look/desktop-gpu/` in the project.
- `REVIEW.md`: the single Opus visual/evidence review of the earlier candidate. `decisions.tsv`: decision trail, including fixes after that review.

ZIP SHA256: `962cf93d63e5372ecb8d5b3e6b64630ff780adc30b548bdef9e4cd768d2febfc`.

## Choices in this slice

- **Surface reading:** shell-cream top planes, darker blue-green vertical faces, low-frequency top variation and sparse warm chips on sides. Existing landing-edge paint becomes vermilion; new wall fascia follows the actual wall lips. Lighthouse identification bands and red/green navigation props retain their roles.
- **Light:** a custom three-band directional response, warm sun and restrained cool ambient fill. Existing cast shadows remain. High-frequency scanned normal/roughness maps are absent from the new structural materials.
- **Ink:** 615 authored structural segments in one visual mesh, with smaller radii on deck edges. Opacity fades between 28 and 95 m, and physical width also shrinks with distance. Paint polygons, texture detail and internal coplanar deck joins are not outlined. No screen-wide edge detector or motion blur is used.
- **Sky:** an original generated static painted panorama. A small sky shader feathers opposite edge strips to remove the raw image's wrap discontinuity. A six-longitude native check covers the wrap; the chosen rotation places the main clouds left of the lighthouse and clear sky ahead. No TIME or camera-position dependency triggers continual radiance updates.
- **Water:** opaque, unshaded sea-glass bands with restrained moving highlights. It uses no screen-space reflection or expensive refraction pass.
- **Comparison host:** subclass the existing R15 host, add a reversible rendering layer after Breakwater is built, keep the original materials/environment/light states by reference. The player, Source law, collision, checkpoints, kill bounds and timing code remain byte-for-byte unchanged.

## What matches, what does not

The implementation carries the concept's cream/teal value split, narrow orange edge rule, quiet structural ink, sea-glass palette and large painted clouds into the actual route. The first review found a sky seam, wrong cloud framing, camouflage-like wear, excessive deck joints and doubled ink around painted strips. These were corrected and inspected in `evidence/views-reviewed-fixes/`. The double lines came from treating flat paint strips as solids; those strips no longer receive ink.

This is still simpler than the illustration. Brushwork is procedural rather than hand-authored, cloud detail is limited by the 1774×887 panorama, wall caps are thin fascia, and the original square lamp supports and block-built architecture remain. Water has no authored sun-reflection path. The lighthouse and sourced props are not a complete toon-asset conversion. Hands, runner, title card and other maps are untouched. No claim is made that the result looks good or that Mike has approved it.

## Verification

- **75 checks pass** through actual engine input dispatch: repeated L press/release, body transform and velocity, run state, exact original material/environment restoration, collision/progress snapshots, profile isolation, another-map isolation and return to Breakwater. See `evidence/invariants/reviewed-fixes.log`.
- **Original F2 route:** the baseline host, old-look host and toggled-look host produce identical decompressed full physics traces: SHA256 `aaa30e3e29af4da6e8021c42293b372197c426f533e262f43d519a36dd2f6c31`. Clean finish 44.6015625 s, zero respawns. The final native run has the same finish and unchanged geometry.
- **Fast AA1000 excerpt:** the original host, repeatedly toggled look host and final native replay all produce the same full trace SHA256 `44a002b29584fb85db684191411e9fa36d1ecf52ed636d36999ab921d38532bf`, reach 899 u/s and stop after 4,778 ticks without a respawn. This proves parity on that excerpt, not a successful full fast route.
- **Exact ZIP:** official Godot 4.7.2 Linux release runtime, SHA256 `d9f79ab89b5ae369aeed11c6052d402e8218cd503bf85b4a235f9c30c46a7c63`, matching the pinned template provenance. PCK SHA256 `9180812f4ea3ad87b136f0c45faf19d79e712fcbd13a9b5562e228fc8d637441`. Headless normal startup exits 0 outside source; native OS-input captures use the extracted ZIP and the actual AMD GPU. Capture source manifests match the packaged script, scene, shader and new-asset bytes.
- Native movie/contact inspection covers ordinary and faster landings, distant ink, turns and approach to the breach. This is scripted input, not Mike's subjective readability or enjoyment verdict. Immediate fixture shutdown emits ObjectDB leak warnings. The headless packed startup check has none, but the desktop native release also reports 12 leaked instances at exit. These warnings are retained in the logs; successful startup and measured GPU time do not establish leak-free shutdown.

## Desktop performance

Verified on Mike's **RTX 2070 SUPER, NVIDIA 595.99.02**, through private hardware X11 displays. Both 1280×720 and the primary monitor's 2560×1440 resolution were measured, with actual viewport pixels asserted. Two alternating rounds, 40 warmup frames then 120 measured frames per look/view/round: **3,840 accepted samples**. Values are GPU milliseconds, median / p95.

| View | 720p original | 720p experiment | 1440p original | 1440p experiment |
|---|---:|---:|---:|---:|
| Concept angle | 0.694 / 0.712 | 0.384 / 0.412 | 1.681 / 2.035 | 0.794 / 0.831 |
| Straight breakwater | 0.541 / 0.575 | 0.352 / 0.359 | 1.453 / 1.839 | 0.737 / 0.765 |
| Box rows | 1.298 / 1.648 | 0.638 / 0.653 | 2.518 / 2.985 | 1.419 / 1.765 |
| Breach | 0.583 / 0.622 | 0.335 / 0.344 | 1.609 / 1.873 | 0.745 / 0.778 |

No GPU-time regression appeared in these views. The worst experiment p95 is 1.765 ms at 1440p. These are paused fixed-view measurements with vsync disabled, not whole-run frame pacing, physical display/input latency or a human readability verdict. Normal desktop apps remained active, and clocks were not locked.

The exact ZIP's release executable started and exited successfully on the desktop GPU. Timing used the official **4.7.2 editor with the exact delivered PCK**, from an empty external working directory with no loose project source. The release runtime did not execute the external measurement fixture, so its failed fixture attempt is retained separately. Do not read these numbers as release-binary timing. All 986 manifest files match the packaged source commit; ZIP, runtime and PCK hashes match the delivery. Device logs, NVIDIA graphics-client observations and GPU device descriptors prove hardware rendering.

The first run was rejected because kiosk-shell output sizing overrode the requested viewport dimensions. Accepted runs use separate exact-size private outputs and assert window and render texture dimensions. Full raw samples, frame intervals, commands, failures and safety receipts are in `evidence/desktop-gpu/`; the parent independently checked transferred hashes, sample counts, dimensions, medians, hardware clients and successful cleanup. Desktop monitor configuration and the recorded application processes were preserved. No private display or benchmark process remains.

## Laptop comparison

Godot GPU timestamps, 1280×720, private X11/AMD display on the **laptop Renoir iGPU**, vsync off. Two alternating orders, 40 warmup frames then 120 samples per look/view in each round. All numbers below are GPU milliseconds. These are paused fixed-view measurements, not whole-run frame pacing or physical display/input latency.

| View | Original median / p95 | Experiment median / p95 |
|---|---:|---:|
| Concept angle | 5.19 / 5.74 | 2.06 / 2.29 |
| Straight breakwater | 3.86 / 4.00 | 1.85 / 1.95 |
| Box rows | 11.97 / 13.17 | 5.19 / 6.24 |
| Breach | 4.64 / 5.56 | 2.00 / 2.18 |

Raw laptop measurements and method: `evidence/performance-final/`. Desktop execution was initially unavailable over SSH; Mike subsequently linked it through T3, enabling the completed benchmark above.

HOME was checked before captures/exports against the look brief's 15,000,000,000-byte floor. Imports and export staging used bounded RAM scratch. Superseded task-created images and movies were removed; `evidence/cleanup.json` records their hashes and reclaimed bytes. The independent review's pre-fix observations remain labelled as such.

## Provenance and rollout

The cloud PNG was made with the built-in OpenAI image generator from the retained text prompt, without supplying external images to that generation. The wear PNG is original seeded mathematical texture work, reproducible with `tools/generate-look-wear.py`. Both are hashed in `assets/look/MANIFEST.json`; the prompt and provenance are beside them. Original R15 assets stay in the pack for the old look and other maps, with their existing CC0/other redistribution notices copied into `licenses/` in the ZIP. No private concept reference image is redistributed.

A rollout needs per-map material roles and climate palettes, especially snow, wet night surfaces and Sunken Court's stonework. Expose a small presentation hook after each map's art pass, map its real landable faces and edge markings to the new materials, author only its major contours, then repeat the same input-parity and native speed-view checks. Reuse the sky/ink/water code where appropriate, not Breakwater's hard-coded mesh-name mapping. Imported props need their own restrained toon materials and some silhouette work. Integrating with the completed R16 host is a separate deliberate change after its movement/recording work settles; this experiment does not take that integration decision.

Godot references consulted: [sky shader update rules](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/sky_shader.html), [material toon and grow behavior](https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html), and [rendering measurements](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html).
