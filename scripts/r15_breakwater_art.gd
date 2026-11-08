extends RefCounted
## p / r15 Breakwater art: everything the course draws, from the level's own records. the level
## calls dress() once at the end of build(); nothing here adds or moves a collision body on the
## route, changes progress data or enters the geometry hash. the only bodies added are the
## crane legs and ship hull standing in the harbour, which a runner could fall against, each a
## named prism listed in scenery_bodies.
##
## the look: a container port at dusk under a poly haven sunset sky. container roofs and sides use
## the container_side scan in six paint colours; quays and the breakwater are pale pavers, roads
## asphalt, walls the kit's concrete. sourced props (rollershutter doors, lifebuoys, wall lamps,
## fenders, buoys, sea markers, barrels, road barriers) set the place. provenance and every
## modification: assets/r15/breakwater/MANIFEST.json.

const Materials := preload("res://scripts/momentum_materials.gd")
const SHADER: Shader = preload("res://shaders/momentum_surface.gdshader")
const KIT := "res://assets/r15/breakwater/"
const VERSION := "breakwater-art-1"

## texture sets: base path (without _diff_1k etc.), file type and metres per repeat.
const SETS := {
	&"container": {"base": KIT + "textures/container_side/container_side", "ext": "jpg", "metres": 1.94},
	&"cladding": {"base": KIT + "textures/box_profile_metal_sheet/box_profile_metal_sheet", "ext": "jpg", "metres": 2.0},
	&"crane": {"base": KIT + "textures/rusty_painted_metal/rusty_painted_metal", "ext": "jpg", "metres": 2.2},
	&"asphalt": {"base": KIT + "textures/asphalt_02/asphalt_02", "ext": "jpg", "metres": 3.0},
	&"pavers": {"base": KIT + "textures/square_concrete_pavers/square_concrete_pavers", "ext": "jpg", "metres": 1.8},
	&"plaster": {"base": KIT + "textures/white_plaster_rough_02/white_plaster_rough_02", "ext": "jpg", "metres": 2.0},
	&"formwork": {"base": "res://assets/momentum/textures/concrete_layers_02/concrete_layers_02", "ext": "png", "metres": 2.0},
	&"plate": {"base": "res://assets/momentum/textures/metal_plate_02/metal_plate_02", "ext": "png", "metres": 2.0},
}
## p / container paints, linear multipliers on the desaturated scan: blue, oxide red, orange,
## grey, green, off-white. roofs are lighter than sides (sun-bleached), so a landing reads.
const PAINTS := [
	Vector3(0.36, 0.62, 1.15), Vector3(1.2, 0.42, 0.3), Vector3(1.75, 0.85, 0.3),
	Vector3(1.0, 1.02, 1.04), Vector3(0.5, 0.9, 0.6), Vector3(1.75, 1.72, 1.62),
]
## p / the looks of every prism kind: [top set, side set, shader parameters].
const LOOKS := {
	&"pavers": [&"pavers", &"formwork", {"desaturate": 0.75, "top_tint": Vector3(1.55, 1.5, 1.42), "side_tint": Vector3(0.62, 0.63, 0.66), "macro_strength": 0.06, "stain": 0.2, "waterline": -2.4}],
	&"asphalt": [&"asphalt", &"formwork", {"desaturate": 0.5, "top_tint": Vector3(1.55, 1.52, 1.5), "side_tint": Vector3(0.6, 0.61, 0.64), "macro_strength": 0.1, "stain": 0.3, "waterline": -2.4}],
	&"land": [&"asphalt", &"formwork", {"desaturate": 0.5, "top_tint": Vector3(0.95, 0.95, 0.95), "side_tint": Vector3(0.55, 0.56, 0.58), "macro_strength": 0.14, "stain": 0.5, "waterline": -2.4}],
	&"concrete": [&"formwork", &"formwork", {"desaturate": 0.8, "top_tint": Vector3(1.15, 1.13, 1.1), "side_tint": Vector3(0.95, 0.94, 0.92), "side_joint_spacing": 6.0, "side_bay_tone": 0.05, "macro_strength": 0.08, "stain": 0.35, "waterline": -2.4}],
	&"steel_ramp": [&"plate", &"plate", {"desaturate": 0.85, "top_tint": Vector3(0.75, 0.8, 0.86), "side_tint": Vector3(0.5, 0.54, 0.6), "metallic_scale": 0.6, "roughness_scale": 0.8, "macro_strength": 0.04}],
	&"plaster": [&"plaster", &"plaster", {"desaturate": 0.92, "top_tint": Vector3(1.7, 1.68, 1.62), "side_tint": Vector3(1.75, 1.72, 1.66), "macro_strength": 0.05, "stain": 0.25, "waterline": -2.2}],
	&"plaster_red": [&"plaster", &"plaster", {"desaturate": 0.95, "top_tint": Vector3(1.3, 0.3, 0.24), "side_tint": Vector3(1.3, 0.3, 0.24), "macro_strength": 0.05}],
	&"cladding": [&"cladding", &"cladding", {"desaturate": 0.85, "top_tint": Vector3(0.75, 0.82, 0.9), "side_tint": Vector3(0.75, 0.82, 0.92), "metallic_scale": 0.4, "macro_strength": 0.06}],
	&"cladding_warm": [&"cladding", &"cladding", {"desaturate": 0.3, "top_tint": Vector3(0.8, 0.8, 0.8), "side_tint": Vector3(0.95, 0.9, 0.85), "metallic_scale": 0.4, "macro_strength": 0.06}],
	&"crane": [&"crane", &"crane", {"desaturate": 0.55, "top_tint": Vector3(1.5, 0.75, 0.42), "side_tint": Vector3(1.5, 0.75, 0.42), "metallic_scale": 0.5, "macro_strength": 0.04}],
	&"crane_dark": [&"crane", &"crane", {"desaturate": 0.95, "top_tint": Vector3(0.42, 0.45, 0.5), "side_tint": Vector3(0.42, 0.45, 0.5), "metallic_scale": 0.6, "macro_strength": 0.04}],
	&"hull": [&"crane", &"crane", {"desaturate": 0.95, "top_tint": Vector3(0.3, 0.32, 0.36), "side_tint": Vector3(0.26, 0.28, 0.32), "metallic_scale": 0.4, "stain": 0.3}],
	&"hull_white": [&"crane", &"crane", {"desaturate": 0.97, "top_tint": Vector3(1.6, 1.6, 1.58), "side_tint": Vector3(1.6, 1.6, 1.58), "metallic_scale": 0.3}],
	&"frame": [&"crane", &"crane", {"desaturate": 0.9, "top_tint": Vector3(0.35, 0.36, 0.38), "side_tint": Vector3(0.32, 0.33, 0.35), "metallic_scale": 0.6, "macro_strength": 0.02}],
}
## flat colours for the neutral attribution mode and the unlit paints.
const FLAT := {
	&"paint_yellow": Color("e0b02a"), &"paint_white": Color("e6e4dc"), &"paint_dark": Color("1d1e21"),
	&"pavers": Color("b9b5ab"), &"asphalt": Color("6c6d70"), &"land": Color("4a4b4e"), &"concrete": Color("a3a5a6"),
	&"steel_ramp": Color("6f7884"), &"plaster": Color("dedad2"), &"plaster_red": Color("a63a2e"), &"cladding": Color("6d7c8e"),
	&"cladding_warm": Color("8a6f5a"), &"crane": Color("c2652c"), &"crane_dark": Color("3c4048"), &"hull": Color("2e3036"),
	&"hull_white": Color("d8d8d4"), &"frame": Color("3a3b3e"),
}
const NEUTRAL_PAINTS := [Color("3d6b9e"), Color("9b3a2c"), Color("d07a2a"), Color("8a8d90"), Color("4b7d58"), Color("d8d5cc")]
## p / the sun: low in the south-west, about 9 degrees up (the sky's own sun is 2 degrees up;
## the extra height keeps decks readable). the panorama is turned so its sun sits behind it.
const SUN_YAW := -135.0
const SUN_PITCH := -9.0
const SKY_TURN := 0.0

