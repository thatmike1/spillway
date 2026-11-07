extends Node3D
## p / r13 game: overflow within spillway, on the carry runner with the original air law.
## self-contained on purpose: it does not extend spillway_main.gd, so r12's build id, save
## path and record namespace cannot leak into this build's identity or its records. it only
## borrows r12's static key bindings, so the controls are the same keys.
##
## records live in their own profile file, keyed by the course's geometry, its stage titles,
## the timing rules and the runner's tuning. a changed course starts a fresh record set and
## never inherits incomparable bests; the earlier set stays in the file untouched.
##
## persistence is off unless the launch scene asks for it, so a driver, tape executor or
## comparison that builds this node with new() neither reads nor writes any profile.
## godot --path . res://scenes/momentum_overflow.tscn [-- --no-records] [-- --r13-profile=PATH]
## godot --path . --script res://scripts/momentum_overflow_launch.gd   (same scene)

const BUILD_ID := "spillway-2026.11.07-r13-overflow"
const BUILD_LABEL := "Spillway R13"
const COURSE_NAME := "Overflow"
const SAVE_PATH := "user://spillway_r13.cfg"
## read once, settings only, when no r13 profile exists yet. never opened for writing.
const R12_SETTINGS_PATH := "user://spillway_r12.cfg"
const PROFILE_FORMAT := 1
## p / bump when what counts as a finish, a split or a clean run changes.
const TIMING_RULES := "r13-timing-1"
const LEVEL := preload("res://scripts/momentum_overflow_level.gd")
const ART := preload("res://scripts/momentum_overflow_art.gd")
const RUNNER := preload("res://scripts/momentum_carry_air_candidate.gd")
const HUD := preload("res://scripts/momentum_overflow_hud.gd")
const AUDIO := preload("res://scripts/momentum_overflow_audio.gd")
const R12_MAIN := preload("res://scripts/spillway_main.gd")
const DEFAULT_SETTINGS := {"sensitivity": 1.0, "fov": 90.0, "volume": 0.70, "comfort": false, "autohop": true}
## p / the inherited course envelope; a level may publish its own `kill_bounds` AABB.
const KILL_BOUNDS := AABB(Vector3(-180, -8.3, -400), Vector3(360, 400, 460))
## p / speed shown to the player: mean finite-difference travel over the last 0.1 s.
const SPEED_WINDOW := 12

## the launch scene sets this; anything built with new() stays read-free and write-free.
@export var persist: bool = false
var profile_path: String = SAVE_PATH
## optional Script, or path of a level node with the overflow interface. default: the course.
var level_script: Variant = null
## "course" unless a factory or --overflow-world= picks one of the level's other variants.
var world: String = "course"
var set_window_title: bool = true

var player: CharacterBody3D
var level: Node3D
var hud: CanvasLayer
var audio: Node
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var paused: bool = false

# run state
var elapsed: float = 0.0
var finished: bool = false
## clean (every stage in order), open (clean, but a stage was skipped) or practice.
var finish_kind: String = ""
var checkpoint_index: int = 0
var respawn_count: int = 0
var clean_eligible: bool = true
## the stage practice started from, or -1 on a clean run.
var practice_stage: int = -1
## time at each stage boundary (index 0 is the first checkpoint after the start, the last is the
## finish); -1 where the runner never measured it. skipped stages stay -1.
var stage_times: Array[float] = []
## per-stage segment deltas against the best segment, NAN where no comparison exists.
var split_deltas: Array[float] = []

# records for this course key only
var course_key: String = ""
var course_geometry: String = ""
var best_time: float = -1.0
var open_best_time: float = -1.0
var best_splits: Array[float] = []
var best_segments: Array[float] = []
## the clean best before the latest finish, for the finish card's comparison.
var previous_best: float = -1.0
var last_save_ok: bool = false
var profile_state: String = "off"

