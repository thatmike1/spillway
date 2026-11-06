extends SceneTree
## packed preflight: every runtime module and shader must load without source fallback.
func _initialize() -> void:
	var failures := 0
	for path: String in [
		"res://scenes/main.tscn",
		"res://scripts/spillway_main.gd", "res://scripts/spillway_player.gd",
		"res://scripts/spillway_level.gd", "res://scripts/spillway_course.gd",
		"res://scripts/spillway_hud.gd", "res://scripts/spillway_audio.gd",
		"res://scripts/spillway_driver.gd", "res://scripts/audio.gd",
		"res://scripts/spillway_art.gd", "res://scripts/spillway_finish_presentation.gd",
		"res://shaders/spillway_concrete.gdshader", "res://shaders/spillway_water.gdshader",
		"res://shaders/spillway_art_brick.gdshader", "res://shaders/spillway_art_terrain.gdshader",
		"res://shaders/spillway_finish_water.gdshader", "res://shaders/spillway_screen.gdshader",
	]:
		var present := ResourceLoader.exists(path)
		var loaded: Resource = load(path) if present else null
		var success := present and loaded != null
		print("%s packed resource %s" % ["PASS" if success else "FAIL", path])
		if not success:
			failures += 1
	quit(1 if failures else 0)
