extends Node3D
## p / r16 attempt session: the one place an attempt opens, is sampled and is sealed. it owns the
## style service, the run recorder and the ghost, and it only reads the game: nothing here writes
## the body, its velocity, input, progress or the clock. docs/r16/PLAYABLE.md is the contract.
##
## when a sample is taken. godot runs the main's physics callback before its children, so in
## frame N the host first does its bookkeeping (preset switch waiting for room, timer, kill
## bounds and respawn, checkpoints, finish) on the body left by motor step N-1, then the runner
## takes motor step N, then the strafe stats (priority 100) read it. this node runs after them
## (priority 999) and takes sample N from the body exactly as motor step N left it, with the host
## state as it stands at the end of that frame. that is the convention of the accepted r15 tape
## traces (post sample in a priority 1000 node), so a recording and a tape read alike. it runs
## before any priority 1000 observer, so an input such an observer injects for the next tick is
## never pulled into this tick's rows. sample N is
## stepped through style and written before frame N+1 begins, so a preset switch, a respawn or a
## reset made in frame N+1 can never be attributed to motor step N.
##
## boundaries. an R, F, map, preset, loadout or quit that ends an attempt calls boundary() before
## the game changes anything: the open file gets the boundary event, carrying the input edge that
## caused it, and is sealed; begin() then opens the next attempt after the body was placed. inputs
## delivered before the edge in the same batch go with the old attempt when the body is placed
## anew (a reset discards their effect), and stay for the new attempt when the body continues
## (a preset or loadout switch keeps feet, velocity, view and a pending jump).

const RECORDER := preload("res://scripts/r16_run_recorder.gd")
const READER := preload("res://scripts/r16_run_reader.gd")
const STYLE := preload("res://scripts/r16_style.gd")
const GHOST := preload("res://scripts/r16_ghost.gd")
const SAMPLE_VERSION := "r16-sample-1"
## p / after the strafe stats (100), before tape and pack observers (1000).
const PRIORITY := 999
## the actions whose held state enters every sample's mask.
const HELD := ["move_forward", "move_back", "move_left", "move_right", "jump", "crouch", "r15_slide", "r15_grapple", "look_left", "look_right", "look_up", "look_down"]
## boundaries after which the body is placed anew; the others keep it moving.
const RESET_KINDS := ["spawn", "restart", "practice", "map", "quit"]
## p / pending input rows kept between two samples; more are counted, not stored.
const MAX_PENDING := 8192
## p / the runner's reported travel and the host's finite difference agree to this, m/s.
const ACTUAL_V_TOLERANCE := 1e-3

var game: Node
var recorder := RECORDER.new()
var style := STYLE.new()
var ghost: Node3D
## where attempts are written; "" records nothing.
var directory: String = ""
var attempt_live: bool = false
var attempt_reason: String = ""
var tick: int = 0
## input rows since the last sample, in delivery order: InputEvent copies and action dictionaries.
var pending: Array = []
var dropped_inputs: int = 0
var last_seal: Dictionary = {}
var last_begin: Dictionary = {}
var last_sample: Dictionary = {}
var last_error: String = ""
## files this process sealed, in order: {kind, ok, status, path, run_id, ticks}.
var sealed: Array[Dictionary] = []
var actual_v_checks: int = 0
var actual_v_mismatches: int = 0
var actual_v_worst: float = 0.0
## the fastest clean complete recording for the active motion identity.
var ghost_path: String = ""
var ghost_ticks: int = -1
var ghost_state: String = "off"
## motion identity key -> {path, ticks, state}: a revisit never rescans the folder.
var _ghost_cache: Dictionary = {}
var _edge: InputEvent
var _edge_start: int = -1
var _paused_inputs: int = 0
var _prev_p := Vector3.ZERO
var _have_prev: bool = false
var _clock_prev: float = 0.0
var _clock_cur: float = 0.0
var _errors_shown: Dictionary = {}

func _init(host: Node = null, record_directory: String = "") -> void:
	name = "R16Session"
	game = host
	directory = record_directory
	recorder.enabled = not directory.is_empty()
	process_physics_priority = PRIORITY

func _ready() -> void:
	ghost = GHOST.new()
	ghost.name = "Ghost"
	add_child(ghost)

func _exit_tree() -> void:
	if attempt_live:
		boundary("quit", {"reason": "the game left the tree"})

# --- input --------------------------------------------------------------------------------------

