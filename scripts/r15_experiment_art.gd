extends RefCounted
## p / r15 Movement Lab art: everything the workshop draws, from the level's own records. the
## level calls dress() once at the end of build(); nothing here adds a collision body, moves one,
## changes progress or anchors, or enters the geometry hash.
##
## the look: a clean service workshop under even working light. floors are the momentum kit's
## brushed concrete with bay joints, housings and the mezzanine blue-grey steel plate, gantries
## and trims ochre, the pit old concrete. yellow-black hazard paint marks every edge a move starts
## from: the lane mouth, the striped wall-jump faces, the mezzanine lip. anchors are lit orange
## rings. sourced kenney factory/industrial props (cc0, assets/r15/library) dress the hub and the
## stations; reachable ones stand on the level's own collision prisms.

const Materials := preload("res://scripts/momentum_materials.gd")
const ASSETS := preload("res://scripts/r15_assets.gd")
const VERSION := "movement-lab-art-1"

## p / prism kinds -> momentum kit kinds (or a flat colour).
const KIT := {&"floor": &"deck", &"lane_floor": &"steel", &"housing": &"steel", &"deck_steel": &"steel", &"wall_panel": &"concrete",
	&"pit_floor": &"old_concrete", &"chute": &"old_concrete", &"grating": &"steel", &"gantry": &"ochre", &"column": &"ochre", &"rack": &"steel", &"rack_low": &"ochre", &"steel": &"steel"}
const FLAT := {&"roof": Color("3b4048"), &"paint_white": Color("e8e6de"), &"paint_yellow": Color("e3b52b")}
## p / overrides that keep neighbouring steel kinds apart at a glance.
const TINTS := {
	&"housing": {"top_tint": Vector3(0.8, 0.9, 1.02), "side_tint": Vector3(0.8, 0.9, 1.02)},
	&"deck_steel": {"top_tint": Vector3(0.75, 0.82, 0.9), "side_tint": Vector3(0.45, 0.5, 0.56)},
	&"lane_floor": {"top_tint": Vector3(0.9, 0.92, 0.95), "side_tint": Vector3(0.5, 0.52, 0.56)},
	&"grating": {"top_tint": Vector3(0.6, 0.62, 0.62), "side_tint": Vector3(0.4, 0.42, 0.44)},
	&"rack": {"top_tint": Vector3(0.36, 0.4, 0.46), "side_tint": Vector3(0.36, 0.4, 0.46)},
}
## visual-only sourced pieces out of reach: model, feet, scale, yaw (turns).
const DRESSING := [
	["kenney-factory/models/pipe-large-long.glb", Vector3(-0.0, 1.62, -22.52), 0.98, 0.0],
	["kenney-factory/models/pipe-large-long.glb", Vector3(-0.0, 2.62, -22.52), 0.98, 0.0],
	["kenney-factory/models/pipe-large-valve.glb", Vector3(-6.5, 8.5, -24.5), 1.4, 0.0],
	["kenney-factory/models/pipe-large-long.glb", Vector3(4.2, 8.5, -24.5), 1.4, 0.0],
	["kenney-factory/models/machine.glb", Vector3(-7.0, 8.5, -50.0), 1.8, 0.0],
	["kenney-factory/models/hopper-square.glb", Vector3(7.0, 8.5, -50.0), 2.0, 0.0],
	["kenney-factory/models/robot-arm-a.glb", Vector3(-9.0, 8.5, -24.5), 0.9, 0.25],
	["kenney-factory/models/crane.glb", Vector3(9.0, 8.5, -48.0), 1.2, 0.75],
	["kenney-space/models/machine_generatorLarge.glb", Vector3(9.0, 8.5, -24.5), 2.2, 0.0],
	["kenney-industrial/models/detail-tank.glb", Vector3(-8.0, -20.0, -77.0), 3.0, 0.0],
]
## p / roof lamps: z positions of the lamp rows, metres; omni lights stay under the
## compatibility renderer's per-object limit of eight with the two anchor glows.
const LAMPS := [0.0, -20.0, -40.0, -58.0, -76.0, -94.0]

