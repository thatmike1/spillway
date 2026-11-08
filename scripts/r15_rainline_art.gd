extends RefCounted
## p / r15 Rainline art: everything the course draws, from the level's own records. the level
## calls dress() once at the end of build(); nothing here adds or moves a collision body, changes
## progress data or enters the geometry hash. reachable props carry the level's own box pieces.
##
## the look: a rainy rooftop district at night. roofs and decks are wet (darker, glossy, with
## puddles) and that is appearance only. brick and render facades carry a lit window grid; the
## sourced kenney retro urban, industrial, factory, space and train models dress roofs, facades,
## streets and the comms mast; the momentum kit's scanned brick, concrete and plate textures
## surface the solids. rain is falling streaks round the camera, not fog. light: a cool moon for
## shape, sodium lamps on the route, a warm lit lamp room, white scaffold lifts, lit windows.

const ASSETS := preload("res://scripts/r15_assets.gd")
const VERSION := "rainline-art-1"
const MOMENTUM := "res://assets/momentum/textures/"
## texture sets: base path (without _diff_1k etc.) and metres per repeat.
const SETS := {
	&"brick": {"base": MOMENTUM + "red_brick/red_brick", "metres": 1.6},
	&"concrete": {"base": MOMENTUM + "concrete_layers_02/concrete_layers_02", "metres": 2.5},
	&"brushed": {"base": MOMENTUM + "brushed_concrete/brushed_concrete", "metres": 2.0},
	&"plate": {"base": MOMENTUM + "metal_plate_02/metal_plate_02", "metres": 1.5},
}
## p / every prism kind: top set, side set and the surface parameters. "win" puts the lit window
## grid on its sides (fraction of windows lit), "wet" and "puddles" only change the look.
const LOOKS := {
	&"roof_tar": {"top": &"brushed", "side": &"brick", "top_tint": Color(0.42, 0.42, 0.45), "side_tint": Color(0.75, 0.62, 0.58), "wet": 0.55, "puddles": 0.6, "win": 0.32},
	&"roof_felt": {"top": &"concrete", "side": &"brick", "top_tint": Color(0.36, 0.38, 0.37), "side_tint": Color(0.62, 0.55, 0.52), "wet": 0.55, "puddles": 0.55, "win": 0.28},
	&"roof_gravel": {"top": &"concrete", "side": &"concrete", "top_tint": Color(0.55, 0.55, 0.56), "side_tint": Color(0.62, 0.6, 0.57), "wet": 0.45, "puddles": 0.45, "win": 0.3},
	&"brick_cap": {"top": &"concrete", "side": &"brick", "top_tint": Color(0.72, 0.72, 0.7), "side_tint": Color(0.7, 0.58, 0.55), "wet": 0.5, "puddles": 0.0, "win": 0.0},
	&"render": {"top": &"concrete", "side": &"concrete", "top_tint": Color(0.62, 0.6, 0.57), "side_tint": Color(0.86, 0.8, 0.7), "wet": 0.35, "puddles": 0.2, "win": 0.0},
	&"brick": {"top": &"concrete", "side": &"brick", "top_tint": Color(0.6, 0.6, 0.6), "side_tint": Color(0.8, 0.66, 0.6), "wet": 0.2, "puddles": 0.0, "win": 0.0},
	&"tower": {"top": &"concrete", "side": &"brick", "top_tint": Color(0.5, 0.5, 0.5), "side_tint": Color(0.6, 0.6, 0.62), "wet": 0.5, "puddles": 0.0, "win": 0.12, "desat": 0.6},
	&"concrete": {"top": &"concrete", "side": &"concrete", "top_tint": Color(0.6, 0.6, 0.6), "side_tint": Color(0.55, 0.55, 0.56), "wet": 0.5, "puddles": 0.35, "win": 0.0},
	&"workshop_floor": {"top": &"concrete", "side": &"brick", "top_tint": Color(0.78, 0.68, 0.56), "side_tint": Color(0.72, 0.6, 0.55), "wet": 0.0, "puddles": 0.0, "win": 0.3},
	&"grating": {"top": &"plate", "side": &"plate", "top_tint": Color(0.62, 0.66, 0.7), "side_tint": Color(0.22, 0.3, 0.34), "wet": 0.5, "puddles": 0.0, "win": 0.0, "metal": 0.6},
	&"board": {"top": &"plate", "side": &"plate", "top_tint": Color(0.78, 0.74, 0.62), "side_tint": Color(0.5, 0.48, 0.42), "wet": 0.45, "puddles": 0.0, "win": 0.0, "metal": 0.3},
	&"steel_paint": {"top": &"plate", "side": &"plate", "top_tint": Color(0.18, 0.34, 0.38), "side_tint": Color(0.16, 0.32, 0.36), "wet": 0.4, "puddles": 0.0, "win": 0.0, "metal": 0.5},
	&"steel_dark": {"top": &"plate", "side": &"plate", "top_tint": Color(0.22, 0.23, 0.25), "side_tint": Color(0.22, 0.23, 0.25), "wet": 0.4, "puddles": 0.0, "win": 0.0, "metal": 0.6},
	&"scaffold": {"top": &"plate", "side": &"plate", "top_tint": Color(0.4, 0.42, 0.44), "side_tint": Color(0.36, 0.38, 0.4), "wet": 0.4, "puddles": 0.0, "win": 0.0, "metal": 0.55},
	&"lamp_post": {"top": &"plate", "side": &"plate", "top_tint": Color(0.2, 0.21, 0.22), "side_tint": Color(0.2, 0.21, 0.22), "wet": 0.5, "puddles": 0.0, "win": 0.0, "metal": 0.7},
	&"lattice": {"top": &"plate", "side": &"plate", "top_tint": Color(0.75, 0.3, 0.22), "side_tint": Color(0.82, 0.32, 0.24), "wet": 0.3, "puddles": 0.0, "win": 0.0, "metal": 0.4},
	&"plant": {"top": &"plate", "side": &"plate", "top_tint": Color(0.5, 0.53, 0.55), "side_tint": Color(0.55, 0.58, 0.6), "wet": 0.45, "puddles": 0.0, "win": 0.0, "metal": 0.5, "ribs": 1.0},
	&"duct": {"top": &"plate", "side": &"plate", "top_tint": Color(0.72, 0.75, 0.78), "side_tint": Color(0.7, 0.73, 0.76), "wet": 0.5, "puddles": 0.0, "win": 0.0, "metal": 0.8, "ribs": 1.0},
	&"duct_floor": {"top": &"plate", "side": &"plate", "top_tint": Color(0.5, 0.52, 0.55), "side_tint": Color(0.5, 0.52, 0.55), "wet": 0.2, "puddles": 0.0, "win": 0.0, "metal": 0.6},
	&"timber": {"top": &"brushed", "side": &"brushed", "top_tint": Color(0.55, 0.38, 0.22), "side_tint": Color(0.45, 0.3, 0.18), "wet": 0.0, "puddles": 0.0, "win": 0.0},
	&"glass_frame": {"top": &"plate", "side": &"plate", "top_tint": Color(0.3, 0.42, 0.5), "side_tint": Color(0.25, 0.27, 0.3), "wet": 0.9, "puddles": 0.0, "win": 0.0, "metal": 0.7, "glaze": 1.0},
	&"facade_brick": {"top": &"concrete", "side": &"brick", "top_tint": Color(0.34, 0.34, 0.36), "side_tint": Color(0.62, 0.48, 0.44), "wet": 0.5, "puddles": 0.4, "win": 0.38},
	&"facade_render": {"top": &"concrete", "side": &"concrete", "top_tint": Color(0.36, 0.36, 0.38), "side_tint": Color(0.7, 0.64, 0.56), "wet": 0.45, "puddles": 0.4, "win": 0.42},
	&"facade_dark": {"top": &"brushed", "side": &"brick", "top_tint": Color(0.3, 0.3, 0.32), "side_tint": Color(0.4, 0.38, 0.4), "wet": 0.5, "puddles": 0.4, "win": 0.3, "desat": 0.5},
	&"street": {"top": &"brushed", "side": &"concrete", "top_tint": Color(0.2, 0.2, 0.22), "side_tint": Color(0.4, 0.4, 0.4), "wet": 0.8, "puddles": 0.8, "win": 0.0},
	&"pavement": {"top": &"concrete", "side": &"concrete", "top_tint": Color(0.4, 0.4, 0.42), "side_tint": Color(0.4, 0.4, 0.42), "wet": 0.7, "puddles": 0.6, "win": 0.0},
}
## flat colours for paints, the neutral attribution mode and unknown kinds.
const FLAT := {
	&"paint_yellow": Color("e3b12c"), &"paint_white": Color("e8e6de"), &"paint_dark": Color("1b1c1f"),
	&"roof_tar": Color("4a4b50"), &"roof_felt": Color("4c524f"), &"roof_gravel": Color("6c6c6e"), &"brick_cap": Color("8c7068"),
	&"render": Color("b3a796"), &"brick": Color("8a5a4c"), &"tower": Color("6e6e72"), &"concrete": Color("77787a"),
	&"workshop_floor": Color("9a8a72"), &"grating": Color("6f7880"), &"board": Color("9a9078"), &"steel_paint": Color("2c5560"),
	&"steel_dark": Color("36383c"), &"scaffold": Color("5c6064"), &"lamp_post": Color("2f3134"), &"lattice": Color("b54a36"), &"plant": Color("7d8488"),
	&"duct": Color("a8afb5"), &"duct_floor": Color("767a80"), &"timber": Color("6e4a2a"), &"glass_frame": Color("435866"),
	&"facade_brick": Color("6e4c44"), &"facade_render": Color("968a7a"), &"facade_dark": Color("4a4648"), &"street": Color("2c2d30"), &"pavement": Color("55575a"),
}
## meshes are merged by kind inside cells of this size, so each stays within the compatibility
## renderer's per-object light limit near the lamps that light it.
const CELL := 24.0

