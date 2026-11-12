extends Node
## fixture, not root's wiring: a labelled stand-in for r16_main's style hookup on the unchanged
## r15 main. after every node's physics step (priority 1000) it builds the INTERFACES post-step
## sample from the game and runs the style service on it; a change of game.attempts or map is a
## new attempt (style.reset), a respawn is a discontinuity. it only reads the game.
## tests/test_r16_style*.gd use it; root's r16_main replaces it.

const STYLE := preload("res://scripts/r16_style.gd")
const PANEL := preload("res://scripts/r16_style_panel.gd")
const HELD := ["move_forward", "move_back", "move_left", "move_right", "jump", "crouch"]

var game: Node
var style: RefCounted = STYLE.new()
var panel: Control
## every scored event, with the attempt it belongs to.
var scored: Array[Dictionary] = []
## compact per-tick rows when `keep_rows`.
var rows: Array[Dictionary] = []
var keep_rows := true
var tick := 0
var attempt := -1
var lifecycle: Array[Dictionary] = []
var _map := ""
var _respawns := 0
var _inputs: Array = []

func _init(host: Node) -> void:
	name = "R16StyleProbe"
	game = host
	process_physics_priority = 1000

## optional: the panel on the game's hud layer (or a new layer when the game has none).
func attach_panel() -> Control:
	panel = PANEL.new()
	var layer: Node = game.get("hud")
	if layer == null:
		layer = CanvasLayer.new()
		game.add_child(layer)
	layer.add_child(panel)
	panel.call("attach", game, style)
	return panel

func _input(event: InputEvent) -> void:
	if event is InputEventKey and not (event as InputEventKey).echo:
		_inputs.append({"key": (event as InputEventKey).physical_keycode, "pressed": (event as InputEventKey).pressed})
	elif event is InputEventMouseMotion:
		_inputs.append({"mouse": [(event as InputEventMouseMotion).screen_relative.x, (event as InputEventMouseMotion).screen_relative.y]})

## the INTERFACES post-step sample, built from an r15 main after the motor.
static func sample_of(host: Node, at_tick: int, inputs: Array = []) -> Dictionary:
	var player: CharacterBody3D = host.get("player")
	var motion: Dictionary = player.call("get_motion_state")
	var held := {}
	for action: String in HELD:
		held[action] = InputMap.has_action(action) and Input.is_action_pressed(action)
	return {
		"tick": at_tick, "dt": float(motion.get("delta", 1.0 / float(host.get("physics_hz")))), "physics_hz": int(host.get("physics_hz")),
		"elapsed": float(host.get("elapsed")), "started": bool(host.get("_started")), "finished": bool(host.get("finished")),
		"clean": bool(host.get("clean_eligible")), "practice_reason": str(host.get("practice_reason")), "checkpoint": int(host.get("checkpoint_index")),
		"respawns": int(host.get("respawn_count")), "p": player.global_position, "reference_p": host.call("body_reference"), "v": player.velocity,
		"actual_v": motion.get("actual_velocity", Vector3.ZERO), "yaw": float(player.get("yaw")), "pitch": float(player.get("pitch")),
		"grounded": bool(player.call("is_grounded")), "ducked": bool(host.call("is_crouched")), "motion": motion,
		"stats": host.get("stats").call("snapshot"), "held": held, "input_events": inputs,
	}

func _physics_process(_delta: float) -> void:
	if game == null or game.get("player") == null or bool(game.get("paused")):
		return
	var attempts := int(game.get("attempts"))
	if attempts != attempt or str(game.get("map_id")) != _map:
		attempt = attempts
		_map = str(game.get("map_id"))
		tick = 0
		_respawns = int(game.get("respawn_count"))
		style.call("reset", {"map": _map, "preset": str(game.get("preset_id")), "attempt": attempt})
		lifecycle.append({"kind": "attempt", "attempt": attempt, "map": _map})
	if int(game.get("respawn_count")) != _respawns:
		_respawns = int(game.get("respawn_count"))
		style.call("discontinuity", "respawn")
		lifecycle.append({"kind": "respawn", "attempt": attempt, "tick": tick})
	var sample := sample_of(game, tick, _inputs.duplicate())
	_inputs.clear()
	var level: Node3D = game.get("level")
	var fresh: Array = style.call("step", sample, game.get("player"), level)
	for event: Dictionary in fresh:
		var copy := event.duplicate(true)
		copy["attempt"] = attempt
		scored.append(copy)
	if keep_rows:
		var snap: Dictionary = style.call("snapshot")
		rows.append({"a": attempt, "t": tick, "p": _v(sample.p), "spd": snappedf(Vector2((sample.actual_v as Vector3).x, (sample.actual_v as Vector3).z).length() / 0.0254, 0.01),
			"g": sample.grounded, "d": sample.ducked, "score": snap.score, "combo": snap.combo, "new": fresh.map(func(e: Dictionary) -> String: return str(e.kind)),
			"crouch": (snap.diag.crouch.last as Dictionary).get("class", (snap.diag.crouch.last as Dictionary).get("verdict", ""))})
	tick += 1

static func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.0001), snappedf(v.y, 0.0001), snappedf(v.z, 0.0001)]