## every event the game's _input sees, before the game acts on it. read-only: a copy is kept.
func input(event: InputEvent) -> void:
	_edge = event.duplicate() as InputEvent
	_edge_start = -1
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	if bool(game.paused):
		_paused_inputs += 1
		return
	if not attempt_live:
		return
	if pending.size() >= MAX_PENDING:
		dropped_inputs += 1
		return
	_edge_start = pending.size()
	pending.append(_edge)
	if event is InputEventMouseMotion or event is InputEventJoypadMotion:
		return
	var pressed := event.is_pressed()
	for action: StringName in InputMap.get_actions():
		if not str(action).begins_with("ui_") and event.is_action(action, true):
			pending.append({"type": "action", "action": str(action), "pressed": pressed})

func input_done() -> void:
	_edge = null
	_edge_start = -1

## the edge being handled now and its action rows, taken out of the pending rows.
func _take_edge() -> Array:
	if _edge == null:
		return []
	var rows: Array = [describe(_edge)]
	if _edge_start >= 0 and _edge_start < pending.size():
		for row: Variant in pending.slice(_edge_start + 1):
			rows.append(describe(row))
		pending = pending.slice(0, _edge_start)
	_edge = null
	_edge_start = -1
	return rows

## a json-safe description in the recorder's dictionary forms (docs/r16/RECORDINGS.md).
static func describe(input: Variant) -> Dictionary:
	if input is Dictionary:
		return (input as Dictionary).duplicate()
	if input is InputEventKey:
		var k := input as InputEventKey
		return {"type": "key", "keycode": k.keycode, "physical_keycode": k.physical_keycode, "pressed": k.pressed, "echo": k.echo}
	if input is InputEventMouseButton:
		var b := input as InputEventMouseButton
		return {"type": "mouse_button", "button_index": b.button_index, "pressed": b.pressed, "double_click": b.double_click, "factor": b.factor}
	if input is InputEventMouseMotion:
		var m := input as InputEventMouseMotion
		return {"type": "mouse_motion", "relative": [m.relative.x, m.relative.y], "screen_relative": [m.screen_relative.x, m.screen_relative.y]}
	if input is InputEventAction:
		return {"type": "action", "action": str((input as InputEventAction).action), "pressed": (input as InputEventAction).pressed}
	if input is InputEventJoypadButton:
		var j := input as InputEventJoypadButton
		return {"type": "joypad_button", "button_index": j.button_index, "pressed": j.pressed, "device": j.device}
	if input is InputEventJoypadMotion:
		var a := input as InputEventJoypadMotion
		return {"type": "joypad_motion", "axis": a.axis, "axis_value": a.axis_value, "device": a.device}
	return {"type": "other", "text": str(input).left(120)}

static func describe_all(rows: Array) -> Array:
	var out: Array = []
	for row: Variant in rows:
		out.append(describe(row))
	return out

# --- attempts -----------------------------------------------------------------------------------

## opens an attempt on the body as it now stands. a recording opens when a directory is set.
func begin(reason: String) -> void:
	if attempt_live:
		boundary(reason)
	attempt_live = true
	attempt_reason = reason
	tick = 0
	_have_prev = false
	_clock_prev = float(game.elapsed)
	_clock_cur = _clock_prev
	style.reset({"map": str(game.map_id), "preset": str(game.preset_id), "reason": reason, "attempt": int(game.attempts), "course_key": str(game.course_key)})
	last_begin = {"ok": false, "status": "off"}
	if recorder.enabled:
		last_begin = recorder.begin_run(game.call("recording_metadata", reason), directory)
		if not bool(last_begin.ok):
			_report("Recording could not start: %s. Play continues without a file." % str(last_begin.get("error", "")))
	if ghost != null and ghost.get("loaded") == true:
		ghost.call("set_time", _clock_cur)

## ends the open attempt before the game changes anything. kind: restart, practice, map,
## preset, loadout or quit. nothing is open after a finish, so post-finish play writes nothing.
func boundary(kind: String, data: Dictionary = {}) -> void:
	var edge := _take_edge()
	if not attempt_live:
		if kind in RESET_KINDS:
			pending.clear()
		return
	attempt_live = false
	var info := data.duplicate()
	info["edge"] = edge
	info["paused"] = bool(game.paused)
	if kind in RESET_KINDS:
		info["inputs"] = describe_all(pending)
		pending.clear()
	else:
		info["inputs_carried"] = pending.size()
	var score := style.summary()
	_close(kind, {"kind": kind, "clean": false, "finished": false, "elapsed": float(game.elapsed), "respawns": int(game.respawn_count),
		"checkpoint": int(game.checkpoint_index), "practice_reason": str(game.practice_reason), "style": {"score": int(score.score), "by_kind": score.by_kind}}, info)

## an event inside the open attempt (respawn, settings, pause, ghost...). `discontinuity` names
## a style discontinuity, "" for none. a placed body restarts the travel check.
func lifecycle(kind: String, data: Dictionary = {}, discontinuity: String = "", placed: bool = false) -> void:
	if not attempt_live:
		return
	if recorder.is_open():
		recorder.event(kind, data)
	if not discontinuity.is_empty():
		style.discontinuity(discontinuity)
	if placed:
		_have_prev = false