var report := {"version": VERSION}
var scenery_bodies: Array[String] = []
var _cache := {}
var _surfaces := {}
var _paints: Array = []
var _neutral := false
var _beam: Node3D
var _lamp: OmniLight3D
var _lantern: StandardMaterial3D
var _glow := 0.0
var _finished := false
var _rng := RandomNumberGenerator.new()
## the level script's constants (sizes, edges, radii), read once.
var K: Dictionary = {}

## dresses the level once, from its records.
func dress(level: Node3D) -> void:
	var started := Time.get_ticks_usec()
	_neutral = str(level.get("material_mode")) == "neutral"
	K = (level.get_script() as Script).get_script_constant_map()
	_rng.seed = 150
	_environment(level)
	_land(level)
	_draw_prisms(level)
	_scenery(level)
	_commit(level)
	_draw_containers(level)
	_labels(level)
	if not _neutral:
		_props(level)
		# prop supports are authored after the main prism/container batches.
		_commit(level, "PropSupports_", "prop_support_triangles")
	report["neutral"] = _neutral
	report["apply_ms"] = (Time.get_ticks_usec() - started) / 1000.0
	report["scenery_bodies"] = scenery_bodies
	level.set_meta("breakwater_art", report)

## presentation after a finish: the lantern brightens. never touches physics.
func finished(_level: Node3D, on: bool) -> void:
	_finished = on

func tick(_level: Node3D, delta: float) -> void:
	_glow = move_toward(_glow, 1.0 if _finished else 0.0, delta * 1.5)
	if is_instance_valid(_beam):
		_beam.rotate_y(delta * (0.9 + _glow * 1.5))
	if _lantern != null:
		_lantern.emission_energy_multiplier = 4.0 + _glow * 8.0
	if is_instance_valid(_lamp):
		_lamp.light_energy = 2.5 + _glow * 3.0

# --- materials ------------------------------------------------------------------------------

