extends RefCounted
## p / r14 movement preset registry. one entry per selectable movement law: its family (which
## runner script plays it), the motor preset and overrides it applies, its physics rate and the
## words the hud and pause menu show. r14_main.gd builds and switches runners from this table
## only, so a later family is one FAMILIES entry plus one PRESETS entry, with no change to the
## main loop. F4 is not a new family: it is a labelled configuration of the same source motion
## module and collision adapter (docs/r14/QUAKE.md).
##
## records: physics_fingerprint() is what enters the record key. ui settings (mouse, view
## angle, wheel binding) are removed from it; every cvar and policy that moves the body stays.

const SOURCE_PLAYER := "res://scripts/r14_source_player.gd"
const R13_PLAYER := "res://scripts/momentum_carry_air_candidate.gd"
const MOTION := preload("res://scripts/r14_source_motion.gd")

## how each family's runner is made. `version` enters the record key; bump it when a family's
## movement code changes what a run means. `hull` names the collision shape for the fit check.
const FAMILIES := {
	"source": {"script": SOURCE_PLAYER, "version": "r14-source-motion-3", "label": "Source", "hull": "source_box"},
	"r13": {"script": R13_PLAYER, "version": "r13-carry-air-candidate-1", "label": "R13", "hull": "r13_capsule"},
}

## hot keys and the pause list, in this order.
const ORDER := ["vanilla64", "server128", "r13_original120", "quake3_inspired128", "server128_aa1000"]

const PRESETS := {
	"vanilla64": {
		"slot": 1, "family": "source", "source_preset": "csgo_vanilla", "overrides": {}, "rate": 64,
		"label": "CS:GO vanilla", "short": "vanilla",
		"air": "AA 12", "jump": "manual: press Space or scroll for every hop",
		# the review's qualifier: the cvars are the reference values, the stamina and clamp are fits.
		"qualifier": "vanilla cvars · stamina reconstructed",
		"summary": "vanilla cvars · AA 12 · 64 Hz · manual jump · stamina and 275 u/s takeoff clamp reconstructed, not a binary match",
		"controls": "WASD run · mouse look · Space or mouse wheel jumps; each hop needs a fresh press\nAir strafe: release W, hold A or D and turn the mouse the same way · release keys to coast",
	},
	"server128": {
		"slot": 2, "family": "source", "source_preset": "csgo_server", "overrides": {}, "rate": 128,
		"label": "CS:GO bhop server", "short": "bhop server",
		"air": "AA 100", "jump": "autohop: hold Space (wheel works too)",
		"summary": "AA 100 · 128 Hz · autohop · no stamina, no takeoff clamp",
		"controls": "WASD run · mouse look · hold Space to keep hopping (or scroll)\nAir strafe: release W, hold A or D and turn the mouse the same way · release keys to coast",
	},
	"r13_original120": {
		"slot": 3, "family": "r13", "rate": 120,
		"label": "R13 Overflow (unchanged)", "short": "R13",
		"air": "R13 bend + carve", "jump": "R13 autohop: hold Space",
		"summary": "the original R13 runner and camera · 120 Hz · keys bend the flight, A/D with the mouse carves a little",
		"controls": "WASD run · mouse look · hold Space to keep hopping\nIn the air keys bend your flight where they point · no keys keeps your line · S brakes",
	},
	# p / quake iii-inspired projection on the source body: the released q3 base game's declared
	# accelerate 10, airaccelerate 1, friction 6, stopspeed 100, speed 320, gravity 800 and jump
	# 270 (docs/r14/WIDE.md), with the full wishspeed as the air ceiling instead of the 30 u cap.
	# the jump order is exact ballistic, the air surface constant (no deadstrafe), and there is no
	# stamina or takeoff/ground clamp. 128 Hz, autohop, the source hull, eye, u-to-metre scale and
	# sv_maxvelocity bound are comparison choices. no quake command subdivision, velocity
	# rounding, cmdscale upmove term, contact or ramp rules: not quake, not cpma.
	"quake3_inspired128": {
		"slot": 4, "family": "source", "source_preset": "csgo_server", "rate": 128,
		"overrides": {
			"preset": "quake3_inspired", "label": "Quake III-inspired projection (P)", "tickrate": 128,
			"sv_accelerate": 10.0, "sv_airaccelerate": 1.0, "sv_friction": 6.0, "sv_stopspeed": 100.0,
			"player_maxspeed": 320.0, "sv_maxspeed": 320.0, "sv_air_max_wishspeed": 320.0,
			"sv_gravity": 800.0, "sv_jump_impulse": 270.0, "jump_order": "ideal", "air_surface": "constant",
			"stamina_model": "off", "ground_speed_clamp": false,
			"sv_enablebunnyhopping": true, "sv_autobunnyhopping": true,
		},
		"label": "Quake III-inspired", "short": "Q3-inspired",
		"air": "AA 1 · 320 u wish, not 30 u",
		"jump": "P autohop: hold Space (wheel works too)",
		"qualifier": "not Quake",
		"summary": "P: Quake III's declared accel 10 · AA 1 · friction 6 · stopspeed 100 · 320 u/s · gravity 800 · jump 270, projected to the full 320 u wish instead of Source's 30 u cap · 128 Hz · Source hull and collision · no Quake command rounding or contacts, not Quake or CPMA",
		"controls": "WASD run (320 u/s) · mouse look · hold Space to keep hopping (or scroll)\nIn the air: hold W with A or D and turn the mouse gently the same way · let go of every key to coast on your line",
	},
	"server128_aa1000": {
		"slot": 5, "family": "source", "source_preset": "csgo_server", "overrides": {"sv_airaccelerate": 1000.0}, "rate": 128,
		"label": "P server config AA 1000", "short": "AA 1000",
		"air": "AA 1000", "jump": "autohop: hold Space (wheel works too)",
		"summary": "the bhop server profile at AA 1000 · 128 Hz · a configured comparison some servers run, not universal CS",
		"controls": "WASD run · mouse look · hold Space to keep hopping (or scroll)\nAir strafe: release W, hold A or D and turn the mouse the same way · release keys to coast",
	},
}

