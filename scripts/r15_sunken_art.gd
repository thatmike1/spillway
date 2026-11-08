extends RefCounted
## p / Sunken Court dressing: sky and sun, the sandstone surfaces of the level's own prisms, the
## pools and the river, the library models the course stands on, and the scenery round it. it reads
## the level's records (prisms, models, pools, markings) and never adds route collision: the only
## bodies it makes are none. scenery models stand out of reach (on land behind walls a jump cannot
## clear, on wall tops, in the river under the kill line or hanging on faces), so they need none.
## the surface shader is original, in this file: flagstones on tops, ashlar courses on faces, moss
## in joints and low on walls. the models keep their own kenney materials and colour map.

const ASSETS := preload("res://scripts/r15_assets.gd")
const VERSION := "sunken-art-1"
const LIB := "kenney-castle/models/"
const NAT := "kenney-nature/models/"

## p / the looks of every prism kind: stone tones a/b (warm sandstone matched by eye to the kenney
## castle colour map), joint and moss colours, flagstone size (m), ashlar course height and block
## length (m), moss amount on tops and on faces.
const LOOKS := {
	&"flag": {"a": Color("c9ab82"), "b": Color("b8966c"), "joint": Color("8c7458"), "moss": Color("6f8a4a"), "flag": Vector2(1.6, 1.1), "course": 0.55, "block": 1.3, "moss_top": 0.12, "moss_side": 0.35},
	&"ashlar": {"a": Color("d8a77c"), "b": Color("c99468"), "joint": Color("7d5a40"), "moss": Color("5f7d3e"), "flag": Vector2(1.4, 1.0), "course": 0.6, "block": 1.4, "moss_top": 0.35, "moss_side": 0.45},
	&"architrave": {"a": Color("d9b98f"), "b": Color("c9a67c"), "joint": Color("7a5c42"), "moss": Color("5f7d3e"), "flag": Vector2(4.0, 1.2), "course": 0.38, "block": 4.0, "moss_top": 0.2, "moss_side": 0.5},
	&"vault": {"a": Color("b88a63"), "b": Color("a77b56"), "joint": Color("5e4532"), "moss": Color("4f6b35"), "flag": Vector2(1.2, 0.9), "course": 0.45, "block": 0.9, "moss_top": 0.4, "moss_side": 0.6},
	&"stair": {"a": Color("bfa27a"), "b": Color("ad8f68"), "joint": Color("7a6248"), "moss": Color("66823f"), "flag": Vector2(4.0, 0.42), "course": 0.42, "block": 1.0, "moss_top": 0.15, "moss_side": 0.4},
	&"moss": {"a": Color("7e9a52"), "b": Color("6c8a45"), "joint": Color("4a5f30"), "moss": Color("55753a"), "flag": Vector2(0.9, 0.7), "course": 0.5, "block": 1.0, "moss_top": 0.7, "moss_side": 0.7},
	&"pool_floor": {"a": Color("8f9a78"), "b": Color("7e8b6a"), "joint": Color("4f5a40"), "moss": Color("4f6f38"), "flag": Vector2(1.5, 1.5), "course": 0.6, "block": 1.4, "moss_top": 0.55, "moss_side": 0.6},
	&"column": {"a": Color("e3cfae"), "b": Color("d3bc96"), "joint": Color("8e7558"), "moss": Color("5f7d3e"), "flag": Vector2(3.0, 3.0), "course": 0.9, "block": 9.0, "moss_top": 0.2, "moss_side": 0.3},
	&"land": {"a": Color("67803f"), "b": Color("5a7337"), "joint": Color("5a7438"), "moss": Color("5c7a3a"), "flag": Vector2(7.0, 5.0), "course": 1.6, "block": 3.0, "moss_top": 0.0, "moss_side": 0.0},
	&"cliff": {"a": Color("a08066"), "b": Color("8c6f58"), "joint": Color("5c4838"), "moss": Color("5a7438"), "flag": Vector2(3.0, 2.0), "course": 1.4, "block": 2.6, "moss_top": 0.6, "moss_side": 0.25},
}
const FLAT := {
	&"paint_lip": Color("f4e7c2"), &"paint_duck": Color("e9a640"), &"paint_finish": Color("fbf3dc"),
	&"flag": Color("dfc49a"), &"ashlar": Color("cf9c70"), &"vault": Color("ad8059"), &"architrave": Color("d2b089"), &"stair": Color("d4b890"),
	&"moss": Color("749349"), &"pool_floor": Color("86926f"), &"column": Color("dbc6a2"), &"land": Color("76934a"), &"cliff": Color("967861"),
}
## p / a high warm sun from behind the start, a little to the right: arches throw their shadows
## forward along the route and every landing top is lit.
const SUN_YAW := 35.0
const SUN_PITCH := -50.0

