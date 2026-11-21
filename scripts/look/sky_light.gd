extends RefCounted
## per-map sky, sun, fill, ambient and fog for the current look (L on). presentation only:
## nothing here enters course, motion, scoring, recording or ghost identities.
##
## contract with the look layer (scripts/r17_look.gd) and the map art files:
##   has_map(id) -> bool
##   environment(base, id) -> Environment   a configured duplicate of the map's original environment
##   light(index, id) -> Dictionary         {"rotation_degrees": Vector3, "color": Color, "energy": float}
##                                          index 0 is the sun, any other directional light is the cool fill
## keys are real map ids; "practice" doubles as the palette alias the newer maps attach with.
const SKY_SHADER := preload("res://shaders/look/sky.gdshader")
const ROOT := "res://assets/look/r17/"

const MAPS := {
	"breakwater": {"sky":"res://assets/look/cloud-sky.png", "turn":180.0, "sun":"fff0d3", "sun_energy":0.48, "pitch":-24.0, "yaw":-135.0, "fill":"a6bfc3", "fill_light":"9bb9c4", "fill_energy":0.12, "ambient":0.32, "fog":"a5c2bd", "fog_density":0.0007, "exposure":0.92},
	"whiteout-relay": {"sky":ROOT+"whiteout-sky.png", "turn":0.0, "sun":"ffe9cb", "sun_energy":0.48, "pitch":-26.0, "yaw":-36.2, "fill":"a7c1d9", "ambient":0.32, "fog":"b2c4d1"},
	"sunken-court": {"sky":ROOT+"sunken-sky.png", "turn":0.0, "sun":"fff4df", "sun_energy":0.48, "pitch":-50.0, "yaw":35.0, "fill":"b7cac5", "ambient":0.32, "fog":"b4c7b3"},
	"rainline": {"sky":ROOT+"rainline-sky.png", "turn":0.0, "sun":"c6d6e5", "sun_energy":0.48, "pitch":-48.0, "yaw":-25.0, "fill":"9eb9c9", "ambient":0.48, "fog":"6f8c9a"},
	"night-shift": {"sky":ROOT+"night-sky.png", "turn":0.0, "sun":"b7c9e6", "sun_energy":0.48, "pitch":-40.0, "yaw":40.0, "fill":"849cb8", "ambient":0.55, "fog":"3b506c"},
	"practice": {"sky":ROOT+"practice-sky.png", "turn":0.0, "sun":"fff0d2", "sun_energy":0.48, "pitch":-34.0, "yaw":-110.0, "fill":"b0c7c9", "ambient":0.32, "fog":"adc5be"},
	"overflow": {"sky":ROOT+"overflow-sky.png", "turn":0.0, "sun":"ffe2bc", "sun_energy":0.48, "pitch":-27.0, "yaw":-120.0, "fill":"b1c6c6", "ambient":0.32, "fog":"adc2b6"},
	"experiment": {"sky":ROOT+"lab-sky.png", "turn":0.0, "sun":"fff0d9", "sun_energy":0.65, "pitch":-62.0, "yaw":25.0, "fill":"b6c9d5", "ambient":0.45, "fog":"8d9fa8"},
}

static func has_map(id: String) -> bool:
	return MAPS.has(id)

static func entry(id: String) -> Dictionary:
	return MAPS[id]

static func make_sky(id: String) -> Sky:
	var values: Dictionary = MAPS[id]
	var material := ShaderMaterial.new()
	material.shader = SKY_SHADER
	material.set_shader_parameter("panorama", load(str(values.sky)))
	var sky := Sky.new()
	sky.sky_material = material
	return sky

static func environment(base: Environment, id: String) -> Environment:
	var values: Dictionary = MAPS[id]
	var env := base.duplicate() as Environment
	env.background_mode = Environment.BG_SKY
	env.sky = make_sky(id)
	env.sky_rotation = Vector3(0, deg_to_rad(float(values.turn)), 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(str(values.fill))
	env.ambient_light_energy = float(values.ambient)
	env.ambient_light_sky_contribution = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = float(values.get("exposure", 0.92))
	env.fog_light_color = Color(str(values.fog))
	env.fog_density = float(values.get("fog_density", 0.0012))
	env.fog_sky_affect = 0.0
	return env

static func light(index: int, id: String) -> Dictionary:
	var values: Dictionary = MAPS[id]
	if index == 0:
		return {"rotation_degrees":Vector3(float(values.pitch), float(values.yaw), 0), "color":Color(str(values.sun)), "energy":float(values.sun_energy)}
	return {"rotation_degrees":Vector3(-55, float(values.yaw)+180.0, 0), "color":Color(str(values.get("fill_light", values.fill))), "energy":float(values.get("fill_energy", 0.12))}
