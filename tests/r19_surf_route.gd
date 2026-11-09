extends "res://tests/r19_surf_driver.gd"
## earned full-route gate plus every-piece collision/manifest and maximum-piece-size checks.
const GEOMETRY_AUDIT := preload("res://tests/r19_surf_geometry.gd")

func _start() -> void:
	super._start()
	var geometry := GEOMETRY_AUDIT.audit(level)
	_write("geometry.json", geometry)
	assert(geometry.ok, "saltglass geometry audit failed: " + str(geometry.errors))
	assert(game.map_id == "saltglass" and not game.runner_is_standin(), "must use actual course and runner")
	assert(player.get_script().resource_path == "res://scripts/r15_source_player.gd", "frozen source runner required")
	assert(game.hull_fits(game.preset, level.spawn.origin), "authored spawn must clear the standing hull")
	assert(hz == 128 and game.preset_id == "server128", "exact F2 128 Hz required")
