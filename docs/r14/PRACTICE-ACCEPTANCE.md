# Penstock Yard v3 in the actual game

8 November 2026. P layout revision: blocks and the valve bend come before the
128 m straight, so speed built there feeds the wide gauge gaps. Four 32 m runway
sections replace one large collider. Geometry `8475d8a82763`; 141 pieces.

Root copied only the map worker's owned files and reran 1,599 geometry/interface
checks with no failures. The actual R14 main then replayed the worker's exact v2
key/mouse tapes from the normal spawn, with records disabled:

| Input line | Preset | Clean finish | Respawns |
| --- | --- | ---: | ---: |
| basic | bhop server | 56.328125 s | 0 |
| advanced | bhop server | 28.609375 s | 0 |
| basic | vanilla | 57.718750 s | 0 |
| final-gap miss and return | bhop server | 67.007813 s | 0 |
| final-gap miss and return | vanilla | 68.406250 s | 0 |
| basic | original R13 | 42.875000 s | 0 |

Every run reaches all seven stages in order. Delivery/order/rate checks report no
integrity or movement flags. Source grounding matches the lab driver on every
tick. Driver positions are rounded to millimetres; the largest product/driver
position difference is 1.14 mm on the server recovery, including 1.09 mm vertically.
These are matching outcomes, not a claim of bit-identical lab/product motion.

The lab sets `mouse_sensitivity` to 0.0022 rad/count after applying its Source
preset, equivalent to Source sensitivity 5.7295779513 at m_yaw 0.022. The game's
P default is 2.5. Root's first product replays used that default and diverged;
they are retained as a setup failure. Replays above use a thin subclass that sets
only the recorded look scale before startup. It overrides no movement, input or
progress methods. Events were not retimed. R13 needs no look override.

The advanced server run earns about 1,100 u/s and clears speed gaps. Vanilla's
advanced line remains unproven and the attempted first wide bend lands short.
The outer pump notch has no proven line. The worker's open-loop jump/mouse timing
perturbations mostly fail; no closed-loop noisy-input or human forgiveness result
is established. Return pits go back to the jump's takeoff, rather than bypass it.
The residual engine cast fault is quantified in BACKEND-CHECK.md.

Evidence outside Git: `checkpoints/spillway/r14/practice-root/` contains the copy
manifest, root geometry/cast results, actual-main replay traces and
`look-matched-acceptance.json`. `product/` holds the first wrong-look-scale attempt
and its separate acceptance analysis. `product-look-matched/` is the Source set
above. The R13 line is in `product/r13-basic/`. Worker native lab movies and all
failed trials remain in `practice-source/`, indexed by EVIDENCE.md. Those movies
show the level, not the final product HUD. No enjoyment, Windows or GPU claim.
