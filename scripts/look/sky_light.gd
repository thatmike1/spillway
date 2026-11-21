extends RefCounted
## per-map sky, sun, fill, ambient and fog for the current look (L on). presentation only:
## nothing here enters course, motion, scoring, recording or ghost identities.
##
## contract with the look layer (scripts/r17_look.gd) and the map art files:
##   has_map(id) -> bool
##   environment(base, id, reuse = null) -> Environment   a configured duplicate of the map's original
##                                          environment; reuse repaints an existing undrawn Sky
##   light(index, id) -> Dictionary         {"rotation_degrees": Vector3, "color": Color, "energy": float}
##                                          index 0 is the sun, any other directional light is the cool fill
##   apply(env, sun, id)                    for maps that own their look: configures env and sun in place
## keys are real map ids; "practice" doubles as the palette alias the newer maps attach with.
##
## one game, each map its own hour: warm direct sun against a cool ambient so sun-facing and shaded
## faces of the same pale concrete separate, a painted sky with sculpted cumulus whose lit side
## follows the sun, and depth fog that fades far structure toward the horizon colour.
const SKY_SHADER := preload("res://shaders/look/sky/painted.gdshader")
const PANORAMA_SHADER := preload("res://shaders/look/sky.gdshader")
const CLOUDS := "res://assets/look/sky/cloud-atlas.png"
const WISPS := "res://assets/look/sky/wisp-atlas.png"
const ROOT := "res://assets/look/r17/"

## card layouts: [azimuth, bottom elevation, width (negative mirrors), atlas cell], all degrees.
## azimuth 0 looks down -Z; each map turns its layout so its big clouds stand over the route.
const LAYOUTS := {
	"fair": [[-30, 4, 52, 0], [18, 13, 34, 3], [62, 2, 50, 1], [108, 9, 40, 2], [152, 3, 54, 0], [200, 12, 38, 3], [248, 5, 56, 1], [300, 8, 44, 2]],
	"towers": [[-22, 2, 48, 0], [22, 9, 62, 1], [72, 4, 52, 2], [118, 11, 46, 0], [165, 3, 64, 1], [215, 8, 50, 2], [262, 2, 56, 0], [312, 10, 48, 3]],
	"sparse": [[-40, 10, 42, 2], [40, 4, 56, 1], [130, 12, 38, 3], [215, 6, 50, 0], [295, 8, 44, 1]],
	"banks": [[-45, 1, 72, 1], [10, 6, 66, 1], [65, 2, 74, 1], [120, 8, 66, 2], [175, 3, 72, 1], [230, 7, 64, 2], [285, 2, 70, 1], [335, 9, 60, 2]],
}
## wisp strips 1 (parallel cirrus streaks) and 2 (broken altocumulus flecks) only: strips 0 and 3
## curl into ribbons that read as drawn squiggles next to the painted cumulus.
const WISP_LAYOUTS := {
	"high": [[-10, 28, 70, 1], [70, 36, 60, 2], [170, 24, 80, 1], [260, 32, 64, 2]],
	"low": [[0, 16, 80, 1], [120, 14, 90, 2], [240, 18, 76, 1]],
	"none": [],
}