const SURFACE := """shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D top_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D top_arm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D side_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D side_arm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float top_tile = 2.0;
uniform float side_tile = 2.0;
uniform vec3 top_tint : source_color = vec3(1.0);
uniform vec3 side_tint : source_color = vec3(1.0);
uniform float desaturate = 0.3;
uniform float metal = 0.0;
uniform float wet = 0.5;
uniform float puddles = 0.0;
uniform float windows = 0.0;
uniform float ribs = 0.0;
uniform float glaze = 0.0;
uniform float floor_h = 3.1;
uniform float bay_w = 2.8;
uniform vec3 lit_color : source_color = vec3(1.0, 0.7, 0.4);
uniform float lit_energy = 1.4;
uniform float seed = 0.0;
varying vec3 wpos;
varying vec3 wnorm;
varying vec2 span;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	span = UV2;
}
void fragment() {
	bool top = wnorm.y > 0.7;
	float h = abs(wnorm.x) > abs(wnorm.z) ? wpos.z : wpos.x;
	vec3 albedo; vec3 arm;
	if (top) {
		vec2 uv = wpos.xz / top_tile;
		albedo = texture(top_albedo, uv).rgb * top_tint;
		arm = texture(top_arm, uv).rgb;
	} else {
		vec2 uv = vec2(h, -wpos.y) / side_tile;
		albedo = texture(side_albedo, uv).rgb * side_tint;
		arm = texture(side_arm, uv).rgb;
		if (ribs > 0.5) { albedo *= 0.82 + 0.18 * smoothstep(0.35, 0.5, abs(fract(h * 2.5) - 0.5)); }
	}
	float l = dot(albedo, vec3(0.299, 0.587, 0.114));
	albedo = mix(albedo, vec3(l), desaturate);
	float rough = arm.g;
	float wetness = wet;
	if (top) {
		float pud = smoothstep(0.58, 0.66, noise(wpos.xz * 0.31) * 0.72 + noise(wpos.xz * 1.7) * 0.28) * puddles;
		// rings from drops on the standing water, a look only.
		vec2 cell = floor(wpos.xz * 2.0);
		float t = fract(TIME * 0.9 + hash(cell));
		float ring = 1.0 - smoothstep(0.0, 0.06, abs(length(fract(wpos.xz * 2.0) - 0.5) - t * 0.45));
		albedo *= mix(1.0, 0.65, pud);
		wetness = max(wetness, pud);
		rough = mix(rough, 0.03, pud) + ring * pud * (1.0 - t) * 0.25;
	}
	if (!top) {
		// rain runs down the faces: darker vertical streaks.
		float streak = noise(vec2(h * 3.0, wpos.y * 0.15 + h)) * 0.5 + 0.5;
		albedo *= mix(1.0, 0.82, wetness * streak);
	}
	albedo *= mix(1.0, 0.7, wetness);
	rough = mix(rough, 0.12, wetness);
	vec3 emit = vec3(0.0);
	float metallic = metal * arm.b;
	if (glaze > 0.5 && top) {
		albedo = vec3(0.05, 0.08, 0.1); rough = 0.04; metallic = 0.0;
		emit = vec3(0.25, 0.32, 0.36) * 0.15;
	}
	if (!top && windows > 0.0) {
		float y_top = span.x - 1.3;
		float y_low = span.y + 0.8;
		if (wpos.y < y_top && wpos.y > y_low) {
			float face = floor(wnorm.x * 2.5) * 17.0 + floor(wnorm.z * 2.5) * 31.0;
			vec2 cellw = vec2(floor(h / bay_w), floor((y_top - wpos.y) / floor_h));
			vec2 f = vec2(fract(h / bay_w), fract((y_top - wpos.y) / floor_h));
			if (f.x > 0.24 && f.x < 0.76 && f.y > 0.2 && f.y < 0.7) {
				float r = hash(cellw + vec2(seed + face, face * 0.37));
				albedo = vec3(0.025, 0.03, 0.04); rough = 0.04; metallic = 0.0;
				if (r < windows) {
					float tone = hash(cellw * 1.7 + vec2(seed));
					vec3 c = tone > 0.82 ? vec3(0.45, 0.62, 1.0) : lit_color * (0.55 + 0.6 * tone);
					float blind = step(0.5, hash(cellw * 2.3 + face)) * smoothstep(0.42, 0.45, f.y) * 0.6;
					emit = c * lit_energy * (1.0 - blind);
				}
			} else if (f.x > 0.2 && f.x < 0.8 && f.y > 0.16 && f.y < 0.76) {
				albedo = vec3(0.16, 0.15, 0.14); rough = 0.4;
			}
		}
	}
	ALBEDO = albedo;
	ROUGHNESS = clamp(rough, 0.02, 1.0);
	METALLIC = metallic;
	SPECULAR = 0.5;
	AO = arm.r;
	EMISSION = emit;
}
"""