func pause_changed(now_paused: bool) -> void:
	var edge := _take_edge()
	if now_paused:
		_paused_inputs = 0
		lifecycle("pause", {"edge": edge, "pending_inputs": pending.size()})
	else:
		lifecycle("resume", {"edge": edge, "inputs_while_paused": _paused_inputs})

func _close(kind: String, outcome: Dictionary, data: Dictionary) -> Dictionary:
	var result := {"ok": false, "status": recorder.status, "kind": kind, "error": "recording is off" if not recorder.enabled else ""}
	if recorder.is_open():
		recorder.event(kind, data)
		result = recorder.finish(outcome)
		result["kind"] = kind
		if not bool(result.ok):
			_report("Recording of this attempt failed: %s. The partial file is kept and play continues." % str(result.get("error", recorder.last_error)))
	elif recorder.status == "disk-error":
		result["error"] = recorder.last_error
		result["dropped_ticks"] = recorder.dropped_ticks
	last_seal = result
	if recorder.enabled:
		sealed.append({"kind": kind, "ok": bool(result.ok), "status": str(result.get("status", "")), "path": str(result.get("path", "")),
			"run_id": str(result.get("run_id", "")), "ticks": int((result.get("counts", {}) as Dictionary).get("ticks", 0)), "error": str(result.get("error", ""))})
	return result

# --- the post-step sample -----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if game == null or game.player == null:
		return
	# the ghost's clock pair moves like the runner's camera pair: frozen while paused.
	_clock_prev = _clock_cur
	_clock_cur = float(game.elapsed)
	if bool(game.paused) or not attempt_live:
		return
	var sample := build_sample(delta)
	var scored: Array[Dictionary] = style.step(sample, game.player, game.level)
	if recorder.is_open() or recorder.status == "disk-error":
		recorder.capture(sample, scored)
		if recorder.status == "disk-error":
			_report("Recording stopped: %s. Play continues; this attempt's file stays partial." % recorder.last_error)
	last_sample = sample
	tick += 1
	if bool(game.finished):
		_seal_finish()

## the INTERFACES.md post-step sample of the body as the motor left it this frame.
func build_sample(delta: float) -> Dictionary:
	var player: CharacterBody3D = game.player
	var motion: Dictionary = player.call("get_motion_state") if player.has_method("get_motion_state") else {}
	var p := player.global_position
	# the runner reports its own travel, measured from where its step began, so a host
	# placement before the step never reads as speed. the finite difference checks it.
	var reported: Variant = motion.get("actual_velocity")
	var shift: Variant = motion.get("duck_shift", Vector3.ZERO)
	var actual := Vector3.ZERO
	if _have_prev:
		var travel := (p - _prev_p - (shift as Vector3 if shift is Vector3 else Vector3.ZERO)) / delta
		if reported is Vector3:
			var gap := (travel - (reported as Vector3)).length()
			actual_v_checks += 1
			actual_v_worst = maxf(actual_v_worst, gap)
			if gap > ACTUAL_V_TOLERANCE:
				actual_v_mismatches += 1
			actual = reported
		else:
			actual = travel
	elif reported is Vector3:
		actual = reported
	_prev_p = p
	_have_prev = true
	var held := {}
	for action: String in HELD:
		if InputMap.has_action(action):
			held[action] = Input.is_action_pressed(action)
	var rows := pending
	pending = []
	return {
		"tick": tick, "dt": delta, "physics_hz": int(game.physics_hz), "elapsed": float(game.elapsed),
		"started": bool(game.get("_started")), "finished": bool(game.finished), "clean": bool(game.clean_eligible),
		"practice_reason": str(game.practice_reason), "checkpoint": int(game.checkpoint_index), "respawns": int(game.respawn_count),
		"p": p, "reference_p": game.call("body_reference"), "v": player.velocity, "actual_v": actual,
		"yaw": float(player.get("yaw")), "pitch": float(player.get("pitch")),
		"grounded": bool(player.call("is_grounded")), "ducked": bool(game.call("is_crouched")),
		"motion": motion, "stats": game.stats.call("snapshot"), "held": held, "input_events": rows,
	}

