extends RefCounted
## keep every delivered catalog entry; saltglass changes geometry and tether gains an isolated mouse runner.
const BASE := preload("res://scripts/r19_map_catalog.gd")
const SURF := preload("res://scripts/r20_surf_level.gd")

static func make() -> Dictionary:
	var maps := BASE.make().duplicate(true)
	maps.catalog[SURF.MAP_ID] = SURF.MAP_ENTRY.duplicate(true)
	var tether: Dictionary = maps.catalog["tether-yard"]
	tether.runner = "res://scripts/r20_tether_player.gd"
	tether.script = "res://scripts/r20_tether_level.gd"
	tether.key_hint = " · Hold LMB at a ring; RMB reel; release LMB to coast"
	tether.instructions = "EXPERIMENTAL grapple only. LMB holds the rope; RMB reels. Space jumps to lift. Esc chooses automatic reel or Classic / Pendulum / Elastic. Release LMB to coast; E stays in Movement Lab."
	return maps