## sky palettes: gradient, horizon band, sun glow and the cloud light/shadow ramp.
const SKIES := {
	# late afternoon, apricot light on the clouds, lavender-blue shadow, teal zenith.
	"golden": {"zenith":"2c6c99", "upper":"4f93b8", "horizon":"b9d1cf", "band":"f4d2a6", "band_strength":0.55, "below":"8fb4b6",
		"glow":"ffd8a0", "glow_strength":0.45, "glow_size":10.0, "light":"fff0d6", "mid":"f0c9a2", "shadow":"7f93b4", "rim":"ffd7a0", "contrast":1.05, "haze":0.5},
	# clear late morning: crisp ivory towers over a deep sea-blue sky.
	"noon": {"zenith":"1f5f93", "upper":"3f8bbc", "horizon":"bcd7da", "band":"e8efe6", "band_strength":0.35, "below":"9bc0c6",
		"glow":"fff4dc", "glow_strength":0.30, "glow_size":14.0, "light":"fffaf0", "mid":"dfe2e3", "shadow":"8fa3bb", "rim":"fff3dc", "contrast":1.0, "haze":0.45},
	# cold winter morning: pale blue, ivory clouds, cool shadows.
	"winter": {"zenith":"3c6f9e", "upper":"7ea5c8", "horizon":"d3dee5", "band":"f3e6d6", "band_strength":0.45, "below":"b6c8d6",
		"glow":"fff0dc", "glow_strength":0.35, "glow_size":9.0, "light":"fffaf2", "mid":"dfe1e8", "shadow":"8d9fbc", "rim":"ffeedd", "contrast":0.95, "haze":0.55},
	# mediterranean noon: deep cyan above, white towers, warm sand band.
	"cyan": {"zenith":"175e94", "upper":"3190bf", "horizon":"bad5e0", "band":"f2e4c4", "band_strength":0.35, "below":"95cbc8",
		"glow":"fff6e2", "glow_strength":0.30, "glow_size":16.0, "light":"fffdf4", "mid":"e6e6df", "shadow":"86a6bb", "rim":"fff6e0", "contrast":1.05, "haze":0.4},
	# after rain: slate banks with a thin bright break low over the sea.
	"slate": {"zenith":"2d3e50", "upper":"4a5f72", "horizon":"9aacb5", "band":"d9d8c8", "band_strength":0.45, "below":"6d808c",
		"glow":"e9e4d4", "glow_strength":0.12, "glow_size":6.0, "light":"9eaab4", "mid":"76838f", "shadow":"3d4957", "rim":"b9bfc2", "contrast":0.7, "haze":0.65, "opacity":0.75},
	# moonlit night: indigo above, lavender clouds lit from the moon side, a few stars.
	"night": {"zenith":"121a36", "upper":"222d52", "horizon":"45527a", "band":"6d6f93", "band_strength":0.45, "below":"2c3656",
		"glow":"c7d3f0", "glow_strength":0.22, "glow_size":40.0, "light":"aeb3d6", "mid":"6c6f9c", "shadow":"2c3058", "rim":"d2d8f2", "contrast":1.0, "haze":0.5, "stars":0.7, "disc":0.8},
	# early morning: low peach sun, soft blue, pink-lit clouds.
	"dawn": {"zenith":"3d6a98", "upper":"7ea0c2", "horizon":"d8d3cf", "band":"f6c9a8", "band_strength":0.6, "below":"a9b7c0",
		"glow":"ffcf9e", "glow_strength":0.5, "glow_size":9.0, "light":"ffe9d8", "mid":"e9bfb0", "shadow":"8191b4", "rim":"ffc995", "contrast":1.0, "haze":0.55},
	# early afternoon: a touch warmer than noon, cumulus with a cream lit side.
	"afternoon": {"zenith":"23628f", "upper":"468dba", "horizon":"c3d8d6", "band":"f1e2c8", "band_strength":0.45, "below":"9fc0c2",
		"glow":"ffeccc", "glow_strength":0.35, "glow_size":12.0, "light":"fff6e4", "mid":"ead9c6", "shadow":"8a9cb8", "rim":"ffe8c8", "contrast":1.0, "haze":0.45},
	# salt pans: a deep clear blue behind bleached surfaces, few clouds, white glare at the horizon.
	"salt": {"zenith":"1a5486", "upper":"3a80b0", "horizon":"bccfd6", "band":"e2e2d8", "band_strength":0.35, "below":"a8c2c8",
		"glow":"fff8ea", "glow_strength":0.2, "glow_size":14.0, "light":"eeebe2", "mid":"d2d6d8", "shadow":"8a9eb6", "rim":"f0ede4", "contrast":1.0, "haze":0.5},
	# pale bright overcast-white haze for the lab and the salt pans.
	# the pearl haze held below the salt decks, so the runway stays the palest thing at seaward.
	"haze": {"zenith":"6d8ea8", "upper":"95adc0", "horizon":"c6d2d6", "band":"e2dfd4", "band_strength":0.3, "below":"b4c2c8",
		"glow":"fff6e6", "glow_strength":0.18, "glow_size":6.0, "light":"ece9e2", "mid":"ced2d6", "shadow":"9aa8b8", "rim":"f0ece4", "contrast":0.85, "haze":0.6},
	"pearl": {"zenith":"6d8ea8", "upper":"9db4c5", "horizon":"dfe5e5", "band":"eee9dc", "band_strength":0.4, "below":"c2ced2",
		"glow":"fff6e6", "glow_strength":0.25, "glow_size":6.0, "light":"fbf8f1", "mid":"dadde0", "shadow":"a3b0bf", "rim":"fffaf0", "contrast":0.85, "haze":0.6},
}

