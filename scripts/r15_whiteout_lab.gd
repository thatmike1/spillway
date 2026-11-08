extends SceneTree
## p / r15 Whiteout Relay lab: the actual r15 game on this map, without touching records. it is
## r15_launch.gd's path with the map fixed: the registry's `whiteout-relay` entry, F2 bhop server
## by default (F5 AA 1000), real crouch, the r15 hud, stage practice, restart and quit.
## godot --path . --script res://scripts/r15_whiteout_lab.gd [-- --r15-preset=ID] [-- --whiteout-neutral]
## keys (r15): R restart at the hangar, F practise from the last checkpoint, C or Ctrl crouch, Esc menu.

const MAIN := preload("res://scripts/r15_main.gd")
const PRESETS := preload("res://scripts/r15_presets.gd")
const MAP_ID := "whiteout-relay"

func _initialize() -> void:
	# the starting preset's physics rate is set before the world exists, as r15_launch.gd does.
	var id: String = MAIN.DEFAULT_PRESET
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--r15-preset="):
			var named := PRESETS.resolve(arg.trim_prefix("--r15-preset="))
			if PRESETS.available(named):
				id = named
	Engine.physics_ticks_per_second = int(PRESETS.entry(id).rate)
	var game: Node3D = MAIN.new()
	game.name = "R15"
	game.set("map_id", MAP_ID)
	game.set("persist", false)
	root.add_child(game)
	current_scene = game