const STONE := """shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// p / sunken court stone: world-space flagstones on up-facing faces, ashlar courses on walls,
// darker joints, moss in the joints and in noise patches. no textures, no mesh uvs.
uniform vec3 tone_a : source_color = vec3(0.9, 0.81, 0.65);
uniform vec3 tone_b : source_color = vec3(0.85, 0.72, 0.55);
uniform vec3 joint : source_color = vec3(0.55, 0.45, 0.35);
uniform vec3 moss : source_color = vec3(0.43, 0.54, 0.29);
uniform vec2 flag_size = vec2(1.6, 1.1);
uniform float course = 0.55;
uniform float block = 1.3;
uniform float moss_top = 0.12;
uniform float moss_side = 0.35;
uniform float joint_width = 0.035;
varying vec3 wpos;
varying vec3 wnrm;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) { return noise(p) * 0.55 + noise(p * 2.13 + 7.1) * 0.3 + noise(p * 4.37 + 3.3) * 0.15; }
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec2 uv;
	vec2 size;
	float mossy;
	if (abs(wnrm.y) > 0.6) {
		uv = wpos.xz;
		size = flag_size;
		mossy = moss_top;
	} else {
		vec2 t = normalize(vec2(-wnrm.z, wnrm.x) + vec2(1e-5));
		uv = vec2(dot(wpos.xz, t), wpos.y);
		size = vec2(block, course);
		mossy = moss_side;
	}
	vec2 g = uv / size;
	float row = floor(g.y);
	g.x += mod(row, 2.0) * 0.5 + hash(vec2(row, 3.7)) * 0.3;
	vec2 cell = floor(g);
	vec2 f = fract(g);
	vec2 edge = min(f, 1.0 - f) * size;
	float j = 1.0 - smoothstep(joint_width * 0.5, joint_width, min(edge.x, edge.y));
	float h = hash(cell);
	vec3 stone = mix(tone_a, tone_b, h);
	stone *= 0.9 + 0.2 * fbm(uv * 3.1);
	float patch = smoothstep(0.55, 0.8, fbm(uv * 0.35 + cell * 0.01)) * mossy;
	float low = abs(wnrm.y) > 0.6 ? 0.0 : smoothstep(1.4, 0.0, fract(wpos.y / 6.0) * 6.0) * mossy * 0.6;
	vec3 col = mix(stone, joint, j * 0.85);
	col = mix(col, moss * (0.85 + 0.3 * noise(uv * 5.0)), clamp(max(patch, low) + j * mossy, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = 0.88 - j * 0.1;
	SPECULAR = 0.3;
}
"""

const WATER := """shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;
// p / sunlit water: shallow teal over the court and cistern stone, deep green in the river.
uniform vec3 shallow : source_color = vec3(0.32, 0.55, 0.5);
uniform vec3 deep : source_color = vec3(0.08, 0.2, 0.2);
uniform float alpha = 0.55;
uniform vec3 sun_dir = vec3(0.4, 0.7, 0.5);
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz * 0.35;
	float t = TIME;
	vec2 g = vec2(cos(p.x * 2.3 + t * 0.8) + cos((p.x + p.y) * 3.1 + t * 1.2) * 0.5, cos(p.y * 1.9 - t * 0.6) + cos((p.x - p.y) * 3.9 - t) * 0.5);
	vec3 n = normalize(vec3(g.x * 0.05, 1.0, g.y * 0.05));
	vec3 view = normalize((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz - CAMERA_POSITION_WORLD);
	float fresnel = pow(1.0 - max(dot(-view, n), 0.0), 3.0);
	float glint = pow(max(dot(reflect(view, n), normalize(sun_dir)), 0.0), 180.0) * 3.0;
	ALBEDO = mix(shallow, deep, 0.35 + g.x * 0.05);
	EMISSION = vec3(0.55, 0.7, 0.8) * fresnel * 0.25 + vec3(1.0, 0.95, 0.8) * glint;
	ALPHA = clamp(alpha + fresnel * 0.3, 0.0, 1.0);
	ROUGHNESS = 0.12;
	SPECULAR = 0.6;
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
}
"""

