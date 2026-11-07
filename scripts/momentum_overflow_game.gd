extends "res://scripts/momentum_carry_game.gd"
## p / r13 overflow game: the carry factory on the overflow course. air profile comes from
## air_profile or motor as in the carry factory; world picks the course or a block variant.
## godot --path . --script <a SceneTree that adds this node> -- [--overflow-world=block]
## the tape executor loads it as --game-script res://scripts/momentum_overflow_game.gd with
## --game-class Block, BlockMirror or BlockOffset for the neutral block and its holdouts.

const OVERFLOW_LEVEL := preload("res://scripts/momentum_overflow_level.gd")

## "course", "block", "block_mirror" or "block_offset"; empty reads --overflow-world=.
var world: String = ""

func _ready() -> void:
	OVERFLOW_LEVEL.next_variant = _world(world)
	level_script = OVERFLOW_LEVEL
	super()

func identity_line() -> String:
	return "OVERFLOW %s / %s AIR / R13 MOVEMENT EXPERIMENT" % [OVERFLOW_LEVEL.next_variant.to_upper(), air_profile.to_upper()]

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
