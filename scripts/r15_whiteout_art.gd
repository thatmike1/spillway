extends RefCounted
## p / r15 Whiteout Relay art: everything the course draws, from the level's own records. the
## level calls dress() once at the end of build(). nothing here adds or moves a collision body on
## the route, changes progress data or enters the geometry hash. the only bodies added are the
## rock pads under the far scenery dishes, named `scenery_*` and listed in scenery_bodies.
##
## the look: a radar station on a snowy ridge above a cloud sea, late-afternoon sun low in the
## west-south-west behind the outbound run. route decks are dark slate tread plate with yellow
## lips, so every landing reads against the snow; snow is warm-grey rather than white, under a
## filmic curve, so running views do not glare. warm interiors: the hangar, the ridge and saddle
## shelters, the cable works shed and the relay house porch. sourced models (Kenney Space Kit dishes,
## hangars and machines; Kenney Nature Kit pines and rocks, re-surfaced with snow) set the place
## through r15_assets.gd. provenance: assets/r15/whiteout/MANIFEST.json and the shared library's.

const SHADER: Shader = preload("res://shaders/momentum_surface.gdshader")
const ASSETS := preload("res://scripts/r15_assets.gd")
const KIT := "res://assets/r15/whiteout/"
const LIB := "res://assets/r15/library/"
const VERSION := "whiteout-art-1"

