# Spillway checkpoint

2026-11-05, 17:40 CET. **The new motor and Crest slice work; the complete game is still being built.** Current default scene is Spillway. Mirror’s Edge and FEEL acceptance remain retired; BRIEF.md beside this file is the current contract.

Implemented: one velocity motor, immediate run, always-on jump grace, visible air correction, continuous landings/slide exits, downhill slides, clearance-aware crouch and intentional cancellable airborne mantle. Running arms are hidden. New settings/profile and clean-record provenance are separate from the old game. Crest has smooth ramp stairs, fast chute/channel jump, shallow-water recovery, a narrow terrace exit and safe turning alternative. Audio is original synthesis with spatial water. The slice cannot save a full three-segment record.

Lead verification: `tools/check-spillway.sh --play-routes --seed=0` passed 80/80 behavioral checks and all three current slice routes with no script errors. Safe19.817s, fast7.158s, recovery17.083s. Fast peak14.17m/s, one jump; recovery zero jumps and no reset. Delegate also reports seeds1/2 passed. Captures and JSONL are outside Git under outer `checkpoints/spillway/`. These are executable lines, not proof of enjoyment.

Native frames caught clipped-white lighting. Linear tone mapping, reduced warm sun/cool ambient and less reflective deck colour fixed the clipping. Native renderer is Compatibility on llvmpipe, not Mike's desktop GPU. Landscape and industrial silhouettes still need an art pass. A temporary lighting experiment had a type-inference parse error followed by a Godot abort; corrected temporary script ran. No gameplay crash claimed.

Next: inspect uninterrupted safe/fast/recovery slice captures, then finish Sluice yard and Outflow with meaningful route choices. Opus consultation may start at17:45 CET, then at most hourly. Full-route playbacks, critique, audio/presentation refinement, practice/PB flow checks and portable delivery remain. Work through at least20:00 Prague time. No mid-run human gate. Human enjoyment/comfort and native Windows execution remain unverified.