const NETTING := """shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform vec3 tint : source_color = vec3(0.12, 0.32, 0.36);
varying vec3 wpos;
varying vec3 wnorm;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wnorm = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz; }
void fragment() {
	float h = abs(wnorm.x) > abs(wnorm.z) ? wpos.z : wpos.x;
	vec2 g = abs(fract(vec2(h, wpos.y) * 9.0) - 0.5);
	float thread = step(0.36, max(g.x, g.y));
	float sag = 0.5 + 0.5 * sin(h * 1.3 + wpos.y * 0.7);
	ALBEDO = tint * (0.8 + 0.3 * sag);
	ALPHA = 0.28 + thread * 0.55;
	ROUGHNESS = 0.3;
	SPECULAR = 0.6;
}
"""

const GLASS := """shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
void fragment() {
	ALBEDO = vec3(0.12, 0.16, 0.18);
	ALPHA = 0.22;
	ROUGHNESS = 0.03;
	METALLIC = 0.2;
	SPECULAR = 0.9;
}
"""

var report := {"version": VERSION}
var _cache := {}
var _surfaces := {}
var _neutral := false
var _rng := RandomNumberGenerator.new()
var _rain: CPUParticles3D
var _splash: CPUParticles3D
var _beacons: Array[StandardMaterial3D] = []
var _finish_glow: OmniLight3D
var _finished := false
var _clock := 0.0
var _models := 0
var _lights := 0
var K: Dictionary = {}

## dresses the level once, from its records.
func dress(level: Node3D) -> void:
	var started := Time.get_ticks_usec()
	_neutral = str(level.get("material_mode")) == "neutral"
	K = (level.get_script() as Script).get_script_constant_map()
	_rng.seed = 1515
	_environment(level)
	_streets(level)
	_skyline(level)
	for prism: Dictionary in level.get("prisms"):
		_prism(prism)
	_commit(level)
	_lamps(level)
	_labels(level)
	if not _neutral:
		_props(level)
		_scaffold(level)
		_roofscape(level)
		_street_life(level)
		_mast(level)
		_rainfall(level)
	report["neutral"] = _neutral
	report["models"] = _models
	report["lights"] = _lights
	report["apply_ms"] = (Time.get_ticks_usec() - started) / 1000.0
	level.set_meta("rainline_art", report)

## presentation after a finish: the mast beacons and the finish lamp brighten. never touches physics.
func finished(_level: Node3D, on: bool) -> void:
	_finished = on

func tick(level: Node3D, delta: float) -> void:
	_clock += delta
	var blink := 1.0 if fmod(_clock, 1.6) < 0.25 else 0.15
	for m: StandardMaterial3D in _beacons:
		m.emission_energy_multiplier = (6.0 if _finished else 3.5) * blink
	if is_instance_valid(_finish_glow):
		_finish_glow.light_energy = move_toward(_finish_glow.light_energy, 4.0 if _finished else 2.0, delta * 3.0)
	# the rain box follows whatever camera renders: the runner's eye in play, a view camera in tests.
	var camera := level.get_viewport().get_camera_3d() if level.is_inside_tree() else null
	if camera != null and is_instance_valid(_rain):
		var ahead := -camera.global_transform.basis.z
		ahead.y = 0.0
		var at := camera.global_position + ahead.normalized() * 6.0
		_rain.global_position = at + Vector3.UP * 7.0
		_splash.global_position = Vector3(at.x, camera.global_position.y - 1.75, at.z)

# --- materials ------------------------------------------------------------------------------