var report := {"version": VERSION}
var _cache := {}
var _surfaces := {}
var _neutral := false
var _finish_light: OmniLight3D
var _glow := 0.0
var _finished := false
var _rng := RandomNumberGenerator.new()
## the level script's constants, read once.
var K: Dictionary = {}

## dresses the level once, from its records.
func dress(level: Node3D) -> void:
	var started := Time.get_ticks_usec()
	_neutral = str(level.get("material_mode")) == "neutral"
	K = (level.get_script() as Script).get_script_constant_map()
	_rng.seed = 1507
	_environment(level)
	for prism: Dictionary in level.get("prisms"):
		_prism(prism.top, prism.bottom, prism.kind)
	_land()
	_commit(level)
	_water(level)
	var placed := _course_models(level)
	report["course_models"] = placed
	_scenery(level)
	_labels(level)
	_finish_glow(level)
	report["neutral"] = _neutral
	report["apply_ms"] = (Time.get_ticks_usec() - started) / 1000.0
	level.set_meta("sunken_art", report)

## presentation after a finish: the sanctuary light warms. never touches physics.
func finished(_level: Node3D, on: bool) -> void:
	_finished = on

func tick(_level: Node3D, delta: float) -> void:
	_glow = move_toward(_glow, 1.0 if _finished else 0.0, delta * 1.5)
	if is_instance_valid(_finish_light):
		_finish_light.light_energy = 0.6 + _glow * 3.0

# --- materials ------------------------------------------------------------------------------------

func material(kind: StringName) -> Material:
	if _cache.has(kind):
		return _cache[kind]
	var made: Material
	if String(kind).begins_with("paint") or _neutral or not LOOKS.has(kind):
		var flat := StandardMaterial3D.new()
		flat.albedo_color = FLAT.get(kind, Color("888888"))
		flat.roughness = 0.8
		made = flat
	else:
		var look: Dictionary = LOOKS[kind]
		var shader := _shader("stone", STONE)
		var stone := ShaderMaterial.new()
		stone.shader = shader
		stone.set_shader_parameter("tone_a", look.a)
		stone.set_shader_parameter("tone_b", look.b)
		stone.set_shader_parameter("joint", look.joint)
		stone.set_shader_parameter("moss", look.moss)
		stone.set_shader_parameter("flag_size", look.flag)
		stone.set_shader_parameter("course", look.course)
		stone.set_shader_parameter("block", look.block)
		stone.set_shader_parameter("moss_top", look.moss_top)
		stone.set_shader_parameter("moss_side", look.moss_side)
		made = stone
	_cache[kind] = made
	return made

func _shader(key: String, code: String) -> Shader:
	var id := "shader_" + key
	if not _cache.has(id):
		var shader := Shader.new()
		shader.code = code
		_cache[id] = shader
	return _cache[id]

# --- sky, sun, water ------------------------------------------------------------------------------

func _environment(level: Node3D) -> void:
	var world := WorldEnvironment.new()
	world.name = "Environment"
	var environment := Environment.new()
	var sky := Sky.new()
	var procedural := ProceduralSkyMaterial.new()
	procedural.sky_top_color = Color("3f78c2")
	procedural.sky_horizon_color = Color("bcd3e6")
	procedural.ground_horizon_color = Color("b9c8b0")
	procedural.ground_bottom_color = Color("5d6b48")
	procedural.sun_angle_max = 20.0
	sky.sky_material = procedural
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_white = 6.0
	environment.tonemap_exposure = 0.85
	environment.fog_enabled = true
	environment.fog_light_color = Color("c9d8e6")
	environment.fog_density = 0.0016
	environment.fog_aerial_perspective = 0.5
	environment.fog_sky_affect = 0.1
	world.environment = environment
	level.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation = Vector3(deg_to_rad(SUN_PITCH), deg_to_rad(SUN_YAW), 0.0)
	sun.light_energy = 1.05
	sun.light_color = Color("fff0d2")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	level.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.rotation = Vector3(deg_to_rad(-60.0), deg_to_rad(SUN_YAW + 180.0), 0.0)
	fill.light_energy = 0.25
	fill.light_color = Color("a9c4e8")
	level.add_child(fill)