var display_speed: float = 0.0
var _speed_samples: Array[float] = []
var _started: bool = false
var _spawn_origin: Vector3
var _recovery_time: float = 0.0
var _quitting: bool = false
var _kill_bounds: AABB = KILL_BOUNDS

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	R12_MAIN.bind_inputs()
	var args := OS.get_cmdline_user_args()
	var explicit_profile := false
	for arg: String in args:
		if arg.begins_with("--r13-profile="):
			profile_path = arg.trim_prefix("--r13-profile=")
			explicit_profile = true
		elif arg.begins_with("--overflow-level="):
			level_script = arg.trim_prefix("--overflow-level=")
		elif arg.begins_with("--overflow-world="):
			world = arg.trim_prefix("--overflow-world=")
	# p / headless runs are tests or drivers: they persist only into a profile named for them.
	if args.has("--no-records") or (DisplayServer.get_name() == "headless" and not explicit_profile and profile_path == SAVE_PATH):
		persist = false
	_build_world()
	_kill_bounds = level.get("kill_bounds") if level.get("kill_bounds") is AABB else KILL_BOUNDS
	course_geometry = _geometry_id()
	course_key = _course_key()
	_load()
	hud = HUD.new()
	add_child(hud)
	hud.call("attach", self)
	audio = AUDIO.new()
	add_child(audio)
	audio.call("attach", player, level)
	_apply_settings()
	restart_run()
	if args.has("--no-hud"):
		hud.hide()
	if set_window_title and DisplayServer.get_name() != "headless":
		get_window().title = "%s · %s" % [BUILD_LABEL, COURSE_NAME]
	print("r13 overflow: build=%s; course=%s; stages=%d; course_key=%s; records=%s; runner=%s; renderer=%s" % [BUILD_ID, COURSE_NAME, stage_count(), course_key, profile_state, player.get("air_policy"), RenderingServer.get_current_rendering_method()])
	if args.has("--verify-startup"):
		await get_tree().physics_frame
		await get_tree().physics_frame
		request_quit()

func _build_world() -> void:
	var script: Script = LEVEL
	if level_script is Script:
		script = level_script
	elif level_script is String and not str(level_script).is_empty():
		script = load(str(level_script))
	if script == LEVEL:
		LEVEL.next_variant = world
	level = script.new()
	level.name = "Spillway"
	add_child(level)
	level.call("build")
	ART.apply(level)
	player = RUNNER.new()
	# the carry base needs a profile name before it enters the tree; the candidate law ignores it.
	player.set("air_profile", "broad")
	player.name = "Runner"
	add_child(player)

## progress points after the start, the finish included: the number of timed segments.
func stage_count() -> int:
	return maxi(1, (level.get("checkpoints") as Array).size())

## the name of the place segment i ends at: a checkpoint title, then the finish.
func segment_title(i: int) -> String:
	var points: Array = level.get("checkpoints")
	if i + 1 < points.size():
		return str((points[i + 1] as Dictionary).get("title", "Stage %d" % (i + 1)))
	var finish_title: Variant = level.get("finish_title")
	return str(finish_title) if finish_title is String and not str(finish_title).is_empty() else "Finish"

func stage_title(stage: int) -> String:
	var points: Array = level.get("checkpoints")
	return str((points[stage] as Dictionary).get("title", "Start")) if stage < points.size() else "Start"

# --- run lifecycle -----------------------------------------------------------------------------

func restart_run() -> void:
	elapsed = 0.0
	finished = false
	finish_kind = ""
	checkpoint_index = 0
	respawn_count = 0
	clean_eligible = true
	practice_stage = -1
	_reset_stage_times()
	_started = false
	_recovery_time = 0.0
	player.call("reset_to", level.get("spawn"))
	_spawn_origin = player.global_position
	if level.has_method("reset_state"):
		level.call("reset_state")
	_clear_speed()
	set_paused(false)
	hud.call("run_started")