func material(kind: StringName) -> Material:
	if _cache.has(kind):
		return _cache[kind]
	var made: Material
	if kind == &"netting":
		var net := ShaderMaterial.new()
		net.shader = _shader("netting", NETTING)
		made = net
	elif kind == &"glass":
		var glass := ShaderMaterial.new()
		glass.shader = _shader("glass", GLASS)
		made = glass
	elif String(kind).begins_with("paint") or _neutral or not LOOKS.has(kind):
		var flat := StandardMaterial3D.new()
		flat.albedo_color = FLAT.get(kind, Color("888888"))
		flat.roughness = 0.35
		if String(kind).begins_with("paint") and kind != &"paint_dark":
			# p / road-marking paint picks up the lamps: a faint glow keeps a lip readable in rain.
			flat.emission_enabled = true
			flat.emission = flat.albedo_color
			flat.emission_energy_multiplier = 0.22
		made = flat
	else:
		var look: Dictionary = LOOKS[kind]
		var m := ShaderMaterial.new()
		m.shader = _shader("surface", SURFACE)
		for slot: Array in [["top", look.top], ["side", look.side]]:
			var spec: Dictionary = SETS[slot[1]]
			m.set_shader_parameter(slot[0] + "_albedo", load("%s_diff_1k.png" % spec.base))
			m.set_shader_parameter(slot[0] + "_arm", load("%s_arm_1k.png" % spec.base))
			m.set_shader_parameter(slot[0] + "_tile", float(spec.metres))
		m.set_shader_parameter("top_tint", look.top_tint)
		m.set_shader_parameter("side_tint", look.side_tint)
		m.set_shader_parameter("wet", float(look.wet))
		m.set_shader_parameter("puddles", float(look.puddles))
		m.set_shader_parameter("windows", float(look.win))
		m.set_shader_parameter("metal", float(look.get("metal", 0.0)))
		m.set_shader_parameter("ribs", float(look.get("ribs", 0.0)))
		m.set_shader_parameter("glaze", float(look.get("glaze", 0.0)))
		m.set_shader_parameter("desaturate", float(look.get("desat", 0.3)))
		m.set_shader_parameter("seed", float(hash(kind) % 997))
		made = m
	_cache[kind] = made
	return made

func _shader(key: String, code: String) -> Shader:
	var k := "shader_" + key
	if not _cache.has(k):
		var shader := Shader.new()
		shader.code = code
		_cache[k] = shader
	return _cache[k]

func _emissive(colour: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.emission_enabled = true
	m.emission = colour
	m.emission_energy_multiplier = energy
	return m

# --- sky, moon and rain ---------------------------------------------------------------------

func _environment(level: Node3D) -> void:
	var world := WorldEnvironment.new()
	world.name = "Environment"
	var environment := Environment.new()
	var sky := Sky.new()
	var night := ProceduralSkyMaterial.new()
	# p / overcast night over a lit city: the cloud base takes the sodium glow at the horizon.
	night.sky_top_color = Color("0c121d")
	night.sky_horizon_color = Color("4a3a36")
	night.ground_horizon_color = Color("3a302e")
	night.ground_bottom_color = Color("0a0a0c")
	night.sky_curve = 0.12
	night.sun_angle_max = 0.0
	night.energy_multiplier = 1.0
	sky.sky_material = night
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("4d566a")
	environment.ambient_light_energy = 0.55
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.25
	environment.tonemap_white = 5.0
	# p / a thin haze for distance only (rain does the weather): 150 m still reads.
	environment.fog_enabled = true
	environment.fog_light_color = Color("2a2d36")
	environment.fog_density = 0.0055
	environment.fog_sky_affect = 0.4
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	environment.glow_bloom = 0.05
	environment.glow_hdr_threshold = 1.1
	world.environment = environment
	level.add_child(world)
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(35.0), 0.0)
	moon.light_color = Color("a9bde6")
	moon.light_energy = 0.42
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 90.0
	level.add_child(moon)
	report["moon"] = {"pitch": -52.0, "yaw": 35.0, "energy": 0.42}

func _rainfall(level: Node3D) -> void:
	# streaks fall through a box ahead of the camera in world space; splashes on the roof level
	# round the camera. the box follows the camera in tick(), so the weather is never a wall.
	var streak := QuadMesh.new()
	streak.size = Vector2(0.018, 0.6)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(0.62, 0.7, 0.82, 0.32)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	streak.material = m
	_rain = CPUParticles3D.new()
	_rain.name = "Rain"
	_rain.amount = 2600
	_rain.lifetime = 1.15
	_rain.preprocess = 1.2
	_rain.local_coords = false
	_rain.mesh = streak
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(18.0, 0.5, 18.0)
	_rain.direction = Vector3(0.12, -1.0, 0.05)
	_rain.spread = 2.0
	_rain.gravity = Vector3(0, -6.0, 0)
	_rain.initial_velocity_min = 13.0
	_rain.initial_velocity_max = 16.0
	_rain.color = Color(1, 1, 1, 1)
	_rain.custom_aabb = AABB(Vector3(-30, -40, -30), Vector3(60, 50, 60))
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(_rain)
	var dot := QuadMesh.new()
	dot.size = Vector2(0.06, 0.03)
	var sm := m.duplicate() as StandardMaterial3D
	sm.albedo_color = Color(0.7, 0.76, 0.86, 0.16)
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dot.material = sm
	_splash = CPUParticles3D.new()
	_splash.name = "Splashes"
	_splash.amount = 260
	_splash.lifetime = 0.28
	_splash.local_coords = false
	_splash.mesh = dot
	_splash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_splash.emission_box_extents = Vector3(9.0, 0.02, 9.0)
	_splash.direction = Vector3.UP
	_splash.spread = 35.0
	_splash.gravity = Vector3(0, -9.0, 0)
	_splash.initial_velocity_min = 0.6
	_splash.initial_velocity_max = 1.4
	_splash.scale_amount_min = 0.6
	_splash.scale_amount_max = 1.3
	_splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(_splash)
	report["rain"] = {"streaks": _rain.amount, "splashes": _splash.amount, "box_m": [36, 1, 36], "fall_mps": [13, 16]}

# --- prisms ---------------------------------------------------------------------------------

func _prism(prism: Dictionary) -> void:
	var kind: StringName = prism.kind
	if prism.has("hull"):
		_hull_faces(prism)
		return
	var top: Array = prism.top
	var base: float = prism.base
	if kind == &"netting":
		_netting(top, base)
		return
	var n := top.size()
	var centre := Vector3.ZERO
	var top_y := -INF
	for p: Vector3 in top:
		centre += p / n
		top_y = maxf(top_y, p.y)
	var key := "%s|%d|%d" % [kind, floori(centre.x / CELL), floori(centre.z / CELL)]
	var st := _st(key, kind)
	for i: int in range(1, n - 1):
		_tri(st, top[0], top[i], top[i + 1], Vector3.UP, true, Vector2(top_y, base))
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
		var span := Vector2(maxf(a.y, b.y), base)
		_tri(st, a, b, b0, out, false, span)
		_tri(st, a, b0, a0, out, false, span)