func _water(level: Node3D) -> void:
	var to_sun := Basis.from_euler(Vector3(deg_to_rad(SUN_PITCH), deg_to_rad(SUN_YAW), 0.0)) * Vector3.BACK
	# the river: one broad plane under everything, out to the horizon.
	var river := MeshInstance3D.new()
	river.name = "River"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(900, 900)
	river.mesh = mesh
	river.position = Vector3(20, float(K.RIVER_Y), -60)
	river.material_override = _water_material(Color("2f6a63"), Color("0d2f2e"), 0.92, to_sun)
	river.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(river)
	# the court pool and the cistern: shallow sheets 6 cm over their stone floors.
	for i: int in (level.get("pools") as Array).size():
		var p: Array = (level.get("pools") as Array)[i]
		var sheet := MeshInstance3D.new()
		sheet.name = "Pool_%d" % i
		var plane := PlaneMesh.new()
		plane.size = Vector2(absf(float(p[1]) - float(p[0])), absf(float(p[3]) - float(p[2])))
		sheet.mesh = plane
		sheet.position = Vector3((float(p[0]) + float(p[1])) * 0.5, float(p[4]), (float(p[2]) + float(p[3])) * 0.5)
		sheet.material_override = _water_material(Color("5f9c8d"), Color("23524b"), 0.5, to_sun)
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		level.add_child(sheet)

func _water_material(shallow: Color, deep: Color, alpha: float, to_sun: Vector3) -> Material:
	if _neutral:
		var flat := StandardMaterial3D.new()
		flat.albedo_color = Color(shallow, alpha)
		flat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		return flat
	var water := ShaderMaterial.new()
	water.shader = _shader("water", WATER)
	water.set_shader_parameter("shallow", shallow)
	water.set_shader_parameter("deep", deep)
	water.set_shader_parameter("alpha", alpha)
	water.set_shader_parameter("sun_dir", to_sun)
	return water

# --- prisms ---------------------------------------------------------------------------------------

func _prism(top: Array, bottom: Array, kind: StringName) -> void:
	# a convex prism: the top polygon, the bottom polygon (seen from below under a vault) and the
	# side quads between them. flat normals, godot's clockwise fronts.
	var st := _st(kind)
	var n := top.size()
	var centre := Vector3.ZERO
	for p: Vector3 in top:
		centre += p / n
	for i: int in range(1, n - 1):
		_tri(st, top[0], top[i], top[i + 1], Vector3.UP, 1)
		_tri(st, bottom[0], bottom[i], bottom[i + 1], Vector3.DOWN, -1)
	for i: int in n:
		var a: Vector3 = top[i]
		var b: Vector3 = top[(i + 1) % n]
		var a0: Vector3 = bottom[i]
		var b0: Vector3 = bottom[(i + 1) % n]
		if Vector2(b.x - a.x, b.z - a.z).length_squared() < 1e-8:
			continue
		var out := (b - a).cross(Vector3.UP).normalized()
		var mid := (a + b) * 0.5
		if out.dot(Vector3(mid.x - centre.x, 0, mid.z - centre.z)) < 0.0:
			out = -out
		_tri(st, a, b, b0, out, 0)
		_tri(st, a, b0, a0, out, 0)

## a triangle facing `normal`; facing +1 asks for the polygon's own upward normal, -1 downward.
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, facing: int) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	var face := n.normalized()
	if facing > 0 and face.y < 0.0:
		face = -face
	elif facing < 0 and face.y > 0.0:
		face = -face
	elif facing == 0:
		face = normal
	if n.dot(face) > 0.0:
		var swap := b
		b = c
		c = swap
	for v: Vector3 in [a, b, c]:
		st.set_normal(face)
		st.add_vertex(v)

