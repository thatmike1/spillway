extends RefCounted
## p / r15 Night Shift art: everything the course draws, from the level's own records. the level
## calls dress() once at the end of build(); nothing here adds or moves a collision body, changes
## progress data or enters the geometry hash. every reachable solid already has its prism in the
## level; what this adds is out of reach (roofs, masts, girders, skyline) or flush with a deck
## (rails sunk into ballast and floors, painted strips).
##
## the look: a transit depot at night. a high cool moon lights the tops of decks; their sides stay
## dark. warm sodium and cool led lamps pool on the route, lip lights trace every edge that faces
## a gap, and neon signs and fascias name the places. kenney's train kit supplies the subway cars,
## trams, the shunting loco and the rails; its factory, industrial and retro-urban kits the shed
## fittings, lamps and skyline. surfaces use the existing scanned poly haven sets through the
## momentum surface shader. sources and licences: assets/r15/library/MANIFEST.json,
## assets/r15/breakwater/MANIFEST.json and assets/momentum/MANIFEST.json; no file is modified.

const Materials := preload("res://scripts/momentum_materials.gd")
const ASSETS := preload("res://scripts/r15_assets.gd")
const SHADER: Shader = preload("res://shaders/momentum_surface.gdshader")
const BW := "res://assets/r15/breakwater/textures/"
const MOM := "res://assets/momentum/textures/"
const VERSION := "nightshift-art-1"
## p / prisms are batched per kind and per 24 m cell: the compatibility renderer gives each mesh
## at most 8 lights, so one batch for the whole map would leave most lamps dark.
const CELL := 24.0

## texture sets: base path (without _diff_1k etc.), file type and metres per repeat.
const SETS := {
	&"pavers": {"base": BW + "square_concrete_pavers/square_concrete_pavers", "ext": "jpg", "metres": 1.8},
	&"asphalt": {"base": BW + "asphalt_02/asphalt_02", "ext": "jpg", "metres": 3.0},
	&"cladding": {"base": BW + "box_profile_metal_sheet/box_profile_metal_sheet", "ext": "jpg", "metres": 2.0},
	&"rust": {"base": BW + "rusty_painted_metal/rusty_painted_metal", "ext": "jpg", "metres": 2.2},
	&"brick": {"base": MOM + "red_brick/red_brick", "ext": "png", "metres": 2.0},
	&"formwork": {"base": MOM + "concrete_layers_02/concrete_layers_02", "ext": "png", "metres": 2.0},
	&"brushed": {"base": MOM + "brushed_concrete/brushed_concrete", "ext": "png", "metres": 2.5},
	&"plate": {"base": MOM + "metal_plate_02/metal_plate_02", "ext": "png", "metres": 2.0},
}
## p / the looks of every prism kind: [top set, side set, shader parameters]. tops are lit and pale,
## sides darker, so a landing reads against its own face at night.
const LOOKS := {
	&"platform": [&"pavers", &"formwork", {"desaturate": 0.7, "top_tint": Vector3(1.45, 1.42, 1.38), "side_tint": Vector3(0.42, 0.43, 0.5), "macro_strength": 0.06, "stain": 0.25}],
	&"cabinet": [&"plate", &"formwork", {"desaturate": 0.8, "top_tint": Vector3(1.3, 1.32, 1.28), "side_tint": Vector3(0.32, 0.42, 0.4), "metallic_scale": 0.4, "macro_strength": 0.04}],
	&"bed": [&"asphalt", &"asphalt", {"desaturate": 0.6, "top_tint": Vector3(0.62, 0.6, 0.58), "side_tint": Vector3(0.38, 0.38, 0.4), "macro_strength": 0.16, "stain": 0.4}],
	&"ground": [&"asphalt", &"asphalt", {"desaturate": 0.6, "top_tint": Vector3(0.36, 0.36, 0.38), "side_tint": Vector3(0.3, 0.3, 0.32), "macro_strength": 0.2, "stain": 0.5}],
	&"brick": [&"brick", &"brick", {"desaturate": 0.35, "top_tint": Vector3(0.75, 0.62, 0.58), "side_tint": Vector3(0.62, 0.5, 0.48), "macro_strength": 0.06}],
	&"concrete": [&"formwork", &"formwork", {"desaturate": 0.8, "top_tint": Vector3(1.05, 1.05, 1.08), "side_tint": Vector3(0.56, 0.57, 0.62), "side_joint_spacing": 6.0, "side_bay_tone": 0.05, "macro_strength": 0.08, "stain": 0.3}],
	&"floor": [&"brushed", &"formwork", {"desaturate": 0.75, "top_tint": Vector3(1.25, 1.25, 1.28), "side_tint": Vector3(0.45, 0.46, 0.5), "macro_strength": 0.08, "stain": 0.35}],
	&"flyover": [&"brushed", &"formwork", {"desaturate": 0.75, "top_tint": Vector3(1.35, 1.34, 1.36), "side_tint": Vector3(0.48, 0.48, 0.55), "side_joint_spacing": 8.0, "side_bay_tone": 0.06, "macro_strength": 0.07, "stain": 0.25}],
	&"cladding": [&"cladding", &"cladding", {"desaturate": 0.85, "top_tint": Vector3(0.75, 0.82, 0.92), "side_tint": Vector3(0.78, 0.88, 1.02), "metallic_scale": 0.2, "macro_strength": 0.05}],
	&"roof": [&"cladding", &"cladding", {"desaturate": 0.9, "top_tint": Vector3(0.3, 0.32, 0.38), "side_tint": Vector3(0.3, 0.33, 0.4), "metallic_scale": 0.4}],
	&"shutter": [&"cladding", &"cladding", {"desaturate": 0.4, "top_tint": Vector3(1.4, 0.95, 0.35), "side_tint": Vector3(1.35, 0.9, 0.32), "metallic_scale": 0.3, "macro_strength": 0.03}],
	&"steel": [&"plate", &"plate", {"desaturate": 0.85, "top_tint": Vector3(1.05, 1.08, 1.12), "side_tint": Vector3(0.45, 0.48, 0.54), "metallic_scale": 0.6, "roughness_scale": 0.8, "macro_strength": 0.04}],
	&"stand": [&"plate", &"rust", {"desaturate": 0.3, "top_tint": Vector3(1.3, 1.05, 0.35), "side_tint": Vector3(0.9, 0.7, 0.25), "metallic_scale": 0.4, "macro_strength": 0.03}],
	&"girder": [&"rust", &"rust", {"desaturate": 0.9, "top_tint": Vector3(0.38, 0.4, 0.46), "side_tint": Vector3(0.34, 0.36, 0.42), "metallic_scale": 0.6, "macro_strength": 0.02}],
	&"tower": [&"formwork", &"formwork", {"desaturate": 0.85, "top_tint": Vector3(0.5, 0.52, 0.58), "side_tint": Vector3(0.45, 0.47, 0.54), "side_joint_spacing": 3.0, "side_bay_tone": 0.08}],
}
## flat colours for the neutral mode and the painted kinds. emissive kinds glow at `GLOW` energy.
const FLAT := {
	&"paint_yellow": Color("d6a62a"), &"paint_white": Color("d8dcdf"), &"hazard": Color("e0a81e"),
	&"platform": Color("b4b2ab"), &"cabinet": Color("8d968f"), &"bed": Color("4b4a49"), &"ground": Color("2e2e30"),
	&"brick": Color("7a4b40"), &"concrete": Color("8d8f94"), &"floor": Color("9a9ca0"), &"flyover": Color("a5a6aa"),
	&"cladding": Color("4d5a6c"), &"roof": Color("2a2e36"), &"shutter": Color("c48a2c"), &"steel": Color("6c727c"),
	&"stand": Color("b28a2c"), &"girder": Color("3a3d44"), &"tower": Color("50535a"),
}
const GLOW := {
	&"lip": [Color("fff1d0"), 1.6], &"neon_cyan": [Color("2fe7ff"), 3.2], &"neon_magenta": [Color("ff36c8"), 3.0],
	&"neon_amber": [Color("ffae3a"), 2.6], &"bulb_warm": [Color("ffd59a"), 4.0], &"bulb_cool": [Color("d8ecff"), 4.0],
	&"bulb_red": [Color("ff3a2a"), 4.0], &"bulb_green": [Color("4dff7a"), 4.0], &"skylight": [Color("9fc4ff"), 1.2],
}
## p / the moon: high in the south-west, so tops catch it and walls stay in shade.
const MOON_YAW := 148.0
const MOON_PITCH := -62.0
## lamp kinds: colour, energy, range.
const LAMPS := {
	"canopy": [Color("ffd8a8"), 1.5, 11.0], "under": [Color("cfe6ff"), 1.3, 10.0], "post": [Color("ffc27a"), 1.6, 13.0],
	"signal": [Color("ff4632"), 0.9, 6.0], "mast": [Color("ffb766"), 2.4, 18.0], "bay": [Color("dbe9ff"), 2.6, 15.0],
	"flood": [Color("ffd2a0"), 2.0, 14.0], "flyover": [Color("cfe2ff"), 2.0, 15.0], "terminus": [Color("ffcf96"), 1.8, 14.0],
	"canal": [Color("4fe6ff"), 1.6, 14.0],
}

