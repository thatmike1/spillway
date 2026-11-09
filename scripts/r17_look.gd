extends Node3D
## reversible visual state only. meshes, solids, progress and recording identities stay untouched.
const PALETTES := preload("res://scripts/r17_palettes.gd")
const BREAKWATER := preload("res://scripts/look_breakwater.gd")
const CONTOURS := preload("res://scripts/r17_contours.gd")
const SURFACE := preload("res://shaders/look/surface.gdshader")
const SKY := preload("res://shaders/look/sky.gdshader")
const WATER := preload("res://shaders/look/water.gdshader")
const PROP := preload("res://shaders/look/r17_prop.gdshader")
const INTERIOR := preload("res://shaders/look/r17_interior.gdshader")
var enabled := false
var swaps: Array[Dictionary] = []
var world: WorldEnvironment
var old_environment: Environment
var painted_environment: Environment
var light_states: Array[Dictionary] = []
var base: Node3D
var palette: Dictionary
var _materials := {}
var _route_kinds: Array[String] = []
var _map_id := ""
var _label_colors: Array[Dictionary] = []
var report := {}

func attach(level: Node3D, map_id: String) -> void:
	name = "R17Look"
	process_mode = Node.PROCESS_MODE_ALWAYS
	palette = PALETTES.MAPS[map_id]
	_map_id = map_id
	for solid: Dictionary in level.get("manifest"):
		var kind := str(solid.get("kind", ""))
		if str(solid.get("role", "")) in ["route","recovery","baffle"] and not kind.is_empty() and not kind in _route_kinds:
			_route_kinds.append(kind)
	if map_id == "breakwater":
		base = BREAKWATER.new()
		add_child(base)
		base.attach(level)
		# wall copings are cream; orange stays on jump lips instead of broad decorative caps.
		var caps := base.get_node("BoundaryCaps") as MeshInstance3D
		caps.material_override = flat(Color(palette.top))
	else:
		for node: Node in level.find_children("*","WorldEnvironment",true,false):
			if node.is_queued_for_deletion():
				continue
			world = node
			old_environment = world.environment
			break
		assert(world != null, "r17: map has no original environment")
		painted_environment = old_environment.duplicate()
		var sky := Sky.new()
		var panorama := ShaderMaterial.new()
		panorama.shader = SKY
		assert(ResourceLoader.exists(palette.sky), "r17: painted sky is missing")
		panorama.set_shader_parameter("panorama",load(palette.sky))
		sky.sky_material = panorama
		painted_environment.background_mode = Environment.BG_SKY
		painted_environment.sky = sky
		painted_environment.sky_rotation = Vector3(0,deg_to_rad(palette.turn),0)
		painted_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		painted_environment.ambient_light_color = Color(palette.fill)
		painted_environment.ambient_light_energy = palette.ambient
		painted_environment.ambient_light_sky_contribution = 0.0
		painted_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		painted_environment.tonemap_exposure = 0.92
		painted_environment.fog_light_color = Color(palette.fog)
		painted_environment.fog_density = 0.0012
		painted_environment.fog_sky_affect = 0.0
		for node: Node in level.find_children("*","DirectionalLight3D",true,false):
			if node.is_queued_for_deletion():
				continue
			light_states.append({"node":node,"rotation":node.rotation,"color":node.light_color,"energy":node.light_energy})
	for node: Node in level.find_children("*","GeometryInstance3D",true,false):
		if node.is_queued_for_deletion() or is_ancestor_of(node) or not node is MeshInstance3D and not node is MultiMeshInstance3D:
			continue
		if map_id == "breakwater" and not "R16Opportunities" in str(level.get_path_to(node)) and not str(node.name).begins_with("Mesh_paint"):
			continue
		var key := str(node.name)
		var old: Material = node.material_override
		var replacement := material_for(key,old,node)
		if replacement != null:
			swaps.append({"node":node,"old":old,"new":replacement})
	if map_id == "night-shift":
		for label: Node in level.find_children("*","Label3D",true,false):
			_label_colors.append({"node":label,"old":label.modulate,"outline":label.outline_modulate})
	var contours := CONTOURS.new()
	add_child(contours.build(level,map_id != "breakwater"))
	report = {"map":map_id,"swaps":swaps.size(),"ink_segments":contours.line_count+(base.line_count if base != null else 0),"jump_lips":contours.lip_count,"sky":palette.sky,"presentation_only":true}
	set_meta("report",report)