var report := {"version": VERSION}
var _surfaces := {}
var _cache := {}
var _hazard: StandardMaterial3D
var _anchor_material: StandardMaterial3D
var _bay_lamp: OmniLight3D
var _finished := false
var _glow := 0.0
var _time := 0.0

func dress(level: Node3D) -> void:
	var started := Time.get_ticks_usec()
	_environment(level)
	for prism: Dictionary in level.get("prisms"):
		if prism.kind != &"prop_proxy":
			_prism(prism.top, float(prism.base), prism.kind)
	for mark: Dictionary in level.get("markings"):
		if str(mark.kind) == "strip":
			_prism(mark.top, float(mark.base), mark.paint)
	_commit(level)
	_signs(level)
	_panels(level)
	_anchors(level)
	_lamps(level)
	var placed := 0
	for prop: Dictionary in level.get("props"):
		ASSETS.place(level, str(prop.model), prop.feet, Vector3.ONE * float(prop.scale), float(prop.yaw))
		placed += 1
	for item: Array in DRESSING:
		ASSETS.place(level, str(item[0]), item[1], Vector3.ONE * float(item[2]), float(item[3]) * TAU)
		placed += 1
	report["props_placed"] = placed
	report["apply_ms"] = (Time.get_ticks_usec() - started) / 1000.0
	level.set_meta("movement_lab_art", report)

func finished(_level: Node3D, on: bool) -> void:
	_finished = on

func tick(_level: Node3D, delta: float) -> void:
	_time += delta
	_glow = move_toward(_glow, 1.0 if _finished else 0.0, delta * 1.5)
	if _anchor_material != null:
		_anchor_material.emission_energy_multiplier = 2.2 + 0.6 * sin(_time * 3.0)
	if is_instance_valid(_bay_lamp):
		_bay_lamp.light_energy = 1.2 + _glow * 2.0

# --- materials ------------------------------------------------------------------------------

func material(kind: StringName) -> Material:
	if _cache.has(kind):
		return _cache[kind]
	var made: Material
	if kind == &"paint_hazard":
		made = hazard()
	elif KIT.has(kind):
		made = Materials.variant(KIT[kind], TINTS.get(kind, {})) if TINTS.has(kind) else Materials.get_material(KIT[kind])
	else:
		var flat := StandardMaterial3D.new()
		flat.albedo_color = FLAT.get(kind, Color("8a8d90"))
		flat.roughness = 0.75
		made = flat
	_cache[kind] = made
	return made

## original yellow-black diagonal stripes, generated here, mapped in world metres.
func hazard() -> StandardMaterial3D:
	if _hazard != null:
		return _hazard
	var image := Image.create(64, 64, true, Image.FORMAT_RGB8)
	for y: int in 64:
		for x: int in 64:
			image.set_pixel(x, y, Color("e3b52b") if ((x + y) / 16) % 2 == 0 else Color("1d1e21"))
	image.generate_mipmaps()
	_hazard = StandardMaterial3D.new()
	_hazard.albedo_texture = ImageTexture.create_from_image(image)
	_hazard.uv1_triplanar = true
	_hazard.uv1_world_triplanar = true
	_hazard.uv1_scale = Vector3.ONE * 2.0
	_hazard.roughness = 0.6
	return _hazard

# --- light ----------------------------------------------------------------------------------

func _environment(level: Node3D) -> void:
	var world := WorldEnvironment.new()
	world.name = "Environment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("2a3038")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b9c4cf")
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.05
	environment.fog_enabled = true
	environment.fog_light_color = Color("8f9aa6")
	environment.fog_density = 0.004
	world.environment = environment
	level.add_child(world)
	# p / the skylights' light: high and slightly from the east, with shadows, so every deck
	# edge and the lane mouth read from the run-up.
	var sun := DirectionalLight3D.new()
	sun.name = "Skylight"
	sun.rotation = Vector3(deg_to_rad(-62.0), deg_to_rad(25.0), 0.0)
	sun.light_color = Color("fff3e2")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	level.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.rotation = Vector3(deg_to_rad(-30.0), deg_to_rad(200.0), 0.0)
	fill.light_color = Color("cfe0f5")
	fill.light_energy = 0.35
	level.add_child(fill)

