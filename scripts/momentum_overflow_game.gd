extends "res://scripts/momentum_carry_game.gd"
## p / r13 overflow game: the carry factory on the overflow course. the runner uses the
## provisional original air law (momentum_carry_air_candidate.gd) unless motor, or
## --overflow-air=, names a carry profile ("broad" or "narrow") as a labelled control.
## world picks the course or a block variant.
## godot --path . --script <a SceneTree that adds this node> -- [--overflow-world=block] [--overflow-air=broad]
## the tape executor loads it as --game-script res://scripts/momentum_overflow_game.gd with
## --game-class Block, BlockMirror or BlockOffset for the neutral block and its holdouts, and
## --motor candidate, broad or narrow.

const OVERFLOW_LEVEL := preload("res://scripts/momentum_overflow_level.gd")
const CANDIDATE := preload("res://scripts/momentum_carry_air_candidate.gd")
const CANDIDATE_CONTROLS := "WASD run. Space jump; hold to keep hopping.\nAir: keys bend the flight where they point (W view, A/D sideways); no keys keeps the line.\nA/D turned with the mouse carves a little speed. S brakes. Ctrl / C ducks.\nR new run    F segment practice    Esc settings"

## "course", "block", "block_mirror" or "block_offset"; empty reads --overflow-world=.
var world: String = ""

func _ready() -> void:
	OVERFLOW_LEVEL.next_variant = _world(world)
	level_script = OVERFLOW_LEVEL
	var law := air_law()
	if law == "candidate":
		player_script = CANDIDATE
	else:
		motor = law
	super()
	if law != "candidate":
		return
	hud.get("status").text = CANDIDATE_CONTROLS
	for node: Node in (hud.get("pause_panel") as Node).find_children("*", "Label", true, false):
		var label := node as Label
		if label.text.begins_with(CARRY_BUILD):
			label.text = "%s / %s / records disabled" % [CARRY_BUILD, player.get("air_policy")]
		elif label.text.begins_with("WASD run."):
			label.text = CANDIDATE_CONTROLS
	if set_window_title and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title("Spillway R13 / OVERFLOW %s / %s / records disabled" % [OVERFLOW_LEVEL.next_variant, player.get("air_policy")])
	print("overflow: air_policy=%s (the carry line above names the unused base profile)" % player.get("air_policy"))

## the air law this game runs: "candidate", or a carry profile kept as a control.
func air_law() -> String:
	var requested := motor
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--overflow-air="):
			requested = arg.trim_prefix("--overflow-air=")
	return requested if CARRY_PLAYER.PROFILES.has(requested) else "candidate"

func identity_line() -> String:
	var law := air_law()
	return "OVERFLOW %s / %s / R13 MOVEMENT EXPERIMENT" % [OVERFLOW_LEVEL.next_variant.to_upper(), "CANDIDATE AIR" if law == "candidate" else law.to_upper() + " AIR CONTROL"]

static func _world(requested: String) -> String:
	if not requested.is_empty():
		return requested
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--overflow-world="):
			return arg.trim_prefix("--overflow-world=")
	return "course"

class Block:
	extends "res://scripts/momentum_overflow_game.gd"
	func _init() -> void:
		world = "block"

class BlockMirror:
	extends "res://scripts/momentum_overflow_game.gd"
	func _init() -> void:
		world = "block_mirror"

class BlockOffset:
	extends "res://scripts/momentum_overflow_game.gd"
	func _init() -> void:
		world = "block_offset"
