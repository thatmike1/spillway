extends Node
## fixture, not root's wiring: a labelled stand-in for r16_main's recording hookup, so the
## recorder and ghost can be exercised on the real, unchanged R15 host before root integrates
## them. it builds the INTERFACES post-step sample after every node's physics step (priority
## 1000), collects the actual input events the viewport delivers, and opens and seals one
## recording per attempt. it only reads the game; it never writes the body, input or progress.
##
## attempt boundaries: a change of game.attempts (R, F, stage practice) or map seals the old
## attempt with that outcome and opens a new one; the edge that caused it (the R or F press) is
## recorded in the old attempt as the boundary event's data, not in the new attempt's first tick.
## the finish line seals the attempt on the tick the game reports finished. pause ticks are not
## samples; pause and resume are lifecycle events. respawns stay inside the attempt.

const RECORDER := preload("res://scripts/r16_run_recorder.gd")
const READER := preload("res://scripts/r16_run_reader.gd")
const HELD := ["move_forward", "move_back", "move_left", "move_right", "jump", "crouch", "r15_slide", "r15_grapple", "look_left", "look_right", "look_up", "look_down"]
const BOUNDARY_ACTIONS := {"restart": "restart", "practice": "practice"}

var game: Node
var directory := ""
var recorder := RECORDER.new()
var results: Array[Dictionary] = []
var trace: Array[Dictionary] = []
var ghost: Node3D
## wall time of each capture() call, microseconds: the per-tick cost, chunk writes included.
var capture_usec := PackedInt64Array()
var _attempt := -1
var _map := ""
var _tick := 0
var _pending_inputs: Array = []
var _boundary_inputs: Array = []
var _was_paused := false
var _was_respawns := 0
var _sealed := false

func _init(host: Node, dir: String) -> void:
	name = "R16RecordAdapter"
	game = host
	directory = dir
	process_physics_priority = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton or (event is InputEventKey and not (event as InputEventKey).echo) \
			or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		for action: String in BOUNDARY_ACTIONS:
			if event.is_action_pressed(action):
				_boundary_inputs.append(event)
				return
		_pending_inputs.append(event)

func identity() -> Dictionary:
	var player: Node = game.player
	return {"map": str(game.map_id), "preset": str(game.preset_id), "course_key": str(game.course_key), "geometry": str(game.course_geometry),
		"mechanics": str((player.get_script() as Script).resource_path) + "#" + str(player.get("MOTOR_VERSION") if "MOTOR_VERSION" in player else ""),
		"physics_hz": int(game.physics_hz), "fixture": "tests/r16_record_adapter.gd"}

func _begin(reason: String) -> void:
	var meta := {"map": str(game.map_id), "preset": str(game.preset_id), "attempt": int(game.attempts), "start_reason": reason,
		"build": "r16-recorder-fixture (R15 host, labelled test adapter)", "identity": identity(),
		"practice_stage": int(game.practice_stage), "held_actions": HELD}
	var opened := recorder.begin_run(meta, directory)
	if not bool(opened.ok):
		push_error("r16 adapter: " + str(opened.error))
	_tick = 0
	_sealed = false
	_attempt = int(game.attempts)
	_map = str(game.map_id)
	_was_respawns = int(game.respawn_count)

func _seal(outcome: Dictionary) -> void:
	if recorder.is_open():
		var done := recorder.finish(outcome)
		results.append(done)
	_sealed = true

func close(kind: String = "quit") -> void:
	if recorder.is_open():
		recorder.event(kind, {})
		_seal({"kind": kind, "clean": false, "finished": false})

func _physics_process(delta: float) -> void:
	if game == null or game.player == null:
		return
	if bool(game.paused):
		if not _was_paused and recorder.is_open():
			recorder.event("pause", {})
		_was_paused = true
		return
	if _was_paused and recorder.is_open():
		recorder.event("resume", {})
	_was_paused = false
	if _attempt < 0:
		_begin("spawn")
	elif int(game.attempts) != _attempt or str(game.map_id) != _map:
		var kind := "map" if str(game.map_id) != _map else ("practice" if int(game.practice_stage) >= 0 else "restart")
		if recorder.is_open():
			recorder.event(kind, {"inputs": _describe(_boundary_inputs)})
			_seal({"kind": kind, "clean": false, "finished": false})
		_boundary_inputs.clear()
		_begin(kind)
	if _sealed:
		_pending_inputs.clear()
		return
	var player: CharacterBody3D = game.player
	var motion: Dictionary = player.call("get_motion_state")
	if int(game.respawn_count) > _was_respawns:
		recorder.event("respawn", {"count": int(game.respawn_count), "checkpoint": int(game.checkpoint_index)})
	_was_respawns = int(game.respawn_count)
	var held := {}
	for action: String in HELD:
		held[action] = InputMap.has_action(action) and Input.is_action_pressed(action)
	var sample := {
		"tick": _tick, "dt": delta, "physics_hz": int(game.physics_hz), "elapsed": float(game.elapsed),
		"started": bool(game.get("_started")), "finished": bool(game.finished), "clean": bool(game.clean_eligible),
		"practice_reason": str(game.practice_reason), "checkpoint": int(game.checkpoint_index), "respawns": int(game.respawn_count),
		"p": player.global_position, "reference_p": game.call("body_reference"), "v": player.velocity,
		"actual_v": motion.get("actual_velocity", Vector3.ZERO), "yaw": float(player.get("yaw")), "pitch": float(player.get("pitch")),
		"grounded": bool(player.call("is_grounded")), "ducked": bool(game.call("is_crouched")), "motion": motion,
		"stats": game.stats.call("snapshot"), "held": held, "input_events": _pending_inputs.duplicate(),
	}
	_pending_inputs.clear()
	trace.append({"tick": _tick, "attempt": _attempt, "p": player.global_position, "v": player.velocity, "yaw": float(player.get("yaw")),
		"pitch": float(player.get("pitch")), "elapsed": float(game.elapsed), "checkpoint": int(game.checkpoint_index)})
	var before := Time.get_ticks_usec()
	recorder.capture(sample)
	var spent := Time.get_ticks_usec() - before
	capture_usec.append(spent)
	_tick += 1
	if ghost != null:
		ghost.call("set_time", float(game.elapsed))
	if bool(game.finished):
		recorder.event("finish", {"finish_kind": str(game.finish_kind), "elapsed": float(game.elapsed)})
		_seal({"kind": "finish", "clean": bool(game.clean_eligible) and str(game.finish_kind) == "clean", "finish_kind": str(game.finish_kind),
			"time": float(game.elapsed), "finished": true, "respawns": int(game.respawn_count)})

static func _describe(events: Array) -> Array:
	var out: Array = []
	for e: Variant in events:
		if e is InputEventKey:
			out.append({"keycode": (e as InputEventKey).keycode, "physical_keycode": (e as InputEventKey).physical_keycode, "pressed": (e as InputEventKey).pressed})
		else:
			out.append(str(e).left(120))
	return out