const MAPS := {
	# container port at dusk: low apricot sun from the left of the run, towering clouds, cool blue shade.
	"breakwater": {"sky":"res://assets/look/cloud-sky.png", "paint":"golden", "layout":"towers", "wisp":"none", "cloud_turn":0.0, "cell_shift":0,
		"sun":"fff0da", "sun_energy":0.42, "pitch":-22.0, "yaw":-135.0, "fill":"98b8d0", "fill_light":"8fb0c8", "fill_energy":0.14, "ambient":0.5, "fog":"bccfdb", "fog_density":0.0011, "exposure":0.76},
	# cold clear winter morning: low pale sun, ivory clouds, blue shade on the snow.
	"whiteout-relay": {"sky":ROOT+"whiteout-sky.png", "paint":"winter", "layout":"fair", "wisp":"none", "cloud_turn":-25.0, "cell_shift":3,
		"sun":"fff0dc", "sun_energy":0.5, "pitch":-22.0, "yaw":-36.2, "fill":"9dbdd0", "fill_energy":0.14, "ambient":0.56, "fog":"d3dee5", "fog_density":0.0012, "exposure":0.77},
	# bright late morning by the sea: high warm sun, white towers, clear blue-grey shade.
	"sunken-court": {"sky":ROOT+"sunken-sky.png", "paint":"cyan", "layout":"towers", "wisp":"none", "cloud_turn":0.0, "cell_shift":6,
		"sun":"fff2da", "sun_energy":0.48, "pitch":-52.0, "yaw":35.0, "fill":"a6b8d8", "fill_energy":0.12, "ambient":0.5, "fog":"bccfdf", "fog_density":0.0011, "exposure":0.77},
	# after rain: slate banks, a thin bright break over the sea, a weak sun so shadows stay soft, high cool ambient.
	"rainline": {"sky":ROOT+"rainline-sky.png", "paint":"slate", "layout":"banks", "wisp":"none", "cloud_turn":0.0, "cell_shift":2, "panorama_mix":0.55,
		"sun":"dde3e8", "sun_energy":0.2, "pitch":-48.0, "yaw":-25.0, "fill":"a6b4c2", "fill_energy":0.16, "ambient":0.66, "fog":"9aacb5", "fog_density":0.001, "exposure":0.76},
	# moonlit night: a grey-cool moon high to the side, a lavender sky with stars; decks stay brightest without reading as snow.
	"night-shift": {"sky":ROOT+"night-sky.png", "paint":"night", "layout":"sparse", "wisp":"none", "cloud_turn":20.0, "cell_shift":5,
		"sun":"c4cbe0", "sun_energy":0.36, "pitch":-42.0, "yaw":40.0, "fill":"7c86a0", "fill_energy":0.12, "ambient":0.5, "fog":"3a4770", "fog_density":0.0014, "exposure":0.85},
	# clear mid-morning over the yard: fair-weather cumulus all round.
	"practice": {"sky":ROOT+"practice-sky.png", "paint":"noon", "layout":"fair", "wisp":"none", "cloud_turn":35.0, "cell_shift":1,
		"sun":"fff0e2", "sun_energy":0.46, "pitch":-38.0, "yaw":-110.0, "fill":"a0bcd2", "fill_energy":0.12, "ambient":0.48, "fog":"bed4e0", "fog_density":0.0013, "exposure":0.7},
	# late afternoon on the dam: warm low sun down the tail race, towering clouds.
	"overflow": {"sky":ROOT+"overflow-sky.png", "paint":"golden", "layout":"towers", "wisp":"none", "cloud_turn":60.0, "cell_shift":4,
		"sun":"ffdcb0", "sun_energy":0.58, "pitch":-24.0, "yaw":-120.0, "fill":"98b8d0", "fill_energy":0.14, "ambient":0.55, "fog":"bccfdb", "fog_density":0.0013, "exposure":0.78},
	# the lab: high pearl skylight, soft and even.
	"experiment": {"sky":ROOT+"lab-sky.png", "paint":"pearl", "layout":"sparse", "wisp":"none", "cloud_turn":60.0, "cell_shift":0,
		"sun":"fff0d9", "sun_energy":0.34, "pitch":-62.0, "yaw":25.0, "fill":"a8b8cc", "fill_energy":0.1, "ambient":0.34, "fog":"dfe5e5", "fog_density":0.0012, "exposure":0.56},
	# salt pans at noon: bleached pearl haze, the sea glare carries the scene.
	"saltglass-seaward": {"sky":ROOT+"practice-sky.png", "paint":"haze", "layout":"fair", "wisp":"none", "cloud_turn":30.0, "cell_shift":3,
		"sun":"fff0e2", "sun_energy":0.56, "pitch":-40.0, "yaw":-110.0, "fill":"a0bcd2", "fill_energy":0.12, "ambient":0.56, "fog":"dfe5e5", "fog_density":0.0012, "exposure":0.78},
	# transfer yard in full morning: towering cumulus over the rope lines.
	"tether-yard": {"sky":ROOT+"practice-sky.png", "paint":"noon", "layout":"sparse", "wisp":"none", "cloud_turn":0.0, "cell_shift":6,
		"sun":"fff0e2", "sun_energy":0.56, "pitch":-34.0, "yaw":-120.0, "fill":"a0bcd2", "fill_energy":0.12, "ambient":0.55, "fog":"bed4e0", "fog_density":0.0013, "exposure":0.78},
	# first light: a low peach sun across the line, long shadows.
	"through-line": {"sky":ROOT+"practice-sky.png", "paint":"dawn", "layout":"fair", "wisp":"none", "cloud_turn":-50.0, "cell_shift":2,
		"sun":"ffd8b2", "sun_energy":0.56, "pitch":-24.0, "yaw":-70.0, "fill":"98b8cc", "fill_energy":0.14, "ambient":0.6, "fog":"d8d3cf", "fog_density":0.0011, "exposure":0.78},
	# a breezy bright day over the roofs.
	"mail-run": {"sky":ROOT+"practice-sky.png", "paint":"noon", "layout":"fair", "wisp":"none", "cloud_turn":100.0, "cell_shift":5,
		"sun":"fff0e2", "sun_energy":0.46, "pitch":-36.0, "yaw":-140.0, "fill":"a0bcd2", "fill_energy":0.12, "ambient":0.46, "fog":"bed4e0", "fog_density":0.0013, "exposure":0.72},
	# salt works at noon: deep blue behind the pale pans so slopes and decks read against it.
	"saltglass": {"sky":ROOT+"practice-sky.png", "paint":"salt", "layout":"sparse", "wisp":"none", "cloud_turn":10.0, "cell_shift":1,
		"sun":"fff0e2", "sun_energy":0.56, "pitch":-40.0, "yaw":-110.0, "fill":"a0bcd2", "fill_energy":0.12, "ambient":0.56, "fog":"d7e4e2", "fog_density":0.0012, "exposure":0.78},
	# valley dam in the afternoon: side sun along the deck line.
	"viaduct": {"sky":ROOT+"overflow-sky.png", "paint":"afternoon", "layout":"towers", "wisp":"none", "cloud_turn":28.0, "cell_shift":4,
		"sun":"fff0e2", "sun_energy":0.56, "pitch":-36.0, "yaw":-110.0, "fill":"a0bcd2", "fill_energy":0.12, "ambient":0.55, "fog":"bccfdb", "fog_density":0.0013, "exposure":0.72},
	# drydock gantries, mid afternoon.
	"gantry": {"sky":"res://assets/look/cloud-sky.png", "paint":"afternoon", "layout":"fair", "wisp":"none", "cloud_turn":-20.0, "cell_shift":0,
		"sun":"fff0e2", "sun_energy":0.56, "pitch":-34.0, "yaw":-110.0, "fill":"a0bcd2", "fill_energy":0.12, "ambient":0.55, "fog":"c3d8d6", "fog_density":0.0013, "exposure":0.78},
	# the longer chain runs into later, warmer light.
	"gantry-chain": {"sky":"res://assets/look/cloud-sky.png", "paint":"golden", "layout":"fair", "wisp":"none", "cloud_turn":-20.0, "cell_shift":3,
		"sun":"ffe6c0", "sun_energy":0.56, "pitch":-28.0, "yaw":-110.0, "fill":"98b8d0", "fill_energy":0.12, "ambient":0.55, "fog":"bccfdb", "fog_density":0.0013, "exposure":0.78},
	# tidal estuary, late afternoon; the sun stands behind the runner so the spill-tower court is lit.
	"sluice-six": {"sky":"res://assets/look/cloud-sky.png", "paint":"golden", "layout":"towers", "wisp":"none", "cloud_turn":150.0, "cell_shift":6,
		"sun":"ffe4bc", "sun_energy":0.58, "pitch":-38.0, "yaw":20.0, "fill":"98b8d0", "fill_energy":0.12, "ambient":0.55, "fog":"bccfdb", "fog_density":0.0012, "exposure":0.78},
	# the outer reach at golden hour: broad open sky, long side light over the corridors.
	"outer-reach": {"sky":"res://assets/look/cloud-sky.png", "paint":"golden", "layout":"towers", "wisp":"none", "cloud_turn":-60.0, "cell_shift":2,
		"sun":"ffd9a8", "sun_energy":0.6, "pitch":-20.0, "yaw":-120.0, "fill":"98b8d0", "fill_energy":0.12, "ambient":0.55, "fog":"bccfdb", "fog_density":0.0011, "exposure":0.78},
	# foundry at dusk: warm low haze around the hall.
	"foundry": {"sky":ROOT+"practice-sky.png", "paint":"dawn", "layout":"sparse", "wisp":"none", "cloud_turn":30.0, "cell_shift":5,
		"sun":"ffd4a8", "sun_energy":0.56, "pitch":-26.0, "yaw":-110.0, "fill":"98b8cc", "fill_energy":0.12, "ambient":0.56, "fog":"d8d3cf", "fog_density":0.0011, "exposure":0.78},
	# planning yard: a clear even noon so the plan reads; few clouds.
	"plan-yard": {"sky":"res://assets/look/cloud-sky.png", "paint":"afternoon", "layout":"sparse", "wisp":"none", "cloud_turn":0.0, "cell_shift":1,
		"sun":"fff0e2", "sun_energy":0.42, "pitch":-40.0, "yaw":-30.0, "fill":"a0bcd2", "fill_energy":0.1, "ambient":0.46, "fog":"bccfdb", "fog_density":0.0012, "exposure":0.64},
}