var report := {"version": VERSION}
var scenery_bodies: Array[String] = []
var _cache := {}
var _surfaces := {}
var _neutral := false
var _rng := RandomNumberGenerator.new()
var _signs: Array[Label3D] = []
var _finish_sign: Label3D
var _finish_lamp: OmniLight3D
var _glow := 0.0
var _finished := false
var _time := 0.0
var _lights := 0
## the level script's constants (sizes, edges, radii), read once.
var K: Dictionary = {}

## dresses the level once, from its records. every prism, support and fixture is authored first;
## the batches are committed once, at the very end, so nothing authored is left undrawn.
func dress(level: Node3D) -> void:
	var started := Time.get_ticks_usec()
	_neutral = str(level.get("material_mode")) == "neutral"
	K = (level.get_script() as Script).get_script_constant_map()
	_rng.seed = 155
	_environment(level)
	_ground(level)
	for prism: Dictionary in level.get("prisms"):
		_prism(prism.top, float(prism.base), prism.kind)
	_station(level)
	_flyover(level)
	_shed(level)
	_loop(level)
	_terminus(level)
	_skyline(level)
	_lamps(level)
	_commit(level)
	_trains(level)
	_rails(level)
	_props(level)
	_labels(level)
	report["neutral"] = _neutral
	report["pending_after_dress"] = _surfaces.size()
	report["lights"] = _lights
	report["apply_ms"] = (Time.get_ticks_usec() - started) / 1000.0
	report["scenery_bodies"] = scenery_bodies
	level.set_meta("nightshift_art", report)

## presentation after a finish: the terminus sign brightens. never touches physics.
func finished(_level: Node3D, on: bool) -> void:
	_finished = on

func tick(_level: Node3D, delta: float) -> void:
	_time += delta
	_glow = move_toward(_glow, 1.0 if _finished else 0.0, delta * 1.5)
	# p / one tube of the depot sign buzzes; a steady hum, never a strobe.
	for i: int in _signs.size():
		var sign := _signs[i]
		if is_instance_valid(sign) and sign.has_meta("buzz"):
			var on := fmod(_time * 0.37 + i * 0.21, 1.0) > 0.06
			sign.modulate.a = 1.0 if on else 0.55
	if is_instance_valid(_finish_sign):
		_finish_sign.modulate = Color("2fe7ff").lerp(Color("fff4d8"), _glow)
	if is_instance_valid(_finish_lamp):
		_finish_lamp.light_energy = 1.8 + _glow * 2.5

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
	if GLOW.has(kind):
		var glow := StandardMaterial3D.new()
		var spec: Array = GLOW[kind]
		glow.albedo_color = (spec[0] as Color) * 0.4
		glow.emission_enabled = true
		glow.emission = spec[0]
		glow.emission_energy_multiplier = float(spec[1])
		glow.roughness = 0.6
		made = glow
	elif kind == &"glass":
		var glass := StandardMaterial3D.new()
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.albedo_color = Color(0.55, 0.75, 0.95, 0.16)
		glass.roughness = 0.08
		glass.metallic_specular = 0.8
		glass.cull_mode = BaseMaterial3D.CULL_DISABLED
		made = glass
	elif String(kind).begins_with("paint") or kind == &"hazard" or _neutral or not LOOKS.has(kind):
		var flat := StandardMaterial3D.new()
		flat.albedo_color = FLAT.get(kind, Color("777777"))
		flat.roughness = 0.75
		made = flat
	else:
		var look: Array = LOOKS[kind]
		made = _surface(look[0], look[1], look[2])
	_cache[kind] = made
	return made

# --- sky, moon, fog and water ---------------------------------------------------------------

const SKY := """shader_type sky;
uniform vec3 top_color : source_color = vec3(0.012, 0.016, 0.04);
uniform vec3 horizon_color : source_color = vec3(0.13, 0.06, 0.15);
uniform vec3 sodium : source_color = vec3(0.36, 0.17, 0.05);
uniform vec3 moon_dir = vec3(0.4, 0.88, 0.25);
void sky() {
	vec3 d = normalize(EYEDIR);
	float y = d.y;
	vec3 c = mix(horizon_color, top_color, smoothstep(-0.05, 0.5, y));
	c += sodium * exp(-abs(y) * 12.0) * 0.55;
	vec2 uv = vec2(atan(d.x, d.z), asin(clamp(y, -1.0, 1.0))) * 140.0;
	vec2 cell = floor(uv);
	float h = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	vec2 f = fract(uv) - 0.5;
	float star = step(0.9972, h) * smoothstep(0.08, 0.35, y) * smoothstep(0.35, 0.0, length(f));
	c += vec3(0.75, 0.8, 1.0) * star * (0.5 + fract(h * 91.0));
	float m = dot(d, normalize(moon_dir));
	c += vec3(0.85, 0.9, 1.0) * smoothstep(0.99955, 0.9998, m) * 1.6 + vec3(0.06, 0.07, 0.12) * pow(max(m, 0.0), 48.0);
	COLOR = c;
}
"""