## the finish sample was just captured: seal the file, then the game keeps its bests.
func _seal_finish() -> void:
	attempt_live = false
	var summary := style.summary()
	var clean := bool(game.clean_eligible) and str(game.finish_kind) == "clean"
	var time_ticks: int = game.call("_record_ticks", float(game.elapsed))
	var outcome := {"kind": "finish", "clean": clean, "finish_kind": str(game.finish_kind), "time": float(game.elapsed), "time_ticks": time_ticks,
		"respawns": int(game.respawn_count), "checkpoint": int(game.checkpoint_index), "practice_reason": str(game.practice_reason),
		"style": {"score": int(summary.score), "by_kind": summary.by_kind, "best_eligible": bool(summary.best_eligible) and clean}}
	var result := _close("finish", outcome, {"finish_kind": str(game.finish_kind), "elapsed": float(game.elapsed), "time_ticks": time_ticks})
	var ghost_changed := false
	if clean and bool(result.ok):
		ghost_changed = offer_ghost(str(result.path), time_ticks)
	game.call("finish_sealed", result, summary, ghost_changed)

func _report(text: String) -> void:
	last_error = text
	if _errors_shown.has(text):
		return
	_errors_shown[text] = true
	push_warning("r16: " + text)
	if game != null and game.hud != null:
		game.hud.call("notify", text)

# --- ghost --------------------------------------------------------------------------------------

## the fastest clean recording for this motion identity: the stored pointer when it still reads
## as one, else one scan of the recording folder, then cached for this identity.
func refresh_ghost(identity: Dictionary, stored: Dictionary) -> void:
	var key := JSON.stringify(READER.json_safe(identity), "", true)
	ghost_path = ""
	ghost_ticks = -1
	if ghost != null:
		ghost.call("clear")
	var cached: Dictionary = _ghost_cache.get(key, {})
	var scanned := bool(cached.get("scanned", false))
	var source: Dictionary = cached if cached.has("path") else {"path": str(stored.get("path", "")), "ticks": int(stored.get("ticks", -1))}
	ghost_state = "none yet"
	if not str(source.path).is_empty() and _load_ghost(str(source.path), identity, int(source.ticks)):
		_ghost_cache[key] = {"path": ghost_path, "ticks": ghost_ticks, "scanned": scanned}
		return
	var why := ghost_state
	_ghost_cache[key] = {"path": "", "ticks": -1, "scanned": true}
	if scanned or directory.is_empty() or not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(directory)):
		return
	# one scan per identity and process; it verifies every candidate's chain.
	var found := READER.fastest_clean(directory, identity)
	if bool(found.ok) and _load_ghost(str(found.path), identity, -1):
		_ghost_cache[key] = {"path": ghost_path, "ticks": ghost_ticks, "scanned": true}
		return
	ghost_state = why

func _load_ghost(path: String, identity: Dictionary, expected_ticks: int) -> bool:
	if ghost == null:
		return false
	var absolute := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute):
		ghost_state = "stored run missing (%s)" % path.get_file()
		return false
	var loaded: Dictionary = ghost.call("load_run", absolute, identity)
	if not bool(loaded.ok):
		ghost_state = "stored run refused (%s)" % str(loaded.get("error", "")).left(120)
		return false
	var ticks: int = game.call("_record_ticks", float(loaded.time))
	if expected_ticks >= 0 and ticks != expected_ticks:
		ghost.call("clear")
		ghost_state = "stored run time differs from its pointer"
		return false
	ghost_path = absolute
	ghost_ticks = ticks
	ghost_state = "loaded"
	return true

## a clean finish was sealed: it becomes the ghost when it is the fastest by integer ticks.
func offer_ghost(path: String, ticks: int) -> bool:
	if ticks < 0 or (ghost_ticks >= 0 and ticks >= ghost_ticks):
		return false
	var identity: Dictionary = game.call("motion_identity")
	var previous := {"path": ghost_path, "ticks": ghost_ticks}
	if not _load_ghost(path, identity, ticks):
		# the new file did not read back: keep racing the previous ghost.
		if not str(previous.path).is_empty():
			_load_ghost(str(previous.path), identity, int(previous.ticks))
		return false
	_ghost_cache[JSON.stringify(READER.json_safe(identity), "", true)] = {"path": ghost_path, "ticks": ghost_ticks, "scanned": true}
	return true

func _process(_delta: float) -> void:
	if ghost == null or game == null or ghost.get("loaded") != true:
		return
	ghost.visible = bool(game.call("ghost_shown"))
	if not ghost.visible:
		return
	# the runner draws its feet between the last two motor steps; the ghost takes the course
	# clock between the same two samples, so equal runs overlap at every rendered frame.
	var fraction := clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
	ghost.call("set_time", lerpf(_clock_prev, _clock_cur, fraction))

## a one-line state for the menu.
func recording_text() -> String:
	if not recorder.enabled:
		return "Recording off"
	var state := str(recorder.status)
	if state == "disk-error" or not last_error.is_empty():
		return "Recording to %s  ·  last problem: %s" % [ProjectSettings.globalize_path(directory), last_error.left(160)]
	return "Recording every attempt to %s" % ProjectSettings.globalize_path(directory)
