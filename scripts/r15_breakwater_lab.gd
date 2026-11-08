extends SceneTree
## p / r15 Breakwater lab: the map in the unchanged r14 game, for play before root wires it into
## the r15 shell. it builds r14_main.gd with level_script set to the Breakwater level (the r14
## "fixture" map slot), so the hud, presets (F2 bhop server default, F5 AA 1000), stage practice,
## restart and quit are the delivered r14 ones. it never reads or writes a record profile.
## godot --path . --script res://scripts/r15_breakwater_lab.gd [-- --r14-preset=ID] [-- --no-hud]
##   [-- --breakwater-neutral]
## keys (r14): R restart from the gate, F practise from the last stage, Esc pause and stage list.

const MAIN := preload("res://scripts/r14_main.gd")
const PRESETS := preload("res://scripts/r14_presets.gd")
const LEVEL := "res://scripts/r15_breakwater_level.gd"

func _initialize() -> void:
	# the starting preset's physics rate is set before the world exists, as r14_launch.gd does.
	var id: String = MAIN.DEFAULT_PRESET
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--r14-preset="):
			var named := PRESETS.resolve(arg.trim_prefix("--r14-preset="))
			if PRESETS.available(named):
				id = named
	Engine.physics_ticks_per_second = int(PRESETS.entry(id).rate)
	var game: Node3D = MAIN.new()
	game.name = "R14"
	game.set("level_script", load(LEVEL))
	game.set("persist", false)
	root.add_child(game)
	current_scene = game