## names other tools use for the same entries (the tape hook's `motor`, the source presets).
const ALIASES := {
	"csgo_vanilla": "vanilla64", "vanilla": "vanilla64", "f1": "vanilla64",
	"csgo_server": "server128", "server": "server128", "f2": "server128",
	"r13": "r13_original120", "candidate": "r13_original120", "f3": "r13_original120",
	"quake": "quake3_inspired128", "f4": "quake3_inspired128",
	"aa1000": "server128_aa1000", "f5": "server128_aa1000",
}

## settings that only change how the player looks around or binds a key. they never enter a
## record key, so changing them keeps a preset's bests comparable.
const UI_KEYS := ["sensitivity", "m_yaw", "m_pitch", "fov", "wheel_jump", "label"]

## the registry id for an id or alias, or "" when nothing matches.
static func resolve(name: String) -> String:
	var key := name.strip_edges().to_lower()
	if PRESETS.has(key):
		return key
	return str(ALIASES.get(key, ""))

static func entry(id: String) -> Dictionary:
	var found: Dictionary = PRESETS.get(id, {})
	var out := found.duplicate(true)
	out["id"] = id
	return out

## false for a reserved slot, or a family nobody has built yet.
static func available(id: String) -> bool:
	var found: Dictionary = PRESETS.get(id, {})
	return not found.is_empty() and bool(found.get("available", true)) and FAMILIES.has(str(found.get("family", "")))

static func id_for_slot(slot: int) -> String:
	for id: String in ORDER:
		if int(PRESETS[id].slot) == slot:
			return id
	return ""

## the source runner's full settings for an entry, with the player's ui choices applied.
## ui: {sensitivity (source units), fov (4:3 reference degrees)}. wheel jump is always on here.
static func source_settings(id: String, ui: Dictionary) -> Dictionary:
	var found: Dictionary = PRESETS[id]
	var settings := MOTION.preset(str(found.source_preset))
	settings.merge(found.get("overrides", {}), true)
	settings["sensitivity"] = float(ui.get("sensitivity", 2.5))
	settings["fov"] = float(ui.get("fov", 90.0))
	settings["wheel_jump"] = true
	return settings

## the movement configuration that enters the record key: everything except UI_KEYS.
static func physics_fingerprint(settings: Dictionary) -> Dictionary:
	var out := {}
	for key: String in settings:
		if not key in UI_KEYS:
			out[key] = settings[key]
	return out
