extends SceneTree
## p / r13 carry air candidate lab: the carry game on its neutral calibration block, with the
## candidate air law as the runner. records and settings are never written.
## godot --path . --script res://scripts/momentum_carry_air_lab.gd -- [--steady-camera] [--no-hud]
## the tape executor loads the same game as
##   --game-script res://scripts/momentum_carry_air_lab.gd --game-class Game

const CARRY_LAB := preload("res://scripts/momentum_carry_lab.gd")
const CANDIDATE := preload("res://scripts/momentum_carry_air_candidate.gd")

## carry's game factory with the candidate runner and the calibration block. the runner's base
## projection profile stays broad as a constructor prerequisite; its constants are unused.
class Game:
	extends "res://scripts/momentum_carry_game.gd"

	const CONTROLS := "WASD run. Space jump; hold to keep hopping.\nAir: keys bend the flight where they point (W view, A/D sideways); no keys keeps the line.\nA/D turned with the mouse carves a little speed. S brakes. Ctrl / C ducks.\nR new run    F segment practice    Esc settings"

	func _init() -> void:
		player_script = CANDIDATE
		level_script = CARRY_LAB.CalibrationBlock

	func _ready() -> void:
		super()
		var policy: String = player.get("air_policy")
		hud.get("status").text = CONTROLS
		for node: Node in (hud.get("pause_panel") as Node).find_children("*", "Label", true, false):
			var label := node as Label
			if label.text.begins_with(CARRY_BUILD):
				label.text = "%s / %s / records disabled" % [CARRY_BUILD, policy]
			elif label.text.begins_with("WASD run."):
				label.text = CONTROLS
		if set_window_title and DisplayServer.get_name() != "headless":
			DisplayServer.window_set_title("Spillway R13 / CARRY %s%s / records disabled" % [policy, " / steady camera" if steady_camera else ""])
		print("carry air candidate: air_policy=%s (the carry line above names the unused base profile); player=%s" % [policy, (player.get_script() as Script).resource_path])

	func identity_line() -> String:
		return "CARRY / AIR CANDIDATE%s / R13 MOVEMENT EXPERIMENT" % (" / STEADY CAMERA" if steady_camera else "")

func _initialize() -> void:
	var game := Game.new()
	game.name = "CarryAirLab"
	game.steady_camera = OS.get_cmdline_user_args().has("--steady-camera")
	root.add_child(game)