func _surface(top: StringName, side: StringName, params: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	for slot: Array in [["top", top], ["side", side]]:
		var spec: Dictionary = SETS[slot[1]]
		var base := str(spec.base)
		material.set_shader_parameter(slot[0] + "_albedo", load("%s_diff_1k.%s" % [base, spec.ext]))
		material.set_shader_parameter(slot[0] + "_normal", load("%s_nor_gl_1k.%s" % [base, spec.ext]))
		material.set_shader_parameter(slot[0] + "_arm", load("%s_arm_1k.%s" % [base, spec.ext]))
		material.set_shader_parameter(slot[0] + "_tile", Vector2.ONE * float(spec.metres))
	for key: String in params:
		material.set_shader_parameter(key, params[key])
	return material

func material(kind: StringName) -> Material:
	if _cache.has(kind):
		return _cache[kind]
	var made: Material
	if String(kind).begins_with("paint") or _neutral or not LOOKS.has(kind):
		var flat := StandardMaterial3D.new()
		flat.albedo_color = FLAT.get(kind, Color("888888"))
		flat.roughness = 0.7
		made = flat
	else:
		var look: Array = LOOKS[kind]
		made = _surface(look[0], look[1], look[2])
	_cache[kind] = made
	return made

func _paint(colour: int) -> Material:
	var key := StringName("container_%d" % colour)
	if _cache.has(key):
		return _cache[key]
	var made: Material
	if _neutral:
		var flat := StandardMaterial3D.new()
		flat.albedo_color = NEUTRAL_PAINTS[colour]
		flat.roughness = 0.6
		made = flat
	else:
		var paint: Vector3 = PAINTS[colour]
		made = _surface(&"container", &"container", {"desaturate": 0.9, "side_tint": paint, "top_tint": paint * 1.25 + Vector3.ONE * 0.12,
			"metallic_scale": 0.35, "roughness_scale": 0.95, "macro_strength": 0.08, "stain": 0.15, "top_min_up": 0.9})
	_cache[key] = made
	return made

# --- sky, sun and water ---------------------------------------------------------------------

func _environment(level: Node3D) -> void:
	var world := WorldEnvironment.new()
	world.name = "Environment"
	var environment := Environment.new()
	var sky := Sky.new()
	if _neutral:
		var plain := ProceduralSkyMaterial.new()
		plain.sky_top_color = Color("35507a")
		plain.sky_horizon_color = Color("d9a27a")
		sky.sky_material = plain
	else:
		var panorama := PanoramaSkyMaterial.new()
		panorama.panorama = load(KIT + "sky/industrial_sunset_02_puresky_2k.hdr")
		panorama.energy_multiplier = 0.55
		sky.sky_material = panorama
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.sky_rotation = Vector3(0, deg_to_rad(SKY_TURN), 0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_white = 6.0
	environment.tonemap_exposure = 1.0
	environment.fog_enabled = true
	environment.fog_light_color = Color("9a8f98")
	environment.fog_density = 0.0022
	environment.fog_aerial_perspective = 0.6
	environment.fog_sky_affect = 0.15
	world.environment = environment
	level.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation = Vector3(deg_to_rad(SUN_PITCH), deg_to_rad(SUN_YAW), 0.0)
	sun.light_energy = 1.35
	sun.light_color = Color("ffb27a")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	level.add_child(sun)
	# a cool fill from the opposite sky, no shadows: dusk keeps the shaded faces blue, not black.
	var fill := DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(SUN_YAW + 180.0), 0.0)
	fill.light_energy = 0.28
	fill.light_color = Color("8fa6d8")
	level.add_child(fill)
	_water(level)

const WATER := """shader_type spatial;
render_mode cull_disabled;
uniform vec3 deep : source_color = vec3(0.02, 0.045, 0.075);
uniform vec3 shallow : source_color = vec3(0.06, 0.11, 0.17);
uniform vec3 glow : source_color = vec3(1.0, 0.6, 0.35);
uniform vec3 sun_dir = vec3(-0.7, 0.16, -0.7);
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz * 0.22;
	float t = TIME;
	vec2 g = vec2(cos(p.x * 2.1 + t * 0.9) + cos((p.x + p.y) * 3.7 + t * 1.4) * 0.5, cos(p.y * 1.7 - t * 0.7) + cos((p.x - p.y) * 4.3 - t * 1.1) * 0.5);
	vec3 n = normalize(vec3(g.x * 0.06, 1.0, g.y * 0.06));
	vec3 view = normalize((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz - CAMERA_POSITION_WORLD);
	float fresnel = pow(1.0 - max(dot(-view, n), 0.0), 4.0);
	vec3 r = reflect(view, n);
	float glint = pow(max(dot(r, normalize(sun_dir)), 0.0), 220.0) * 6.0;
	float horizon = smoothstep(-0.05, 0.25, r.y);
	vec3 sky = mix(glow * 0.9, vec3(0.22, 0.38, 0.62), horizon);
	ALBEDO = mix(deep, shallow, 0.4 + g.x * 0.05);
	EMISSION = sky * fresnel * 0.3 + glow * glint;
	ROUGHNESS = 0.18;
	SPECULAR = 0.5;
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
}
"""

func _water(level: Node3D) -> void:
	var plane := MeshInstance3D.new()
	plane.name = "Harbour"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(1400, 1400)
	mesh.subdivide_width = 8
	mesh.subdivide_depth = 8
	plane.mesh = mesh
	if _neutral:
		var flat := StandardMaterial3D.new()
		flat.albedo_color = Color("24384a")
		plane.material_override = flat
	else:
		var shader := Shader.new()
		shader.code = WATER
		var water := ShaderMaterial.new()
		water.shader = shader
		var to_sun := Basis.from_euler(Vector3(deg_to_rad(SUN_PITCH), deg_to_rad(SUN_YAW), 0.0)) * Vector3.BACK
		water.set_shader_parameter("sun_dir", to_sun)
		plane.material_override = water
	plane.position = Vector3(-40, float(K.WATER_Y), -150)
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(plane)

# --- prisms ---------------------------------------------------------------------------------

func _draw_prisms(level: Node3D) -> void:
	for prism: Dictionary in level.get("prisms"):
		_prism(prism.top, float(prism.base), prism.kind)

func _land(level: Node3D) -> void:
	# p / the terminal around the route, 6 cm under deck level so a deck drawn over it always
	# wins. every piece is behind a wall a jump cannot clear; none is reachable.
	var y := -0.06
	var half: float = K.HALF
	for r: Array in [[-70.0, -half, 20.0, -77.928], [half, 70.0, 20.0, -97.832], [-half, half, 20.0, 8.4]]:
		_prism(_rect(r[0], r[1], r[2], r[3], y), float(K.BASE), &"land")

func _prism(top: Array, base: float, kind: StringName) -> void:
	# a convex prism: the top polygon, its walls down to base. flat normals, godot's clockwise fronts.
	var st := _st(kind)
	var n := top.size()
	var centre := Vector3.ZERO
	for p: Vector3 in top:
		centre += p / n
	var bottom := centre
	bottom.y = base
	for i: int in range(1, n - 1):
		_tri(st, top[0], top[i], top[i + 1], Vector3.UP, true)
	for i: int in n:
		var a: Vector3 = top[i]
		var b: Vector3 = top[(i + 1) % n]
		var a0 := Vector3(a.x, base, a.z)
		var b0 := Vector3(b.x, base, b.z)
		var out := (b - a).cross(Vector3.UP).normalized()
		var mid := (a + b) * 0.5
		if out.dot(Vector3(mid.x - centre.x, 0, mid.z - centre.z)) < 0.0:
			out = -out
		if (b - a).length_squared() < 1e-8:
			continue
		_quad(st, [a, b, b0, a0], out)

## a triangle facing `normal` (for a top, `up` asks for the polygon's own upward normal).
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

func _quad(st: SurfaceTool, q: Array, normal: Vector3) -> void:
	_tri(st, q[0], q[1], q[2], normal)
	_tri(st, q[0], q[2], q[3], normal)

func _box(kind: StringName, lo: Vector3, hi: Vector3) -> void:
	_prism(_rect(lo.x, hi.x, lo.z, hi.z, hi.y), lo.y, kind)

func _rect(x0: float, x1: float, z0: float, z1: float, y: float) -> Array:
	return [Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1)]