func _environment(level: Node3D) -> void:
	var world := WorldEnvironment.new()
	world.name = "Environment"
	var environment := Environment.new()
	var sky := Sky.new()
	var to_moon := Basis.from_euler(Vector3(deg_to_rad(MOON_PITCH), deg_to_rad(MOON_YAW), 0.0)) * Vector3.BACK
	if _neutral:
		var plain := ProceduralSkyMaterial.new()
		plain.sky_top_color = Color("0b1024")
		plain.sky_horizon_color = Color("2a1a32")
		plain.ground_horizon_color = Color("2a1a32")
		plain.ground_bottom_color = Color("0b0b10")
		sky.sky_material = plain
	else:
		var shader := Shader.new()
		shader.code = SKY
		var night := ShaderMaterial.new()
		night.shader = shader
		night.set_shader_parameter("moon_dir", to_moon)
		sky.sky_material = night
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("3a4466")
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_white = 5.0
	environment.tonemap_exposure = 1.15
	environment.fog_enabled = true
	environment.fog_light_color = Color("1c1830")
	environment.fog_density = 0.006
	environment.fog_aerial_perspective = 0.3
	environment.fog_sky_affect = 0.05
	world.environment = environment
	level.add_child(world)
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.rotation = Vector3(deg_to_rad(MOON_PITCH), deg_to_rad(MOON_YAW), 0.0)
	moon.light_energy = 0.5
	moon.light_color = Color("b4c6ff")
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 90.0
	level.add_child(moon)
	# a dim warm bounce from the city below the sky, no shadows: sides are dark, never black.
	var bounce := DirectionalLight3D.new()
	bounce.name = "CityBounce"
	bounce.rotation = Vector3(deg_to_rad(-12.0), deg_to_rad(MOON_YAW + 160.0), 0.0)
	bounce.light_energy = 0.12
	bounce.light_color = Color("ff9a5a")
	level.add_child(bounce)
	_canal_water(level)

const WATER := """shader_type spatial;
render_mode cull_disabled;
uniform vec3 deep : source_color = vec3(0.01, 0.015, 0.03);
uniform vec3 neon_a : source_color = vec3(1.0, 0.2, 0.75);
uniform vec3 neon_b : source_color = vec3(0.18, 0.9, 1.0);
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz * 0.35;
	float t = TIME;
	float g = cos(p.x * 2.3 + t * 0.8) * 0.5 + cos((p.x + p.y) * 4.1 - t * 1.3) * 0.35 + cos(p.y * 7.0 + t * 0.6) * 0.15;
	vec3 view = normalize((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz - CAMERA_POSITION_WORLD);
	float fresnel = pow(1.0 - max(dot(-view, vec3(0.0, 1.0, 0.0)), 0.0), 3.0);
	float streak_a = smoothstep(0.55, 1.0, sin(wpos.z * 0.9 + g * 2.0) * 0.5 + 0.5) * smoothstep(3.0, 0.0, abs(wpos.z - 11.0) - 1.0);
	float streak_b = smoothstep(0.6, 1.0, sin(wpos.x * 1.3 + g * 2.5) * 0.5 + 0.5) * smoothstep(4.0, 0.0, abs(wpos.x + 38.0) - 2.0);
	ALBEDO = deep;
	EMISSION = (neon_a * streak_a * 0.35 + neon_b * streak_b * 0.25) * (0.4 + fresnel) + vec3(0.02, 0.03, 0.06) * fresnel;
	ROUGHNESS = 0.12;
	SPECULAR = 0.6;
	NORMAL = (VIEW_MATRIX * vec4(normalize(vec3(g * 0.05, 1.0, g * 0.04)), 0.0)).xyz;
}
"""

func _canal_water(level: Node3D) -> void:
	var canal: Array = K.CANAL
	var plane := MeshInstance3D.new()
	plane.name = "Canal"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(absf(float(canal[1]) - float(canal[0])) + 1.0, 60.0)
	mesh.subdivide_width = 4
	mesh.subdivide_depth = 8
	plane.mesh = mesh
	if _neutral:
		var flat := StandardMaterial3D.new()
		flat.albedo_color = Color("0f1a26")
		plane.material_override = flat
	else:
		var shader := Shader.new()
		shader.code = WATER
		var water := ShaderMaterial.new()
		water.shader = shader
		plane.material_override = water
	plane.position = Vector3((float(canal[0]) + float(canal[1])) * 0.5, float(K.WATER_Y), 5.0)
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(plane)

# --- prisms ---------------------------------------------------------------------------------

func _ground(_level: Node3D) -> void:
	# p / the depot floor and the city round the route, 5 cm under the trackbed so a catch drawn
	# over it always wins, tiled by cell for the lights. none of it is reachable: walls, fences and
	# parapets stand between it and every deck. the canal is left open for its water.
	var y := float(K.BED) - 0.05
	var canal: Array = K.CANAL
	var open := [-24.0, 36.0]
	var x := -112.0
	while x < 84.0:
		var z := -136.0
		while z < 48.0:
			var x1 := x + CELL
			var z1 := z + CELL
			for zs: Array in _minus(z, z1, float(open[0]), float(open[1])):
				_prism(_rect(x, x1, zs[0], zs[1], y), y - 2.0, &"ground")
			var inside := [maxf(z, float(open[0])), minf(z1, float(open[1]))]
			if inside[0] < inside[1]:
				for span: Array in _minus(x, x1, float(canal[1]) - 6.0, float(canal[0]) + 0.5):
					_prism(_rect(span[0], span[1], inside[0], inside[1], y), y - 2.0, &"ground")
			z = z1
		x += CELL
	# the canal banks beyond the concourse walls and the canal walls under the water line.
	var c: Array = K.CONCOURSE
	for zs: Array in [[float(c[3]) + 0.4, 36.0], [-24.0, float(c[2]) - 0.4]]:
		_prism(_rect(float(canal[1]) - 6.0, float(canal[1]), zs[0], zs[1], 0.0), float(K.WATER_Y) - 1.0, &"concrete")
		_prism(_rect(float(canal[0]), float(canal[0]) + 0.5, zs[0], zs[1], 0.0), float(K.WATER_Y) - 1.0, &"concrete")
	for zs: Array in [[float(open[0]) - 0.5, float(open[0])], [float(open[1]), float(open[1]) + 0.5]]:
		_prism(_rect(float(canal[1]), float(canal[0]), zs[0], zs[1], 0.0), float(K.WATER_Y) - 1.0, &"concrete")

static func _minus(a0: float, a1: float, b0: float, b1: float) -> Array:
	# [a0, a1] without [b0, b1].
	if b1 <= a0 or b0 >= a1:
		return [[a0, a1]]
	var out: Array = []
	if b0 > a0:
		out.append([a0, b0])
	if b1 < a1:
		out.append([b1, a1])
	return out

