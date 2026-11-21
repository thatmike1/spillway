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
## optional per-map sky and light values (lane 02 owns the file) and per-map look overrides
## (map lanes own scripts/look/maps/<map-id>.gd). docs/look-language.md describes both shapes.
const SKY_LIGHT_PATH := "res://scripts/look/sky_light.gd"
const MAP_OVERRIDE_ROOT := "res://scripts/look/maps/"
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
## the sky_light.gd entry in use: the real map id first, then the palette alias; empty means palette values.
var sky_id := ""
var override: Object
var dressing: Node3D
var _sky_light: Script

func attach(level: Node3D, map_id: String) -> void:
	name = "R17Look"
	process_mode = Node.PROCESS_MODE_ALWAYS
	palette = PALETTES.MAPS[map_id].duplicate()
	_map_id = map_id
	var real_id := _real_map_id(level, map_id)
	var override_path := MAP_OVERRIDE_ROOT+real_id+".gd"
	if ResourceLoader.exists(override_path):
		var override_script := load(override_path) as Script
		assert(override_script != null, "r17: map look override does not load: "+override_path)
		override = override_script.new()
		var constants := override_script.get_script_constant_map()
		if constants.has("PALETTE"):
			palette.merge(constants.PALETTE, true)
	_load_sky_light(map_id, real_id)
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
		if not sky_id.is_empty():
			# breakwater's own environment and lights yield to the sky_light entry when it has one.
			world = base.world
			old_environment = base.old_environment
			light_states = base.light_states.duplicate()
			_paint_environment()
			base.painted_environment = painted_environment
	else:
		for node: Node in level.find_children("*","WorldEnvironment",true,false):
			if node.is_queued_for_deletion():
				continue
			world = node
			old_environment = world.environment
			break
		assert(world != null, "r17: map has no original environment")
		for node: Node in level.find_children("*","DirectionalLight3D",true,false):
			if node.is_queued_for_deletion():
				continue
			light_states.append({"node":node,"rotation":node.rotation,"color":node.light_color,"energy":node.light_energy})
		_paint_environment()
	for node: Node in level.find_children("*","GeometryInstance3D",true,false):
		if node.is_queued_for_deletion() or is_ancestor_of(node) or not node is MeshInstance3D and not node is MultiMeshInstance3D:
			continue
		if map_id == "breakwater" and not "R16Opportunities" in str(level.get_path_to(node)) and not str(node.name).begins_with("Mesh_paint"):
			continue
		var key := str(node.name)
		var old: Material = node.material_override
		var replacement := material_for(key,old,node)
		if override != null and override.has_method("material"):
			replacement = override.call("material",key,node,replacement)
		if replacement != null:
			swaps.append({"node":node,"old":old,"new":replacement})
	if map_id == "night-shift":
		for label: Node in level.find_children("*","Label3D",true,false):
			_label_colors.append({"node":label,"old":label.modulate,"outline":label.outline_modulate})
	var contours := CONTOURS.new()
	add_child(contours.build(level,map_id != "breakwater"))
	if override != null and override.has_method("dress"):
		var proposed: Node = override.call("dress",level)
		if proposed != null and (not proposed is Node3D or _collides(proposed)):
			# dressing is look-only: anything that could collide rejects the whole dressing before it enters the tree.
			push_error("r17: look dressing rejected, it may collide or is not a Node3D: "+override_path)
			proposed.free()
		elif proposed != null:
			dressing = proposed
			dressing.name = "MapDressing"
			add_child(dressing)
	report = {"map":map_id,"swaps":swaps.size(),"ink_segments":contours.line_count+(base.line_count if base != null else 0),"jump_lips":contours.lip_count,"sky":palette.sky,"sky_light":sky_id,"override":override != null,"presentation_only":true}
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
				if override != null and override.has_method("material"):
					copy = override.call("material",key,mesh,copy)
				if copy != null:
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
	var indoor_role := ""
	if _map_id in ["experiment", "whiteout-relay"]:
		for role: String in ["wall_panel", "housing", "rack_low", "roof", "cladding_slate", "cladding_red", "machine", "frame"]:
			if kind == role or kind.begins_with(role+"_"):
				indoor_role = role
				break
	if not indoor_role.is_empty():
		if not _materials.has(kind):
			var interior := ShaderMaterial.new()
			interior.shader = INTERIOR
			var value := 0.22
			if indoor_role in ["wall_panel", "cladding_slate", "cladding_red"]:
				value = 0.40
			elif indoor_role in ["roof", "rack_low"]:
				value = 0.55
			interior.set_shader_parameter("base_color",Color(palette.side).lightened(value))
			_materials[kind] = interior
		return _materials[kind]
	var surfaces: Dictionary = override.get_script().get_script_constant_map().get("SURFACES", {}) if override != null else {}
	# a full node-name override gets its own cache entry, so Mesh_x and Art_x never share it by accident.
	var surface_key := key if surfaces.has(key) else (kind if surfaces.has(kind) else "")
	var material_key := key if surface_key == key else kind
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
	if not surface_key.is_empty():
		for parameter: String in surfaces[surface_key]:
			var value: Variant = surfaces[surface_key][parameter]
			material.set_shader_parameter(parameter, Color(value) if value is String else value)
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
	var sun_index := 0
	if base != null:
		for i: int in light_states.size():
			if str(light_states[i].node.name) == "Sun":
				sun_index = i
	for i: int in light_states.size():
		var state: Dictionary = light_states[i]
		if value and not sky_id.is_empty():
			# index 0 asks sky_light for the sun, any other index for the fill.
			var values: Dictionary = _sky_light.call("light", 0 if i == sun_index else i+1, sky_id)
			state.node.rotation_degrees = values.rotation_degrees
			state.node.light_color = values.color
			state.node.light_energy = values.energy
		elif value:
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
	if override != null and override.has_method("set_enabled"):
		override.call("set_enabled",value)

