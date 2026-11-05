# Spillway result

Delivered **spillway-2026.11.05-r10**, runtime source **5a8cf81e**, on **feat/foldrunner-me-build**. The active game is one original dam descent through Crest, Sluice yard and Outflow. BRIEF.md retires the reconstruction and folding-city targets. All tuning is P / game choices.

Portable packages, controls and exact evidence are in `/home/thatmike1/foldrunner-build-2026-11-05/REPORT.md` and `checkpoints/reboot.md`. Media stays outside Git; private game material is excluded.

Source regression suites pass 93/93 motor, 94/94 flow, 66/66 actual-level access and 92/92 boundary checks. The frozen input matrix ran from source snapshot **5a8cf81e** and finished **39/41**: the original 36 cases finish 35/36, and five new rail-hop cases finish 4/5. Both failures remain preserved. One late-jump follower waits for an elevated marker after landing in the basin; one rail-hop follower cuts a machinery corner before jumping. Neither resets.

The delivered Linux PCK passes 93 motor and 92 boundary checks, 93 native flow checks and 66 native access checks. External test fixtures load gameplay resources from that PCK. Separate isolated processes save and reload settings and clean records; practice preserves those records. Both portable archives pass CRC, pack/runtime hashes, architecture and licence checks. The actual native default launcher opens Spillway r10 from a folder containing spaces, outside source. Windows contains pinned official binaries with verified provenance; native Windows execution was unavailable.

Four uninterrupted native movies finish clean, with ordered stages and zero respawns: safe 48.433 s, fast 22.358 s, recovery 43.933 s and rail-hop recovery 28.383 s. Driver time includes startup before the HUD clock begins on movement. These are executable scripted lines, not expected first-play times. Downhill speed reaches about 15.87 m/s against 8.5 m/s running. Original AVI and MP4 frame counts match, with audio below full scale and normal playback at 30 fps.

R10 admits stages from grounded entry decks and authored regions. Side contacts, airborne proximity outside those regions and stale reset contacts do not grant stages. Every wheel arrival finishes. Missing stages produce an exploration result with no saved best or invented split. The basin, supports and loading apron do not grant Outflow because one hop from the yard entrance reaches them. No motor, camera, art or collision change was made in R10.

Final Opus 5.5 review reproduced no gameplay must-fix across 30 rail-hop variants, rail-perch continuations and six direct wheel approaches against the delivered PCK. It confirmed hashes, counts, source identity and evidence links. Its required final documentation commit/push is resolved by this delivery. Known polish: the decorative wheel has no collider and can be walked through after finishing. Saved results remain intact, but the close rotating view has not had a human comfort assessment.

Original materials, lighting, terrain and synthesized audio have whole-route rendered coverage. Matched art, retaining-wall and ramp comparisons are linked by the checkpoint. Models inspected code, traces, still frames and dense strips, not a human play session or an audio audition.

Captures use Compatibility/llvmpipe software rendering. Fixed-rate capture is not measured hardware FPS. An earlier batching comparison reduced 3,396 draw calls to 700 while software speed stayed about 2.8 fps. Desktop GPU frame pacing, physical controllers, native Windows gameplay, listening quality, enjoyment and comfort remain unverified. Course expansion began before the intended first-slice critique; [decisions.tsv](decisions.tsv) records that deviation and the later corrections. Final passing checks do not erase it.
