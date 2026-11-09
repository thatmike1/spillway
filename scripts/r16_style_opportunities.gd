extends RefCounted
## optional solid installations, appended after the frozen map's build. the style service
## discovers these through ordinary physics queries; there are no score or progress hooks.

const VERSION := "r16-opportunities-1"
const ROOT_NAME := "R16Opportunities"
const META := "r16_opportunities"
const METAL := "res://assets/r15/breakwater/textures/rusty_painted_metal/rusty_painted_metal_diff_1k.jpg"
const CONCRETE := "res://assets/momentum/textures/concrete_layers_02/concrete_layers_02_diff_1k.png"
const TARGETS := {
	"res://scripts/r15_breakwater_level.gd": "r15-breakwater",
	"res://scripts/r15_whiteout_level.gd": "r15-whiteout-relay",
}

## call once after build(), with the level in the tree; repeated calls return a detached copy.
## hash is deliberately separate from geometry_hash()/manifest. root combines both identities.
static func apply(level: Node3D) -> Dictionary:
	if level == null:
		return _skip("null_level")
	if level.has_meta(META):
		return (level.get_meta(META) as Dictionary).duplicate(true)
	if not level.is_inside_tree():
		return _skip("level_not_in_tree")
	var script := level.get_script() as Script
	var path := script.resource_path if script != null else ""
	if not TARGETS.has(path):
		var skipped := _skip("non_target_map")
		level.set_meta(META, skipped)
		return skipped.duplicate(true)
	if str(level.get("level_id")) != str(TARGETS[path]) or (level.get("manifest") as Array).is_empty():
		return _skip("level_not_built")
	if level.has_node(NodePath(ROOT_NAME)):
		return _skip("reserved_name_in_use")
	var branch := Node3D.new()
	branch.name = ROOT_NAME
	level.add_child(branch)
	var report := {"version": VERSION, "applied": true, "reason": "optional_solid_geometry", "map": str(TARGETS[path]), "opportunities": []}
	if str(TARGETS[path]) == "r15-breakwater":
		_opening(branch, report.opportunities, "RunwayCrouch", Vector3(-81.3, 0, -166), "s3_runway_2")
		_thread(branch, report.opportunities, "RunwayThread", Vector3(-81.3, 0, -198), "s3_runway_3")
	else:
		_opening(branch, report.opportunities, "ApronCrouch", Vector3(-8, 0, -28), "s0_apron")
	report["hash"] = JSON.stringify(report).sha256_text()
	level.set_meta(META, report.duplicate(true))
	return report

static func _skip(reason: String) -> Dictionary:
	return {"version": VERSION, "applied": false, "reason": reason, "hash": "", "opportunities": []}

static func _opening(parent: Node3D, rows: Array, title: String, at: Vector3, deck: String) -> void:
	var row := _installation(parent, title, at, "airborne_crouch", deck)
	# 1.65 m opening: the 1.3716 m duck hull fits, the 1.8288 m standing hull cannot.
	# a 1.4 m sill and thin frame leave the jump's apex available without an added platform.
	_box(row.node, row.report.solids, "Sill", Vector3(0, 0.7, 0), Vector3(2.8, 1.4, 0.28), "concrete")
	_box(row.node, row.report.solids, "Lintel", Vector3(0, 3.16, 0), Vector3(3.24, 0.22, 0.28), "steel")
	for side: int in [-1, 1]:
		_box(row.node, row.report.solids, "WestPost" if side < 0 else "EastPost", Vector3(side * 1.51, 1.525, 0), Vector3(0.22, 3.05, 0.28), "steel")
	row.report["opening_m"] = {"width": 2.8, "bottom": 1.4, "top": 3.05, "depth": 0.28}
	_cue(row.node, "CROUCH", Vector3(0, 3.16, 0.151))
	rows.append(row.report)

static func _thread(parent: Node3D, rows: Array, title: String, at: Vector3, deck: String) -> void:
	var row := _installation(parent, title, at, "near_miss", deck)
	# 1.05 m between the two visible walls: 11.86 cm per side of a centred 32 u hull.
	for side: int in [-1, 1]:
		_box(row.node, row.report.solids, "WestWall" if side < 0 else "EastWall", Vector3(side * 0.675, 1.8, 0), Vector3(0.3, 3.6, 1.5), "steel")
	row.report["opening_m"] = {"width": 1.05, "bottom": 0.0, "top": null, "depth": 1.5}
	_cue(row.node, "STYLE", Vector3(-0.675, 2.6, 0.761))
	rows.append(row.report)

static func _installation(parent: Node3D, title: String, at: Vector3, kind: String, deck: String) -> Dictionary:
	var node := Node3D.new()
	node.name = title
	node.position = at
	parent.add_child(node)
	return {"node": node, "report": {"name": title, "kind": kind, "deck_role": "route", "deck_piece": deck,
		"origin_m": _v(at), "normal_line": "open deck to the east", "solids": []}}

static func _box(parent: Node3D, rows: Array, title: String, at: Vector3, size: Vector3, kind: String) -> void:
	var body := StaticBody3D.new()
	body.name = title
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 1
	body.set_meta("surface", "r16_optional_style")
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	visual.name = "SolidMesh"
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	var texture := METAL if kind == "steel" else CONCRETE
	material.albedo_texture = load(texture) as Texture2D
	material.albedo_color = Color("c88e56") if kind == "steel" else Color("c6c3bb")
	material.metallic = 0.45 if kind == "steel" else 0.0
	material.roughness = 0.8
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * 0.7
	visual.material_override = material
	body.add_child(visual)
	parent.add_child(body)
	var transform := body.global_transform
	rows.append({"name": title, "path": str(parent.get_parent().get_path_to(body)), "shape": "BoxShape3D", "size_m": _v(shape.size),
		"world_origin_m": _v(transform.origin), "world_basis": [_v(transform.basis.x), _v(transform.basis.y), _v(transform.basis.z)],
		"layer": body.collision_layer, "mask": body.collision_mask, "material": {"kind": kind, "texture": texture, "licence": "CC0-1.0",
		"tint": material.albedo_color.to_html(), "metallic": material.metallic, "roughness": material.roughness, "triplanar_scale": 0.7}})

static func _cue(parent: Node3D, text: String, at: Vector3) -> void:
	var label := Label3D.new()
	label.name = "Cue"
	label.text = text
	label.position = at
	label.font_size = 36
	label.pixel_size = 0.004
	label.modulate = Color("f4e8ce")
	label.outline_modulate = Color("302d27")
	label.outline_size = 5
	parent.add_child(label)

static func _v(value: Vector3) -> Array:
	return [value.x, value.y, value.z]
