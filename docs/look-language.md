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
