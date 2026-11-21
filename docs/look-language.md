# Look language (look C)

Spillway's current look (L on) is one shared layer, `scripts/r17_look.gd`, that swaps materials, adds ink contours and orange lips, and paints sky and light. L off restores every original material, environment and light by reference. Nothing here enters geometry, collision, map identity, recordings or scoring.

The eight original maps (`MAPS.ORDER` in `scripts/r15_maps.gd`) attach it from `r17_main.gd`. Saltglass and maps whose entry has `look_palette` attach it from `r19_main.gd` with a palette alias (usually `practice`). Maps with `own_look: true` never attach it; their art files apply these rules themselves.

## Hooks for other lanes

### Sky and light: `scripts/look/sky_light.gd` (lane 02)

Optional. When it exists, `r17_look.gd` calls its static functions:

- `has_map(id) -> bool`, asked with the real map id first, then the palette alias.
- `environment(old_environment, id) -> Environment`: the painted environment for L on.
- `light(index, id) -> {"rotation_degrees", "color", "energy"}`: index 0 is the sun, any other index the fill.

On Breakwater the entry also replaces `look_breakwater.gd`'s own environment and lights. Without an entry the palette values in `r17_palettes.gd` apply, as before.

### Per-map look: `scripts/look/maps/<map-id>.gd` (map lanes)

Optional, keyed by the real map id (Saltglass is `saltglass`, not `practice`). A plain script, `extends RefCounted`; every member is optional:

```gdscript
extends RefCounted
## merged over this map's r17_palettes.gd entry before any material is built.
const PALETTE := {"top": "ece3d3", "side": "4d6f7d"}
## per mesh kind (node name without Mesh_/Art_, or the full node name): surface shader parameters.
## strings become colours. see "Surface" below for the parameter names.
## a full node name (Art_concrete) wins over the kind and gets its own material.
const SURFACES := {"concrete": {"side_color": "3f5f6b", "wear_amount": 0.3}}

## called for every mesh the layer visits, with the material it would use (or null to leave it).
## return that, your own material, or null to keep the original. imported models are asked once per
## surface with that surface's proposal, then once for the node with null: to restyle a model, answer
## the per-surface calls and return null for the node call. a returned ShaderMaterial needs its shader.
func material(key: String, node: GeometryInstance3D, proposed: Material) -> Material:
	return proposed

## look-only dressing. it is parented under the look layer, so it shows only with L on.
## a dressing that contains anything able to collide (physics bodies, areas, collision shapes,
## GridMap, CSG with use_collision) is rejected whole, with an error, in every build.
func dress(level: Node3D) -> Node3D:
	return null

## called after the layer has applied L on or L off.
func set_enabled(value: bool) -> void:
	pass
```

Dressing has no collision, stays clear of every swept path and rope line, and never hides a landing, lip, checkpoint or anchor. On Breakwater most materials come from `scripts/look_breakwater.gd`, so `material()` and `SURFACES` reach only the paint and opportunity meshes there; `PALETTE.top` still sets the cream wall copings.

## The rules

One idea carries readability: **what you land on is the palest thing in view, the side under it is clearly darker, the underside darkest.** Everything else serves that.

### Deck value target (every map, shared layer or own look)

Measure the near deck at running height in a 1280x720 capture (crop about x 490-790, y 620-700):
- **in sun:** shell white, about sRGB (236, 230, 218); stay within roughly ±8 per channel and never above 250 in any channel (clipped) or with blue more than 30 below red (yellow);
- **in the sun's shadow:** cool and still pale, about (195, 202, 204), always clearly lighter than the side face beside it;
- **night maps:** the same order of values, cooler overall; the deck stays the palest surface in view.

### Surface (`shaders/look/surface.gdshader`)