## segment practice from the last stage the runner reached. never recorded.
func practice_restart() -> void:
	clean_eligible = false
	finished = false
	finish_kind = ""
	practice_stage = checkpoint_index
	_reset_stage_times()
	# p / the practice clock starts at the segment, so each practice shows that segment's time.
	elapsed = 0.0
	_started = false
	_restore_checkpoint()
	_spawn_origin = player.global_position
	if level.has_method("reset_state"):
		level.call("reset_state")
	set_paused(false)
	hud.call("practice_started", stage_title(checkpoint_index))

## a fall out of the course: back to the last stage, as practice.
func respawn() -> void:
	respawn_count += 1
	clean_eligible = false
	finished = false
	finish_kind = ""
	_restore_checkpoint()
	hud.call("respawned", stage_title(checkpoint_index))

func _restore_checkpoint() -> void:
	var points: Array = level.get("checkpoints")
	var pose: Transform3D = level.get("spawn")
	if checkpoint_index < points.size():
		pose = (points[checkpoint_index] as Dictionary)["pose"]
	player.call("reset_to", pose)
	_recovery_time = 0.0
	_clear_speed()

func _reset_stage_times() -> void:
	stage_times.clear()
	split_deltas.clear()
	for i: int in stage_count():
		stage_times.append(-1.0)

func _physics_process(delta: float) -> void:
	if player == null or paused:
		return
	_sample_speed()
	if not _started and player.global_position.distance_to(_spawn_origin) > 0.5:
		_started = true
	if _started and not finished:
		elapsed += delta
	var water := false
	for region: Dictionary in level.get("water_regions"):
		if (region["bounds"] as AABB).has_point(player.global_position):
			water = true
	player.set("in_water", water)
	if not _kill_bounds.has_point(player.global_position):
		_recovery_time += delta
		if _recovery_time > 0.12:
			if finished:
				# p / looking round after a finish cannot change its result: back onto the finish.
				var look_pitch: float = player.get("pitch")
				var look_yaw: float = player.get("yaw")
				player.call("reset_to", Transform3D(Basis(Vector3.UP, look_yaw), (level.get("finish_position") as Vector3) + Vector3.UP * 0.04))
				player.set("pitch", look_pitch)
				_recovery_time = 0.0
				_clear_speed()
				hud.call("notify", "Back at the finish")
			else:
				respawn()
		return
	_recovery_time = 0.0
	if finished:
		return
	_collect_checkpoints()
	if level.call("is_finish_at", player.global_position):
		_finish()

func _collect_checkpoints() -> void:
	# p / the next stage, or a later one reached by a physical skip; a skipped stage gets no time.
	var points: Array = level.get("checkpoints")
	for stage: int in range(points.size() - 1, checkpoint_index, -1):
		var point: Dictionary = points[stage]
		var reached := false
		if point.get("bounds") is AABB:
			reached = (point["bounds"] as AABB).has_point(player.global_position)
		else:
			reached = player.global_position.distance_to((point["pose"] as Transform3D).origin) < float(point.get("radius", 5.0))
		if reached or _stands_on_stage(stage):
			var skipped := stage - checkpoint_index - 1
			checkpoint_index = stage
			stage_times[stage - 1] = elapsed
			hud.call("stage_reached", stage - 1, skipped)
			return

func _stands_on_stage(stage: int) -> bool:
	# p / progress follows decks the runner actually stands on, never side-wall contact.
	if not player.is_grounded():
		return false
	var feet: Vector3 = player.global_position
	for i: int in player.get_slide_collision_count():
		var contact: KinematicCollision3D = player.get_slide_collision(i)
		for j: int in contact.get_collision_count():
			if contact.get_normal(j).y < cos(player.floor_max_angle) - 0.01:
				continue
			var point: Vector3 = contact.get_position(j)
			if absf(point.y - feet.y) > 0.3 or Vector2(point.x - feet.x, point.z - feet.z).length() > 0.8:
				continue
			var body := contact.get_collider(j) as Node
			if body != null and int(body.get_meta("progress_stage", -1)) == stage:
				return true
	return false