## texture sets: [diffuse, normal, arm] paths and metres per repeat.
const SETS := {
	&"tread": {"files": [KIT + "textures/metal_plate/metal_plate_diff_1k.jpg", KIT + "textures/metal_plate/metal_plate_nor_gl_1k.jpg", KIT + "textures/metal_plate/metal_plate_arm_1k.jpg"], "metres": 1.0},
	&"corrugated": {"files": [KIT + "textures/corrugated_iron_02/corrugated_iron_02_diff_1k.jpg", KIT + "textures/corrugated_iron_02/corrugated_iron_02_nor_gl_1k.jpg", KIT + "textures/corrugated_iron_02/corrugated_iron_02_arm_1k.jpg"], "metres": 2.7},
	&"snow": {"files": [LIB + "polyhaven-snow-02/snow_02_diff_1k.jpg", LIB + "polyhaven-snow-02/snow_02_nor_gl_1k.png", LIB + "polyhaven-snow-02/snow_02_arm_1k.png"], "metres": 2.5},
	&"formwork": {"files": ["res://assets/momentum/textures/concrete_layers_02/concrete_layers_02_diff_1k.png", "res://assets/momentum/textures/concrete_layers_02/concrete_layers_02_nor_gl_1k.png", "res://assets/momentum/textures/concrete_layers_02/concrete_layers_02_arm_1k.png"], "metres": 2.0},
	&"plate": {"files": ["res://assets/momentum/textures/metal_plate_02/metal_plate_02_diff_1k.png", "res://assets/momentum/textures/metal_plate_02/metal_plate_02_nor_gl_1k.png", "res://assets/momentum/textures/metal_plate_02/metal_plate_02_arm_1k.png"], "metres": 2.0},
}
## p / the looks of every prism kind: [top set, side set, shader parameters]. the tread is pushed
## dark and cool so decks read as the track; snow stays below about 0.85 albedo.
const SNOW_TOP := Vector3(0.80, 0.83, 0.88)
const SNOW_SIDE := Vector3(0.70, 0.74, 0.81)
const LOOKS := {
	&"tread": [&"tread", &"plate", {"desaturate": 0.85, "top_tint": Vector3(0.40, 0.43, 0.48), "side_tint": Vector3(0.30, 0.32, 0.36), "metallic_scale": 0.45, "roughness_scale": 0.95, "macro_strength": 0.05, "top_min_up": 0.9}],
	&"tread_warm": [&"tread", &"plate", {"desaturate": 0.7, "top_tint": Vector3(0.52, 0.46, 0.40), "side_tint": Vector3(0.36, 0.33, 0.30), "metallic_scale": 0.45, "roughness_scale": 0.95, "macro_strength": 0.05, "top_min_up": 0.9}],
	&"grate": [&"tread", &"plate", {"desaturate": 0.9, "top_tint": Vector3(0.24, 0.25, 0.28), "side_tint": Vector3(0.22, 0.23, 0.26), "metallic_scale": 0.5, "macro_strength": 0.04}],
	&"hurdle": [&"plate", &"plate", {"desaturate": 0.9, "top_tint": Vector3(0.3, 0.3, 0.32), "side_tint": Vector3(0.3, 0.3, 0.32), "paint_color": Vector3(0.88, 0.62, 0.12), "paint_amount": 0.85, "paint_roughness": 0.55}],
	&"snow": [&"snow", &"snow", {"desaturate": 0.3, "top_tint": SNOW_TOP, "side_tint": SNOW_SIDE, "roughness_scale": 1.1, "macro_strength": 0.08, "normal_strength": 0.8}],
	&"snow_bank": [&"snow", &"snow", {"desaturate": 0.3, "top_tint": SNOW_TOP, "side_tint": SNOW_SIDE * 0.95, "roughness_scale": 1.1, "macro_strength": 0.1, "normal_strength": 0.8, "top_min_up": 0.5}],
	&"rock": [&"snow", &"formwork", {"desaturate": 0.7, "top_tint": SNOW_TOP, "side_tint": Vector3(0.34, 0.33, 0.33), "macro_strength": 0.18, "stain": 0.3, "stain_color": Vector3(0.3, 0.3, 0.32), "top_min_up": 0.75}],
	&"plateau": [&"snow", &"formwork", {"desaturate": 0.7, "top_tint": SNOW_TOP * 0.97, "side_tint": Vector3(0.30, 0.30, 0.31), "macro_strength": 0.2, "stain": 0.35, "stain_color": Vector3(0.3, 0.3, 0.32), "top_min_up": 0.75}],
	&"concrete": [&"formwork", &"formwork", {"desaturate": 0.85, "top_tint": Vector3(0.72, 0.72, 0.72), "side_tint": Vector3(0.62, 0.62, 0.63), "side_joint_spacing": 4.0, "macro_strength": 0.08, "stain": 0.25}],
	&"cladding_red": [&"snow", &"corrugated", {"desaturate": 0.75, "top_tint": SNOW_TOP, "side_tint": Vector3(1.05, 0.34, 0.24), "metallic_scale": 0.3, "macro_strength": 0.06, "top_min_up": 0.8}],
	&"cladding_orange": [&"snow", &"corrugated", {"desaturate": 0.75, "top_tint": SNOW_TOP, "side_tint": Vector3(1.35, 0.66, 0.24), "metallic_scale": 0.3, "macro_strength": 0.06, "top_min_up": 0.8}],
	&"cladding_slate": [&"snow", &"corrugated", {"desaturate": 0.85, "top_tint": SNOW_TOP, "side_tint": Vector3(0.48, 0.54, 0.62), "metallic_scale": 0.35, "macro_strength": 0.06, "top_min_up": 0.8}],
	&"roof": [&"snow", &"corrugated", {"desaturate": 0.85, "top_tint": SNOW_TOP, "side_tint": Vector3(0.36, 0.37, 0.40), "metallic_scale": 0.35, "top_min_up": 0.8}],
	&"rail": [&"plate", &"plate", {"desaturate": 0.9, "top_tint": Vector3(0.5, 0.5, 0.5), "side_tint": Vector3(0.5, 0.5, 0.5), "paint_color": Vector3(0.86, 0.66, 0.16), "paint_amount": 0.9, "paint_roughness": 0.5}],
	&"frame": [&"plate", &"plate", {"desaturate": 0.9, "top_tint": Vector3(0.3, 0.31, 0.34), "side_tint": Vector3(0.28, 0.29, 0.32), "metallic_scale": 0.6, "macro_strength": 0.02}],
	&"machine": [&"plate", &"plate", {"desaturate": 0.85, "top_tint": Vector3(0.55, 0.57, 0.6), "side_tint": Vector3(0.5, 0.52, 0.56), "metallic_scale": 0.5}],
	&"drum": [&"plate", &"plate", {"desaturate": 0.9, "top_tint": Vector3(0.2, 0.22, 0.24), "side_tint": Vector3(0.16, 0.18, 0.2), "metallic_scale": 0.2, "roughness_scale": 1.0}],
	&"drum_flange": [&"plate", &"plate", {"desaturate": 0.9, "top_tint": Vector3(0.5, 0.5, 0.5), "side_tint": Vector3(0.5, 0.5, 0.5), "paint_color": Vector3(0.8, 0.32, 0.12), "paint_amount": 0.9}],
}
## flat colours for the neutral attribution mode and the paints.
const FLAT := {
	&"paint_yellow": Color("d8a92a"), &"paint_warm": Color("e07a2c"), &"paint_white": Color("d8dadc"), &"paint_dark": Color("1c1d20"),
	&"tread": Color("4a4e55"), &"tread_warm": Color("5a5048"), &"grate": Color("303236"), &"hurdle": Color("c08a20"), &"snow": Color("c6ccd6"),
	&"snow_bank": Color("bfc6d1"), &"rock": Color("5a5856"), &"plateau": Color("b9c0ca"), &"concrete": Color("8e8f90"), &"cladding_red": Color("8e3a2c"),
	&"cladding_orange": Color("c4772c"), &"cladding_slate": Color("5c6878"), &"roof": Color("4b4d52"), &"rail": Color("c99a2a"), &"frame": Color("3a3b3f"),
	&"machine": Color("7d8189"), &"drum": Color("2c3034"), &"drum_flange": Color("a8461e"),
}
## p / the scene sun follows the sky panorama's own sun: 19 degrees up, light travelling toward
## +x/-z (the sun is behind the left shoulder on the outbound run, ahead-left on the way home).
const SUN_YAW := -36.2
const SUN_PITCH := -19.3
const SKY_TURN := 0.0
## where meshes split, so a hangar light never shares a mesh with the shed's lights (the
## compatibility renderer caps lights per object).
const REGIONS := ["hangar", "road", "ridge", "saddle", "ring", "shed", "land"]

var report := {"version": VERSION}
var scenery_bodies: Array[String] = []
var _cache := {}
var _surfaces := {}
var _neutral := false
var _rng := RandomNumberGenerator.new()
var _snow: CPUParticles3D
var _beacons: Array[StandardMaterial3D] = []
var _porch: OmniLight3D
var _time := 0.0
var _finished := false
var _glow := 0.0
## the level script's constants, read once.
var K: Dictionary = {}

