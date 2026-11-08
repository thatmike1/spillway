extends RefCounted
## p / r15 movement preset registry. the main experience is the approved r14 bhop server (F2) and
## its AA 1000 comparison (F5). vanilla64 is not offered here; the delivered r14 build keeps it.
## the quake iii-inspired projection (F4) and the unchanged r13 runner (F3) stay reachable as
## advanced comparisons, folded away in the pause menu. every source entry is the r14 cvar set,
## read from r14_presets.gd, so the approved laws cannot drift apart between the two builds.
##
## the source family's runner is res://scripts/r15_source_player.gd (real crouch). a game can be
## told to play the delivered r14 runner instead, as a labelled stand-in with its own record
## identity (r15_main.gd `source_runner`); nothing falls back to it silently.

const R14 := preload("res://scripts/r14_presets.gd")

const SOURCE_PLAYER := "res://scripts/r15_source_player.gd"
const STANDIN_PLAYER := R14.SOURCE_PLAYER

## `version` enters the record key. the source runner may refine it with its own
## `record_version` (r15_main.gd reads it from the running body).
const FAMILIES := {
	"source": {"script": SOURCE_PLAYER, "version": "r15-source-crouch", "label": "Source", "hull": "source_box"},
	"r13": {"script": R14.R13_PLAYER, "version": "r13-carry-air-candidate-1", "label": "R13", "hull": "r13_capsule"},
}
## the labelled stand-in: the approved r14 runner, without crouch.
const STANDIN_FAMILY := {"script": STANDIN_PLAYER, "version": "r14-source-motion-3", "label": "R14 Source stand-in (no crouch)", "hull": "source_box"}

## hot keys and the pause list, in this order: the main presets first, then the advanced ones.
const ORDER := ["server128", "server128_aa1000", "quake3_inspired128", "r13_original120"]
const PRIMARY := ["server128", "server128_aa1000"]
## F1 is not bound to a preset in r15; pressing it explains where vanilla went.
const RETIRED_SLOTS := {1: "CS:GO vanilla (64 Hz) is not part of R15. The delivered R14 build keeps it for comparison."}

## r15 words for the r14 entries; every motion field (family, source preset, overrides, rate)
## is read from r14_presets.gd.
const WORDS := {
	"server128": {"label": "CS:GO bhop server", "short": "bhop server",
		"summary": "the approved R14 bhop server: AA 100 · 128 Hz · autohop · no stamina, no takeoff clamp · crouch with Ctrl or C",
		"controls": "WASD run · mouse look · hold Space to keep hopping (or scroll) · Ctrl or C crouches, on the ground and in the air\nAir strafe: release W, hold A or D and turn the mouse the same way · release keys to coast"},
	"server128_aa1000": {"label": "Bhop server AA 1000", "short": "AA 1000",
		"summary": "the same bhop server at AA 1000 · 128 Hz · a configured comparison some servers run, not universal CS",
		"controls": "WASD run · mouse look · hold Space to keep hopping (or scroll) · Ctrl or C crouches\nAir strafe: release W, hold A or D and turn the mouse the same way · release keys to coast"},
	"quake3_inspired128": {"advanced": true},
	"r13_original120": {"advanced": true, "summary": "the original R13 runner and camera · 120 Hz · keys bend the flight · its own capsule body, so crouch passages may not fit"},
}

## names other tools use for the same entries (the tape hook's `motor`, the source presets).
## vanilla aliases resolve to nothing: they are not an r15 preset.
const ALIASES := {
	"csgo_server": "server128", "server": "server128", "f2": "server128",
	"aa1000": "server128_aa1000", "f5": "server128_aa1000",
	"quake": "quake3_inspired128", "f4": "quake3_inspired128",
	"r13": "r13_original120", "candidate": "r13_original120", "f3": "r13_original120",
}

static func resolve(name: String) -> String:
	var key := name.strip_edges().to_lower()
	if key in ORDER:
		return key
	return str(ALIASES.get(key, ""))

## the r14 entry with r15's words and flags. empty for anything outside ORDER.
static func entry(id: String) -> Dictionary:
	if not id in ORDER:
		return {}
	var out := R14.entry(id)
	out.merge(WORDS.get(id, {}), true)
	out["advanced"] = bool(out.get("advanced", false))
	return out

static func available(id: String) -> bool:
	return id in ORDER and R14.available(id) and FAMILIES.has(str(R14.PRESETS[id].family))

static func id_for_slot(slot: int) -> String:
	for id: String in ORDER:
		if int(R14.PRESETS[id].slot) == slot:
			return id
	return ""

static func slots() -> Array[int]:
	var out: Array[int] = []
	for id: String in ORDER:
		out.append(int(R14.PRESETS[id].slot))
	return out

## the approved r14 cvars with the player's look choices (see r14_presets.gd). the r15 runner
## completes crouch cvars it needs itself, and those enter the key through the running body.
static func source_settings(id: String, ui: Dictionary) -> Dictionary:
	return R14.source_settings(id, ui)

static func physics_fingerprint(settings: Dictionary) -> Dictionary:
	return R14.physics_fingerprint(settings)
