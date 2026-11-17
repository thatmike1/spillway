extends RefCounted
## p / r15 map registry. every map the r15 game knows about, in menu order, whether or not its
## module has been written yet. a map is playable only when its level script exists and loads;
## the menu lists playable maps only, so a planned map never looks finished. adding a map is one
## CATALOG entry plus its level script with the r14 level interface (docs/r15/PLAYABLE.md).
##
## `kind`: "course" counts toward the five themed courses, "legacy" is an r14 course carried
## over, "lab" is the separate movement playground (its own timing identity, never a course).
## `dress`: the r14 art/readability passes apply (the two r14 maps only).
## `roles`: surface roles a deck must have to count as stage progress; empty means any tagged
## deck. a level's own `progress_roles` wins over this.

const PRACTICE_LEVEL := preload("res://scripts/r14_practice_level.gd")
const OVERFLOW_LEVEL := preload("res://scripts/momentum_overflow_level.gd")

const CATALOG := {
	"breakwater": {"name": "Breakwater", "theme": "Container port at dusk", "kind": "course", "script": "res://scripts/r15_breakwater_level.gd"},
	"whiteout-relay": {"name": "Whiteout Relay", "theme": "Snowy radar station", "kind": "course", "script": "res://scripts/r15_whiteout_level.gd"},
	"sunken-court": {"name": "Sunken Court", "theme": "Sunlit overgrown ruin", "kind": "course", "script": "res://scripts/r15_sunken_level.gd"},
	"rainline": {"name": "Rainline", "theme": "Rainy rooftop district", "kind": "course", "script": "res://scripts/r15_rainline_level.gd"},
	"night-shift": {"name": "Night Shift", "theme": "Neon transit works", "kind": "course", "script": "res://scripts/r15_nightshift_level.gd"},
	"practice": {"name": "Penstock Yard", "theme": "R14 practice yard", "kind": "legacy", "script": "res://scripts/r14_practice_level.gd", "variant": "practice", "roles": ["route"], "dress": true},
	"overflow": {"name": "Overflow", "theme": "R13/R14 dam course", "kind": "legacy", "script": "res://scripts/momentum_overflow_level.gd", "variant": "course", "dress": true},
	"experiment": {"name": "Movement Lab", "theme": "Slide, wall jump and grapple", "kind": "lab", "script": "res://scripts/r15_experiment_level.gd"},
}
const ORDER := ["breakwater", "whiteout-relay", "sunken-court", "rainline", "night-shift", "practice", "overflow", "experiment"]
## the first available of these is the default map. penstock is the labelled development
## stand-in while breakwater does not exist.
const DEFAULT_CHAIN := ["breakwater", "practice"]

## a catalog with only the given entries, for tests that register labelled fixture maps.
## catalog: {id: entry}, order: ids. entries may give `script` as a Script instead of a path.
static func make(catalog: Dictionary = CATALOG, order: Array = ORDER, default_chain: Array = DEFAULT_CHAIN) -> Dictionary:
	return {"catalog": catalog, "order": order, "default_chain": default_chain}

static func entry(maps: Dictionary, id: String) -> Dictionary:
	var found: Dictionary = (maps.catalog as Dictionary).get(id, {})
	var out := found.duplicate()
	if not out.is_empty():
		out["id"] = id
	return out

## the level script for an entry, or null when the module is absent or does not load.
static func script_for(maps: Dictionary, id: String) -> Script:
	var found: Dictionary = (maps.catalog as Dictionary).get(id, {})
	var source: Variant = found.get("script")
	if source is Script:
		var base := (source as Script).get_instance_base_type()
		return source if base == &"Node3D" or ClassDB.is_parent_class(base, &"Node3D") else null
	if not source is String or not ResourceLoader.exists(str(source)):
		return null
	var loaded := load(str(source))
	if not loaded is Script or not (loaded as Script).can_instantiate():
		return null
	var base := (loaded as Script).get_instance_base_type()
	return loaded if base == &"Node3D" or ClassDB.is_parent_class(base, &"Node3D") else null

static func available(maps: Dictionary, id: String) -> bool:
	return (maps.catalog as Dictionary).has(id) and script_for(maps, id) != null

## playable ids in menu order.
static func playable(maps: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id: String in maps.order:
		if available(maps, id):
			out.append(id)
	return out

## registered ids whose module is not there yet, for reports; the menu never lists them.
static func missing(maps: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id: String in maps.order:
		if not available(maps, id):
			out.append(id)
	return out

static func default_id(maps: Dictionary) -> String:
	for id: String in maps.default_chain:
		if available(maps, id):
			return id
	var ids := playable(maps)
	return ids[0] if not ids.is_empty() else ""

## true when the default fell past the first entry of the chain (penstock standing in).
static func default_is_standin(maps: Dictionary, id: String) -> bool:
	var chain: Array = maps.default_chain
	return not chain.is_empty() and id != str(chain[0]) and id in chain

## a new, unbuilt level node for an entry. the r14 maps choose their variant through a static.
static func instantiate(maps: Dictionary, id: String) -> Node3D:
	var script := script_for(maps, id)
	if script == null:
		return null
	var found: Dictionary = (maps.catalog as Dictionary)[id]
	if script == PRACTICE_LEVEL:
		PRACTICE_LEVEL.next_variant = str(found.get("variant", "practice"))
	elif script == OVERFLOW_LEVEL:
		OVERFLOW_LEVEL.next_variant = str(found.get("variant", "course"))
	return script.new() as Node3D