func dress(level: Node3D) -> void:
	var started := Time.get_ticks_usec()
	_neutral = str(level.get("material_mode")) == "neutral"
	K = (level.get_script() as Script).get_script_constant_map()
	_rng.seed = 1507
	_environment(level)
	_plateaus(level)
	for prism: Dictionary in level.get("prisms"):
		_prism(prism.top, float(prism.base), prism.kind)
	_drums(level)
	_mast(level)
	_mountains(level)
	_commit(level)
	_lights(level)
	_labels(level)
	_cloud(level)
	_snowfall(level)
	if not _neutral:
		_props(level)
	report["neutral"] = _neutral
	report["apply_ms"] = (Time.get_ticks_usec() - started) / 1000.0
	report["scenery_bodies"] = scenery_bodies
	level.set_meta("whiteout_art", report)

## presentation after a finish: the porch light warms up and the mast beacons speed. never physics.
func finished(_level: Node3D, on: bool) -> void:
	_finished = on

func tick(level: Node3D, delta: float) -> void:
	_time += delta
	_glow = move_toward(_glow, 1.0 if _finished else 0.0, delta * 1.5)
	var blink := 0.5 + 0.5 * sin(_time * (2.2 + _glow * 4.0))
	for beacon: StandardMaterial3D in _beacons:
		beacon.emission_energy_multiplier = 1.0 + blink * 5.0
	if is_instance_valid(_porch):
		_porch.light_energy = 2.0 + _glow * 2.5
	# the snowfall box rides with whichever camera renders the level.
	if is_instance_valid(_snow) and level.is_inside_tree():
		var camera := level.get_viewport().get_camera_3d()
		if camera != null:
			_snow.global_position = camera.global_position + Vector3.UP * 6.0

# --- materials ------------------------------------------------------------------------------

func _surface(top: StringName, side: StringName, params: Dictionary) -> ShaderMaterial:
	var made := ShaderMaterial.new()
	made.shader = SHADER
	for slot: Array in [["top", top], ["side", side]]:
		var spec: Dictionary = SETS[slot[1]]
		var files: Array = spec.files
		made.set_shader_parameter(slot[0] + "_albedo", load(files[0]))
		made.set_shader_parameter(slot[0] + "_normal", load(files[1]))
		made.set_shader_parameter(slot[0] + "_arm", load(files[2]))
		made.set_shader_parameter(slot[0] + "_tile", Vector2.ONE * float(spec.metres))
	for key: String in params:
		made.set_shader_parameter(key, params[key])
	return made

func material(kind: StringName) -> Material:
	if _cache.has(kind):
		return _cache[kind]
	var made: Material
	if String(kind).begins_with("paint") or _neutral or not LOOKS.has(kind):
		var flat := StandardMaterial3D.new()
		flat.albedo_color = FLAT.get(kind, Color("888888"))
		flat.roughness = 0.75
		if kind == &"paint_warm":
			flat.emission_enabled = true
			flat.emission = Color("e07a2c")
			flat.emission_energy_multiplier = 0.35
		made = flat
	else:
		var look: Array = LOOKS[kind]
		made = _surface(look[0], look[1], look[2])
	_cache[kind] = made
	return made

# --- sky, sun, cloud and snowfall -----------------------------------------------------------

func _environment(level: Node3D) -> void:
	var world := WorldEnvironment.new()
	world.name = "Environment"
	var environment := Environment.new()
	var sky := Sky.new()
	if _neutral:
		var plain := ProceduralSkyMaterial.new()
		plain.sky_top_color = Color("3b6aa8")
		plain.sky_horizon_color = Color("c9d4e2")
		sky.sky_material = plain
	else:
		var panorama := PanoramaSkyMaterial.new()
		panorama.panorama = load(KIT + "sky/qwantani_late_afternoon_puresky_2k.hdr")
		panorama.energy_multiplier = 1.0
		sky.sky_material = panorama
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.sky_rotation = Vector3(0, deg_to_rad(SKY_TURN), 0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_white = 5.0
	environment.tonemap_exposure = 0.92
	environment.fog_enabled = true
	environment.fog_light_color = Color("aebbd0")
	environment.fog_density = 0.0016
	environment.fog_aerial_perspective = 0.5
	environment.fog_sky_affect = 0.1
	world.environment = environment
	level.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation = Vector3(deg_to_rad(SUN_PITCH), deg_to_rad(SUN_YAW), 0.0)
	sun.light_energy = 1.15
	sun.light_color = Color("ffd2a6")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	level.add_child(sun)
	# a cool sky fill from the opposite side: shaded snow stays blue-grey, not black.
	var fill := DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(SUN_YAW + 180.0), 0.0)
	fill.light_energy = 0.3
	fill.light_color = Color("9db6e0")
	level.add_child(fill)