static func has_map(id: String) -> bool:
	return MAPS.has(id)

static func entry(id: String) -> Dictionary:
	return MAPS[id]

## reuse: an existing, not yet drawn Sky to repaint instead of making a new one. a Sky that is
## dropped before its first draw leaks its radiance textures at exit (seen on breakwater).
static func make_sky(id: String, reuse: Sky = null) -> Sky:
	var values: Dictionary = MAPS[id]
	var material := ShaderMaterial.new()
	material.shader = SKY_SHADER if values.has("paint") else PANORAMA_SHADER
	material.set_shader_parameter("panorama", load(str(values.sky)))
	if values.has("paint"):
		_paint(material, values)
	var sky := reuse if reuse != null else Sky.new()
	sky.sky_material = material
	# ambient comes from a colour, so the sky radiance map only feeds reflections: keep it small.
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	return sky

static func _paint(material: ShaderMaterial, values: Dictionary) -> void:
	var paint: Dictionary = SKIES[str(values.paint)]
	material.set_shader_parameter("panorama_mix", float(values.get("panorama_mix", 0.0)))
	for key: String in ["zenith", "upper", "horizon", "band", "below"]:
		material.set_shader_parameter(key, Color(str(paint[key])))
	material.set_shader_parameter("band_strength", float(paint.band_strength))
	material.set_shader_parameter("glow_color", Color(str(paint.glow)))
	material.set_shader_parameter("glow_strength", float(paint.glow_strength))
	material.set_shader_parameter("glow_size", float(paint.glow_size))
	material.set_shader_parameter("disc_strength", float(paint.get("disc", 0.0)))
	material.set_shader_parameter("stars", float(paint.get("stars", 0.0)))
	material.set_shader_parameter("cloud_light", Color(str(paint.light)))
	material.set_shader_parameter("cloud_mid", Color(str(paint.mid)))
	material.set_shader_parameter("cloud_shadow", Color(str(paint.shadow)))
	material.set_shader_parameter("cloud_rim", Color(str(paint.rim)))
	material.set_shader_parameter("cloud_contrast", float(paint.contrast))
	material.set_shader_parameter("cloud_haze", float(paint.haze))
	material.set_shader_parameter("cloud_opacity", float(paint.get("opacity", 1.0)))
	var sun_basis := Basis.from_euler(Vector3(deg_to_rad(float(values.pitch)), deg_to_rad(float(values.yaw)), 0))
	material.set_shader_parameter("sun_dir", sun_basis * Vector3(0, 0, 1))
	if ResourceLoader.exists(CLOUDS):
		var atlas: Texture2D = load(CLOUDS)
		material.set_shader_parameter("clouds", atlas)
		# a 4x2 atlas holds a second set of paintings: every other card uses its partner cell.
		var columns := 4 if atlas.get_width() >= atlas.get_height() * 2 else 2
		material.set_shader_parameter("cloud_cells", Vector2(columns, 2))
		var cards := PackedVector4Array()
		var layout: Array = LAYOUTS[str(values.layout)]
		for i: int in layout.size():
			var card: Array = layout[i]
			var cell := int(card[3])
			if columns == 4:
				# row 0 holds the first four paintings, row 1 the second four; each map shifts the
				# choice by its own amount so no two maps share a composition. cell 7, a two-crown
				# cloud that reads as a cut-out, is skipped.
				cell = (cell + (4 if i % 2 == 1 else 0) + int(values.get("cell_shift", 0))) % 7
			cards.append(Vector4(float(card[0]) + float(values.cloud_turn), card[1], card[2], cell))
		material.set_shader_parameter("card_count", cards.size())
		cards.resize(8)
		material.set_shader_parameter("cards", cards)
	if ResourceLoader.exists(WISPS):
		material.set_shader_parameter("wisps", load(WISPS))
		var strips := PackedVector4Array()
		for card: Array in WISP_LAYOUTS[str(values.wisp)]:
			strips.append(Vector4(float(card[0]) + float(values.cloud_turn), card[1], card[2], card[3]))
		material.set_shader_parameter("wisp_count", strips.size())
		strips.resize(4)
		material.set_shader_parameter("wisp_cards", strips)