func _hull_faces(prism: Dictionary) -> void:
	# a general convex piece: each listed quad face, its normal turned away from the centre.
	var pts: Array = prism.hull
	var centre := Vector3.ZERO
	for p: Vector3 in pts:
		centre += p / pts.size()
	var st := _st("hull_" + str(prism.name), prism.kind)
	for face: Array in prism.faces:
		var a: Vector3 = pts[face[0]]
		var b: Vector3 = pts[face[1]]
		var c: Vector3 = pts[face[2]]
		var d: Vector3 = pts[face[3]]
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-10:
			n = (c - a).cross(d - a)
		n = n.normalized()
		if n.dot((a + c) * 0.5 - centre) < 0.0:
			n = -n
		var span := Vector2(maxf(maxf(a.y, b.y), maxf(c.y, d.y)), minf(minf(a.y, b.y), minf(c.y, d.y)))
		_tri(st, a, b, c, n, false, span)
		_tri(st, a, c, d, n, false, span)

func _netting(top: Array, base: float) -> void:
	# the netting draws as one sheet on its long inner face, a scaffold tube along its top.
	var a: Vector3 = top[0]
	var b: Vector3 = top[1]
	var st := _st("netting", &"netting")
	var span := Vector2(maxf(a.y, b.y), base)
	var a0 := Vector3(a.x, base + 0.5, a.z)
	var b0 := Vector3(b.x, base + 0.5, b.z)
	_tri(st, a, b, b0, Vector3.UP, false, span)
	_tri(st, a, b0, a0, Vector3.UP, false, span)
	_strut(&"lamp_post", a + Vector3.DOWN * 0.05, b + Vector3.DOWN * 0.05, 0.035)

func _st(key: String, kind: StringName) -> SurfaceTool:
	if not _surfaces.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_surfaces[key] = {"st": st, "kind": kind}
	return _surfaces[key].st

## a triangle facing `normal` (for a top, `up` asks for the polygon's own upward normal).
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, up: bool = false, span: Vector2 = Vector2.ZERO) -> void:
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
		st.set_uv2(span)
		st.add_vertex(v)

func _strut(kind: StringName, a: Vector3, b: Vector3, r: float) -> void:
	# a square member from a to b, half-width r, four quads with flat normals.
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.UP)
	if side.length_squared() < 1e-6:
		side = Vector3.RIGHT
	side = side.normalized() * r
	var up := side.cross(axis).normalized() * r
	var st := _st("strut_" + String(kind), kind)
	var corners := [side + up, -side + up, -side - up, side - up]
	for i: int in 4:
		var p: Vector3 = corners[i]
		var q: Vector3 = corners[(i + 1) % 4]
		var normal := ((p + q) * 0.5).normalized()
		_tri(st, a + p, a + q, b + q, normal)
		_tri(st, a + p, b + q, b + p, normal)

func _box(kind: StringName, lo: Vector3, hi: Vector3) -> void:
	_prism({"kind": kind, "top": [Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)], "base": lo.y})

func _commit(level: Node3D) -> void:
	var counts := {}
	for key: String in _surfaces:
		var entry: Dictionary = _surfaces[key]
		var instance := MeshInstance3D.new()
		instance.name = "Mesh_" + key.replace("|", "_")
		instance.mesh = (entry.st as SurfaceTool).commit()
		var kind: StringName = entry.kind
		instance.material_override = material(kind)
		if String(kind).begins_with("paint") or kind == &"netting" or kind == &"glass":
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		level.add_child(instance)
		counts[String(kind)] = int(counts.get(String(kind), 0)) + instance.mesh.get_faces().size() / 3
	_surfaces.clear()
	report["triangles"] = report.get("triangles", {})
	for k: String in counts:
		report.triangles[k] = int(report.triangles.get(k, 0)) + counts[k]

# --- streets and skyline (visual only, all far below or beyond the kill envelope) -------------

func _streets(level: Node3D) -> void:
	# street floors 18 m down: asphalt with pavements, lit by sodium lamps and shop windows.
	var y: float = float(K.STREET)
	for r: Array in [[8.35, 21.65, -137.0, 40.0], [-12.0, 90.0, -0.5, 9.0], [-12.0, 90.0, -137.0, -125.0], [21.65, 23.0, -125.0, -66.0], [53.3, 56.0, -124.0, -66.0], [60.0, 66.7, -66.0, -52.0]]:
		_box(&"street", Vector3(r[0], y - 1.0, r[2]), Vector3(r[1], y, r[3]))
	for r: Array in [[8.35, 10.6, -137.0, 40.0], [19.4, 21.65, -137.0, 40.0], [-12.0, 90.0, -0.5, 1.6], [-12.0, 90.0, 6.9, 9.0]]:
		_box(&"pavement", Vector3(r[0], y, r[2]), Vector3(r[1], y + 0.15, r[3]))
	# centre lines and tram rails on the second street.
	var z := -132.0
	while z < 36.0:
		_box(&"paint_white", Vector3(14.9, y + 0.005, z), Vector3(15.1, y + 0.01, z + 3.0))
		z += 6.0
	for rail_z: float in [3.6, 5.0]:
		_box(&"steel_dark", Vector3(-12.0, y, rail_z - 0.04), Vector3(90.0, y + 0.06, rail_z + 0.04))
	for at: Vector3 in [Vector3(15.0, y + 5.0, -10.0), Vector3(15.0, y + 5.0, -55.0), Vector3(15.0, y + 5.0, -100.0), Vector3(40.0, y + 5.0, 4.25), Vector3(75.0, y + 5.0, 4.25), Vector3(30.0, y + 5.0, -131.0)]:
		_light(level, at, Color("ff9e50"), 2.4, 18.0)