func _box(kind: StringName, lo: Vector3, hi: Vector3) -> void:
	var top := [Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]
	var bottom := [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z)]
	_prism(top, bottom, kind)

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

func _land() -> void:
	# p / the ground round the course, every top 0.2 m under the wall beside it or lower and behind a
	# wall a jump cannot clear: none of it is reachable, so none of it has collision. its faces drop
	# to the river as cliffs.
	var down := float(K.RIVER_Y) - 2.0
	var high := float(K.TERRACE_Y) + float(K.WALL_UP) - 0.2
	var court := float(K.BALCONY_Y) + 2.4 - 0.2
	for r: Array in [
		# [x0, x1, z0, z1, top]
		[-90.0, -8.8, 60.0, -40.7, high], [8.8, 20.0, 60.0, -40.7, high], [-8.8, 8.8, 60.0, 15.0, high],
		[-90.0, -24.0, -40.7, -101.5, court], [-90.0, -24.0, -101.5, -125.0, -1.0],
		[24.0, 27.0, -40.7, -101.5, court], [20.0, 27.0, -40.7, -34.0, high],
		[57.0, 110.0, 60.0, -63.0, 9.3], [20.0, 57.0, 60.0, 12.8, 11.4], [20.0, 20.2, 12.8, -6.8, 11.4],
		[20.0, 49.2, -6.8, -33.0, 9.0],
	]:
		_box(&"land", Vector3(r[0], down, r[3]), Vector3(r[1], r[4], r[2]))
	# rock banks along the river's far side.
	for r: Array in [[-90.0, 110.0, -150.0, -200.0, 2.0], [60.0, 110.0, -63.0, -150.0, 1.0]]:
		_box(&"cliff", Vector3(r[0], down, r[3]), Vector3(r[1], r[4], r[2]))

# --- models ---------------------------------------------------------------------------------------

## the library palette's near-white walk tops clip in full sun: placed course models get tinted
## copies of their own materials (the files stay as imported), bridges more than the rest.
const BRIDGE_TINT := Color(0.74, 0.68, 0.58)
const MODEL_TINT := Color(0.92, 0.88, 0.82)
var _tinted := {}

func _tint(node: Node, tint: Color) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh_node := node as MeshInstance3D
		for i: int in mesh_node.mesh.get_surface_count():
			var original := mesh_node.get_active_material(i)
			if not original is BaseMaterial3D:
				continue
			var key := [original.get_instance_id(), tint]
			if not _tinted.has(key):
				var copy := original.duplicate() as BaseMaterial3D
				copy.albedo_color = copy.albedo_color * tint
				_tinted[key] = copy
			mesh_node.set_surface_override_material(i, _tinted[key])
	for child: Node in node.get_children():
		_tint(child, tint)

func _course_models(level: Node3D) -> int:
	# the library models whose collision the level authored, at the level's own transforms.
	var group := Node3D.new()
	group.name = "CourseModels"
	level.add_child(group)
	var count := 0
	for m: Dictionary in level.get("models"):
		var xf: Transform3D = m.xf
		var bx := xf.basis.x
		var yaw := atan2(-bx.z, bx.x)
		var node := ASSETS.place(group, str(m.model), xf.origin, xf.basis.get_scale(), yaw)
		node.name = "Model_" + str(m.id)
		node.set_meta("sunken_model_id", str(m.id))
		if not _neutral:
			_tint(node, BRIDGE_TINT if str(m.model).ends_with("bridge-straight.glb") else MODEL_TINT)
		count += 1
	return count

func _deco(parent: Node3D, model: String, at: Vector3, height: float, yaw: float = -1.0) -> Node3D:
	var key := (NAT if model.begins_with("NAT:") else LIB) + model.trim_prefix("NAT:")
	var node := ASSETS.place(parent, key, at, ASSETS.scale_for_height(key, height), yaw if yaw >= 0.0 else _rng.randf() * TAU)
	var placed: Dictionary = report.get("scenery", {})
	placed[key.get_file()] = int(placed.get(key.get_file(), 0)) + 1
	report["scenery"] = placed
	return node