func _st(kind: StringName) -> SurfaceTool:
	if not _surfaces.has(kind):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_surfaces[kind] = st
	return _surfaces[kind]

func _commit(level: Node3D, prefix := "Mesh_", report_key := "prism_triangles") -> void:
	var counts := {}
	for kind: StringName in _surfaces:
		var instance := MeshInstance3D.new()
		instance.name = prefix + String(kind)
		instance.mesh = (_surfaces[kind] as SurfaceTool).commit()
		instance.material_override = material(kind)
		if String(kind).begins_with("paint"):
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		level.add_child(instance)
		counts[String(kind)] = instance.mesh.get_faces().size() / 3
	_surfaces.clear()
	report[report_key] = counts

# --- containers -----------------------------------------------------------------------------

func _draw_containers(level: Node3D) -> void:
	# every container: a roof the size of its footprint, side panels set 3 cm in between a dark
	# frame (corner posts and rails on the footprint's own planes), and locking bars on one end.
	# nothing stands outside the footprint, so the drawn box is exactly its collision.
	var count := 0
	var all: Array = (level.get("containers") as Array).duplicate()
	all.append_array(_yard_containers(level))
	for box: Dictionary in all:
		_container(box, level)
		count += 1
	for colour: int in 6:
		var key := StringName("container_%d" % colour)
		if _surfaces.has(key):
			var instance := MeshInstance3D.new()
			instance.name = "Containers_%d" % colour
			instance.mesh = (_surfaces[key] as SurfaceTool).commit()
			instance.material_override = _paint(colour)
			level.add_child(instance)
	if _surfaces.has(&"frame"):
		var frame := MeshInstance3D.new()
		frame.name = "ContainerFrames"
		frame.mesh = (_surfaces[&"frame"] as SurfaceTool).commit()
		frame.material_override = material(&"frame")
		level.add_child(frame)
	_surfaces.clear()
	report["containers_drawn"] = count
	report["route_containers"] = (level.get("containers") as Array).size()

func _container(box: Dictionary, level: Node3D) -> void:
	var c: Vector3 = box.centre
	var length: float = box.length
	var width: float = box.width
	var h: float = K.CH
	var along: Vector3 = Vector3.RIGHT if box.along_x else Vector3.BACK
	var across := Vector3.BACK if box.along_x else Vector3.RIGHT
	var hl := length * 0.5
	var hw := width * 0.5
	var at := func(u: float, v: float, y: float) -> Vector3: return c + along * u + across * v + Vector3.UP * y
	var paint := _st(StringName("container_%d" % int(box.colour)))
	var frame := _st(&"frame")
	var inset := 0.03
	var post := 0.16
	# roof over the full footprint
	_tri(paint, at.call(-hl, -hw, h), at.call(hl, -hw, h), at.call(hl, hw, h), Vector3.UP, true)
	_tri(paint, at.call(-hl, -hw, h), at.call(hl, hw, h), at.call(-hl, hw, h), Vector3.UP, true)
	# long sides and ends, inset between the posts and rails
	for s: float in [-1.0, 1.0]:
		var v := s * (hw - inset)
		_quad(paint, [at.call(-hl + post, v, 0.16), at.call(hl - post, v, 0.16), at.call(hl - post, v, h - 0.12), at.call(-hl + post, v, h - 0.12)], across * s)
		var u := s * (hl - inset)
		_quad(paint, [at.call(u, -hw + post, 0.16), at.call(u, hw - post, 0.16), at.call(u, hw - post, h - 0.12), at.call(u, -hw + post, h - 0.12)], along * s)
	# corner posts and the top and bottom rails, on the footprint's planes
	for su: float in [-1.0, 1.0]:
		for sv: float in [-1.0, 1.0]:
			var p0: Vector3 = at.call(su * hl, sv * hw, 0.0)
			var p1: Vector3 = at.call(su * (hl - post), sv * (hw - post), h)
			_box_frame(frame, p0.min(p1), p0.max(p1))
	for sv: float in [-1.0, 1.0]:
		for rail: Array in [[0.0, 0.16], [h - 0.12, h]]:
			var p0: Vector3 = at.call(-hl + post, sv * hw, rail[0])
			var p1: Vector3 = at.call(hl - post, sv * (hw - inset), rail[1])
			_box_frame(frame, p0.min(p1), p0.max(p1))
	for su: float in [-1.0, 1.0]:
		for rail: Array in [[0.0, 0.16], [h - 0.12, h]]:
			var p0: Vector3 = at.call(su * hl, -hw + post, rail[0])
			var p1: Vector3 = at.call(su * (hl - inset), hw - post, rail[1])
			_box_frame(frame, p0.min(p1), p0.max(p1))
	# door end: four locking bars inside the inset
	for k: int in 4:
		var v := lerpf(-hw + 0.45, hw - 0.45, k / 3.0)
		var p0: Vector3 = at.call(hl - inset, v - 0.025, 0.2)
		var p1: Vector3 = at.call(hl - 0.002, v + 0.025, h - 0.16)
		_box_frame(frame, p0.min(p1), p0.max(p1))