const CLOUD := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform vec3 lit : source_color = vec3(0.86, 0.84, 0.82);
uniform vec3 shade : source_color = vec3(0.50, 0.57, 0.68);
uniform vec3 warm : source_color = vec3(1.0, 0.78, 0.6);
uniform vec2 sun_xz = vec2(-0.59, 0.81);
varying vec3 wpos;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
float fbm(vec2 p) { float a = 0.5; float s = 0.0; for (int k = 0; k < 5; k++) { s += a * n(p); p = p * 2.03 + 7.1; a *= 0.5; } return s; }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz * 0.018 + vec2(TIME * 0.006, TIME * 0.003);
	float c = fbm(p);
	float d = fbm(p + normalize(sun_xz) * 0.08);
	float light = clamp(0.55 + (c - d) * 6.0, 0.0, 1.0);
	vec3 col = mix(shade, lit, light * 0.8 + c * 0.25);
	float far = clamp(length(wpos.xz - CAMERA_POSITION_WORLD.xz) / 900.0, 0.0, 1.0);
	col = mix(col, warm * 0.85, far * 0.35);
	ALBEDO = col * 0.95;
}
"""

func _cloud(level: Node3D) -> void:
	var plane := MeshInstance3D.new()
	plane.name = "CloudSea"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(2600, 2600)
	plane.mesh = mesh
	if _neutral:
		var flat := StandardMaterial3D.new()
		flat.albedo_color = Color("aab4c4")
		plane.material_override = flat
	else:
		var shader := Shader.new()
		shader.code = CLOUD
		var cloud := ShaderMaterial.new()
		cloud.shader = shader
		plane.material_override = cloud
	plane.position = Vector3(20, float(K.CLOUD_Y), -120)
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(plane)

func _snowfall(level: Node3D) -> void:
	# light snow drifting past the camera: visual only, never a surface or a force.
	if _neutral:
		return
	var snow := CPUParticles3D.new()
	snow.name = "Snowfall"
	snow.amount = 700
	snow.lifetime = 6.0
	snow.preprocess = 6.0
	snow.local_coords = false
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(28, 6, 28)
	snow.direction = Vector3(0.3, -1, 0.15)
	snow.spread = 12.0
	snow.gravity = Vector3(0.4, -0.6, 0.2)
	snow.initial_velocity_min = 1.0
	snow.initial_velocity_max = 2.2
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	var flake := StandardMaterial3D.new()
	flake.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flake.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flake.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flake.albedo_color = Color(0.92, 0.94, 0.98, 0.7)
	quad.material = flake
	snow.mesh = quad
	snow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(snow)
	_snow = snow

# --- prisms ---------------------------------------------------------------------------------

func _region(centre: Vector3) -> String:
	if centre.x < -40.0 or centre.x > 70.0 or centre.z > 40.0 or centre.y < -20.0:
		return "land"
	if centre.x > 33.0 and centre.z > -184.0:
		return "shed"
	if centre.z > -44.0:
		return "hangar"
	if centre.z > -113.0:
		return "road"
	if centre.z > -162.0 and centre.x < 20.0:
		return "ridge"
	if centre.x < 6.0 and centre.z > -205.0 and centre.x > -25.0 and Vector2(centre.x - 22.0, centre.z + 183.5).length() > 29.0:
		return "saddle"
	return "ring"

func _prism(top: Array, base: float, kind: StringName) -> void:
	# a convex prism: the top polygon, its walls down to base, and a bottom face for anything
	# raised (roofs, lintels, slabs seen from under). flat normals.
	var n := top.size()
	var centre := Vector3.ZERO
	for p: Vector3 in top:
		centre += p / n
	var st := _st(kind, _region(centre))
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
		_quad(st, [a, b, b0, a0], out)
	if base > -2.5:
		for i: int in range(1, n - 1):
			var p0: Vector3 = top[0]
			var p1: Vector3 = top[i]
			var p2: Vector3 = top[i + 1]
			_tri(st, Vector3(p0.x, base, p0.z), Vector3(p1.x, base, p1.z), Vector3(p2.x, base, p2.z), Vector3.DOWN)

## a triangle facing `normal` (for a top, `up` asks for the polygon's own upward normal).
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, up: bool = false) -> void:
	var nn := (b - a).cross(c - a)
	if nn.length_squared() < 1e-12:
		return
	var face := nn.normalized()
	if up and face.y < 0.0:
		face = -face
	elif not up:
		face = normal
	if nn.dot(face) > 0.0:
		var swap := b
		b = c
		c = swap
	for v: Vector3 in [a, b, c]:
		st.set_normal(face)
		st.add_vertex(v)

func _quad(st: SurfaceTool, q: Array, normal: Vector3) -> void:
	_tri(st, q[0], q[1], q[2], normal)
	_tri(st, q[0], q[2], q[3], normal)

func _rect(x0: float, x1: float, z0: float, z1: float, y: float) -> Array:
	return [Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1)]

func _box(kind: StringName, lo: Vector3, hi: Vector3) -> void:
	_prism(_rect(lo.x, hi.x, lo.z, hi.z, hi.y), lo.y, kind)

func _st(kind: StringName, region: String) -> SurfaceTool:
	var key := "%s|%s" % [kind, region]
	if not _surfaces.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_surfaces[key] = st
	return _surfaces[key]

func _commit(level: Node3D) -> void:
	var counts := {}
	for key: String in _surfaces:
		var parts := key.split("|")
		var kind := StringName(parts[0])
		var instance := MeshInstance3D.new()
		instance.name = "Mesh_%s_%s" % [parts[0], parts[1]]
		instance.mesh = (_surfaces[key] as SurfaceTool).commit()
		instance.material_override = material(kind)
		if String(kind).begins_with("paint"):
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		level.add_child(instance)
		counts[key] = instance.mesh.get_faces().size() / 3
	_surfaces.clear()
	report["prism_triangles"] = counts

func _strut(kind: StringName, a: Vector3, b: Vector3, r: float) -> void:
	# a square beam between two points: visual only, out of reach.
	var along := (b - a).normalized()
	var side := along.cross(Vector3.UP if absf(along.y) < 0.95 else Vector3.RIGHT).normalized() * r
	var up := side.cross(along).normalized() * r
	var st := _st(kind, _region((a + b) * 0.5))
	var ring := [side + up, -side + up, -side - up, side - up]
	for i: int in 4:
		var p: Vector3 = ring[i]
		var q: Vector3 = ring[(i + 1) % 4]
		_quad(st, [a + p, a + q, b + q, b + p], ((p + q) * 0.5).normalized())

# --- the ground the station stands on -------------------------------------------------------

func _plateaus(level: Node3D) -> void:
	# p / snow plateaus round the hangar, the road and the relay works, with rock cliffs dropping
	# into the cloud. every piece lies behind a bank or wall a jump cannot top, or under a deck;
	# none is reachable and none has collision.
	var hh: float = K.HANGAR_HALF + float(K.WALL)
	var cliff := -60.0
	for r: Array in [
		[-90.0, -hh, 90.0, -13.0, 1.0], [-90.0, -17.0, -13.0, -44.0, 1.0], [-90.0, -8.0, -44.0, -108.0, 1.0],
		[hh, 34.0, 90.0, -13.0, 1.0], [17.0, 32.0, -13.0, -44.0, 1.0], [8.0, 27.0, -44.0, -108.0, 1.0],
		[-hh, hh, 90.0, float(K.HANGAR_BACK) + float(K.WALL), 1.0],
		[-34.0, -14.5, -108.0, -161.5, -9.0], [14.5, 30.0, -108.0, -161.5, -9.0],
		# two mesas well off the ridge (over 20 m from any reachable top) carry the ridge dishes.
		[-48.0, -36.0, -128.0, -142.0, 1.5], [36.0, 48.0, -138.0, -152.0, 1.5],
		[33.0, 37.4, -128.0, -176.0, 2.0], [29.0, 35.0, -30.0, -128.0, 2.0], [52.6, 110.0, -30.0, -184.0, 2.0], [29.0, 110.0, 20.0, -30.0, 2.0],
	]:
		_prism(_rect(r[0], r[1], r[2], r[3], r[4]), cliff, &"plateau")
	# the saddle's rock shoulder below its deck, and the basin walls' footings.
	var sh: float = K.SADDLE_HALF
	_prism(_rect(-sh - 1.5, sh + 1.5, float(K.SADDLE_NEAR) - 2.5, float(K.SADDLE_END) + 0.3, float(K.KILL_Y) - 1.0), cliff, &"plateau")
	_prism(_rect(-float(K.BASIN_HALF) - 2.5, float(K.BASIN_HALF) + 2.5, float(K.ROAD_END), float(K.SADDLE_NEAR), float(K.BASE) - 2.01), cliff, &"plateau")
	# the dish pit's floor, deep in the cloud.
	var c: Vector3 = K.RECEIVER
	var ring: Array = []
	for s: int in 24:
		var a := TAU * s / 24.0
		ring.append(Vector3(c.x + cos(a) * 15.5, -16.0, c.z + sin(a) * 15.5))
	_prism(ring, cliff, &"concrete")

func _mountains(level: Node3D) -> void:
	# p / a ring of distant snow peaks, original geometry: noisy pyramids far beyond the course.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# flat facets: every triangle keeps its own normal.
	st.set_smooth_group(-1)
	var peaks := 44
	for i: int in peaks:
		var bearing := TAU * (i + _rng.randf() * 0.6) / peaks
		var radius := _rng.randf_range(520.0, 980.0)
		var centre := Vector3(20.0 + sin(bearing) * radius, -40.0, -120.0 + cos(bearing) * radius)
		var height := _rng.randf_range(110.0, 260.0) * (0.7 + 0.3 * absf(cos(bearing * 1.7)))
		var width := height * _rng.randf_range(1.3, 2.1)
		_peak(st, centre, height, width)
	# the landmark: a broad peak to the north-west carrying the big far dish.
	_peak(st, Vector3(-120.0, -40.0, -380.0), 88.0, 150.0)
	st.generate_normals()
	var mountains := MeshInstance3D.new()
	mountains.name = "Mountains"
	mountains.mesh = st.commit()
	var shader := Shader.new()
	shader.code = MOUNTAIN
	var made := ShaderMaterial.new()
	made.shader = shader
	mountains.material_override = made if not _neutral else material(&"plateau")
	mountains.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(mountains)

func _peak(st: SurfaceTool, centre: Vector3, height: float, width: float) -> void:
	# a faceted peak: a jittered apex over a ring of 9 shoulders and a 12-point foot.
	var apex := centre + Vector3(_rng.randf_range(-0.1, 0.1) * width, height, _rng.randf_range(-0.1, 0.1) * width)
	var shoulders: Array = []
	var feet: Array = []
	for k: int in 9:
		var a := TAU * k / 9.0 + _rng.randf() * 0.3
		var r := width * _rng.randf_range(0.22, 0.38)
		shoulders.append(centre + Vector3(cos(a) * r, height * _rng.randf_range(0.45, 0.7), sin(a) * r))
	for k: int in 9:
		var a := TAU * (k + 0.5) / 9.0
		var r := width * _rng.randf_range(0.5, 0.65)
		feet.append(centre + Vector3(cos(a) * r, 0.0, sin(a) * r))
	for k: int in 9:
		var s0: Vector3 = shoulders[k]
		var s1: Vector3 = shoulders[(k + 1) % 9]
		var f0: Vector3 = feet[k]
		for tri: Array in [[apex, s1, s0], [s0, s1, f0], [s1, feet[(k + 1) % 9], f0]]:
			for v: Vector3 in tri:
				st.add_vertex(v)
	# the foot to the previous shoulder.
	for k: int in 9:
		var s0: Vector3 = shoulders[k]
		var f_prev: Vector3 = feet[(k + 8) % 9]
		var f0: Vector3 = feet[k]
		for v: Vector3 in [s0, f0, f_prev]:
			st.add_vertex(v)

const MOUNTAIN := """shader_type spatial;
render_mode cull_disabled;
uniform vec3 snow : source_color = vec3(0.70, 0.74, 0.81);
uniform vec3 rock : source_color = vec3(0.24, 0.24, 0.27);
varying vec3 wpos;
varying vec3 wn;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
void fragment() {
	float streak = n(wpos.xz * 0.01) * 0.25 + n(vec2(wpos.x + wpos.z, wpos.y * 4.0) * 0.02) * 0.15;
	float cover = smoothstep(0.5, 0.62, abs(wn.y) + streak - 0.2);
	ALBEDO = mix(rock, snow, cover);
	ROUGHNESS = 0.95;
}
"""

# --- drums, mast, shelters ------------------------------------------------------------------

func _drums(level: Node3D) -> void:
	# each drum: flanges the size of its collision at foot and head, a winding 6 cm inside.
	for drum: Dictionary in level.get("drums"):
		var c: Vector3 = drum.centre
		var r: float = drum.radius
		var h: float = drum.height
		_prism(_circle(c, r, c.y + 0.16), c.y - 0.02, &"drum_flange")
		_prism(_circle(c, r - 0.06, c.y + h - 0.16), c.y + 0.16, &"drum")
		_prism(_circle(c, r, c.y + h), c.y + h - 0.16, &"drum_flange")

func _circle(c: Vector3, r: float, y: float) -> Array:
	var top: Array = []
	for s: int in 16:
		var a := TAU * s / 16.0
		top.append(Vector3(c.x + cos(a) * r, y, c.z + sin(a) * r))
	return top

func _mast(level: Node3D) -> void:
	# the relay mast on the house roof: a four-legged lattice tapering to 26 m with red beacons.
	var x := (float(K.SHED_X[0]) + float(K.SHED_X[1])) * 0.5
	var z := (float(K.HOUSE[0]) + float(K.HOUSE[1])) * 0.5
	var foot := float(K.TERRACE_2[2]) + 5.2
	var top := foot + 26.0
	var legs: Array = []
	for k: int in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		legs.append([Vector3(x + cos(a) * 2.2, foot, z + sin(a) * 2.2), Vector3(x + cos(a) * 0.5, top, z + sin(a) * 0.5)])
	for k: int in 4:
		_strut(&"rail", legs[k][0], legs[k][1], 0.09)
		var next: Array = legs[(k + 1) % 4]
		for s: int in 6:
			var t0 := s / 6.0
			var t1 := (s + 1) / 6.0
			_strut(&"frame", (legs[k][0] as Vector3).lerp(legs[k][1], t0), (next[0] as Vector3).lerp(next[1], t1), 0.04)
	_box(&"frame", Vector3(x - 0.6, top, z - 0.6), Vector3(x + 0.6, top + 0.4, z + 0.6))
	for b: Vector3 in [Vector3(x, top + 1.0, z), Vector3(x, foot + 13.0, z)]:
		var bulb := MeshInstance3D.new()
		bulb.name = "Beacon"
		var sphere := SphereMesh.new()
		sphere.radius = 0.35
		sphere.height = 0.7
		bulb.mesh = sphere
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color("ff3a26")
		glow.emission_enabled = true
		glow.emission = Color("ff3a26")
		bulb.material_override = glow
		bulb.position = b
		level.add_child(bulb)
		_beacons.append(glow)
	# the antennae: two horn panels and a dish on the mast's head.
	for k: int in 3:
		var a := TAU * k / 3.0
		_box(&"machine", Vector3(x + cos(a) * 0.9 - 0.25, top - 4.0, z + sin(a) * 0.9 - 0.25), Vector3(x + cos(a) * 0.9 + 0.25, top - 1.6, z + sin(a) * 0.9 + 0.25))

func _lights(level: Node3D) -> void:
	# warm interiors and shelters. each sits in one mesh region, so no mesh is lit by many.
	var warm := Color("ffb978")
	var lamps: Array = [
		[Vector3(-6, 6.6, 6), 2.2, 15.0], [Vector3(6, 6.6, 6), 2.2, 15.0], [Vector3(-6, 6.6, -8), 2.2, 15.0], [Vector3(6, 6.6, -8), 2.2, 15.0],
		[Vector3(-5.6, 2.3, -113.6), 1.4, 7.0], [Vector3(5.6, 4.3, -163.6), 1.4, 7.0],
		[Vector3(45, 5.8, -176), 1.9, 14.0], [Vector3(45, 5.8, -160), 1.9, 14.0], [Vector3(45, 5.8, -144), 1.9, 14.0], [Vector3(45, 5.8, -131), 1.6, 12.0],
	]
	for i: int in lamps.size():
		var lamp := OmniLight3D.new()
		lamp.name = "WarmLamp_%d" % i
		lamp.light_color = warm
		lamp.light_energy = lamps[i][1]
		lamp.omni_range = lamps[i][2]
		lamp.position = lamps[i][0]
		level.add_child(lamp)
		# a glowing fitting under each interior lamp.
		if (lamps[i][0] as Vector3).y > 5.0:
			_glow_panel(level, lamps[i][0] + Vector3.UP * 0.4, Vector2(1.6, 0.5))
	_porch = OmniLight3D.new()
	_porch.name = "PorchLamp"
	_porch.light_color = warm
	_porch.light_energy = 2.0
	_porch.omni_range = 11.0
	_porch.position = Vector3(45, float(K.TERRACE_2[2]) + 3.2, float(K.HOUSE[0]) - 2.0)
	level.add_child(_porch)
	# lit windows: shelters, house front and shed doors.
	var house_z := float(K.HOUSE[0]) - 0.03
	var t2 := float(K.TERRACE_2[2])
	for x: float in [40.5, 49.5]:
		_window(level, Vector3(x, t2 + 1.7, house_z), PI, Vector2(2.4, 1.3))
	_window(level, Vector3(45.0, t2 + 1.3, house_z), PI, Vector2(2.0, 2.6))
	_window(level, Vector3(-5.97, 1.5, -113.6), PI * 0.5, Vector2(1.6, 0.9))
	_window(level, Vector3(5.97, 3.5, -163.6), -PI * 0.5, Vector2(1.6, 0.9))

func _glow_panel(level: Node3D, at: Vector3, size: Vector2) -> void:
	var panel := MeshInstance3D.new()
	panel.name = "LampPanel"
	var box := BoxMesh.new()
	box.size = Vector3(size.x, 0.08, size.y)
	panel.mesh = box
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("ffd9b0")
	glow.emission_enabled = true
	glow.emission = Color("ffc890")
	glow.emission_energy_multiplier = 2.5
	panel.material_override = glow
	panel.position = at
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(panel)

func _window(level: Node3D, at: Vector3, yaw: float, size: Vector2) -> void:
	var pane := MeshInstance3D.new()
	pane.name = "Window"
	var quad := QuadMesh.new()
	quad.size = size
	pane.mesh = quad
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("ffcf94")
	glow.emission_enabled = true
	glow.emission = Color("ffb265")
	glow.emission_energy_multiplier = 1.8
	pane.material_override = glow
	pane.transform = Transform3D(Basis(Vector3.UP, yaw), at)
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(pane)

# --- labels ---------------------------------------------------------------------------------

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
			label.modulate = Color("f0c860")
			label.transform = Transform3D(Basis(Vector3.UP, float(mark.yaw)) * Basis(Vector3.RIGHT, -PI * 0.5), (mark.at as Vector3) + Vector3.UP * 0.012)
		else:
			label.pixel_size = float(mark.get("size", 0.009))
			label.modulate = Color("f6e2b8")
			label.outline_size = 10
			label.outline_modulate = Color(0.06, 0.06, 0.08, 0.9)
			label.transform = Transform3D(Basis(Vector3.UP, float(mark.yaw)), mark.at)
		marks.add_child(label)
	# section signs on the shelters and the station name in the hangar.
	for s: Array in [["WHITEOUT RELAY  ·  service hangar", Vector3(0, 7.0, float(K.HANGAR_FRONT) + 0.05), 0.0, 0.014],
			["RIDGE", Vector3(-5.95, 2.25, -113.6), PI * 0.5, 0.012], ["SADDLE", Vector3(5.95, 4.25, -163.6), -PI * 0.5, 0.012],
			["RELAY HOUSE", Vector3(45.0, float(K.TERRACE_2[2]) + 4.4, float(K.HOUSE[0]) - 0.05), PI, 0.018],
			["RECEIVER DECK", Vector3(float(K.RECEIVER.x), float(K.RECEIVER.y) + float(K.PIT_WALL) - 0.55, float(K.RECEIVER.z) - float(K.RING_IN) - 0.05), PI, 0.016]]:
		var sign := Label3D.new()
		sign.name = "Sign_" + str(s[0]).get_slice("\n", 0).replace(" ", "_")
		sign.text = s[0]
		sign.font_size = 96
		sign.pixel_size = s[3]
		sign.modulate = Color("ffe8c2")
		sign.outline_size = 12
		sign.outline_modulate = Color(0.08, 0.06, 0.05, 0.9)
		sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sign.transform = Transform3D(Basis(Vector3.UP, s[2]), s[1])
		marks.add_child(sign)

# --- sourced props --------------------------------------------------------------------------

## the nature kit's flat materials, re-surfaced: grass tops become snow, dirt becomes dark rock,
## pine needles a deep winter green dusted toward their tips. no file changes.
func _nature_material(name: String) -> Material:
	var key := StringName("nature_" + name)
	if _cache.has(key):
		return _cache[key]
	var made := StandardMaterial3D.new()
	made.roughness = 0.95
	match name:
		"grass":
			made.albedo_color = Color("c3cad5")
		"dirt":
			made.albedo_color = Color("4c4a4a")
		"leafsDark":
			made.albedo_color = Color("1f3a30")
		"woodBarkDark":
			made.albedo_color = Color("3a2a22")
		_:
			made.albedo_color = Color("8a8f96")
	_cache[key] = made
	return made

func _resurface(node: Node) -> void:
	for mi: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for s: int in mesh.get_surface_count():
			var source := mesh.surface_get_material(s)
			(mi as MeshInstance3D).set_surface_override_material(s, _nature_material(source.resource_name if source != null else ""))

func _place(level: Node3D, model: String, feet: Vector3, height: float, yaw: float, nature: bool = false) -> Node3D:
	var node := ASSETS.place(level, "kenney-%s" % model, feet, ASSETS.scale_for_height("kenney-%s" % model, height), yaw)
	if nature:
		_resurface(node)
	var placed: Dictionary = report.get("props", {})
	placed[model] = int(placed.get(model, 0)) + 1
	report["props"] = placed
	return node

func _props(level: Node3D) -> void:
	# the level's reachable machines first, exactly over their collision footprints.
	for prop: Dictionary in level.get("props"):
		var node := ASSETS.place(level, prop.model, prop.feet, prop.scale, prop.yaw)
		node.name = "Prop_" + str(prop.name)
		var placed: Dictionary = report.get("props", {})
		placed[str(prop.model).get_file()] = int(placed.get(str(prop.model).get_file(), 0)) + 1
		report["props"] = placed
	var c: Vector3 = K.RECEIVER
	# the big receiver dish rising out of the pit, tipped toward the southern sky.
	_place(level, "space/models/satelliteDish_large.glb", Vector3(c.x, -8.0, c.z - 1.0), 18.0, PI)
	# the far landmark on its peak to the north-west, seen down the road and across the ridge.
	_place(level, "space/models/satelliteDish_large.glb", Vector3(-120.0, 47.0, -380.0), 46.0, deg_to_rad(150))
	# station dishes and buildings on the plateaus, all behind banks.
	_place(level, "space/models/satelliteDish_detailed.glb", Vector3(-26.0, 1.0, -66.0), 7.5, deg_to_rad(200))
	_place(level, "space/models/satelliteDish.glb", Vector3(-32.0, 1.0, -96.0), 6.0, deg_to_rad(160))
	_place(level, "space/models/satelliteDish_large.glb", Vector3(19.0, 1.0, -64.0), 6.5, deg_to_rad(250))
	_place(level, "space/models/satelliteDish_detailed.glb", Vector3(-42.0, 1.5, -135.0), 8.0, deg_to_rad(120))
	_place(level, "space/models/satelliteDish_large.glb", Vector3(42.0, 1.5, -145.0), 7.0, deg_to_rad(220))
	_place(level, "space/models/satelliteDish_detailed.glb", Vector3(72.0, 2.0, -96.0), 9.0, deg_to_rad(250))
	_place(level, "space/models/satelliteDish.glb", Vector3(66.0, 2.0, -150.0), 7.0, deg_to_rad(210))
	_place(level, "space/models/hangar_largeA.glb", Vector3(-36.0, 1.0, 6.0), 9.0, PI * 0.5)
	_place(level, "space/models/hangar_smallA.glb", Vector3(30.0, 1.0, -26.0), 6.0, -PI * 0.5)
	_place(level, "space/models/hangar_smallA.glb", Vector3(-31.0, 1.0, -30.0), 5.0, PI * 0.5)
	_place(level, "space/models/hangar_largeA.glb", Vector3(74.0, 2.0, -126.0), 10.0, -PI * 0.5)
	_place(level, "space/models/machine_generatorLarge.glb", Vector3(-24.0, 1.0, -20.0), 3.0, 0.4)
	_place(level, "space/models/machine_generator.glb", Vector3(62.0, 2.0, -112.0), 2.6, 1.2)
	_place(level, "space/models/machine_wireless.glb", Vector3(21.0, 1.0, -84.0), 3.0, -0.6)
	_place(level, "space/models/supports_high.glb", Vector3(-22.0, 1.0, -48.0), 8.0, 0.0)
	# rocks on the plateau edges and the ridge flanks, capped with snow.
	for r: Array in [[-25.0, 1.0, -112.0, 9.0, 0.3], [26.0, -14.0, -150.0, 13.0, 1.9], [-27.0, -14.0, -158.0, 14.0, 2.6], [30.0, 1.0, -100.0, 7.0, 0.8],
			[60.0, 2.0, -184.0, 10.0, 1.1], [-60.0, 1.0, -40.0, 14.0, 2.2], [40.0, 2.0, -20.0, 8.0, 0.4]]:
		_place(level, "nature/models/rock_tallA.glb", Vector3(r[0], r[1], r[2]), r[3], r[4], true)
	# pines scattered over the plateaus, clear of every bank.
	var zones: Array = [[-80.0, -24.0, 70.0, -100.0, 1.0], [20.0, 32.0, 60.0, -10.0, 1.0], [60.0, 105.0, -20.0, -180.0, 2.0], [32.0, 100.0, 15.0, -25.0, 2.0]]
	var count := 0
	for zone: Array in zones:
		for k: int in 18:
			var p := Vector3(_rng.randf_range(zone[0], zone[1]), zone[4], _rng.randf_range(zone[3], zone[2]))
			var model := "nature/models/tree_pineTallA.glb" if _rng.randf() < 0.5 else "nature/models/tree_pineDefaultA.glb"
			_place(level, model, p, _rng.randf_range(7.0, 13.0), _rng.randf() * TAU, true)
			count += 1
	report["pines"] = count