static func environment(base: Environment, id: String, reuse: Sky = null) -> Environment:
	var env := base.duplicate() as Environment
	_configure(env, id, reuse)
	return env

static func _configure(env: Environment, id: String, reuse: Sky = null) -> void:
	var values: Dictionary = MAPS[id]
	env.background_mode = Environment.BG_SKY
	env.sky = make_sky(id, reuse)
	# painted skies place their clouds by azimuth; the legacy panorama keeps its authored turn.
	env.sky_rotation = Vector3(0, 0.0 if values.has("paint") else deg_to_rad(float(values.turn)), 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(str(values.fill))
	env.ambient_light_energy = float(values.ambient)
	env.ambient_light_sky_contribution = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = float(values.get("exposure", 0.92))
	env.fog_light_color = Color(str(values.fog))
	env.fog_density = float(values.get("fog_density", 0.0012))
	env.fog_sky_affect = 0.0
	# compatibility fog is coarse on long faces (a 0.0035 density washed whole decks out in the
	# first breakwater test), so the fog keeps the original map's enabled state and stays light.

static func light(index: int, id: String) -> Dictionary:
	var values: Dictionary = MAPS[id]
	if index == 0:
		return {"rotation_degrees":Vector3(float(values.pitch), float(values.yaw), 0), "color":Color(str(values.sun)), "energy":float(values.sun_energy)}
	return {"rotation_degrees":Vector3(-55, float(values.yaw)+180.0, 0), "color":Color(str(values.get("fill_light", values.fill))), "energy":float(values.get("fill_energy", 0.12))}

static func apply(env: Environment, sun: DirectionalLight3D, id: String) -> void:
	# repaint the map's own sky object in place rather than replacing it.
	_configure(env, id, env.sky)
	if sun != null:
		var values := light(0, id)
		sun.rotation_degrees = values.rotation_degrees
		sun.light_color = values.color
		sun.light_energy = values.energy