func _lamps(level: Node3D) -> void:
	var tube := StandardMaterial3D.new()
	tube.albedo_color = Color("fffaf0")
	tube.emission_enabled = true
	tube.emission = Color("fff4dc")
	tube.emission_energy_multiplier = 2.5
	tube.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var roof := float((level.get_script() as Script).get_script_constant_map().ROOF)
	for i: int in LAMPS.size():
		var z: float = LAMPS[i]
		for x: float in [-6.0, 6.0]:
			var lamp := MeshInstance3D.new()
			lamp.name = "LampTube_%d_%s" % [i, "w" if x < 0.0 else "e"]
			var box := BoxMesh.new()
			box.size = Vector3(0.25, 0.1, 5.0)
			lamp.mesh = box
			lamp.material_override = tube
			lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			lamp.position = Vector3(x, roof - 0.3, z)
			level.add_child(lamp)
		var light := OmniLight3D.new()
		light.name = "Lamp_%d" % i
		light.position = Vector3(0.0, roof - 1.0, z)
		light.omni_range = 20.0
		light.light_energy = 1.1
		light.light_color = Color("fff1d8")
		level.add_child(light)
		if i == LAMPS.size() - 1:
			_bay_lamp = light

# --- prisms ---------------------------------------------------------------------------------

func _prism(top: Array, base: float, kind: StringName) -> void:
	var st := _st(kind)
	var n := top.size()
	var centre := Vector3.ZERO
	for p: Vector3 in top:
		centre += p / n
	for i: int in range(1, n - 1):
		_tri(st, top[0], top[i], top[i + 1], Vector3.UP, true)
	for i: int in n:
		var a: Vector3 = top[i]
		var b: Vector3 = top[(i + 1) % n]
		if (b - a).length_squared() < 1e-8:
			continue
		var a0 := Vector3(a.x, base, a.z)
		var b0 := Vector3(b.x, base, b.z)
		var out := (b - a).cross(Vector3.UP).normalized()
		var mid := (a + b) * 0.5
		if out.dot(Vector3(mid.x - centre.x, 0, mid.z - centre.z)) < 0.0:
			out = -out
		_tri(st, a, b, b0, out)
		_tri(st, a, b0, a0, out)
	# the underside, so a ceiling (the pipe rack, the gantries) is drawn from below.
	for i: int in range(1, n - 1):
		_tri(st, Vector3(top[0].x, base, top[0].z), Vector3(top[i].x, base, top[i].z), Vector3(top[i + 1].x, base, top[i + 1].z), Vector3.DOWN)

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, up: bool = false) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	var face := n.normalized()
	if up and face.y < 0.0:
		face = -face
	elif not up:
		face = normal
	if n.dot(face) > 0.0:
		var swap := b
		b = c
		c = swap
	for v: Vector3 in [a, b, c]:
		st.set_normal(face)
		st.add_vertex(v)

func _st(kind: StringName) -> SurfaceTool:
	if not _surfaces.has(kind):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_surfaces[kind] = st
	return _surfaces[kind]

func _commit(level: Node3D) -> void:
	var counts := {}
	for kind: StringName in _surfaces:
		var instance := MeshInstance3D.new()
		instance.name = "Mesh_" + String(kind)
		instance.mesh = (_surfaces[kind] as SurfaceTool).commit()
		instance.material_override = material(kind)
		if String(kind).begins_with("paint"):
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		level.add_child(instance)
		counts[String(kind)] = instance.mesh.get_faces().size() / 3
	_surfaces.clear()
	report["prism_triangles"] = counts