func _box_frame(st: SurfaceTool, lo: Vector3, hi: Vector3) -> void:
	var top := _rect(lo.x, hi.x, lo.z, hi.z, hi.y)
	for i: int in range(1, 3):
		_tri(st, top[0], top[i], top[i + 1], Vector3.UP, true)
	for i: int in 4:
		var a: Vector3 = top[i]
		var b: Vector3 = top[(i + 1) % 4]
		var out := (b - a).cross(Vector3.UP).normalized()
		var mid := (a + b) * 0.5 - (lo + hi) * 0.5
		if out.dot(Vector3(mid.x, 0, mid.z)) < 0.0:
			out = -out
		_quad(st, [a, b, Vector3(b.x, lo.y, b.z), Vector3(a.x, lo.y, a.z)], out)

func _yard_containers(level: Node3D) -> Array:
	# p / scenery stacks on the terminal behind the yard walls and on the ship: deterministic,
	# 1 to 4 high, all out of reach (behind walls a jump cannot clear, or on the ship's deck).
	var out: Array = []
	var cw: float = K.CW
	var ch: float = K.CH
	var add := func(x: float, z: float, along_x: bool, length: float, base: float, tiers: int) -> void:
		for t: int in tiers:
			out.append({"centre": Vector3(x, base + t * ch, z), "along_x": along_x, "length": length, "width": cw, "tier": t, "colour": _rng.randi_range(0, 5), "top": t == tiers - 1})
	var half: float = K.HALF
	# east block: rows along z, bays across x
	for row: int in 6:
		var x := half + cw + 2.5 + row * (cw * 2.0 + 3.2)
		for bay: int in 6:
			var z := 4.0 - bay * 13.0
			for side: int in 2:
				var tiers := _rng.randi_range(1, 4) if row > 0 else _rng.randi_range(2, 3)
				add.call(x + side * cw + cw * 0.5, z - 6.1, false, K.L40, -0.06, tiers)
	# west block, north of the warehouse
	for row: int in 5:
		var x := -half - cw - 3.0 - row * (cw * 2.0 + 3.2)
		for bay: int in 4:
			var z := 4.0 - bay * 13.0
			for side: int in 2:
				add.call(x - side * cw - cw * 0.5, z - 6.1, false, K.L40, -0.06, _rng.randi_range(1, 4))
	# the bend's reefer core: low stacks inside the curved plinth wall
	var c1: Vector3 = K.BEND1
	add.call(c1.x + 3.2, c1.z - 1.5, true, K.L20, -0.06, 2)
	add.call(c1.x + 1.7, c1.z - 4.2, true, K.L10, -0.06, 3)
	# the ship's deck cargo
	var deck := 5.0
	for bay: int in 6:
		for row: int in 7:
			add.call(-6.0 - bay * 6.3, -103.6 - row * cw, true, K.L20, deck, _rng.randi_range(2, 4))
	return out

# --- buildings, cranes, ship, lighthouse -----------------------------------------------------

func _scenery(level: Node3D) -> void:
	var half: float = K.HALF
	# the gatehouse behind the start and its canopy over the spawn
	_box(&"cladding", Vector3(-half - 6.0, -0.06, 8.4), Vector3(half + 6.0, 9.0, 18.0))
	_box(&"concrete", Vector3(-half - 6.4, 9.0, 8.0), Vector3(half + 6.4, 9.6, 18.4))
	_box(&"frame", Vector3(-half, 5.0, -6.0), Vector3(half, 5.35, 8.4))
	for x: float in [-half + 1.0, -2.0, 2.0, half - 1.0]:
		_box(&"crane_dark", Vector3(x - 0.12, 5.35, -6.0), Vector3(x + 0.12, 5.75, 8.4))
	# the warehouse north of the crane line and the terminal office by the breakwater root
	_box(&"cladding", Vector3(-58.0, -0.06, -74.0), Vector3(-20.0, 12.0, -52.0))
	_box(&"concrete", Vector3(-58.4, 12.0, -74.4), Vector3(-19.6, 12.6, -51.6))
	_box(&"cladding_warm", Vector3(-100.0, -0.06, -96.0), Vector3(-88.0, 8.0, -78.0))
	# a land strip west of the crane line's north wall and round the breakwater root
	_prism(_rect(-100.0, -70.0, -48.0, -100.0, -0.06), float(K.BASE), &"land")
	_cranes(level)
	_ship(level)
	_lighthouse(level)
	_nav_lights(level)
	_skyline(level)