func _scenery(level: Node3D) -> void:
	var group := Node3D.new()
	group.name = "Scenery"
	level.add_child(group)
	var high := float(K.TERRACE_Y) + float(K.WALL_UP) - 0.2
	var court := float(K.BALCONY_Y) + 2.4 - 0.2
	# pines on the land round the gatehouse and the court, and behind the cloister.
	var groves := [
		[Vector2(-40, 30), Vector2(-12, -38), high, 14], [Vector2(12, 40), Vector2(19, -36), high, 5],
		[Vector2(-80, -45), Vector2(-28, -98), court, 16], [Vector2(62, 40), Vector2(100, -60), 9.3, 14],
		[Vector2(24, 40), Vector2(55, 16), 11.4, 7], [Vector2(-80, -105), Vector2(-28, -122), -1.0, 5],
	]
	for g: Array in groves:
		var a: Vector2 = g[0]
		var b: Vector2 = g[1]
		for k: int in int(g[3]):
			var p := Vector2(lerpf(a.x, b.x, _rng.randf()), lerpf(a.y, b.y, _rng.randf()))
			var tall := _rng.randf() < 0.5
			_deco(group, "NAT:tree_pineTallA.glb" if tall else "NAT:tree_pineDefaultA.glb", Vector3(p.x, float(g[2]), p.y), _rng.randf_range(9.0, 15.0))
			if _rng.randf() < 0.6:
				_deco(group, "NAT:plant_bush.glb", Vector3(p.x + _rng.randf_range(-3, 3), float(g[2]), p.y + _rng.randf_range(-3, 3)), _rng.randf_range(0.9, 1.6))
	# broken columns and an obelisk on the court's wall tops and the land: the old colonnade.
	for z: float in [-58.0, -70.0, -82.0, -94.0]:
		_deco(group, "NAT:statue_columnDamaged.glb", Vector3(-23.0, court + 0.2, z), 4.2)
		_deco(group, "NAT:statue_columnDamaged.glb", Vector3(23.0, court + 0.2, z + 6.0), 3.6)
	for p: Vector3 in [Vector3(-34, court, -60), Vector3(-30, high, -20), Vector3(15, high, -30), Vector3(70, 9.3, -40)]:
		_deco(group, "NAT:statue_obelisk.glb", p, 7.0)
	# the sanctuary: obelisks on the parapet corners.
	var s: Array = K.SANCTUARY
	var parapet := float(K.SANCTUARY_Y) + float(K.WALL_UP)
	for p: Vector2 in [Vector2(float(s[0]) - 0.4, float(s[2]) - 0.4), Vector2(float(s[0]) - 0.4, float(s[3]) + 0.4), Vector2(float(s[1]) + 0.4, float(s[3]) + 0.4)]:
		_deco(group, "NAT:statue_obelisk.glb", Vector3(p.x, parapet, p.y), 5.5, 0.0)
	# ruined castle walls standing on the land, out of reach.
	for w: Array in [[Vector3(-30, high, 4), 0.3], [Vector3(-46, court, -76), 1.4], [Vector3(76, 9.3, -12), 2.2], [Vector3(16, high, 8), 0.9]]:
		_deco(group, "wall-corner.glb", w[0], 6.0, w[1])
	_deco(group, "wall-narrow-gate.glb", Vector3(-38, court, -92), 6.0, 0.6)
	_deco(group, "rocks-large.glb", Vector3(-28, -1.0, -112), 3.0)
	# the river: tall rocks and boulders below the kill line, cliff faces under the court and cloister.
	var river := float(K.RIVER_Y)
	for p: Vector3 in [Vector3(-14, river, -128), Vector3(8, river, -140), Vector3(34, river, -135), Vector3(56, river, -118), Vector3(52, river, -86), Vector3(30, river, -76)]:
		_deco(group, "NAT:rock_tallA.glb", p, _rng.randf_range(5.0, 8.0))
		_deco(group, "NAT:stone_largeA.glb", p + Vector3(3, 0, 2), 2.0)
	for k: int in 8:
		_deco(group, "NAT:cliff_large_rock.glb", Vector3(-20 + 6.0 * k, river - 1.0, -103.0), 8.0, PI)
	for k: int in 5:
		_deco(group, "NAT:cliff_large_rock.glb", Vector3(27.5, river - 1.0, -96.0 + 7.0 * k), 9.0, -PI * 0.5)
	# hanging moss down the court walls' inner faces, and the causeway's sides.
	for z: float in [-56.0, -63.0, -71.0, -78.0, -87.0, -95.0]:
		_deco(group, "NAT:hanging_moss.glb", Vector3(-21.95, court - 1.5, z), 2.4, PI * 0.5)
		_deco(group, "NAT:hanging_moss.glb", Vector3(21.95, court - 1.5, z + 3.0), 2.0, -PI * 0.5)
	# the diagonal architrave's two long sides, moss hanging off the lip every few metres.
	var cs: Array = K.CAUSEWAY_S
	var cn: Array = K.CAUSEWAY_N
	var cl: Array = K.CLOISTER
	var walk := float(K.WALK)
	var zs := float(cl[2]) + walk
	var zn := float(cl[3]) - walk
	var turn := atan2(float(cn[0]) - float(cs[0]), zn - zs)
	for t: float in [0.18, 0.5, 0.82]:
		var z := zs + (zn - zs) * t
		for side: Array in [[lerpf(float(cs[0]), float(cn[0]), t) - 0.02, -PI * 0.5], [lerpf(float(cs[1]), float(cn[1]), t) + 0.02, PI * 0.5]]:
			_deco(group, "NAT:hanging_moss.glb", Vector3(side[0], float(K.CLOISTER_Y) + float(K.CAUSEWAY_UP) - 0.9, z), 0.9, wrapf(float(side[1]) + turn, 0.0, TAU))
	# plants in the pools and the cistern: soft, no collision; kept off every landing.
	for p: Vector3 in [Vector3(-18, -2, -60), Vector3(17, -2, -72), Vector3(-16, -2, -88), Vector3(15, -2, -96), Vector3(10, -2, -54), Vector3(-9, -2, -99)]:
		_deco(group, "NAT:grass_leafs.glb", p, 0.8)
		_deco(group, "NAT:plant_bushSmall.glb", p + Vector3(1.4, 0, 0.6), 1.1)
	for p: Vector3 in [Vector3(35, 2.5, -48), Vector3(38.5, 2.5, -42), Vector3(49.5, 2.5, -52), Vector3(36.5, 2.5, -46.5)]:
		_deco(group, "NAT:grass_leafs.glb", p, 0.7)
	for p: Vector3 in [Vector3(-12, high, 18), Vector3(30, 11.4, 18), Vector3(64, 9.3, -50)]:
		_deco(group, "NAT:log.glb", p, 0.9)

