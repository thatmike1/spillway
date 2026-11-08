extends SceneTree
## p / r14 practice lab: Penstock Yard on its own, for quick repeated practice. it never reads
## or writes a profile or record. the runner is --r14-runner=<script>, else the r14 source
## player when that script exists, else the r13 carry runner as a labelled stand-in (it is not
## source movement). the hud measures every jump from actual take-off and landing positions.
## godot --path . --script res://scripts/r14_practice_lab.gd -- [--r14-runner=res://...]
##   [--stage=N] [--no-hud] [--practice-neutral]
## keys: R restart from the gatehouse, F restart this stage, 1-7 practise stage N, Esc pause.

const LEVEL := preload("res://scripts/r14_practice_level.gd")
const R12_MAIN := preload("res://scripts/spillway_main.gd")
const SOURCE_RUNNER := "res://scripts/r14_source_player.gd"
const STAND_IN := "res://scripts/momentum_carry_air_candidate.gd"
const SOURCE_PRESETS := ["csgo_server", "csgo_vanilla"]

class Lab:
	extends Node3D

	## p / speed shown: mean horizontal travel over the last 0.1 s of physics steps.
	const SPEED_WINDOW := 0.1

	var runner_path: String = ""
	var runner_label: String = ""
	var source_preset: String = "csgo_server"
	## the tape executor's game hook sets this before _ready: a source preset name selects
	## the source runner's profile (and its physics rate), as --r14-preset= does.
	var motor: String = ""
	## the active runner's declared rate, read by the tape executor after _ready.
	var physics_hz: int:
		get:
			return int(player.get("physics_hz")) if player != null and "physics_hz" in player else Engine.physics_ticks_per_second
	var start_stage: int = 0
	var show_hud: bool = true
	var set_window_title: bool = true
	var level: Node3D
	var player: CharacterBody3D
	var hud: CanvasLayer
	var paused: bool = false

	# run state, with the overflow main's meanings
	var elapsed: float = 0.0
	var finished: bool = false
	## clean (every stage in order from the gatehouse), open (from the gatehouse, a stage
	## skipped) or practice (started at a stage, or respawned).
	var finish_kind: String = ""
	var checkpoint_index: int = 0
	var clean_eligible: bool = true
	var respawn_count: int = 0
	var stage_times: Array[float] = []
	var attempts: int = 0
	var display_speed: float = 0.0
	## the last measured jump: take-off and landing positions and speeds, distance, the gap
	## it crossed and whether it landed on a deck.
	var last_jump: Dictionary = {}
	var jumps: Array[Dictionary] = []

	var _samples: Array[float] = []
	var _previous := Vector3.ZERO
	var _started := false
	var _origin := Vector3.ZERO
	var _was_grounded := true
	var _takeoff: Dictionary = {}
	var _outside := 0.0
	var _labels: Dictionary = {}

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		R12_MAIN.bind_inputs()
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--r14-runner="):
				runner_path = arg.trim_prefix("--r14-runner=")
			elif arg.begins_with("--r14-preset="):
				source_preset = arg.trim_prefix("--r14-preset=")
			elif arg.begins_with("--stage="):
				start_stage = int(arg.trim_prefix("--stage="))
			elif arg == "--no-hud":
				show_hud = false
		if SOURCE_PRESETS.has(motor):
			source_preset = motor
		_bind_lab_keys()
		level = LEVEL.new()
		level.name = "PenstockYard"
		add_child(level)
		level.call("build")
		_make_runner()
		_make_hud()
		if start_stage > 0:
			practise(start_stage)
		else:
			restart()
		if set_window_title and DisplayServer.get_name() != "headless":
			DisplayServer.window_set_title("Spillway R14 / %s practice lab / %s / records off" % [LEVEL.LEVEL_NAME, runner_label])
		print("r14 practice lab: level=%s v%d hash=%s runner=%s (%s) physics_hz=%d" % [LEVEL.LEVEL_ID, LEVEL.LEVEL_VERSION, str(level.call("geometry_hash")).left(12), runner_path, runner_label, Engine.physics_ticks_per_second])

	func _make_runner() -> void:
		if runner_path.is_empty():
			runner_path = SOURCE_RUNNER if ResourceLoader.exists(SOURCE_RUNNER) else STAND_IN
		runner_label = "R13 carry runner, stand-in, NOT Source" if runner_path == STAND_IN else (runner_path.get_file().get_basename())
		player = (load(runner_path) as Script).new()
		if runner_path == SOURCE_RUNNER:
			player.call("apply_preset", source_preset)
			player.call("apply_engine_rate")
			runner_label = "%s, %d Hz" % [source_preset, Engine.physics_ticks_per_second]
		# the carry base needs a profile name before it enters the tree; other runners ignore it.
		if "air_profile" in player:
			player.set("air_profile", "broad")
		player.name = "Runner"
		add_child(player)
		for key: String in ["mouse_sensitivity"]:
			if key in player:
				player.set(key, 0.0022)

	func _bind_lab_keys() -> void:
		for i: int in 9:
			var action := "lab_stage_%d" % (i + 1)
			if InputMap.has_action(action):
				InputMap.erase_action(action)
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = KEY_1 + i
			InputMap.action_add_event(action, event)

	func stage_count() -> int:
		return (level.get("checkpoints") as Array).size()

	func stage_title(stage: int) -> String:
		return str(((level.get("checkpoints") as Array)[stage] as Dictionary).title)

	# --- attempts -----------------------------------------------------------------------------

	## a run from the gatehouse; the only kind that can finish clean.
	func restart() -> void:
		_begin(0, true)

	## practice from a stage's pose. never clean.
	func practise(stage: int) -> void:
		_begin(clampi(stage, 0, stage_count() - 1), false)

	func _begin(stage: int, clean: bool) -> void:
		attempts += 1
		elapsed = 0.0
		finished = false
		finish_kind = ""
		checkpoint_index = stage
		clean_eligible = clean and stage == 0
		respawn_count = 0
		stage_times.clear()
		for i: int in stage_count():
			stage_times.append(-1.0)
		_started = false
		var points: Array = level.get("checkpoints")
		player.call("reset_to", (points[stage] as Dictionary).pose)
		_origin = player.global_position
		_previous = player.global_position
		_samples.clear()
		_takeoff = {}
		_was_grounded = true
		level.call("reset_state")
		_set_paused(false)

	func _respawn() -> void:
		respawn_count += 1
		clean_eligible = false
		var points: Array = level.get("checkpoints")
		player.call("reset_to", (points[checkpoint_index] as Dictionary).pose)
		_previous = player.global_position
		_samples.clear()
		_takeoff = {}

	# --- physics: progress, finish, measured jumps ---------------------------------------------

	func _physics_process(delta: float) -> void:
		if player == null or paused:
			return
		var p := player.global_position
		var step := Vector2(p.x - _previous.x, p.z - _previous.z).length() / delta
		_previous = p
		_samples.append(step)
		while _samples.size() > maxi(1, roundi(SPEED_WINDOW * Engine.physics_ticks_per_second)):
			_samples.pop_front()
		var total := 0.0
		for value: float in _samples:
			total += value
		display_speed = total / _samples.size()
		if not _started and p.distance_to(_origin) > 0.5:
			_started = true
		if _started and not finished:
			elapsed += delta
		if not (level.get("kill_bounds") as AABB).has_point(p):
			_outside += delta
			if _outside > 0.12:
				_outside = 0.0
				_respawn()
			return
		_outside = 0.0
		_track_jump(p, step)
		if finished:
			return
		_collect(p)
		if level.call("is_finish_at", p):
			_finish()

	func _track_jump(p: Vector3, speed: float) -> void:
		var grounded: bool = player.call("is_grounded")
		if _was_grounded and not grounded:
			_takeoff = {"p": p, "speed": speed, "t": elapsed}
		elif not _was_grounded and grounded and not _takeoff.is_empty():
			var from: Vector3 = _takeoff.p
			var distance := Vector2(p.x - from.x, p.z - from.z).length()
			if distance > 0.3:
				last_jump = {"from": from, "to": p, "distance_m": distance, "distance_u": distance / LEVEL.U,
					"takeoff_ups": float(_takeoff.speed) / LEVEL.U, "landing_ups": speed / LEVEL.U, "air_s": elapsed - float(_takeoff.t),
					"gap": _crossed_gap(from, p), "surface": _support_role()}
				jumps.append(last_jump)
				if jumps.size() > 64:
					jumps.pop_front()
			_takeoff = {}
		_was_grounded = grounded

	func _crossed_gap(from: Vector3, to: Vector3) -> String:
		# the declared gap whose edge-to-landing line this flight crossed, judged by height.
		var a := Vector2(from.x, from.z)
		var b := Vector2(to.x, to.z)
		for gap: Dictionary in level.get("jump_gaps"):
			var edge: Vector3 = gap.edge
			var land: Vector3 = gap.land
			var mid := Vector2((edge.x + land.x) * 0.5, (edge.z + land.z) * 0.5)
			var along := Vector2(land.x - edge.x, land.z - edge.z).normalized()
			var across := Vector2(-along.y, along.x)
			var half := float(gap.width_m) * 0.5
			# crossing the gap's middle line within 4 m of where it was declared.
			var da := (a - mid).dot(along)
			var db := (b - mid).dot(along)
			if da < 0.0 and db > -half and absf((a - mid).dot(across)) < 4.0 and from.y > edge.y - 0.3:
				var made := to.y > land.y - 0.3 and db >= half - 0.05
				return "%s %.1f m: %s" % [gap.label, gap.width_m, "made" if made else "short"]
		return ""

	func _support_role() -> String:
		var bodies := _supports()
		return str(bodies[0].get_meta("surface", "")) if not bodies.is_empty() else ""

	## the bodies the grounded runner stands on. move_and_slide runners report them as slide
	## collisions; the source runner moves with move_and_collide and reports none, so for it a
	## hull-sized slab at the feet asks the world (a 6 cm slab, 1 cm inside the hull's sides so
	## a wall beside it is not counted).
	func _supports() -> Array[Node]:
		var out: Array[Node] = []
		if "settings" in player and (player.get("settings") as Dictionary).has("hull_width"):
			var width := float((player.get("settings") as Dictionary).hull_width) * LEVEL.U - 0.02
			var slab := BoxShape3D.new()
			slab.size = Vector3(width, 0.06, width)
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = slab
			query.transform = Transform3D(Basis.IDENTITY, player.global_position + Vector3.DOWN * 0.02)
			query.exclude = [player.get_rid()]
			for hit: Dictionary in player.get_world_3d().direct_space_state.intersect_shape(query, 8):
				var body := hit.collider as Node
				if body != null and body.has_meta("surface") and str(body.get_meta("surface")) != "wall" and not out.has(body):
					out.append(body)
			return out
		for i: int in player.get_slide_collision_count():
			var contact := player.get_slide_collision(i)
			for j: int in contact.get_collision_count():
				var body := contact.get_collider(j) as Node
				if body != null and contact.get_normal(j).y > 0.7 and not out.has(body):
					out.append(body)
		return out

	func _collect(p: Vector3) -> void:
		# p / the overflow main's rule: the next or a later stage, by standing on its deck.
		if not player.call("is_grounded"):
			return
		var stage := -1
		for body: Node in _supports():
			if str(body.get_meta("surface", "")) == "route":
				stage = maxi(stage, int(body.get_meta("progress_stage", -1)))
		if stage > checkpoint_index:
			stage_times[stage - 1] = elapsed
			checkpoint_index = stage

	func _finish() -> void:
		finished = true
		stage_times[stage_count() - 1] = elapsed
		var complete := true
		for value: float in stage_times:
			complete = complete and value >= 0.0
		finish_kind = "practice" if not clean_eligible else ("clean" if complete else "open")
		level.call("start_wheel")
		print("r14 practice lab: finish %s %.3f s, runner %s, splits %s" % [finish_kind, elapsed, runner_label, str(stage_times)])

	# --- input -------------------------------------------------------------------------------

	func _input(event: InputEvent) -> void:
		if event.is_action_pressed("restart"):
			restart()
		elif event.is_action_pressed("practice"):
			practise(checkpoint_index)
		elif event.is_action_pressed("pause"):
			_set_paused(not paused)
		elif event.is_action_pressed("fullscreen"):
			var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif event is InputEventMouseButton and event.pressed and not paused and DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			for i: int in 9:
				if event.is_action_pressed("lab_stage_%d" % (i + 1)) and i < stage_count():
					practise(i)

	func _set_paused(value: bool) -> void:
		paused = value
		get_tree().paused = value
		if "input_enabled" in player:
			player.set("input_enabled", not value)
		if DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED

	# --- hud ---------------------------------------------------------------------------------

	func _make_hud() -> void:
		hud = CanvasLayer.new()
		hud.name = "LabHud"
		add_child(hud)
		hud.visible = show_hud
		for key: String in ["title", "speed", "jump", "hint"]:
			var label := Label.new()
			label.add_theme_font_size_override("font_size", 30 if key == "speed" else 18)
			label.add_theme_color_override("font_color", Color("f2ecd8"))
			label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.05, 0.85))
			label.add_theme_constant_override("outline_size", 6)
			hud.add_child(label)
			_labels[key] = label
		(_labels.title as Label).position = Vector2(20, 14)
		(_labels.speed as Label).set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		(_labels.jump as Label).position = Vector2(20, 96)
		(_labels.hint as Label).set_anchors_preset(Control.PRESET_BOTTOM_LEFT)

	func _process(_delta: float) -> void:
		if hud == null or not hud.visible:
			return
		var kind := "clean run" if clean_eligible else "practice"
		(_labels.title as Label).text = "%s · R14 practice lab · %s\nstage %d/%d %s · %s · %.2f s%s" % [LEVEL.LEVEL_NAME, runner_label, checkpoint_index + 1, stage_count(), stage_title(checkpoint_index), kind, elapsed,
			("   FINISH %s" % finish_kind.to_upper()) if finished else ""]
		(_labels.speed as Label).text = "%d u/s   %.2f m/s" % [roundi(display_speed / LEVEL.U), display_speed]
		var size := get_viewport().get_visible_rect().size
		(_labels.speed as Label).position = Vector2(size.x * 0.5 - 130.0, size.y - 120.0)
		if not last_jump.is_empty():
			(_labels.jump as Label).text = "last jump %.2f m / %d u, %.2f s air\ntake-off %d u/s, landing %d u/s%s" % [last_jump.distance_m, roundi(last_jump.distance_u), last_jump.air_s,
				roundi(last_jump.takeoff_ups), roundi(last_jump.landing_ups), ("\n" + str(last_jump.gap)) if not str(last_jump.gap).is_empty() else ""]
		(_labels.hint as Label).text = str(level.call("route_hint", checkpoint_index, player.global_position)) + "\nR restart · F this stage · 1-%d stages · Esc pause" % stage_count()
		(_labels.hint as Label).position = Vector2(20, size.y - 64.0)

func _initialize() -> void:
	var lab := Lab.new()
	lab.name = "PracticeLab"
	root.add_child(lab)
	current_scene = lab
