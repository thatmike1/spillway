extends RefCounted
## p / momentum art kit: cached surface materials over the adopted cc0 scans in
## res://assets/momentum. every kind shares one shader that maps in metres from the
## object's own rotation frame, so plain BoxMesh floors, walls and rotated slopes need
## no uv work. provenance, scale and costs: assets/momentum/MANIFEST.json, docs/momentum/ART.md.

const SHADER: Shader = preload("res://shaders/momentum_surface.gdshader")
const ROOT := "res://assets/momentum/"

# texture sets: folder, measured metres per repeat (poly haven "dimensions").
const SETS := {
	&"deck": {"id": "brushed_concrete", "metres": 2.5},
	&"formwork": {"id": "concrete_layers_02", "metres": 2.0},
	&"plate": {"id": "metal_plate_02", "metres": 2.0},
	&"brick": {"id": "red_brick", "metres": 1.4},
}

# p / each kind names its top and side sets and its shader parameters. decks are the
# lightest plane in view, walls a step below, old concrete and steel darker again,
# with ochre and brick as the only saturated accents.
const KINDS := {
	&"deck": {"top": &"deck", "side": &"formwork", "params": {
		"desaturate": 0.75, "top_tint": Vector3(1.28, 1.31, 1.38), "side_tint": Vector3(1.05, 1.06, 1.1),
		"bay_size": Vector2(4.0, 4.0), "bay_tone": 0.05, "joint_dark": 0.5,
		"side_joint_spacing": 12.0, "macro_strength": 0.06}},
	&"concrete": {"top": &"deck", "side": &"formwork", "params": {
		"desaturate": 0.75, "top_tint": Vector3(1.05, 1.08, 1.13), "side_tint": Vector3(0.92, 0.94, 0.98),
		"bay_size": Vector2(4.0, 4.0), "bay_tone": 0.04, "joint_dark": 0.45,
		"side_joint_spacing": 12.0, "macro_strength": 0.07}},
	&"old_concrete": {"top": &"deck", "side": &"formwork", "params": {
		"desaturate": 0.6, "top_tint": Vector3(0.7, 0.75, 0.73), "side_tint": Vector3(0.58, 0.62, 0.6),
		"bay_size": Vector2(4.0, 4.0), "bay_tone": 0.08, "joint_dark": 0.55,
		"side_joint_spacing": 12.0, "macro_strength": 0.12, "stain": 0.55}},
	&"steel": {"top": &"plate", "side": &"plate", "params": {
		"desaturate": 0.85, "top_tint": Vector3(0.55, 0.68, 0.8), "side_tint": Vector3(0.55, 0.68, 0.8),
		"metallic_scale": 0.65, "roughness_scale": 0.85, "macro_strength": 0.04}},
	&"ochre": {"top": &"plate", "side": &"plate", "params": {
		"desaturate": 0.85, "top_tint": Vector3(0.7, 0.7, 0.7), "side_tint": Vector3(0.7, 0.7, 0.7),
		"metallic_scale": 0.65, "paint_amount": 1.0, "paint_color": Color("a8803c"),
		"paint_roughness": 0.55, "macro_strength": 0.03}},
	&"brick": {"top": &"deck", "side": &"brick", "params": {
		"desaturate": 0.3, "top_tint": Vector3(0.95, 0.96, 1.0), "side_tint": Vector3(0.9, 0.84, 0.8),
		"macro_strength": 0.05}},
}

# p / props: origin at the foot of the (first) post on the walking surface, +x along
# the run of the rail, metres. the proxy is one box over the whole visual envelope, so
# the rail is never a walk-through solid; nothing under the knee rail is passable anyway.
const PROPS := {
	&"rail_section": {"scene": "props/rail_section.gltf", "kind": &"ochre",
		"proxy_size": Vector3(2.08, 1.1, 0.16), "proxy_center": Vector3(0.96, 0.55, 0.0)},
	&"rail_post": {"scene": "props/rail_post.gltf", "kind": &"ochre",
		"proxy_size": Vector3(0.16, 1.1, 0.16), "proxy_center": Vector3(0.0, 0.55, 0.0)},
}

static var _cache: Dictionary = {}


## shared material for a kind; changing it changes every user, so call variant() for edits.
static func get_material(kind: StringName) -> ShaderMaterial:
	if not _cache.has(kind):
		_cache[kind] = build(kind)
	return _cache[kind]


static func kinds() -> PackedStringArray:
	return PackedStringArray(KINDS.keys())


## uncached material; overrides replace shader parameters or name another set for
## "top"/"side" (a SETS key or a {"id", "metres"} dictionary for trials).
static func build(kind: StringName, overrides: Dictionary = {}) -> ShaderMaterial:
	assert(KINDS.has(kind), "unknown momentum material kind " + kind)
	var spec: Dictionary = KINDS[kind]
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.resource_name = "momentum_" + kind
	_bind(material, "top", overrides.get("top", spec.top))
	_bind(material, "side", overrides.get("side", spec.side))
	var params: Dictionary = spec.params.duplicate()
	params.merge(overrides, true)
	for key: String in params:
		if key != "top" and key != "side":
			material.set_shader_parameter(key, params[key])
	return material


## edit-safe copy of a cached kind, e.g. variant(&"old_concrete", {"waterline": 2.5}).
static func variant(kind: StringName, overrides: Dictionary) -> ShaderMaterial:
	return build(kind, overrides)


static func _bind(material: ShaderMaterial, slot: String, set_name: Variant) -> void:
	var texture_set: Dictionary = set_name if set_name is Dictionary else SETS[set_name]
	var base := ROOT + "textures/%s/%s_" % [texture_set.id, texture_set.id]
	material.set_shader_parameter(slot + "_albedo", load(base + "diff_1k.png"))
	material.set_shader_parameter(slot + "_normal", load(base + "nor_gl_1k.png"))
	material.set_shader_parameter(slot + "_arm", load(base + "arm_1k.png"))
	material.set_shader_parameter(slot + "_tile", Vector2.ONE * float(texture_set.metres))


## prop scene with the kit material and its collision proxy (pass false to leave it out,
## e.g. when the placement is unreachable). layer/mask are left at Godot defaults.
static func instance_prop(prop: StringName, collision := true) -> Node3D:
	var spec: Dictionary = PROPS[prop]
	var node: Node3D = (load(ROOT + spec.scene) as PackedScene).instantiate()
	node.name = String(prop).to_pascal_case()
	for mesh: Node in node.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = get_material(spec.kind)
	if collision:
		var body := StaticBody3D.new()
		body.name = "CollisionProxy"
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = spec.proxy_size
		shape.shape = box
		shape.position = spec.proxy_center
		body.add_child(shape)
		node.add_child(body)
	return node