func _prism(top: Array, base: float, kind: StringName) -> void:
	# a convex prism: the top polygon, its walls down to base. flat normals, godot's clockwise fronts.
	var n := top.size()
	var centre := Vector3.ZERO
	for p: Vector3 in top:
		centre += p / n
	var st := _st(kind, centre)
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

func _st(kind: StringName, at: Vector3) -> SurfaceTool:
	var key := "%s@%d,%d" % [kind, floori(at.x / CELL), floori(at.z / CELL)]
	if not _surfaces.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_surfaces[key] = st
	return _surfaces[key]

func _commit(level: Node3D) -> void:
	var counts := {}
	var batches := 0
	var keys := _surfaces.keys()
	keys.sort()
	for key: String in keys:
		var kind := StringName(key.get_slice("@", 0))
		var instance := MeshInstance3D.new()
		instance.name = "Mesh_" + key.replace("@", "_").replace(",", "_").replace("-", "m")
		instance.mesh = (_surfaces[key] as SurfaceTool).commit()
		instance.material_override = material(kind)
		if String(kind).begins_with("paint") or GLOW.has(kind) or kind == &"hazard" or kind == &"glass":
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		level.add_child(instance)
		counts[String(kind)] = int(counts.get(String(kind), 0)) + instance.mesh.get_faces().size() / 3
		batches += 1
	_surfaces.clear()
	report["prism_triangles"] = counts
	report["batches"] = batches
	report["committed"] = true

# --- set pieces -----------------------------------------------------------------------------

func _station(level: Node3D) -> void:
	# platform 1's canopy on its columns, a glowing fascia, and the station block behind the wall.
	var px: float = K.PLAT_X
	var start: float = K.PLAT_START
	var end: float = K.CANOPY_END
	_box(&"roof", Vector3(-px - 0.6, 4.8, end), Vector3(px + 0.6, 5.05, start))
	for x: float in [-4.9, 4.9]:
		_box(&"girder", Vector3(x - 0.15, 4.5, end + 0.2), Vector3(x + 0.15, 4.8, start - 0.2))
	_box(&"neon_cyan", Vector3(-px - 0.62, 4.82, end - 0.04), Vector3(px + 0.62, 4.9, end))
	for x: float in [-px - 0.62, px + 0.58]:
		_box(&"neon_cyan", Vector3(x, 4.82, end), Vector3(x + 0.04, 4.9, start))
	# the station block behind the back wall, its upper storey lit.
	var sx: float = K.STATION_X
	_box(&"brick", Vector3(-sx - 2.0, _low(), start + 0.5), Vector3(sx + 2.0, 9.5, start + 9.0))
	for k: int in 6:
		var x := -sx + 1.5 + k * ((2.0 * sx - 3.0) / 5.0)
		_box(&"bulb_warm", Vector3(x - 0.7, 6.2, start + 0.46), Vector3(x + 0.7, 7.6, start + 0.5))
	# the throat's floodlight masts stand outside its walls.
	for p: Vector3 in [Vector3(-sx - 2.0, 0, -58.0), Vector3(sx + 2.0, 0, -66.0)]:
		_box(&"girder", Vector3(p.x - 0.2, _low(), p.z - 0.2), Vector3(p.x + 0.2, 9.0, p.z + 0.2))
		_box(&"girder", Vector3(p.x - 0.9, 9.0, p.z - 0.3), Vector3(p.x + 0.9, 9.3, p.z + 0.3))
		_box(&"bulb_warm", Vector3(p.x - 0.8, 8.85, p.z - 0.25), Vector3(p.x + 0.8, 9.0, p.z + 0.25))
		_light(level, "ThroatFlood", Vector3(signf(-p.x) * 4.0 + p.x, 8.5, p.z), "mast")

func _flyover(_level: Node3D) -> void:
	# girder fascias with magenta neon on both faces, out-of-reach piers, catenary masts and wires.
	var s: float = K.FLY_S
	var n: float = K.FLY_N
	var x0: float = K.FLY_END
	var x1: float = K.FLY_START
	var y: float = K.FLY_Y
	var bottom: float = K.FLY_BOTTOM
	var wall: float = K.WALL
	var fence: float = K.FENCE
	for face: Array in [[s - wall - 0.06, s - wall], [n + wall, n + wall + 0.06]]:
		_box(&"neon_magenta", Vector3(x0, bottom + 0.35, face[0]), Vector3(x1, bottom + 0.45, face[1]))
		_box(&"neon_magenta", Vector3(x0, y + fence - 0.12, face[0]), Vector3(x1, y + fence - 0.06, face[1]))
	# the glass parapets' steel caps and kerbs, inside the panes' own volume.
	for pane: Array in [[s - wall, s], [n, n + wall]]:
		_box(&"girder", Vector3(x0, y + fence - 0.06, pane[0] + 0.05), Vector3(x1, y + fence, pane[1] - 0.05))
		_box(&"girder", Vector3(x0, y, pane[0] + 0.02), Vector3(x1, y + 0.18, pane[1] - 0.02))
	for x: float in [28.0, -21.0]:
		_box(&"concrete", Vector3(x - 1.0, _low(), s + 2.5), Vector3(x + 1.0, bottom, n - 2.5))
		_box(&"girder", Vector3(x - 1.4, bottom - 0.6, s - wall), Vector3(x + 1.4, bottom, n + wall))
	var x := x1 - 6.0
	while x > x0 + 1.0:
		for zs: Array in [[s - wall + 0.1, s - 0.1], [n + 0.1, n + wall - 0.1]]:
			_box(&"girder", Vector3(x - 0.12, y + fence, zs[0]), Vector3(x + 0.12, y + 5.2, zs[1]))
		_box(&"girder", Vector3(x - 0.08, y + 4.9, s - wall), Vector3(x + 0.08, y + 5.05, n + wall))
		x -= 12.0
	for z: float in [(s + n) * 0.5 - 2.0, (s + n) * 0.5 + 2.0]:
		_box(&"girder", Vector3(x0, y + 4.6, z - 0.02), Vector3(x1, y + 4.64, z + 0.02))
	# the knuckle's signal-box windows and the box's roof lamp.
	var k: Vector3 = K.KNUCKLE
	var r: float = K.KNUCKLE_IN
	for a: float in [330.0, 10.0, 50.0, 80.0]:
		var d := Vector3(cos(deg_to_rad(a)), 0, sin(deg_to_rad(a)))
		var c := k + d * (r - 0.02)
		_prism([c + d.cross(Vector3.UP) * 0.7 + Vector3.UP * 4.2, c - d.cross(Vector3.UP) * 0.7 + Vector3.UP * 4.2, c - d.cross(Vector3.UP) * 0.7 + d * 0.05 + Vector3.UP * 4.2, c + d.cross(Vector3.UP) * 0.7 + d * 0.05 + Vector3.UP * 4.2], k.y + 3.0, &"bulb_warm")