# --- labels and the finish ------------------------------------------------------------------------

func _labels(level: Node3D) -> void:
	var marks := Node3D.new()
	marks.name = "Markings"
	level.add_child(marks)
	for mark: Dictionary in level.get("markings"):
		if mark.kind != "floor":
			continue
		var label := Label3D.new()
		label.name = mark.name
		label.text = mark.text
		label.font_size = 64
		label.pixel_size = 0.008
		label.modulate = Color("5a3b22")
		label.outline_size = 0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.transform = Transform3D(Basis(Vector3.UP, float(mark.yaw)) * Basis(Vector3.RIGHT, -PI * 0.5), (mark.at as Vector3) + Vector3.UP * 0.012)
		marks.add_child(label)
	var sign := Label3D.new()
	sign.name = "GateSign"
	sign.text = "SUNKEN COURT"
	sign.font_size = 96
	sign.pixel_size = 0.028
	sign.modulate = Color("fff4dc")
	sign.outline_size = 12
	sign.outline_modulate = Color(0.25, 0.15, 0.08, 0.9)
	var gate: Vector3 = K.GATE
	sign.transform = Transform3D(Basis.IDENTITY, gate + Vector3(0, 0.88 * float(K.GATE_SCALE), float(K.TOWER_HALF) * float(K.GATE_SCALE) + 0.05))
	marks.add_child(sign)

func _finish_glow(level: Node3D) -> void:
	_finish_light = OmniLight3D.new()
	_finish_light.name = "SanctuaryLight"
	_finish_light.light_color = Color("ffd59a")
	_finish_light.light_energy = 0.6
	_finish_light.omni_range = 16.0
	var arch: Vector3 = K.FINISH_ARCH
	_finish_light.position = arch + Vector3(0, 4.0, 0)
	level.add_child(_finish_light)
