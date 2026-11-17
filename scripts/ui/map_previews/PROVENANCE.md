# Map preview frames

These are original rendered screenshots of Spillway's own maps and redistributable runtime assets. No private reference image, imported third-party map or concept image is included.

Captured by `tools/shot.py` with the pinned Godot engine on its explicit private Xvfb display. Static camera poses use the ordinary first-person spawn camera. Three grounded views make the distinctive route visible: Saltglass Seaward's outer quay, Outer Reach's acceleration-quay edge, and Gantry Chain's third-transfer checkpoint. The HUD is hidden by the wrapper's pose mode. These images describe map appearance, not route traversal or performance. Image pixels are copied unchanged from native viewport PNG readback.

`manifest.json` records each map ID, pose, image SHA256, source revision and engine SHA256. Full capture/source-status/display receipts are retained outside Git under `/home/thatmike1/spillway-r22-run/concept/07-pause-menu/wave2/receipts/`. Previews are presentation resources only; they do not replace a map identity or alter gameplay. Regenerate a map's frame when its authored look changes materially.

The initial map/art/shader/assets baseline is integration `0197ff2`; these paths were verified byte-identical in the capturing worktree. The worktree also contains HUD preview work, hidden by pose capture. Individual receipts report its actual HEAD and dirty paths rather than claiming a clean source. Baseline audit: external `wave2/capture-baseline.json`.