func _real_map_id(level: Node3D, fallback: String) -> String:
	# r19 maps pass a palette alias (saltglass uses practice); the host knows the real id.
	var node: Node = level
	while node != null:
		var id: Variant = node.get("map_id")
		if id is String and not str(id).is_empty():
			return id
		node = node.get_parent()
	return fallback

func _load_sky_light(palette_id: String, real_id: String) -> void:
	# lane 02's file: has_map(id), environment(base, id) -> Environment, light(index, id) -> Dictionary.
	if not ResourceLoader.exists(SKY_LIGHT_PATH):
		return
	_sky_light = load(SKY_LIGHT_PATH) as Script
	assert(_sky_light != null, "r17: sky_light.gd does not load")
	for id: String in [real_id, palette_id]:
		if bool(_sky_light.call("has_map", id)):
			sky_id = id
			return

func _paint_environment() -> void:
	if not sky_id.is_empty():
		# breakwater already built a Sky; repainting it avoids freeing an undrawn one (a radiance leak at exit).
		var reuse: Sky = base.painted_environment.sky if base != null and base.painted_environment != null else null
		var takes_reuse := false
		for method: Dictionary in _sky_light.get_script_method_list():
			if method.name == "environment" and (method.args as Array).size() >= 3:
				takes_reuse = true
		if takes_reuse:
			painted_environment = _sky_light.call("environment", old_environment, sky_id, reuse)
		else:
			painted_environment = _sky_light.call("environment", old_environment, sky_id)
		return
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

func _collides(root: Node) -> bool:
	# release-safe: assertions vanish in exported builds, so this is an ordinary branch.
	var nodes: Array[Node] = [root]
	nodes.append_array(root.find_children("*","",true,false))
	for node: Node in nodes:
		if node is CollisionObject3D or node is CollisionShape3D or node is CollisionPolygon3D or node is GridMap:
			return true
		if node is CSGShape3D and (node as CSGShape3D).use_collision:
			return true
	return false