| Rule | Parameter | Value |
| --- | --- | --- |
| Faces blend into the deck treatment between these world normal-y values, so walkable slopes (Saltglass's 56° surf face is 0.555) stay pale | `top_from`, `top_full` | 0.30, 0.50 |
| Deck colour: per map `top` in `r17_palettes.gd`, near-white and slightly warm, never yellow or clipped | `top_color` | shared-layer palettes: Breakwater e0dad2, Whiteout dcd8d0, Sunken Court d9d5cb, Rainline d9dcd3, Night Shift dedad0, practice dedbd5, Overflow e0dad0, Movement Lab e0dcd3 |
| Quiet deck: fine grain ±1%, broad mottle | `deck_mottle` | 0.02 |
| Sparse seams on decks only, an 8 m × 32 m grid offset to x = 4 + 8k so no seam runs down a spawn axis | `deck` | 0.35 shared layer, 1.0 Breakwater pavers |
| A top in the sun's shadow keeps this share of the lost sun, tinted cool (directional lights only) | `shade_lift`, `shade_tint` | 0.35, (0.70, 0.84, 1.0) |
| Side colour: per map `side`, a clearly darker weathered tone (slate teal, grey-green stone, navy at night) | `side_color` | e.g. Breakwater 527b87, Sunken Court 8e948c, Night Shift 3e5671 |
| Vertical weathering on sides: broad runoff streaks, weaker with distance | `streak_amount` | 0.10 |
| Paint loss on sides: sparse patches that lift toward a lighter, warmer side colour | `wear_amount`, `chip_color` | 0.12 shared layer; chips mix side × 1.5 with (0.78, 0.71, 0.58) at 35% |
| Broad tonal variation on sides, metres across, ±7%, so a large face never reads as one flat tone | `tone` (fixed) | 0.93–1.07 |
| Undersides (normal-y below −0.25) darken to | `underside` | 0.62 × side |
| Toon light: shaded side 0.48, lit side 0.82, faces turned to the sun 1.0 | `light()` | unchanged from R17 |

### Ink (`shaders/look/ink.gdshader`, `scripts/r17_contours.gd`)

- Lines only on real boundaries: the outline of the union of decks at one height (coplanar pieces merge first, so seams between them never get a line), plus vertical strokes on the union's outer corners from the deck down to the water or the foot of the solid.
- Colour (0.035, 0.065, 0.070) at alpha 0.78, a 5 mm square tube in the world (`radius` 0.005).
- A deck outline is drawn only for a camera above that deck (it fades out from 0.15 m above to 0.25 m below); seen from below, an outline would float against the sky. Corner strokes always draw.
- Far lines never get thinner than `min_pixels` 1.2 px on screen; they lighten instead (alpha × 0.45–1.0 by coverage), so distant geometry has no shimmering dashes. Fade from 28 m to 95 m.
- No ink on interior grid seams, weathering, ribs or props.

### Orange

- Colour d95b30, unshaded. Only on the lip where a jump is taken and on its receiver (`jump_gaps` in each level), 0.30 m on the deck plus a 0.14 m face.
- Never on an edge where another deck continues at the same height (that is a seam, not a lip): for flat decks the edge must lie on the outline of the union of all decks at its height. Wall copings are cream, not orange.
- Paint keys containing yellow, orange, hazard, lip or duck render orange; dark paint 263d45; other paint cream fff5db.

### Water (`shaders/look/water.gdshader`)

- Sea-glass: deep (0.17, 0.46, 0.49), lit (0.31, 0.63, 0.62), glints (0.82, 0.89, 0.81), horizon (0.55, 0.72, 0.71). Unshaded, so per-map `water_value` scales it on dim maps (Night Shift 0.5, Rainline 0.8).
- Waves smaller than a few pixels settle to their average instead of aliasing into a checker; glints fade from 40 m to 220 m.
- Pools and shallow sheets (`Pool_*`) use `shallow` 1.0.
- A pale shoreline band (d3e3d8, 0.30 m) where any solid crosses a water plane, from a true horizontal section of the solid, clipped to the water.

### What the look layer does not do

Geometry, collision, spawn, checkpoints, anchors, map ids and recordings are never touched. L off restores every original material, environment, light and label exactly. Painted "N m / N u" distance figures are hidden with L on except on the practice yard.