# --- signs, panels and anchors -----------------------------------------------------------------

func _signs(level: Node3D) -> void:
	for mark: Dictionary in level.get("markings"):
		if str(mark.kind) != "wall":
			continue
		var label := Label3D.new()
		label.name = "Sign_" + str(mark.name)
		label.text = str(mark.text)
		label.font_size = 64
		label.pixel_size = 0.006
		label.outline_size = 10
		label.modulate = Color("f4f1dd")
		label.outline_modulate = Color("15181c")
		label.position = mark.at
		label.rotation.y = float(mark.yaw)
		level.add_child(label)
	# the hub board: what the lab is, its keys, and that it is not a course.
	var board := Label3D.new()
	board.name = "Sign_hub_board"
	board.text = "MOVEMENT LAB  ·  EXPERIMENTAL\nnot a course: its own records\n\nShift  slide      Space at a wall  wall jump      hold E  grapple\n1 / 2 / 3 or Esc  turn each move on or off"
	board.font_size = 72
	board.pixel_size = 0.007
	board.outline_size = 12
	board.modulate = Color("f3cd83")
	board.outline_modulate = Color("15181c")
	board.position = Vector3(0.0, 5.2, -21.95)
	level.add_child(board)

func _panels(level: Node3D) -> void:
	for mark: Dictionary in level.get("markings"):
		if str(mark.kind) != "panel":
			continue
		var panel := MeshInstance3D.new()
		panel.name = "Panel_" + str(mark.name)
		var box := BoxMesh.new()
		box.size = Vector3(0.006, float(mark.y1) - float(mark.y0), absf(float(mark.z1) - float(mark.z0)))
		panel.mesh = box
		panel.material_override = hazard()
		panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		panel.position = Vector3(float(mark.x), (float(mark.y0) + float(mark.y1)) * 0.5, (float(mark.z0) + float(mark.z1)) * 0.5)
		level.add_child(panel)

func _anchors(level: Node3D) -> void:
	_anchor_material = StandardMaterial3D.new()
	_anchor_material.albedo_color = Color("ff9a3c")
	_anchor_material.emission_enabled = true
	_anchor_material.emission = Color("ff9a3c")
	_anchor_material.emission_energy_multiplier = 2.4
	var hook := StandardMaterial3D.new()
	hook.albedo_color = Color("2b2f35")
	hook.metallic = 0.6
	hook.roughness = 0.4
	for anchor: Dictionary in level.get("anchors"):
		var at: Vector3 = anchor.position
		var ring := MeshInstance3D.new()
		ring.name = "AnchorRing_" + str(anchor.name)
		var torus := TorusMesh.new()
		torus.inner_radius = 0.26
		torus.outer_radius = 0.36
		ring.mesh = torus
		ring.material_override = _anchor_material
		# the ring stands upright, facing the approach (+z).
		ring.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), at)
		level.add_child(ring)
		var rod := MeshInstance3D.new()
		rod.name = "AnchorHook_" + str(anchor.name)
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.05
		cylinder.bottom_radius = 0.05
		cylinder.height = 0.4
		rod.mesh = cylinder
		rod.material_override = hook
		rod.position = at + Vector3.UP * 0.5
		level.add_child(rod)
		var label := Label3D.new()
		label.name = "AnchorLabel_" + str(anchor.name)
		label.text = str(anchor.name)
		label.font_size = 48
		label.pixel_size = 0.008
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color("ffcf8a")
		label.outline_size = 8
		label.outline_modulate = Color("15181c")
		label.position = at + Vector3.DOWN * 0.65
		level.add_child(label)
		var glow := OmniLight3D.new()
		glow.name = "AnchorGlow_" + str(anchor.name)
		glow.position = at + Vector3.DOWN * 0.3
		glow.omni_range = 4.0
		glow.light_energy = 0.8
		glow.light_color = Color("ffae5c")
		level.add_child(glow)