func _shed(_level: Node3D) -> void:
	# the wash-bay roof on the walls, skylights, gantry beams, the shutter's slats and hazard posts.
	var x0: float = K.SHED_X0
	var x1: float = K.SHED_X1
	var s: float = K.SHED_S
	var n: float = K.SHED_N
	var top: float = K.SHED_WALL_H
	_box(&"roof", Vector3(x0 - 0.4, top, s - 0.4), Vector3(x1 + 0.4, top + 0.3, n + 0.4))
	_box(&"neon_amber", Vector3(x0 - 0.42, top - 0.14, s - 0.44), Vector3(x1 + 0.42, top - 0.06, s - 0.4))
	_box(&"neon_amber", Vector3(x0 - 0.42, top - 0.14, n + 0.4), Vector3(x1 + 0.42, top - 0.06, n + 0.44))
	for xc: float in [(x0 + float(K.BAY_WM)) * 0.5, (float(K.BAY_WM) + float(K.BAY_ME)) * 0.5, (float(K.BAY_ME) + x1) * 0.5]:
		_box(&"skylight", Vector3(xc - 0.6, top - 0.02, s + 2.0), Vector3(xc + 0.6, top, n - 2.0))
	for z: float in [-70.0, -58.0]:
		_box(&"girder", Vector3(x0 + 0.5, 5.0, z - 0.25), Vector3(x1 - 0.5, 5.5, z + 0.25))
	# the hatch in the east road door: dark grooves across the orange shutter, and hazard bands
	# along its bottom edge and the splash wall's top, on both faces.
	var sh: Array = K.SHUTTER
	var low: float = K.SHUTTER_H
	var yy := low + 0.12
	while yy < float(K.DOOR_H):
		for face: float in [s - 0.01, s + 0.5]:
			_box(&"girder", Vector3(float(sh[0]), yy, face), Vector3(float(sh[1]), yy + 0.03, face + 0.01))
		yy += 0.18
	var sill: float = K.SHUTTER_SILL
	for face: float in [s - 0.02, s + 0.5]:
		_box(&"hazard", Vector3(float(sh[0]), low - 0.12, face), Vector3(float(sh[1]), low, face + 0.02))
		_box(&"hazard", Vector3(float(sh[0]), sill - 0.12, face), Vector3(float(sh[1]), sill, face + 0.02))
	# door frames glow so each opening reads from across the bay: door 1's jambs, and the west
	# bay's open north end, set into the wall ends either side of it.
	var wm := float(K.BAY_WM)
	var door: Array = K.DOOR_1
	for z: float in [float(door[0]), float(door[1])]:
		var into := -0.08 if z == float(door[0]) else 0.08
		_box(&"neon_cyan", Vector3(wm - 0.255, 0.0, minf(z, z + into)), Vector3(wm + 0.255, float(K.DOOR_H), maxf(z, z + into)))
	var header: float = K.BAY_HEADER
	_box(&"neon_cyan", Vector3(x0 + 0.42, 0.0, n - 0.5), Vector3(x0 + 0.5, header, n))
	_box(&"neon_cyan", Vector3(wm - 0.25, 0.0, n - 0.5), Vector3(wm - 0.17, header, n))
	_box(&"neon_cyan", Vector3(x0 + 0.5, header, n - 0.505), Vector3(wm - 0.25, header + 0.08, n - 0.5))

func _loop(_level: Node3D) -> void:
	# the traverser's own rails in the pit, its end buffers, and lamp masts behind the fence.
	var tr: Array = K.TRAVERSER
	for z: float in [float(tr[2]) - 0.8, float(tr[3]) + 0.8]:
		_box(&"girder", Vector3(float(tr[0]), _low(), z - 0.15), Vector3(float(tr[1]), _low() + 0.08, z + 0.15))

func _terminus(_level: Node3D) -> void:
	# the concourse canopy on its walls, the terminus facade's arch of light, and the finish gate.
	var c: Array = K.CONCOURSE
	var w: float = K.WALL
	_box(&"roof", Vector3(float(c[1]), 7.8, float(c[2]) - w), Vector3(float(c[0]) - 4.0, 8.05, float(c[3]) + w))
	for z: float in [float(c[2]) - w * 0.5, float(c[3]) + w * 0.5]:
		var x := float(c[1]) + 2.0
		while x < float(c[0]) - 4.0:
			_box(&"girder", Vector3(x - 0.15, 3.0, z - 0.15), Vector3(x + 0.15, 7.8, z + 0.15))
			x += 6.0
	_box(&"neon_cyan", Vector3(float(c[0]) - 4.0, 7.75, float(c[2]) - w), Vector3(float(c[0]) - 3.92, 7.85, float(c[3]) + w))
	var fx: Array = K.FINISH_X
	_box(&"neon_magenta", Vector3(float(fx[0]) - 0.1, 7.4, float(c[2])), Vector3(float(fx[0]) + 0.1, 7.6, float(c[3])))
	for z: float in [float(c[2]) - w * 0.75, float(c[3]) + w * 0.25]:
		_box(&"neon_magenta", Vector3(float(fx[0]) - 0.1, 3.0, z), Vector3(float(fx[0]) + 0.1, 7.6, z + 0.2))
	for k: int in 7:
		var z := float(c[2]) + 2.0 + k * ((float(c[3]) - float(c[2]) - 4.0) / 6.0)
		_box(&"bulb_warm", Vector3(float(c[1]) + 0.02, 3.4, z - 0.9), Vector3(float(c[1]) + 0.06, 6.4, z + 0.9))

func _skyline(level: Node3D) -> void:
	# p / city blocks round the depot, far enough that fog softens them; lit windows by shader.
	var shader := Shader.new()
	shader.code = WINDOWS
	var facade := ShaderMaterial.new()
	facade.shader = shader
	var blocks := MeshInstance3D.new()
	blocks.name = "Skyline"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spots: Array = []
	for k: int in 9:
		spots.append(Vector3(-100.0 + k * 22.0, 0, -150.0 - _rng.randf() * 12.0))
		spots.append(Vector3(-100.0 + k * 22.0, 0, 62.0 + _rng.randf() * 12.0))
	for k: int in 7:
		spots.append(Vector3(-128.0 - _rng.randf() * 10.0, 0, -120.0 + k * 26.0))
		spots.append(Vector3(96.0 + _rng.randf() * 10.0, 0, -120.0 + k * 26.0))
	for at: Vector3 in spots:
		var w := 10.0 + _rng.randf() * 9.0
		var d := 9.0 + _rng.randf() * 8.0
		var h := 14.0 + _rng.randf() * 34.0
		var top := _rect(at.x - w * 0.5, at.x + w * 0.5, at.z - d * 0.5, at.z + d * 0.5, h)
		var n := top.size()
		for i: int in range(1, n - 1):
			_tri(st, top[0], top[i], top[i + 1], Vector3.UP, true)
		for i: int in n:
			var a: Vector3 = top[i]
			var b: Vector3 = top[(i + 1) % n]
			var out := (b - a).cross(Vector3.UP).normalized()
			if out.dot(Vector3((a.x + b.x) * 0.5 - at.x, 0, (a.z + b.z) * 0.5 - at.z)) < 0.0:
				out = -out
			_quad(st, [a, b, Vector3(b.x, _low(), b.z), Vector3(a.x, _low(), a.z)], out)
	blocks.mesh = st.commit()
	blocks.material_override = facade if not _neutral else material(&"girder")
	blocks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(blocks)
	report["skyline_blocks"] = spots.size()