func material_for(key: String, old: Material, node: GeometryInstance3D) -> Material:
	if key.begins_with("Mesh_paint") or key.begins_with("Art_paint") or key.begins_with("Readability"):
		# these are functional timing, hazard and landing cues, at their inherited widths.
		if key == "ReadabilityPads":
			return flat(Color("9b7770"))
		if key == "ReadabilityNosing" or "yellow" in key or "hazard" in key or "lip" in key or "duck" in key:
			return flat(Color("d95b30"))
		if "dark" in key:
			return flat(Color("263d45"))
		return flat(Color("fff5db"))
	if node is MeshInstance3D and old == null:
		var ancestor: Node = node.get_parent()
		var architectural := false
		while ancestor != null and ancestor != get_parent():
			var asset := str(ancestor.get_meta("r15_asset", ""))
			architectural = architectural or asset.begins_with("kenney-castle/") or asset.begins_with("kenney-train/")
			ancestor = ancestor.get_parent()
		# imported models retain their palette and texture family, with toon diffuse on copies.
		var mesh := node as MeshInstance3D
		for i: int in mesh.mesh.get_surface_count() if mesh.mesh != null else 0:
			var prior := mesh.get_surface_override_material(i)
			var active := mesh.get_active_material(i)
			if active is BaseMaterial3D and not active.emission_enabled:
				var copy: Material
				if architectural:
					var toon := ShaderMaterial.new()
					toon.shader = PROP
					toon.set_shader_parameter("top_color",Color(palette.top))
					toon.set_shader_parameter("side_color",Color(palette.side))
					if active.albedo_texture != null:
						toon.set_shader_parameter("original",active.albedo_texture)
					copy = toon
				else:
					var clone := active.duplicate() as BaseMaterial3D
					clone.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
					clone.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
					copy = clone
				swaps.append({"node":mesh,"surface":i,"old":prior,"new":copy})
		return null
	if old is BaseMaterial3D and old.emission_enabled:
		if key.begins_with("Mesh_neon"):
			var lamp := old.duplicate() as BaseMaterial3D
			lamp.albedo_color = Color(palette.top)
			lamp.emission = Color(palette.top)
			lamp.emission_energy_multiplier = 0.35
			return lamp
		return null
	var water_shader: bool = old is ShaderMaterial and old.shader != null and old.shader.resource_path.ends_with("momentum_overflow_water.gdshader")
	var inline_water: bool = node is MeshInstance3D and node.mesh is PlaneMesh and old is ShaderMaterial and old.get_shader_parameter("tint") != null
	if water_shader or inline_water or key in ["Harbour","Canal","River","Water","PoolWater","Art_Water"] or key.begins_with("Pool_"):
		var water := ShaderMaterial.new()
		water.shader = WATER
		return water
	if not key.begins_with("Mesh_") and not key.begins_with("Art_") and key not in ["SolidMesh","RollingStock","Rails","ReadabilityPads","ReadabilityBars","ReadabilityNosing"]:
		return null
	var kind := key.trim_prefix("Mesh_").trim_prefix("Art_")
	# indoor movement faces get separate values even when no sun reaches the room.
	if _map_id in ["experiment", "whiteout-relay"] and kind in ["wall_panel", "housing", "rack_low", "roof", "cladding_slate", "machine", "frame"]:
		if not _materials.has(kind):
			var interior := ShaderMaterial.new()
			interior.shader = INTERIOR
			var value := 0.22
			if kind in ["wall_panel", "cladding_slate"]:
				value = 0.40
			elif kind in ["roof", "rack_low"]:
				value = 0.55
			interior.set_shader_parameter("base_color",Color(palette.side).lightened(value))
			_materials[kind] = interior
		return _materials[kind]
	var material_key := kind
	if _materials.has(material_key):
		return _materials[material_key]
	var top := Color(palette.top)
	var side := Color(palette.side)
	var deck := key == "RollingStock"
	for candidate: String in PALETTES.LANDABLE+_route_kinds:
		if kind == candidate or kind.begins_with(candidate+"_"):
			deck = true
	for ground: String in PALETTES.GROUND:
		if (kind == ground or kind.begins_with(ground+"_")) and not deck:
			top = Color("8fa7b7") if "snow" in kind or kind in ["rock","plateau"] else Color("718d7d")
			deck = false
	if not deck and top == Color(palette.top):
		top = side.lightened(0.25)
	if key == "SolidMesh":
		top = Color(palette.top)
	var material := ShaderMaterial.new()
	material.shader = SURFACE
	material.set_shader_parameter("wear",load("res://assets/look/painted-wear.png"))
	material.set_shader_parameter("top_color",top)
	material.set_shader_parameter("side_color",side)
	material.set_shader_parameter("wear_amount",0.08)
	material.set_shader_parameter("deck",0.35 if deck else 0.0)
	_materials[material_key] = material
	return material

func flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func set_enabled(value: bool) -> void:
	enabled = value
	visible = value
	if base != null:
		base.set_enabled(value)
	for swap: Dictionary in swaps:
		if not is_instance_valid(swap.node):
			continue
		var chosen: Material = swap.new if value else swap.old
		if swap.has("surface"):
			swap.node.set_surface_override_material(swap.surface,chosen)
		else:
			swap.node.material_override = chosen
	if world != null:
		world.environment = painted_environment if value else old_environment
	for i: int in light_states.size():
		var state: Dictionary = light_states[i]
		if value:
			state.node.rotation_degrees = Vector3(palette.pitch,palette.yaw,0) if i == 0 else Vector3(-55,float(palette.yaw)+180,0)
			state.node.light_color = Color(palette.sun if i == 0 else palette.fill)
			state.node.light_energy = float(palette.sun_energy) if i == 0 else 0.12
		else:
			state.node.rotation = state.rotation
			state.node.light_color = state.color
			state.node.light_energy = state.energy
	for state: Dictionary in _label_colors:
		state.node.modulate = Color(palette.top) if value else state.old
		state.node.outline_modulate = Color("172638") if value else state.outline