func _cranes(level: Node3D) -> void:
	# two ship-to-shore cranes over the quay: legs behind the north wall and on piles in the
	# harbour, portal beams 18 m up, a boom out over the ship, an a-frame and machinery house.
	var north: float = float(K.QUAY_N) + float(K.CW) + 1.4
	var south: float = float(K.QUAY_S) - 2.2
	for k: int in 2:
		var cx := -26.0 - 22.0 * k
		for lx: float in [cx - 8.0, cx + 8.0]:
			_box(&"crane", Vector3(lx - 0.7, -0.06, north - 0.7), Vector3(lx + 0.7, 20.0, north + 0.7))
			_box(&"crane", Vector3(lx - 0.7, float(K.WATER_Y) - 1.0, south - 0.7), Vector3(lx + 0.7, 20.0, south + 0.7))
			_scenery_body(level, "crane_%d_leg_%d" % [k + 1, int(lx)], Vector3(lx - 0.7, float(K.BASE), south - 0.7), Vector3(lx + 0.7, 20.0, south + 0.7))
			_box(&"crane", Vector3(lx - 0.6, 18.0, south - 0.6), Vector3(lx + 0.6, 20.0, north + 0.6))
			_box(&"crane_dark", Vector3(lx - 0.8, -0.06, north - 1.2), Vector3(lx + 0.8, 1.4, north + 1.2))
		for z: float in [north, south]:
			_box(&"crane", Vector3(cx - 8.6, 17.2, z - 0.5), Vector3(cx + 8.6, 18.0, z + 0.5))
		# boom and back-reach, two girders
		for gx: float in [cx - 1.6, cx + 1.6]:
			_box(&"crane", Vector3(gx - 0.45, 29.0, south - 52.0), Vector3(gx + 0.45, 30.6, north + 18.0))
		_box(&"crane_dark", Vector3(cx - 3.0, 30.6, north + 6.0), Vector3(cx + 3.0, 34.5, north + 16.0))
		# legs up to the boom, a-frame and forestays as slim prisms
		for lx: float in [cx - 8.0, cx + 8.0]:
			_strut(&"crane", Vector3(lx, 20.0, north), Vector3(cx + signf(lx - cx) * 1.6, 29.0, north), 0.5)
			_strut(&"crane", Vector3(lx, 20.0, south), Vector3(cx + signf(lx - cx) * 1.6, 29.0, south), 0.5)
		_strut(&"crane", Vector3(cx, 30.0, north - 2.0), Vector3(cx, 46.0, north - 8.0), 0.6)
		_strut(&"crane", Vector3(cx, 30.0, south + 4.0), Vector3(cx, 46.0, north - 8.0), 0.6)
		_strut(&"crane_dark", Vector3(cx, 46.0, north - 8.0), Vector3(cx, 30.6, south - 50.0), 0.18)
		_strut(&"crane_dark", Vector3(cx, 46.0, north - 8.0), Vector3(cx, 30.6, north + 17.0), 0.18)
		# trolley and spreader over the ship
		_box(&"crane_dark", Vector3(cx - 2.2, 27.6, south - 16.0), Vector3(cx + 2.2, 29.0, south - 12.0))
		_strut(&"crane_dark", Vector3(cx - 1.0, 27.6, south - 14.0), Vector3(cx - 1.0, 19.0, south - 14.0), 0.05)
		_strut(&"crane_dark", Vector3(cx + 1.0, 27.6, south - 14.0), Vector3(cx + 1.0, 19.0, south - 14.0), 0.05)
		_box(&"crane", Vector3(cx - 3.0, 18.4, south - 15.2), Vector3(cx + 3.0, 19.0, south - 12.8))

func _strut(kind: StringName, a: Vector3, b: Vector3, r: float) -> void:
	# a square member from a to b, half-width r, drawn as four quads with flat normals.
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.UP)
	if side.length_squared() < 1e-6:
		side = Vector3.RIGHT
	side = side.normalized() * r
	var up := side.cross(axis).normalized() * r
	var st := _st(kind)
	var corners := [side + up, -side + up, -side - up, side - up]
	for i: int in 4:
		var p: Vector3 = corners[i]
		var q: Vector3 = corners[(i + 1) % 4]
		_quad(st, [a + p, a + q, b + q, b + p], ((p + q) * 0.5).normalized())

func _ship(level: Node3D) -> void:
	# a feeder container ship moored under the cranes: a dark hull with a raked bow, a white
	# bridge house at the stern, deck cargo (in _yard_containers). its hull side is a wall a
	# runner could fall against from the bend, so it has one named collision prism.
	var water: float = K.WATER_Y
	var north := -101.2
	var southz := -122.0
	var hull := [Vector3(2.0, 5.0, north), Vector3(-52.0, 5.0, north), Vector3(-56.0, 5.0, (north + southz) * 0.5), Vector3(-52.0, 5.0, southz), Vector3(2.0, 5.0, southz), Vector3(8.0, 5.0, (north + southz) * 0.5)]
	_prism(hull, water - 4.0, &"hull")
	_scenery_hull(level, hull, water - 4.0)
	_box(&"hull_white", Vector3(-50.0, 5.0, -118.5), Vector3(-41.0, 17.0, -104.5))
	_box(&"hull_white", Vector3(-51.0, 17.0, -121.5), Vector3(-40.0, 18.0, -101.5))
	_box(&"crane_dark", Vector3(-47.0, 18.0, -113.0), Vector3(-45.0, 23.0, -110.0))

func _lighthouse(level: Node3D) -> void:
	# the lighthouse on the roundhead: a 4.5 m plinth (its collision is the level's s4_tower), a
	# tapering white tower with two red bands, a gallery, a glazed lantern lit at dusk and a
	# turning beam.
	var head: Vector3 = K.HEAD
	var plinth_top := head.y + 3.0
	_frustum(&"plaster", head, float(K.WATER_Y) - 1.0, plinth_top, 4.5, 4.5, 16)
	var bands := [[plinth_top, 9.0, &"plaster"], [9.0, 12.0, &"plaster_red"], [12.0, 18.0, &"plaster"], [18.0, 21.0, &"plaster_red"], [21.0, 25.0, &"plaster"]]
	for band: Array in bands:
		var r0 := lerpf(3.6, 2.6, (float(band[0]) - plinth_top) / (25.0 - plinth_top))
		var r1 := lerpf(3.6, 2.6, (float(band[1]) - plinth_top) / (25.0 - plinth_top))
		_frustum(band[2], head, band[0], band[1], r0, r1, 16)
	_frustum(&"crane_dark", head, 25.0, 25.4, 3.6, 3.6, 16)
	_frustum(&"plaster_red", head, 28.2, 29.6, 2.0, 0.4, 12)
	for s: int in 16:
		var a := TAU * s / 16.0
		var p := head + Vector3(cos(a) * 3.4, 0, sin(a) * 3.4)
		_strut(&"crane_dark", Vector3(p.x, 25.4, p.z), Vector3(p.x, 26.4, p.z), 0.04)
	var lantern := MeshInstance3D.new()
	lantern.name = "Lantern"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.7
	cylinder.bottom_radius = 1.7
	cylinder.height = 2.8
	cylinder.radial_segments = 8
	lantern.mesh = cylinder
	_lantern = StandardMaterial3D.new()
	_lantern.albedo_color = Color("ffd9a0")
	_lantern.emission_enabled = true
	_lantern.emission = Color("ffc98a")
	_lantern.emission_energy_multiplier = 4.0
	lantern.material_override = _lantern
	lantern.position = Vector3(head.x, 26.8, head.z)
	lantern.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(lantern)
	_lamp = OmniLight3D.new()
	_lamp.name = "LanternLight"
	_lamp.light_color = Color("ffc78a")
	_lamp.light_energy = 2.5
	_lamp.omni_range = 34.0
	_lamp.position = Vector3(head.x, 26.8, head.z)
	level.add_child(_lamp)
	# the beam: two long additive fans, one each way, turning (presentation only).
	_beam = Node3D.new()
	_beam.name = "Beam"
	_beam.position = Vector3(head.x, 26.8, head.z)
	var beam_material := StandardMaterial3D.new()
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_material.vertex_color_use_as_albedo = true
	beam_material.disable_receive_shadows = true
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for dir: float in [1.0, -1.0]:
		for tilt: float in [0.0, PI * 0.5]:
			var w := Vector3(0, cos(tilt), sin(tilt)) * 0.0
			var spread := Vector3(0, cos(tilt), sin(tilt)) * 7.0
			var tip := Vector3(dir * 90.0, 0, 0)
			st.set_color(Color(1.0, 0.82, 0.55, 0.32))
			st.add_vertex(w)
			st.set_color(Color(1.0, 0.82, 0.55, 0.0))
			st.add_vertex(tip + spread)
			st.add_vertex(tip - spread)
	var beam_mesh := MeshInstance3D.new()
	beam_mesh.mesh = st.commit()
	beam_mesh.material_override = beam_material
	beam_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.add_child(beam_mesh)
	level.add_child(_beam)