const WINDOWS := """shader_type spatial;
varying vec3 wpos;
varying vec3 wnormal;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wnormal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz; }
void fragment() {
	float along = abs(wnormal.x) > 0.5 ? wpos.z : wpos.x;
	vec2 cell = floor(vec2(along / 2.4, wpos.y / 3.2));
	vec2 f = fract(vec2(along / 2.4, wpos.y / 3.2));
	float h = fract(sin(dot(cell + floor(wpos.xz / 40.0), vec2(41.3, 289.1))) * 15731.7);
	float window = step(0.18, f.x) * step(f.x, 0.82) * step(0.25, f.y) * step(f.y, 0.75);
	float lit = step(0.62, h) * window * step(0.5, abs(wnormal.y) < 0.5 ? 1.0 : 0.0);
	vec3 warm = mix(vec3(1.0, 0.72, 0.38), vec3(0.7, 0.85, 1.0), step(0.86, h));
	ALBEDO = vec3(0.025, 0.027, 0.035);
	ROUGHNESS = 0.8;
	EMISSION = warm * lit * 0.9;
}
"""

# --- lamps ------------------------------------------------------------------------------------

func _light(level: Node3D, label: String, at: Vector3, kind: String) -> OmniLight3D:
	var spec: Array = LAMPS[kind]
	var light := OmniLight3D.new()
	light.name = "%s_%d" % [label, _lights]
	light.light_color = spec[0]
	light.light_energy = float(spec[1])
	light.omni_range = float(spec[2])
	light.omni_attenuation = 1.2
	light.shadow_enabled = false
	light.position = at
	level.add_child(light)
	_lights += 1
	return light

func _lamps(level: Node3D) -> void:
	# every lamp: its support first (a pole, bracket or rod), its glowing head, then its light.
	# supports and heads are prisms of the same final batch as the course.
	var px: float = K.PLAT_X
	for z: float in [22.5, 14.0]:
		_box(&"girder", Vector3(-0.03, 4.4, z - 0.03), Vector3(0.03, 4.8, z + 0.03))
		_box(&"bulb_warm", Vector3(-0.7, 4.32, z - 0.12), Vector3(0.7, 4.4, z + 0.12))
		_light(level, "Canopy", Vector3(0, 4.1, z), "canopy")
	var fly_mid := (float(K.FLY_S) + float(K.FLY_N)) * 0.5
	for x: float in [-3.0, 3.0]:
		_box(&"bulb_cool", Vector3(x - 0.6, float(K.FLY_BOTTOM) - 0.06, fly_mid - 0.15), Vector3(x + 0.6, float(K.FLY_BOTTOM), fly_mid + 0.15))
		_light(level, "Underpass", Vector3(x, float(K.FLY_BOTTOM) - 0.4, fly_mid), "under")
	for lamp: Dictionary in level.get("lamps"):
		var at: Vector3 = lamp.at
		match str(lamp.kind):
			"post":
				# a platform-end post (its level prism s0_post_*): an arm in over the deck at 4.2 m.
				var tip := at + Vector3(-0.9 * signf(at.x), -0.1, 0)
				_box(&"girder", Vector3(minf(at.x, tip.x), 4.12, -30.05), Vector3(maxf(at.x, tip.x), 4.2, -29.95))
				_box(&"bulb_warm", tip + Vector3(-0.3, -0.12, -0.2), tip + Vector3(0.3, -0.02, 0.2))
				_light(level, "PlatformEnd", tip + Vector3(0, -0.4, 0), "post")
			"signal":
				_box(&"girder", at + Vector3(-0.3, -0.6, -0.2), at + Vector3(0.3, 0.5, 0.2))
				_box(&"bulb_red", at + Vector3(-0.12, 0.15, 0.2), at + Vector3(0.12, 0.38, 0.24))
				_box(&"bulb_green", at + Vector3(-0.12, -0.35, 0.2), at + Vector3(0.12, -0.12, 0.24))
				if bool(lamp.get("light", true)):
					_light(level, "Signal", at + Vector3(0, 0, 0.6), "signal")
			"mast":
				_mast(level, at)
			"bay":
				_box(&"girder", at + Vector3(-0.03, 0.08, -0.03), at + Vector3(0.03, float(K.SHED_WALL_H) - at.y, 0.03))
				_box(&"bulb_cool", at + Vector3(-0.9, 0.0, -0.2), at + Vector3(0.9, 0.08, 0.2))
				if is_equal_approx(at.z, -64.0):
					continue
				_light(level, "Bay", at + Vector3(0, -0.3, 0), "bay")
			"flood":
				var wall_z := float(K.SHED_N)
				_box(&"girder", Vector3(at.x - 0.08, at.y - 0.08, wall_z), Vector3(at.x + 0.08, at.y + 0.08, at.z + 0.1))
				_box(&"bulb_warm", Vector3(at.x - 0.7, at.y - 0.25, at.z), Vector3(at.x + 0.7, at.y + 0.1, at.z + 0.3))
				_light(level, "Forecourt", at + Vector3(0, -0.4, 1.0), "flood")
			"flyover":
				# a pole on the north parapet's top, an arm out over the deck's edge.
				var pole_z := float(K.FLY_N) + float(K.WALL) * 0.5
				var parapet := float(K.FLY_Y) + float(K.FENCE)
				_box(&"girder", Vector3(at.x - 0.08, parapet, pole_z - 0.08), Vector3(at.x + 0.08, at.y + 0.3, pole_z + 0.08))
				_box(&"girder", Vector3(at.x - 0.05, at.y + 0.15, at.z - 0.05), Vector3(at.x + 0.05, at.y + 0.25, pole_z))
				_box(&"bulb_cool", at + Vector3(-0.6, -0.08, -0.2), at + Vector3(0.6, 0.15, 0.2))
				_light(level, "Flyover", at + Vector3(0, -0.4, -1.5), "flyover")
			"terminus":
				var to_wall := float(K.CONCOURSE[2]) - float(K.WALL) * 0.5 if at.z < 6.5 else float(K.CONCOURSE[3]) + float(K.WALL) * 0.5
				if at.z > 0.0 and at.z < 12.0:
					_box(&"girder", at + Vector3(-0.03, 0.1, -0.03), at + Vector3(0.03, 7.8 - at.y, 0.03))
				else:
					_box(&"girder", Vector3(at.x - 0.06, at.y - 0.06, minf(at.z, to_wall)), Vector3(at.x + 0.06, at.y + 0.06, maxf(at.z, to_wall)))
				_box(&"bulb_warm", at + Vector3(-0.5, -0.1, -0.5), at + Vector3(0.5, 0.0, 0.5))
				var light := _light(level, "Terminus", at + Vector3(0, -0.4, 0), "terminus")
				if at.x < -65.0:
					_finish_lamp = light
			"canal":
				var foot := Vector3(float(K.CANAL[0]) + 0.25, 0.0, at.z)
				_box(&"girder", foot + Vector3(-0.1, 0, -0.1), foot + Vector3(0.1, at.y + 0.2, 0.1))
				_box(&"girder", Vector3(at.x, at.y + 0.1, at.z - 0.06), Vector3(foot.x, at.y + 0.2, at.z + 0.06))
				_box(&"bulb_cool", at + Vector3(-0.3, -0.05, -0.3), at + Vector3(0.3, 0.1, 0.3))
				_light(level, "Canal", at + Vector3(0, -0.3, 0), "canal")