func _skyline(level: Node3D) -> void:
	# p / distant towers beyond the streets, silhouettes with lit windows. out of every reach.
	var kinds := [&"facade_brick", &"facade_render", &"facade_dark"]
	for i: int in 34:
		var a := TAU * i / 34.0 + _rng.randf_range(-0.05, 0.05)
		var r := _rng.randf_range(115.0, 190.0)
		var c := Vector3(25.0 + cos(a) * r, 0, -45.0 + sin(a) * r)
		var w := _rng.randf_range(14.0, 30.0)
		var d := _rng.randf_range(14.0, 28.0)
		var h := _rng.randf_range(8.0, 55.0) if i % 5 != 0 else _rng.randf_range(60.0, 95.0)
		_box(kinds[i % 3], Vector3(c.x - w * 0.5, float(K.STREET), c.z - d * 0.5), Vector3(c.x + w * 0.5, h, c.z + d * 0.5))
		if h > 50.0:
			var m := _emissive(Color("ff2a1c"), 3.5)
			_beacons.append(m)
			var lamp := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = 0.6
			s.height = 1.2
			lamp.mesh = s
			lamp.material_override = m
			lamp.position = Vector3(c.x, h + 1.0, c.z)
			level.add_child(lamp)
	# kenney industrial blocks as a nearer low skyline to the south-east, scaled up.
	var models := ["kenney-industrial/models/building-a.glb", "kenney-industrial/models/building-c.glb", "kenney-industrial/models/building-e.glb", "kenney-industrial/models/building-m.glb", "kenney-industrial/models/building-t.glb"]
	var spots := [Vector3(100, float(K.STREET), -60), Vector3(104, float(K.STREET), -20), Vector3(98, float(K.STREET), 25), Vector3(60, float(K.STREET), -160), Vector3(15, float(K.STREET), -158), Vector3(-45, float(K.STREET), -90), Vector3(-48, float(K.STREET), -35)]
	for i: int in spots.size():
		_model(level, models[i % models.size()], spots[i], deg_to_rad(90.0 * i), 18.0 + 3.0 * (i % 3))

# --- lamps ------------------------------------------------------------------------------------

func _lamps(level: Node3D) -> void:
	var head := BoxMesh.new()
	head.size = Vector3(0.5, 0.12, 0.28)
	var strip := BoxMesh.new()
	strip.size = Vector3(0.12, 0.04, 9.0)
	for lamp: Dictionary in level.get("lamps"):
		var at: Vector3 = lamp.at
		var colour: Color = lamp.colour
		var light := _light(level, at + Vector3.DOWN * 0.2, colour, float(lamp.energy), float(lamp.range))
		if str(lamp.purpose) == "finish":
			_finish_glow = light
		var fixture := MeshInstance3D.new()
		fixture.mesh = strip if lamp.mount == "strip" else head
		fixture.material_override = _emissive(colour, 4.0)
		fixture.position = at
		fixture.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		level.add_child(fixture)
		if lamp.mount == "post":
			var foot: Vector3 = lamp.foot
			_strut(&"lamp_post", Vector3(foot.x, at.y + 0.06, foot.z), Vector3(at.x, at.y + 0.06, at.z), 0.04)
		elif lamp.mount == "ceiling":
			_strut(&"lamp_post", at + Vector3.UP * 0.06, at + Vector3.UP * 0.2, 0.015)
	_commit(level)