func _nav_lights(level: Node3D) -> void:
	# lamp heads on the breach's two light posts (the posts are the level's s4_light_red/green).
	var head: Vector3 = K.HEAD
	for spec: Array in [["Red", Vector3(float(K.MOLE_W) + 0.25, 3.45, float(K.MOLE_END) + 0.25), Color("ff3b2e")], ["Green", Vector3(float(K.MOLE_W) + 0.25, head.y + 3.45, float(K.HEAD_N) - 0.25), Color("39ff7a")]]:
		var lamp := MeshInstance3D.new()
		lamp.name = "NavLamp" + spec[0]
		var ball := SphereMesh.new()
		ball.radius = 0.28
		ball.height = 0.5
		lamp.mesh = ball
		var glow := StandardMaterial3D.new()
		glow.albedo_color = spec[2]
		glow.emission_enabled = true
		glow.emission = spec[2]
		glow.emission_energy_multiplier = 1.6
		lamp.material_override = glow
		lamp.position = spec[1]
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		level.add_child(lamp)
		var light := OmniLight3D.new()
		light.name = "NavLight" + spec[0]
		light.light_color = spec[2]
		light.light_energy = 1.2
		light.omni_range = 9.0
		light.position = spec[1] + Vector3(1.0, 0, 0)
		level.add_child(light)

func _frustum(kind: StringName, centre: Vector3, y0: float, y1: float, r0: float, r1: float, sides: int) -> void:
	var st := _st(kind)
	for s: int in sides:
		var a := TAU * s / sides
		var b := TAU * (s + 1) / sides
		var p0 := Vector3(centre.x + cos(a) * r0, y0, centre.z + sin(a) * r0)
		var p1 := Vector3(centre.x + cos(b) * r0, y0, centre.z + sin(b) * r0)
		var q0 := Vector3(centre.x + cos(a) * r1, y1, centre.z + sin(a) * r1)
		var q1 := Vector3(centre.x + cos(b) * r1, y1, centre.z + sin(b) * r1)
		var out := Vector3(cos((a + b) * 0.5), (r0 - r1) / maxf(0.01, y1 - y0), sin((a + b) * 0.5)).normalized()
		_quad(st, [p0, p1, q1, q0], out)
		_tri(st, Vector3(centre.x, y1, centre.z), q0, q1, Vector3.UP, true)

func _skyline(level: Node3D) -> void:
	# p / the far shore: low warehouses and a few lit blocks to the north and east, beyond reach
	# and beyond the fog's first third. no detail, silhouettes only.
	for i: int in 14:
		var x := -160.0 + i * 26.0 + _rng.randf_range(-6.0, 6.0)
		var z := 70.0 + _rng.randf_range(0.0, 60.0)
		var h := _rng.randf_range(8.0, 34.0)
		_box(&"cladding" if i % 3 else &"concrete", Vector3(x, -0.06, z), Vector3(x + _rng.randf_range(10.0, 22.0), h, z + _rng.randf_range(10.0, 20.0)))
	_prism(_rect(-200.0, 140.0, 20.0, 160.0, -0.06), float(K.BASE), &"land")
	_prism(_rect(70.0, 140.0, 20.0, -97.832, -0.06), float(K.BASE), &"land")