func _mast(level: Node3D, at: Vector3) -> void:
	# a lamp mast standing behind a fence or parapet, its arm reaching over the deck at `at`.
	var foot := at
	var loop: Vector3 = K.LOOP
	var reach := Vector3.ZERO
	if at.distance_to(Vector3(loop.x, at.y, loop.z)) < float(K.LOOP_OUT) + 2.0:
		var radial := (Vector3(at.x, 0, at.z) - Vector3(loop.x, 0, loop.z)).normalized()
		foot = Vector3(loop.x, 0, loop.z) + radial * (float(K.LOOP_OUT) + float(K.WALL) + 0.15)
		reach = Vector3(at.x, 0, at.z) - Vector3(foot.x, 0, foot.z)
		foot.y = _low()
	else:
		foot = Vector3(float(K.RAMP[1]) + float(K.WALL) + 0.4, _low(), at.z)
		reach = Vector3(at.x - foot.x, 0, 0)
	var top := at.y + 0.6
	_box(&"girder", Vector3(foot.x - 0.12, foot.y, foot.z - 0.12), Vector3(foot.x + 0.12, top, foot.z + 0.12))
	var tip := Vector3(foot.x, top, foot.z) + reach
	var lo := Vector3(minf(foot.x, tip.x) - 0.06, top - 0.12, minf(foot.z, tip.z) - 0.06)
	var hi := Vector3(maxf(foot.x, tip.x) + 0.06, top, maxf(foot.z, tip.z) + 0.06)
	_box(&"girder", lo, hi)
	_box(&"bulb_warm", tip + Vector3(-0.45, -0.25, -0.45), tip + Vector3(0.45, -0.12, 0.45))
	_light(level, "Mast", tip + Vector3(0, -0.8, 0), "mast")

## the scenery ground under the depot: 5 cm under the trackbed.
static func _low() -> float:
	return -1.25

# --- models -----------------------------------------------------------------------------------

func _trains(level: Node3D) -> void:
	# every parked car on its own prism: the level records feet, yaw and model; the model is
	# scaled uniformly from the train kit, so its wheels sit on the kit's own rails.
	var stock := Node3D.new()
	stock.name = "RollingStock"
	level.add_child(stock)
	var scale := Vector3.ONE * float(K.TRAIN_SCALE)
	var count := {}
	for car: Dictionary in level.get("trains"):
		var placed := ASSETS.place(stock, str(car.model), car.feet, scale, float(car.yaw))
		placed.name = str(car.name)
		count[str(car.model)] = int(count.get(str(car.model), 0)) + 1
	report["trains"] = count

func _track(parent: Node3D, from: Vector3, to: Vector3, sunk: float) -> int:
	# straight kit rails from `from` to `to` (along x or z), tops flush 2 cm over the surface.
	var model := "kenney-train/models/railroad-straight.glb"
	var b := ASSETS.bounds(model)
	var scale := float(K.TRAIN_SCALE)
	var piece := b.size.z * scale
	var span := to - from
	var length := Vector2(span.x, span.z).length()
	var yaw := atan2(span.x, span.z)
	var n := maxi(1, floori(length / piece))
	var dir := span.normalized()
	for i: int in n:
		var feet := from + dir * (piece * i) + Vector3.UP * (sunk - b.size.y * scale + 0.02)
		var placed := ASSETS.place(parent, model, feet, Vector3.ONE * scale, yaw)
		# the measured pivot centres the piece on its foot; each piece covers its own span.
		placed.position += dir * piece * 0.5
	return n

func _rails(level: Node3D) -> void:
	var rails := Node3D.new()
	rails.name = "Rails"
	level.add_child(rails)
	var bed := float(K.BED)
	var n := 0
	var cx := float(K.PLAT_X) + 0.15 + float(K.CAR_W) * 0.5
	for x: float in [-cx, cx]:
		n += _track(rails, Vector3(x, 0, float(K.PLAT_START) - 0.2), Vector3(x, 0, -72.0), bed)
	n += _track(rails, Vector3(0.0, 0, float(K.APRON_END)), Vector3(0.0, 0, -72.0), bed)
	var shed_floor := float(K.DECK_Y)
	for x: float in [(float(K.SHED_X0) + float(K.BAY_WM)) * 0.5, (float(K.BAY_WM) + float(K.BAY_ME)) * 0.5, float(K.E_TRAIN_X) + float(K.CAR_W) * 0.5 - 0.06]:
		n += _track(rails, Vector3(x, 0, float(K.SHED_S) + 0.6), Vector3(x, 0, float(K.SHED_N) - 0.6), shed_floor)
	var tr: Array = K.TRAVERSER
	n += _track(rails, Vector3(float(tr[0]) + 0.3, 0, (float(tr[2]) + float(tr[3])) * 0.5), Vector3(float(tr[1]) - 0.3, 0, (float(tr[2]) + float(tr[3])) * 0.5), float(K.DECK_Y))
	n += _track(rails, Vector3(22.0 - 9.0, 0, -104.0), Vector3(22.0 + 9.0, 0, -104.0), bed)
	# east sidings beside the shed and under the flyover.
	for x: float in [18.0, 23.5, 29.0]:
		n += _track(rails, Vector3(x, 0, -70.0), Vector3(x, 0, 24.0), _low() + 0.05)
	report["rail_pieces"] = n

func _prop(level: Node3D, model: String, feet: Vector3, height: float, yaw: float) -> Node3D:
	var node := ASSETS.place(level, model, feet, ASSETS.scale_for_height(model, height), yaw)
	var placed: Dictionary = report.get("props", {})
	placed[model] = int(placed.get(model, 0)) + 1
	report["props"] = placed
	return node