func _finish() -> void:
	finished = true
	stage_times[stage_count() - 1] = elapsed
	var complete := true
	for value: float in stage_times:
		if value < 0.0:
			complete = false
	if not clean_eligible:
		finish_kind = "practice"
	else:
		finish_kind = "clean" if complete else "open"
	var is_best := false
	var is_open_best := false
	previous_best = best_time
	split_deltas.clear()
	if finish_kind == "clean":
		var previous := 0.0
		for i: int in stage_times.size():
			var segment := stage_times[i] - previous
			previous = stage_times[i]
			split_deltas.append(segment - best_segments[i] if i < best_segments.size() and best_segments[i] > 0.0 else NAN)
			if i >= best_segments.size():
				best_segments.append(segment)
			elif best_segments[i] <= 0.0 or segment < best_segments[i]:
				best_segments[i] = segment
		is_best = best_time < 0.0 or elapsed < best_time
		if is_best:
			best_time = elapsed
			best_splits = stage_times.duplicate()
	if finish_kind == "clean" or finish_kind == "open":
		# p / any clean physical arrival, ordered or not, competes for the open-line best.
		is_open_best = open_best_time < 0.0 or elapsed < open_best_time
		if is_open_best:
			open_best_time = elapsed
		_save()
	if level.has_method("start_wheel"):
		level.call("start_wheel")
	audio.call("finish")
	hud.call("show_finish", is_best, is_open_best)

## the segment time for stage i on this run, or -1 when either end was not measured.
func segment_time(i: int) -> float:
	if i >= stage_times.size() or stage_times[i] < 0.0:
		return -1.0
	if i == 0:
		return stage_times[0]
	if practice_stage >= 0 and i == practice_stage:
		return stage_times[i]
	return stage_times[i] - stage_times[i - 1] if stage_times[i - 1] >= 0.0 else -1.0

## the run's time at stage i against the best full run's, or NAN.
func split_delta_live(i: int) -> float:
	if not clean_eligible or i >= best_splits.size() or i >= stage_times.size() or stage_times[i] < 0.0:
		return NAN
	return stage_times[i] - best_splits[i]

# --- speed shown to the player -----------------------------------------------------------------

func _sample_speed() -> void:
	# the runner's horizontal finite-difference travel from its last step, averaged.
	_speed_samples.append(float(player.call("get_speed")))
	if _speed_samples.size() > SPEED_WINDOW:
		_speed_samples.pop_front()
	var total := 0.0
	for value: float in _speed_samples:
		total += value
	display_speed = total / _speed_samples.size()

func _clear_speed() -> void:
	_speed_samples.clear()
	display_speed = 0.0

# --- input, pause, quit ------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		restart_run()
	elif event.is_action_pressed("practice"):
		practice_restart()
	elif event.is_action_pressed("pause"):
		set_paused(not paused)
	elif event.is_action_pressed("fullscreen"):
		var is_full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if is_full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif event is InputEventMouseButton and event.pressed and not paused and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func set_paused(value: bool) -> void:
	paused = value
	get_tree().paused = value
	if player != null:
		player.set("input_enabled", not value)
	if hud != null:
		hud.call("set_paused", value)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED

func request_quit(exit_code: int = 0) -> void:
	if _quitting:
		return
	_quitting = true
	if audio != null:
		audio.call("stop_all")
	# let the audio server release loop playback before the tree is destroyed.
	for i: int in 8:
		await get_tree().process_frame
	get_tree().quit(exit_code)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_quit()

# --- settings and records ----------------------------------------------------------------------

func change_setting(key: String, value: Variant) -> void:
	settings[key] = value
	_apply_settings()
	_save()

func _apply_settings() -> void:
	player.set("mouse_sensitivity", 0.0022 * float(settings.sensitivity))
	player.set("fov_horizontal", float(settings.fov))
	player.set("comfort", bool(settings.comfort))
	player.set("autohop", bool(settings.autohop))
	if audio != null:
		audio.call("set_volume", float(settings.volume))

