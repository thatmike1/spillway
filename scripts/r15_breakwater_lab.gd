extends SceneTree
## p / standalone Breakwater launcher on the real R15 host and named map.
## presets, stage practice, restart and quit use the product code. records stay off.
## godot --path . --script res://scripts/r15_breakwater_lab.gd [-- --r15-preset=ID] [-- --no-hud]
##   [-- --breakwater-neutral]
## keys (R15): R restart from the gate, F practise from the last stage, Esc pause and stage list.

const MAIN := preload("res://scripts/r15_main.gd")
const PRESETS := preload("res://scripts/r15_presets.gd")

func _initialize() -> void:
	# the starting preset's physics rate is set before the world exists, as r14_launch.gd does.
	var id: String = MAIN.DEFAULT_PRESET
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--r15-preset="):
			var named := PRESETS.resolve(arg.trim_prefix("--r15-preset="))
			if PRESETS.available(named):
				id = named
	Engine.physics_ticks_per_second = int(PRESETS.entry(id).rate)
	var game: Node3D = MAIN.new()
	game.name = "R15"
	game.set("map_id", "breakwater")
	game.set("persist", false)
	root.add_child(game)
	current_scene = game