func _props(level: Node3D) -> void:
	if _neutral:
		return
	var props := Node3D.new()
	props.name = "Props"
	level.add_child(props)
	var g := _low()
	# stored stock in the east sidings, seen from the flyover and the ramp.
	var stock := [["kenney-train/models/train-carriage-tank.glb", 18.0, -60.0], ["kenney-train/models/train-carriage-tank.glb", 18.0, -53.6],
		["kenney-train/models/train-carriage-container-blue.glb", 23.5, -40.0], ["kenney-train/models/train-carriage-container-blue.glb", 23.5, -33.6],
		["kenney-train/models/train-carriage-flatbed-wood.glb", 29.0, -20.0], ["kenney-train/models/train-diesel-box-a.glb", 29.0, -13.6],
		["kenney-train/models/train-electric-city-a.glb", 18.0, 14.0], ["kenney-train/models/train-electric-city-a.glb", 18.0, 19.6]]
	for s: Array in stock:
		ASSETS.place(props, str(s[0]), Vector3(float(s[1]), g + 0.05, float(s[2])), Vector3.ONE * float(K.TRAIN_SCALE), 0.0)
	# industry beyond the sidings and the canal: water tower, chimneys, tanks, sheds.
	_prop(props, "kenney-industrial/models/water-tower.glb", Vector3(70.0, g, -12.0), 22.0, 0.4)
	_prop(props, "kenney-industrial/models/chimney-medium.glb", Vector3(-96.0, g, -70.0), 34.0, 0.0)
	_prop(props, "kenney-industrial/models/chimney-medium.glb", Vector3(-90.0, g, -78.0), 28.0, 0.0)
	_prop(props, "kenney-industrial/models/detail-tank-large.glb", Vector3(66.0, g, -60.0), 10.0, 1.2)
	_prop(props, "kenney-industrial/models/building-c.glb", Vector3(70.0, g, -95.0), 14.0, PI * 0.5)
	_prop(props, "kenney-industrial/models/building-m.glb", Vector3(-62.0, g, -40.0), 16.0, 0.0)
	_prop(props, "kenney-industrial/models/building-e.glb", Vector3(-64.0, g, 44.0), 15.0, PI)
	_prop(props, "kenney-industrial/models/building-t.glb", Vector3(-20.0, g, -118.0), 12.0, 0.3)
	# the shed's fittings, all overhead: hanging screens and a gantry hoist, over 3.6 m.
	_prop(props, "kenney-factory/models/screen-hanging-wide.glb", Vector3((float(K.SHED_X0) + float(K.BAY_WM)) * 0.5, 4.0, -60.0), 0.9, PI * 0.5)
	_prop(props, "kenney-factory/models/screen-hanging-wide.glb", Vector3((float(K.BAY_ME) + float(K.SHED_X1)) * 0.5, 4.0, -66.0), 0.9, -PI * 0.5)
	_prop(props, "kenney-factory/models/crane.glb", Vector3(43.0, 4.6, -64.0), 1.4, PI * 0.5)
	# street furniture on the terminus side of the canal, behind its wall.
	for k: int in 3:
		_prop(props, "kenney-retro-urban/models/detail-dumpster-closed.glb", Vector3(-47.5 - k * 1.5, 0.0, 24.0), 1.3, PI)

# --- labels -----------------------------------------------------------------------------------

func _sign(level: Node3D, label: String, text: String, at: Vector3, yaw: float, colour: Color, size: float, buzz: bool = false) -> Label3D:
	var sign := Label3D.new()
	sign.name = label
	sign.text = text
	sign.font_size = 96
	sign.pixel_size = size
	sign.modulate = colour
	sign.outline_size = 14
	sign.outline_modulate = Color(colour.r * 0.35, colour.g * 0.35, colour.b * 0.35, 0.85)
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.transform = Transform3D(Basis(Vector3.UP, yaw), at)
	if buzz:
		sign.set_meta("buzz", true)
	level.add_child(sign)
	_signs.append(sign)
	return sign

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
			label.modulate = Color("ffe08a")
			label.transform = Transform3D(Basis(Vector3.UP, float(mark.yaw)) * Basis(Vector3.RIGHT, -PI * 0.5), (mark.at as Vector3) + Vector3.UP * 0.012)
		else:
			label.pixel_size = 0.01
			label.modulate = Color("f2e6c4")
			label.outline_size = 8
			label.outline_modulate = Color(0.05, 0.05, 0.08, 0.8)
			label.transform = Transform3D(Basis(Vector3.UP, float(mark.yaw)), mark.at)
		marks.add_child(label)
	var fly_n := float(K.FLY_N) + float(K.WALL) + 0.08
	_sign(marks, "DepotSign", "NIGHT SHIFT  ·  DEPOT LINE", Vector3(0.0, float(K.FLY_BOTTOM) + 0.45, fly_n), 0.0, Color("ff4fd2"), 0.014, true)
	_sign(marks, "Platform1", "PLATFORM  1", Vector3(0.0, 3.6, float(K.PLAT_START) - 0.02), PI, Color("f4f7ff"), 0.012)
	for x: float in [-4.9, 4.9]:
		_sign(marks, "Roundel_%s" % ("w" if x < 0.0 else "e"), "1", Vector3(x, 3.4, 14.78), 0.0, Color("f4f7ff"), 0.008)
	_sign(marks, "ThroatSign", "THROAT  ·  SIGNALS  N1–N3", Vector3(-8.5, 1.3, float(K.THROAT_END) + 0.02), 0.0, Color("ffbf5a"), 0.008)
	_sign(marks, "BaysSign", "WASH BAYS  ·  ROADS 7–9", Vector3((float(K.SHED_X0) + float(K.SHED_X1)) * 0.5, 5.0, float(K.SHED_S) - 0.05), PI, Color("ffae3a"), 0.014)
	var wm := float(K.BAY_WM)
	var me := float(K.BAY_ME)
	_sign(marks, "Door1", "1", Vector3(wm + 0.27, 4.2, (float(K.DOOR_1[0]) + float(K.DOOR_1[1])) * 0.5), PI * 0.5, Color("2fe7ff"), 0.012)
	_sign(marks, "Door2", "2", Vector3((float(K.SHED_X0) + wm) * 0.5, 5.2, float(K.SHED_N) - 0.52), PI, Color("2fe7ff"), 0.012)
	_sign(marks, "ShutterSign", "JUMP + CROUCH", Vector3((float(K.SHUTTER[0]) + float(K.E_TRAIN_X)) * 0.5, 0.7, float(K.SHED_S) - 0.03), PI, Color("ffd04a"), 0.007)
	_sign(marks, "SignalBox", "SIGNAL BOX", Vector3(float(K.KNUCKLE.x) + float(K.KNUCKLE_IN) - 0.04, float(K.FLY_Y) + 3.4, float(K.KNUCKLE.z)), PI * 0.5, Color("2fe7ff"), 0.008)
	var c: Array = K.CONCOURSE
	_finish_sign = _sign(marks, "TerminusSign", "TERMINUS", Vector3(float(c[1]) + 0.02, 7.0, (float(c[2]) + float(c[3])) * 0.5), PI * 0.5, Color("2fe7ff"), 0.03)
	_sign(marks, "LoopSign", "TURNING LOOP", Vector3(float(K.R0[0]) + 0.02, 1.4, -82.0), PI * 0.5, Color("ffbf5a"), 0.007)