func _geometry_id() -> String:
	if level.has_method("geometry_hash"):
		return str(level.call("geometry_hash"))
	# a level without a manifest: its progress layout stands in for the geometry.
	var layout: Array = [level.get("spawn"), level.get("finish_position")]
	for point: Dictionary in level.get("checkpoints"):
		layout.append([point.get("pose"), point.get("bounds")])
	return var_to_str(layout).sha256_text()

func _course_key() -> String:
	var titles: Array = []
	for i: int in stage_count():
		titles.append(segment_title(i))
	var runner := {"policy": player.get("air_policy"), "air": player.get("air_tuning"), "ground": player.get("tuning")}
	var identity := [TIMING_RULES, course_geometry, titles, JSON.stringify(runner, "", true)]
	return JSON.stringify(identity).sha256_text().left(16)

func _section() -> String:
	return "course_" + course_key

func _load() -> void:
	if not persist:
		profile_state = "off"
		return
	var config := ConfigFile.new()
	if config.load(profile_path) != OK:
		profile_state = "new"
		# p / a first r13 launch keeps the player's r12 mouse, view and volume settings; never
		# its records, and the r12 file is only read.
		var r12 := ConfigFile.new()
		if profile_path == SAVE_PATH and r12.load(R12_SETTINGS_PATH) == OK:
			for key: String in settings:
				settings[key] = _setting_value(key, r12.get_value("settings", key, settings[key]))
			profile_state = "new, settings from r12"
		return
	profile_state = "loaded"
	for key: String in settings:
		settings[key] = _setting_value(key, config.get_value("settings", key, settings[key]))
	var section := _section()
	if not config.has_section(section) or str(config.get_value(section, "geometry", "")) != course_geometry or int(config.get_value(section, "stages", 0)) != stage_count():
		return
	best_time = float(config.get_value(section, "clean_best", -1.0))
	open_best_time = float(config.get_value(section, "open_best", -1.0))
	for value: Variant in config.get_value(section, "clean_splits", []):
		best_splits.append(float(value))
	for value: Variant in config.get_value(section, "clean_segments", []):
		best_segments.append(float(value))
	if best_splits.size() != stage_count() or best_segments.size() != stage_count():
		best_time = -1.0
		best_splits.clear()
		best_segments.clear()

func _setting_value(key: String, value: Variant) -> Variant:
	# a damaged or foreign profile cannot push a setting outside what the pause panel offers.
	match key:
		"sensitivity":
			return clampf(float(value), 0.3, 2.5)
		"fov":
			return clampf(float(value), 75.0, 110.0)
		"volume":
			return clampf(float(value), 0.0, 1.0)
	return bool(value)

func _save() -> void:
	last_save_ok = false
	if not persist:
		return
	var config := ConfigFile.new()
	# keep every other course's records; only this course's section is rewritten.
	config.load(profile_path)
	config.set_value("profile", "format", PROFILE_FORMAT)
	config.set_value("profile", "build", BUILD_ID)
	for key: String in settings:
		config.set_value("settings", key, settings[key])
	var section := _section()
	config.set_value(section, "course", COURSE_NAME)
	config.set_value(section, "geometry", course_geometry)
	config.set_value(section, "rules", TIMING_RULES)
	config.set_value(section, "stages", stage_count())
	var titles := PackedStringArray()
	for i: int in stage_count():
		titles.append(segment_title(i))
	config.set_value(section, "titles", titles)
	config.set_value(section, "clean_best", best_time)
	config.set_value(section, "open_best", open_best_time)
	config.set_value(section, "clean_splits", best_splits)
	config.set_value(section, "clean_segments", best_segments)
	last_save_ok = config.save(profile_path) == OK
	profile_state = "saved" if last_save_ok else "save failed"