func _scenery_body(level: Node3D, label: String, lo: Vector3, hi: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "scenery_" + label
	body.set_meta("surface", "scenery")
	var shape := CollisionShape3D.new()
	var box := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for x: float in [lo.x, hi.x]:
		for y: float in [lo.y, hi.y]:
			for z: float in [lo.z, hi.z]:
				points.append(Vector3(x, y, z))
	box.points = points
	shape.shape = box
	body.add_child(shape)
	level.add_child(body)
	scenery_bodies.append(body.name)

func _scenery_hull(level: Node3D, top: Array, base: float) -> void:
	var body := StaticBody3D.new()
	body.name = "scenery_ship_hull"
	body.set_meta("surface", "scenery")
	var shape := CollisionShape3D.new()
	var hull := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for p: Vector3 in top:
		points.append(p)
		points.append(Vector3(p.x, base, p.z))
	hull.points = points
	shape.shape = hull
	body.add_child(shape)
	level.add_child(body)
	scenery_bodies.append(body.name)

# --- labels and props -----------------------------------------------------------------------

func _labels(level: Node3D) -> void:
	var marks := Node3D.new()
	marks.name = "Markings"
	level.add_child(marks)
	for mark: Dictionary in level.get("markings"):
		if mark.kind != "floor" and mark.kind != "wall":
			continue
		var label := Label3D.new()
		label.name = mark.name
		label.text = mark.text
		label.font_size = 64
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if mark.kind == "floor":
			label.pixel_size = 0.008
			label.modulate = Color("f0d27a")
			label.outline_size = 0
			label.transform = Transform3D(Basis(Vector3.UP, float(mark.yaw)) * Basis(Vector3.RIGHT, -PI * 0.5), (mark.at as Vector3) + Vector3.UP * 0.01)
		else:
			label.pixel_size = 0.01
			label.modulate = Color("f2e6c4")
			label.outline_size = 8
			label.outline_modulate = Color(0.1, 0.1, 0.1, 0.8)
			label.transform = Transform3D(Basis(Vector3.UP, float(mark.yaw)), mark.at)
		marks.add_child(label)
	var sign := Label3D.new()
	sign.name = "TerminalSign"
	sign.text = "BREAKWATER TERMINAL"
	sign.font_size = 96
	sign.pixel_size = 0.03
	sign.modulate = Color("f4ead2")
	sign.outline_size = 10
	sign.outline_modulate = Color(0.05, 0.06, 0.08, 0.9)
	sign.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0, 7.2, 8.35))
	marks.add_child(sign)

func _prop(level: Node3D, id: String, at: Vector3, yaw: float, scale: float = 1.0) -> Node3D:
	var scene: PackedScene = load(KIT + "models/%s/%s_1k.gltf" % [id, id])
	var node: Node3D = scene.instantiate()
	node.name = "Prop_%s_%d" % [id, level.get_child_count()]
	node.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale), at)
	level.add_child(node)
	var placed: Dictionary = report.get("props", {})
	placed[id] = int(placed.get(id, 0)) + 1
	report["props"] = placed
	return node

func _props(level: Node3D) -> void:
	var half: float = K.HALF
	var water: float = K.WATER_Y
	# rollershutter doors in the gatehouse face behind the spawn, inside its collision face.
	for x: float in [-6.6, -4.2, 4.2, 6.6]:
		var door := _prop(level, "rollershutter_door", Vector3(x, 0.0, 8.28), PI)
		var graffiti := door.find_child("rollershutter_door_graffiti", true, false)
		if graffiti is Node3D:
			(graffiti as Node3D).visible = false
	# lifebuoys and lamps high on the gatehouse, out of reach.
	for x: float in [-1.2, 1.2]:
		_prop(level, "lifebuoy", Vector3(x, 4.1, 8.32), PI)
	for x: float in [-half - 1.2, half + 1.2]:
		_prop(level, "street_lamp_02", Vector3(x, 3.6, 8.38), PI)
	# lamps on poles along the crown wall, heads over its top.
	var mole_w: float = K.MOLE_W
	var start: float = K.MOLE_START
	for k: int in 5:
		var z := start - 12.0 - 28.0 * k
		var pole := Vector3(mole_w - 0.3, float(K.CROWN), z)
		_box(&"crane_dark", pole + Vector3(-0.13, 0, -0.13), pole + Vector3(0.13, 4.4, 0.13))
		_prop(level, "street_lamp_02", pole + Vector3(0.0, 4.4, 0.0), PI * 0.5)
		if k % 2 == 1:
			_prop(level, "lifebuoy", pole + Vector3(0.12, 2.6, 0.0), PI * 0.5)
		if k % 2 == 0:
			var light := OmniLight3D.new()
			light.name = "CrownLamp_%d" % k
			light.light_color = Color("ffbf7a")
			light.light_energy = 1.6
			light.omni_range = 14.0
			light.position = pole + Vector3(0.9, 4.3, 0.0)
			level.add_child(light)
	# fenders on the quay and breakwater faces, below the deck edge.
	var quay_s: float = K.QUAY_S
	for k: int in 7:
		_prop(level, "old_tyre", Vector3(float(K.QUAY_START) - 3.0 - 6.0 * k, -0.7, quay_s - 0.09), 0.0)
	var mole_e: float = K.MOLE_E
	for k: int in 10:
		_prop(level, "old_tyre", Vector3(mole_e + 0.09, -0.7, start - 8.0 - 12.0 * k), PI * 0.5)
	# the harbour: sea markers at the mouth, buoys inside, all well clear of the route.
	var head: Vector3 = K.HEAD
	_prop(level, "lateral_sea_marker", Vector3(head.x + 34.0, water - 0.2, head.z - 6.0), 0.3)
	_prop(level, "lateral_sea_marker", Vector3(head.x - 30.0, water - 0.2, head.z + 30.0), 1.4)
	for p: Vector3 in [Vector3(-40.0, water, -160.0), Vector3(-30.0, water, -205.0), Vector3(-48.0, water, -238.0)]:
		_prop(level, "ocean_buoy", p + Vector3.UP * 0.6, _rng.randf() * TAU)
	# barrels and road barriers on the terminal, behind the walls.
	for k: int in 6:
		_prop(level, "Barrel_01", Vector3(half + 3.6 + (k % 3) * 0.62, -0.06, -2.0 - floorf(k / 3.0) * 0.62), _rng.randf() * TAU)
	for k: int in 4:
		_prop(level, "concrete_road_barrier", Vector3(-66.0 + 1.6 * k, -0.06, -76.0), 0.0)
	# canopy lights over the start.
	for x: float in [-4.0, 4.0]:
		var light := OmniLight3D.new()
		light.name = "CanopyLight"
		light.light_color = Color("ffd2a0")
		light.light_energy = 1.4
		light.omni_range = 12.0
		light.position = Vector3(x, 4.7, 2.0)
		level.add_child(light)