func _light(level: Node3D, at: Vector3, colour: Color, energy: float, reach: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = colour
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.2
	light.shadow_enabled = false
	level.add_child(light)
	_lights += 1
	return light

# --- labels ------------------------------------------------------------------------------------

func _labels(level: Node3D) -> void:
	for mark: Dictionary in level.get("markings"):
		if mark.kind == "strip":
			continue
		var label := Label3D.new()
		label.name = "Label_" + str(mark.name)
		label.text = str(mark.text)
		label.font_size = 64
		label.pixel_size = 0.006 if mark.kind == "floor" else 0.005
		label.outline_size = 10
		label.modulate = Color("f4ead2") if mark.kind == "floor" else Color("ffd36a")
		label.outline_modulate = Color(0.05, 0.05, 0.06, 0.9)
		label.shaded = false
		label.double_sided = false
		var at: Vector3 = mark.at
		if mark.kind == "floor":
			label.position = at + Vector3.UP * 0.02
			label.rotation = Vector3(-PI * 0.5, float(mark.yaw), 0.0)
		else:
			label.position = at
			label.rotation = Vector3(0.0, float(mark.yaw), 0.0)
		level.add_child(label)
	# signs on the city: neon over the streets, read from the route.
	for sign: Array in [["NOČNÍ PEKÁRNA", Vector3(21.62, -9.0, -20.0), -PI * 0.5, Color("ff5a8a")], ["HOTEL RAINLINE", Vector3(22.0, 4.0, -28.0), -PI * 0.5, Color("6ad8ff")],
			["TISKÁRNA", Vector3(36.4, -5.0, -54.0), PI * 0.5, Color("ffc04a")], ["HALDEN", Vector3(39.0, 16.0, -65.9), 0.0, Color("ffffff")], ["SIGNÁL", Vector3(41.3, 1.0, 26.0), -PI * 0.5, Color("ff6a3a")]]:
		var neon := Label3D.new()
		neon.text = sign[0]
		neon.font_size = 128
		neon.pixel_size = 0.012
		neon.outline_size = 0
		neon.modulate = Color(sign[3]) * 2.2
		neon.shaded = false
		neon.position = sign[1]
		neon.rotation = Vector3(0, sign[2], 0)
		level.add_child(neon)
		_light(level, sign[1] + Vector3(sin(sign[2]), 0, cos(sign[2])) * -1.5, sign[3], 0.9, 7.0)

# --- sourced models ---------------------------------------------------------------------------

func _model(level: Node3D, model: String, feet: Vector3, yaw: float, height: float = 0.0, scale: Vector3 = Vector3.ZERO) -> Node3D:
	var s := scale
	if s == Vector3.ZERO:
		s = ASSETS.scale_for_height(model, height) if height > 0.0 else Vector3.ONE
	var node := ASSETS.place(level, model, feet, s, yaw)
	_models += 1
	return node

func _fit(model: String, box: Vector3) -> Vector3:
	# a scale that fills a collision box's footprint and height with the model's measured bounds.
	var b := ASSETS.bounds(model)
	return Vector3(box.x / maxf(b.size.x, 0.01), box.y / maxf(b.size.y, 0.01), box.z / maxf(b.size.z, 0.01))

func _props(level: Node3D) -> void:
	# the level's props: a reachable one fills its collision box, an out-of-reach one has a height.
	for prop: Dictionary in level.get("props"):
		var box: Vector3 = prop.box
		var node: Node3D
		if box != Vector3.ZERO:
			node = _model(level, prop.model, prop.feet, float(prop.yaw), 0.0, _fit(prop.model, box))
			node.set_meta("rainline_collision", prop.collision)
		else:
			node = _model(level, prop.model, prop.feet, float(prop.yaw), float(prop.height))
		node.name = "Prop_" + str(prop.name)

func _scaffold(level: Node3D) -> void:
	# kenney retro urban scaffold frames standing outside the netting from the street to the tower
	# top, 2.5 m bays, and boards of the next lift 3.6 m over the walking lift. all of it lies
	# outside the walking space or over the headroom, so none of it can be touched.
	var frame := "kenney-retro-urban/models/scaffolding-structure.glb"
	var floor := "kenney-retro-urban/models/scaffolding-floor.glb"
	var poles := "kenney-retro-urban/models/scaffolding-poles.glb"
	var t: Array = K.TOWER
	var bay := 2.5
	var transforms: Array[Transform3D] = []
	var boards: Array[Transform3D] = []
	var x0: float = float(t[0]) - float(K.SCAF_W) - 0.35 - bay * 0.5
	var x1: float = float(t[1]) + float(K.SCAF_W) + 0.35 + bay * 0.5
	var y0: float = float(K.STREET)
	var top: float = float(float(K.TOWER_TOP)) - 2.0
	# west and east faces along z, the south face along x.
	var z := float(t[2]) - bay * 0.5
	while z > float(t[3]) - float(K.SCAF_W) - 2.0:
		var y := y0
		while y < top:
			for x: float in [x0, x1]:
				transforms.append(_frame_at(frame, Vector3(x, y, z), Vector3(bay, bay, bay)))
			y += bay
		z -= bay
	var x := float(t[0]) - float(K.SCAF_W) + bay * 0.5
	while x < float(t[1]) + float(K.SCAF_W):
		var y := y0
		while y < top:
			transforms.append(_frame_at(frame, Vector3(x, y, float(t[3]) - float(K.SCAF_W) - 2.35 - bay * 0.5), Vector3(bay, bay, bay)))
			y += bay
		x += bay
	# p / the kit's pale palette blows out under the lamps; galvanised steel and the deck boards instead.
	_multi(level, frame, transforms, "ScaffoldFrames", &"scaffold")
	# the lift above the walkway, every 2.5 m.
	for piece: Dictionary in level.get("manifest"):
		if not str(piece.name).begins_with("s2_scaf_"):
			continue
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		var pts: Array = piece.points
		for i: int in pts.size() / 2:
			var p: Vector3 = pts[i]
			lo = lo.min(p)
			hi = hi.max(p)
		var bx := lo.x + bay * 0.5
		while bx < hi.x:
			var bz := lo.z + bay * 0.5
			while bz < hi.z:
				boards.append(_frame_at(floor, Vector3(bx, hi.y + 3.6, bz), Vector3(bay, 1.0, bay)))
				bz += bay
			bx += bay
		var rail := lo.y + 3.6
		_strut(&"lamp_post", Vector3(lo.x, rail, lo.z), Vector3(hi.x, rail, lo.z), 0.03)
		_strut(&"lamp_post", Vector3(lo.x, rail, hi.z), Vector3(hi.x, rail, hi.z), 0.03)
	_multi(level, floor, boards, "ScaffoldBoards", &"board")
	# poles in the street under the scaffold's first lift.
	var under: Array[Transform3D] = []
	z = float(t[2])
	while z > float(t[3]):
		for px: float in [float(t[0]) - float(K.SCAF_W) + 0.3, float(t[1]) + float(K.SCAF_W) - 0.3]:
			var y := y0
			while y < float(K.Y_GANTRY) - THIN_GAP:
				under.append(_frame_at(poles, Vector3(px, y, z), Vector3(0.5, bay, bay)))
				y += bay
		z -= bay
	_multi(level, poles, under, "ScaffoldPoles", &"scaffold")
	_commit(level)
	report["scaffold"] = {"frames": transforms.size(), "boards": boards.size(), "poles": under.size()}

const THIN_GAP := 1.2

func _frame_at(model: String, feet: Vector3, size: Vector3) -> Transform3D:
	# a wrapper transform like ASSETS.place: the measured centre at the feet, scaled to `size`.
	var b := ASSETS.bounds(model)
	var s := Vector3(size.x / maxf(b.size.x, 0.01), size.y / maxf(b.size.y, 0.01), size.z / maxf(b.size.z, 0.01))
	var pivot := -Vector3(b.position.x + b.size.x * 0.5, b.position.y, b.position.z + b.size.z * 0.5)
	return Transform3D(Basis.from_scale(s), feet) * Transform3D(Basis.IDENTITY, pivot)

func _multi(level: Node3D, model: String, transforms: Array[Transform3D], label: String, look: StringName = &"") -> void:
	# many copies of one sourced model as multimeshes, one per mesh inside its scene, with the
	# scene's own materials (or one of the map's looks over them) and node transforms. the source
	# files are untouched.
	if transforms.is_empty():
		return
	var scene := (load(ASSETS.ROOT + model) as PackedScene).instantiate() as Node3D
	var meshes: Array = []
	_collect_meshes(scene, Transform3D.IDENTITY, meshes)
	for k: int in meshes.size():
		var entry: Array = meshes[k]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = entry[0]
		multi.instance_count = transforms.size()
		for i: int in transforms.size():
			multi.set_instance_transform(i, transforms[i] * (entry[1] as Transform3D))
		var instance := MultiMeshInstance3D.new()
		instance.name = "%s_%d" % [label, k]
		instance.multimesh = multi
		if look != &"":
			instance.material_override = material(look)
		instance.set_meta("r15_asset", model)
		level.add_child(instance)
	scene.free()
	_models += transforms.size()

func _collect_meshes(node: Node, parent: Transform3D, out: Array) -> void:
	var here := parent
	if node is Node3D:
		here = parent * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append([(node as MeshInstance3D).mesh, here])
	for child: Node in node.get_children():
		_collect_meshes(child, here, out)

func _roofscape(level: Node3D) -> void:
	# kit on roofs out of reach: a water tower, chimneys, tanks, solar arrays, roof plant.
	var y_w1 := 6.0
	_model(level, "kenney-industrial/models/water-tower.glb", Vector3(-18.0, y_w1, -4.0), 0.4, 9.0)
	for at: Vector3 in [Vector3(-22.0, 2.6, -30.0), Vector3(-14.0, 2.6, -50.0), Vector3(30.0, 4.5, -20.0), Vector3(-6.0, 9.0, 30.0), Vector3(80.0, 6.0, -30.0)]:
		_model(level, "kenney-industrial/models/chimney-medium.glb", at, 0.0, 5.0)
	for at: Vector3 in [Vector3(28.0, 4.5, -8.0), Vector3(14.0, 5.0, 30.0), Vector3(75.0, 3.5, 30.0)]:
		_model(level, "kenney-industrial/models/detail-tank-large.glb", at, 1.0, 2.6)
	for i: int in 4:
		_model(level, "kenney-industrial/models/solar-panel-landscape.glb", Vector3(26.0 + 3.2 * i, 7.0, 30.0), PI, 1.2)
		_model(level, "kenney-industrial/models/solar-panel-landscape.glb", Vector3(60.0 + 3.2 * i, 1.0, -90.0), 0.0, 1.2)
	for at: Vector3 in [Vector3(76.0, 6.0, -12.0), Vector3(84.0, 6.0, -50.0), Vector3(-20.0, 6.0, 4.0)]:
		_model(level, "kenney-retro-urban/models/roof-metal-type-b.glb", at, 0.0, 2.2)
	for at: Vector3 in [Vector3(66.0, 1.0, -80.0), Vector3(72.0, 1.0, -100.0)]:
		_model(level, "kenney-factory/models/machine.glb", at, 0.5, 1.4)
	# the tower's roof: a lift house and dishes over the scaffold.
	_model(level, "kenney-space/models/satelliteDish.glb", Vector3(44.0, float(K.TOWER_TOP), -70.0), 2.2, 3.0)
	_model(level, "kenney-industrial/models/water-tower.glb", Vector3(36.0, float(K.TOWER_TOP), -100.0), 1.0, 8.0)

func _street_life(level: Node3D) -> void:
	# facades on the streets the route crosses: fire escapes, awnings, wall lamps, dumpsters, cables,
	# and a tram in the second street. all far below the route.
	var y: float = float(K.STREET)
	var esc_b := "kenney-retro-urban/models/balcony-type-a.glb"
	var esc_l := "kenney-retro-urban/models/balcony-ladder-bottom.glb"
	# [face x, z, yaw]: the print works block and the tannery on the first street, the south block.
	for spot: Array in [[21.75, -14.0, -PI * 0.5], [21.75, -32.0, -PI * 0.5], [8.6, -14.0, PI * 0.5], [8.6, -32.0, PI * 0.5], [7.75, -72.0, PI * 0.5], [7.75, -94.0, PI * 0.5]]:
		for f: int in 5:
			var fy := y + 3.2 + 3.1 * f
			if fy > -5.0:
				break
			_model(level, esc_b, Vector3(spot[0], fy, spot[1]), spot[2], 0.0, Vector3(3.0, 3.0, 3.0))
			_model(level, esc_l, Vector3(spot[0], fy - 2.2, float(spot[1]) + 0.9), spot[2], 0.0, Vector3(3.0, 3.0, 3.0))
	for z: float in [-8.0, -26.0, -44.0, -84.0]:
		_model(level, "kenney-retro-urban/models/detail-awning-small.glb", Vector3(21.3, y + 3.0, z), -PI * 0.5, 0.0, Vector3(5.0, 4.0, 5.0))
		_model(level, "kenney-retro-urban/models/detail-light-single.glb", Vector3(21.6, y + 4.5, z + 3.0), -PI * 0.5, 2.2)
		_model(level, "kenney-retro-urban/models/detail-dumpster-closed.glb", Vector3(20.4, y + 0.15, z - 4.0), PI * 0.5, 1.4)
	for x: float in [30.0, 46.0, 72.0]:
		_model(level, "kenney-retro-urban/models/detail-awning-small.glb", Vector3(x, y + 3.0, 8.9), PI, 0.0, Vector3(5.0, 4.0, 5.0))
	for z: float in [-35.0, -62.0, -88.0]:
		_model(level, "kenney-retro-urban/models/detail-cables-type-a.glb", Vector3(15.0, -7.5, z), PI * 0.5, 0.0, Vector3(13.4, 6.0, 1.0))
	_model(level, "kenney-train/models/train-tram-modern.glb", Vector3(32.0, y, 4.3), PI * 0.5, 3.4)
	_model(level, "kenney-train/models/train-tram-modern.glb", Vector3(36.6, y, 4.3), PI * 0.5, 3.4)
	_model(level, "kenney-industrial/models/shipping-container-a.glb", Vector3(60.0, y, -60.0), 0.2, 2.6)


func _mast(level: Node3D) -> void:
	# the comms mast: four legs (collision pieces) braced from 3.5 m up, with dishes and red
	# aircraft beacons that blink.
	var m: Array = K.MAST
	var y: float = float(K.Y_DECK)
	var legs: Array[Vector3] = []
	for i: int in 4:
		legs.append(Vector3(float(m[0]) + 0.925 if i % 2 == 0 else float(m[1]) - 0.925, 0.0, float(m[2]) + 0.925 if i < 2 else float(m[3]) - 0.925))
	var order := [0, 1, 3, 2]
	var level_y := y + 0.6 + 3.5
	while level_y < y + 33.0:
		for k: int in 4:
			var a: Vector3 = legs[order[k]]
			var b: Vector3 = legs[order[(k + 1) % 4]]
			_strut(&"lattice", Vector3(a.x, level_y, a.z), Vector3(b.x, level_y + 2.5, b.z), 0.05)
			_strut(&"lattice", Vector3(a.x, level_y, a.z), Vector3(b.x, level_y, b.z), 0.04)
		level_y += 2.5
	_commit(level)
	for k: int in 3:
		_model(level, "kenney-space/models/satelliteDish_detailed.glb", Vector3(54.0 + (k - 1) * 1.6, y + 14.0 + 6.0 * k, 40.5 + (k - 1) * 1.6), TAU * k / 3.0, 1.8)
	for h: float in [16.0, 34.5]:
		var beacon := _emissive(Color("ff2418"), 3.5)
		_beacons.append(beacon)
		var lamp := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.25
		s.height = 0.5
		lamp.mesh = s
		lamp.material_override = beacon
		lamp.position = Vector3(54.0, y + h, 40.5)
		level.add_child(lamp)
	_light(level, Vector3(54.0, y + 34.0, 40.5), Color("ff3020"), 1.5, 20.0)
