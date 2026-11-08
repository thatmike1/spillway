extends Node3D
## p / r14 comparison game: one process, several real movement laws, two maps. it starts on
## Penstock Yard with the cs:go bhop-server preset. F1 vanilla, F2 bhop server, F3 the
## unchanged r13 runner, F4 a labelled quake iii-inspired projection on the source body, F5 a
## labelled AA 1000 server config. the pause menu offers the same presets and the map selector (Penstock Yard,
## Overflow). docs/r14/PLAYABLE.md is the player and integration contract.
##
## self-contained like the r13 main: it does not extend r12 or r13 mains, so neither build id,
## save path nor record namespace can leak in. it borrows r12's static key bindings only.
##
## a preset switch keeps the feet position, velocity and view (a new hull that does not fit
## waits for room, with a message) and turns a started attempt into practice. R starts a clean
## attempt in the active map and preset. a map switch starts at that map's spawn.
##
## records live in user://spillway_r14.cfg, one section per key of map identity and geometry,
## stage titles, timing rules, preset, family version, physics rate and the full physics
## configuration. ui settings never enter the key. persistence is off unless the launch scene
## asks for it, so anything built with new() neither reads nor writes a profile.
## godot --path . res://scenes/r14.tscn [-- --no-records] [-- --r14-profile=PATH]
##   [-- --r14-preset=ID] [-- --r14-map=practice|overflow] [-- --r14-source-sensitivity=S]
## godot --path . --script res://scripts/r14_launch.gd   (same scene, rate set before the world)
## tape hook: --game-script res://scripts/r14_main.gd --game-class '' --motor <preset alias>

const BUILD_ID := "spillway-2026.11.08-r14"
const BUILD_LABEL := "Spillway R14"
const SAVE_PATH := "user://spillway_r14.cfg"
const PROFILE_FORMAT := 1
## p / bump when what counts as a finish, a split or a clean run changes.
const TIMING_RULES := "r14-timing-2"
const PRESETS := preload("res://scripts/r14_presets.gd")
const STATS := preload("res://scripts/r14_strafe_stats.gd")
const HUD := preload("res://scripts/r14_hud.gd")
const AUDIO := preload("res://scripts/momentum_overflow_audio.gd")
const ART := preload("res://scripts/momentum_overflow_art.gd")
const PRACTICE_LEVEL := preload("res://scripts/r14_practice_level.gd")
const OVERFLOW_LEVEL := preload("res://scripts/momentum_overflow_level.gd")
const R12_MAIN := preload("res://scripts/spillway_main.gd")
const U := 0.0254
## p / progress roles: penstock yard counts only its route decks, as its own lab does, so a pit
## catch never collects a stage; overflow keeps the r13 main's rule (any tagged deck).
const MAPS := {
	"practice": {"name": "Penstock Yard", "variant": "practice", "roles": ["route"]},
	"overflow": {"name": "Overflow", "variant": "course", "roles": []},
}
const MAP_ORDER := ["practice", "overflow"]
const DEFAULT_MAP := "practice"
const DEFAULT_PRESET := "server128"
## p / source sensitivity starts at 2.5 source units (m_yaw 0.022: 0.055 degrees per count), a
## build choice, not anyone's measured setting. r13 keeps its original 0.0022 rad/count at 1.0
## and its literal 90 degree horizontal view. the two families' settings are separate.
const DEFAULT_SETTINGS := {"source_sensitivity": 2.5, "source_fov": 90.0, "r13_sensitivity": 1.0, "r13_fov": 90.0, "volume": 0.70, "show_ms": true}
const KILL_BOUNDS := AABB(Vector3(-180, -8.3, -400), Vector3(360, 400, 460))
## p / speed shown to the player: mean horizontal travel over the last 0.1 s of steps.
const SPEED_WINDOW_S := 0.1
const R13_PITCH_LIMIT := 1.40
const RATE_LOG_LIMIT := 96

## the launch scene sets this; anything built with new() stays read-free and write-free.
@export var persist: bool = false
var profile_path: String = SAVE_PATH
## the tape hook's preset alias, read once in _ready. empty: --r14-preset= or the default.
var motor: String = ""
## the map to start on; empty: --r14-map= or the default.
var map_id: String = ""
## tests: a level Script (or path) with the overflow level interface. it becomes map "fixture".
var level_script: Variant = null
var set_window_title: bool = true
## a replay's source sensitivity for this run only (--r14-source-sensitivity=), never saved.
var source_sensitivity_override: float = 0.0

var player: CharacterBody3D
var level: Node3D
var hud: CanvasLayer
var audio: Node
var stats: Node
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var paused: bool = false
var preset_id: String = ""
var preset: Dictionary = {}
var physics_hz: int:
	get:
		return int(preset.get("rate", Engine.physics_ticks_per_second))
## a preset switch waiting for room for its hull, or "".
var pending_preset: String = ""
var pending_message: String = ""

# run state, with the r13 main's meanings
var elapsed: float = 0.0
var finished: bool = false
var finish_kind: String = ""
var checkpoint_index: int = 0
var respawn_count: int = 0
var clean_eligible: bool = true
## why the attempt is not clean: "", "practice", "respawn", "preset", "rate".
var practice_reason: String = ""
var practice_stage: int = -1
var stage_times: Array[float] = []
var split_deltas: Array[float] = []
var attempts: int = 0

# records for the active key only
var course_key: String = ""
var course_geometry: String = ""
var best_time: float = -1.0
var open_best_time: float = -1.0
var best_splits: Array[float] = []
var best_segments: Array[float] = []
var previous_best: float = -1.0
var last_save_ok: bool = false
var profile_state: String = "off"

var display_speed: float = 0.0
## the actual delta of the latest physics callback and whether it matched the preset's rate.
var last_delta: float = 0.0
var rate_ok: bool = true
var rate_mismatch_ticks: int = 0
## bounded log of callbacks whose delta differed from 1 / physics_hz (startup, switches).
var rate_log: Array[Dictionary] = []
var physics_calls: int = 0

var _speed_samples: Array[float] = []
var _started: bool = false
var _spawn_origin: Vector3
## timer arming has a 0.5 m grace; preset purity starts with the first actual movement.
var _used_preset_physics: bool = false
var _spawn_jump_count: int = 0
var _recovery_time: float = 0.0
var _quitting: bool = false
var _kill_bounds: AABB = KILL_BOUNDS
var _record_cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	R12_MAIN.bind_inputs()
	_bind_keys()
	var args := OS.get_cmdline_user_args()
	var explicit_profile := false
	var requested := motor
	for arg: String in args:
		if arg.begins_with("--r14-profile="):
			profile_path = arg.trim_prefix("--r14-profile=")
			explicit_profile = true
		elif arg.begins_with("--r14-preset=") and requested.is_empty():
			requested = arg.trim_prefix("--r14-preset=")
		elif arg.begins_with("--r14-map=") and map_id.is_empty():
			map_id = arg.trim_prefix("--r14-map=")
		elif arg.begins_with("--r14-source-sensitivity="):
			source_sensitivity_override = float(arg.trim_prefix("--r14-source-sensitivity="))
	# p / headless runs are tests or drivers: they persist only into a profile named for them.
	if args.has("--no-records") or (DisplayServer.get_name() == "headless" and not explicit_profile and profile_path == SAVE_PATH):
		persist = false
	preset_id = PRESETS.resolve(requested) if not requested.is_empty() else DEFAULT_PRESET
	if preset_id.is_empty() or not PRESETS.available(preset_id):
		push_error("r14: unknown or unavailable preset '%s'; using %s" % [requested, DEFAULT_PRESET])
		preset_id = DEFAULT_PRESET
	preset = PRESETS.entry(preset_id)
	Engine.physics_ticks_per_second = physics_hz
	if level_script != null:
		map_id = "fixture"
	elif not MAPS.has(map_id):
		map_id = DEFAULT_MAP
	_load_settings()
	if source_sensitivity_override > 0.0:
		settings.source_sensitivity = _setting_value("source_sensitivity", source_sensitivity_override)
	_build_level()
	player = _make_runner(preset)
	add_child(player)
	stats = STATS.new()
	stats.name = "StrafeStats"
	add_child(stats)
	hud = HUD.new()
	add_child(hud)
	hud.call("attach", self)
	_build_audio()
	_apply_settings()
	_refresh_records()
	restart_run()
	if args.has("--no-hud"):
		hud.hide()
	_update_title()
	print("r14: build=%s; map=%s; preset=%s; physics_hz=%d; course_key=%s; records=%s; runner=%s; renderer=%s" % [BUILD_ID, map_id, preset_id, physics_hz, course_key, profile_state, (player.get_script() as Script).resource_path, RenderingServer.get_current_rendering_method()])
	if args.has("--verify-startup"):
		await get_tree().physics_frame
		await get_tree().physics_frame
		request_quit()

func _bind_keys() -> void:
	for slot: int in range(1, 6):
		var action := "r14_preset_%d" % slot
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = KEY_F1 + slot - 1
		InputMap.action_add_event(action, event)

# --- world --------------------------------------------------------------------------------------

func map_name() -> String:
	if map_id == "fixture":
		var named: Variant = level.get("level_name") if level != null else null
		return str(named) if named is String else "Fixture"
	return str((MAPS[map_id] as Dictionary).name)

func map_ids() -> Array:
	var ids: Array = MAP_ORDER.duplicate()
	if level_script != null:
		ids.append("fixture")
	return ids

func _build_level() -> void:
	var script: Script
	match map_id:
		"practice":
			PRACTICE_LEVEL.next_variant = "practice"
			script = PRACTICE_LEVEL
		"overflow":
			OVERFLOW_LEVEL.next_variant = "course"
			script = OVERFLOW_LEVEL
		_:
			script = level_script if level_script is Script else load(str(level_script))
	level = script.new()
	level.name = "Map"
	add_child(level)
	level.call("build")
	ART.apply(level)
	_kill_bounds = level.get("kill_bounds") if level.get("kill_bounds") is AABB else KILL_BOUNDS
	course_geometry = _geometry_id()

func _build_audio() -> void:
	if audio != null:
		audio.call("stop_all")
		audio.queue_free()
	audio = AUDIO.new()
	audio.name = "Audio"
	add_child(audio)
	audio.call("attach", player, level)
	audio.call("set_volume", float(settings.volume))

## a configured runner for an entry, not yet in the tree.
func _make_runner(entry: Dictionary) -> CharacterBody3D:
	var family: Dictionary = PRESETS.FAMILIES[str(entry.family)]
	var runner: CharacterBody3D = (load(str(family.script)) as Script).new()
	runner.name = "Runner"
	match str(entry.family):
		"source":
			runner.call("apply_settings", _source_settings(str(entry.id)))
		"r13":
			# the carry base needs a profile name before it enters the tree; the candidate law ignores it.
			runner.set("air_profile", "broad")
	return runner

func _source_settings(id: String) -> Dictionary:
	return PRESETS.source_settings(id, {"sensitivity": settings.source_sensitivity, "fov": settings.source_fov})

# --- presets ------------------------------------------------------------------------------------

## the hot switch: keeps feet, velocity and view; a started attempt becomes practice.
func select_preset(name: String) -> void:
	var id := PRESETS.resolve(name)
	if id.is_empty():
		return
	if not PRESETS.available(id):
		var entry := PRESETS.entry(id)
		hud.call("notify", "F%d: %s" % [int(entry.slot), str(entry.summary)])
		return
	if id == preset_id:
		if not pending_preset.is_empty():
			pending_preset = ""
			pending_message = ""
			hud.call("notify", "Staying on %s" % str(preset.label))
		else:
			hud.call("notify", "%s is already running" % str(preset.label))
		return
	pending_preset = id
	_try_pending()

## applies the pending switch if its hull fits where the runner stands; true when applied.
func _try_pending() -> bool:
	if pending_preset.is_empty():
		return false
	var next := PRESETS.entry(pending_preset)
	var same_body := str(next.family) == str(preset.family) and str(next.family) == "source"
	if not same_body and not hull_fits(next, player.global_position):
		var message := "%s waits for room: its %s does not fit here. Move into open space, or press F%d again to stay." % [str(next.label), _hull_words(next), int(preset.slot)]
		if message != pending_message:
			pending_message = message
			hud.call("notify", message)
		return false
	pending_preset = ""
	pending_message = ""
	_switch_to(next, same_body)
	return true

func _switch_to(next: Dictionary, same_body: bool) -> void:
	var feet := player.global_position
	var velocity := player.velocity
	var look_yaw := float(player.get("yaw"))
	var look_pitch := float(player.get("pitch"))
	_note_preset_physics()
	var untouched := not _used_preset_physics and not _started and not finished
	preset_id = str(next.id)
	preset = next
	if same_body:
		player.call("apply_settings", _source_settings(preset_id))
	else:
		_replace_runner(feet, velocity, look_yaw, look_pitch)
	Engine.physics_ticks_per_second = physics_hz
	if not untouched and not finished and clean_eligible:
		clean_eligible = false
		practice_reason = "preset"
	_apply_settings()
	if untouched:
		_spawn_jump_count = int(player.get("jump_count"))
	stats.call("watch", player)
	_clear_speed()
	_refresh_records()
	_update_title()
	hud.call("preset_changed")
	hud.call("notify", "%s  ·  %d Hz%s" % [str(preset.label), physics_hz, "" if clean_eligible or finished else "  ·  this attempt is now practice, R for a clean run"])

func _replace_runner(feet: Vector3, velocity: Vector3, look_yaw: float, look_pitch: float) -> void:
	var old := player
	remove_child(old)
	old.free()
	player = _make_runner(preset)
	add_child(player)
	player.call("reset_to", Transform3D(Basis(Vector3.UP, look_yaw), feet))
	player.set("yaw", look_yaw)
	var limit := R13_PITCH_LIMIT if str(preset.family) == "r13" else float(player.get("pitch_limit"))
	player.set("pitch", clampf(look_pitch, -limit, limit))
	player.velocity = velocity
	if str(preset.family) == "source":
		# the reset forgets support; categorize once so a grounded runner can jump on the next step.
		var state: Dictionary = player.get("state")
		var normal: Vector3 = player.call("probe_ground", state)
		state.grounded = normal != Vector3.ZERO
		state.ground_normal = normal
	player.set("input_enabled", not paused)
	_build_audio()

## whether the entry's standing hull fits at these feet without touching the world.
func hull_fits(entry: Dictionary, feet: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var lift := 0.004
	match str((PRESETS.FAMILIES[str(entry.family)] as Dictionary).hull):
		"source_box":
			var cvars := _source_settings(str(entry.id))
			var width := float(cvars.hull_width) * U
			var height := float(cvars.hull_height) * U
			var box := BoxShape3D.new()
			box.size = Vector3(width - lift, height - lift, width - lift)
			query.shape = box
			query.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * (height * 0.5 + lift))
		_:
			var capsule := CapsuleShape3D.new()
			capsule.radius = 0.30 - lift * 0.5
			capsule.height = 1.8 - lift
			query.shape = capsule
			query.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * (0.9 + lift))
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _hull_words(entry: Dictionary) -> String:
	if str((PRESETS.FAMILIES[str(entry.family)] as Dictionary).hull) == "source_box":
		return "0.81 m square, 1.83 m tall box"
	return "0.6 m wide, 1.8 m tall capsule"

# --- maps ---------------------------------------------------------------------------------------

func select_map(id: String) -> void:
	if not id in map_ids():
		return
	if id == map_id:
		hud.call("notify", "%s is already loaded" % map_name())
		return
	# a map selection retains the active preset, not a deferred request from another map.
	var cancelled := not pending_preset.is_empty()
	pending_preset = ""
	pending_message = ""
	map_id = id
	remove_child(level)
	level.free()
	_build_level()
	_build_audio()
	_refresh_records()
	restart_run()
	_update_title()
	hud.call("map_changed")
	hud.call("notify", "%s  ·  %s%s" % [map_name(), str(preset.label), "  ·  pending preset cancelled" if cancelled else ""])

# --- stages -------------------------------------------------------------------------------------

func stage_count() -> int:
	return maxi(1, (level.get("checkpoints") as Array).size())

func segment_title(i: int) -> String:
	var points: Array = level.get("checkpoints")
	if i + 1 < points.size():
		return str((points[i + 1] as Dictionary).get("title", "Stage %d" % (i + 1)))
	var finish_title: Variant = level.get("finish_title")
	return str(finish_title) if finish_title is String and not str(finish_title).is_empty() else "Finish"

func stage_title(stage: int) -> String:
	var points: Array = level.get("checkpoints")
	return str((points[stage] as Dictionary).get("title", "Start")) if stage < points.size() else "Start"

# --- run lifecycle ------------------------------------------------------------------------------

func restart_run() -> void:
	attempts += 1
	elapsed = 0.0
	finished = false
	finish_kind = ""
	checkpoint_index = 0
	respawn_count = 0
	clean_eligible = true
	practice_reason = ""
	practice_stage = -1
	_reset_stage_times()
	_started = false
	_recovery_time = 0.0
	player.call("reset_to", level.get("spawn"))
	_spawn_origin = player.global_position
	_used_preset_physics = false
	_spawn_jump_count = int(player.get("jump_count"))
	if level.has_method("reset_state"):
		level.call("reset_state")
	_clear_speed()
	set_paused(false)
	# p / a waiting preset switch is applied at the spawn, where its hull fits, as a clean start.
	_try_pending()
	stats.call("watch", player)
	hud.call("run_started")

## segment practice from the last stage the runner reached. never recorded.
func practice_restart() -> void:
	attempts += 1
	clean_eligible = false
	practice_reason = "practice"
	finished = false
	finish_kind = ""
	practice_stage = checkpoint_index
	_reset_stage_times()
	elapsed = 0.0
	_started = false
	_restore_checkpoint()
	_spawn_origin = player.global_position
	if level.has_method("reset_state"):
		level.call("reset_state")
	set_paused(false)
	stats.call("reset")
	hud.call("practice_started", stage_title(checkpoint_index))

func respawn() -> void:
	respawn_count += 1
	clean_eligible = false
	practice_reason = "respawn"
	finished = false
	finish_kind = ""
	_restore_checkpoint()
	stats.call("reset")
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
	physics_calls += 1
	_note_preset_physics()
	_check_rate(delta)
	if not pending_preset.is_empty():
		_try_pending()
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
				var look_pitch: float = player.get("pitch")
				var look_yaw: float = player.get("yaw")
				player.call("reset_to", Transform3D(Basis(Vector3.UP, look_yaw), (level.get("finish_position") as Vector3) + Vector3.UP * 0.04))
				player.set("pitch", look_pitch)
				_recovery_time = 0.0
				_clear_speed()
				stats.call("reset")
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

## spawn settling can move down a few centimetres. horizontal travel, upward movement or a
## real jump means the current law has acted, even before the timer's 0.5 m start threshold.
func _note_preset_physics() -> void:
	if _used_preset_physics or player == null:
		return
	var offset := player.global_position - _spawn_origin
	_used_preset_physics = Vector2(offset.x, offset.z).length() > 0.0001 \
		or Vector2(player.velocity.x, player.velocity.z).length() > 0.0001 \
		or player.velocity.y > 0.0001 or offset.y > 0.01 \
		or int(player.get("jump_count")) != _spawn_jump_count

## the callback's actual delta against the preset's rate. the engine can deliver a few steps at
## the old delta after a rate change; a started clean attempt that sees one becomes practice.
func _check_rate(delta: float) -> void:
	last_delta = delta
	var expected := 1.0 / float(physics_hz)
	rate_ok = absf(delta - expected) < 1e-7
	if rate_ok:
		return
	rate_mismatch_ticks += 1
	if rate_log.size() < RATE_LOG_LIMIT:
		rate_log.append({"call": physics_calls, "delta": delta, "expected": expected, "engine_hz": Engine.physics_ticks_per_second, "preset": preset_id, "started": _started, "attempt": attempts})
	if _started and not finished and clean_eligible:
		clean_eligible = false
		practice_reason = "rate"
		hud.call("notify", "Physics rate was still settling to %d Hz, so this attempt is practice. R for a clean run." % physics_hz)

func _collect_checkpoints() -> void:
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

## progress follows decks the runner stands on, read with a thin box under its feet, so it
## works for every runner whatever contact api its motor uses.
func _stands_on_stage(stage: int) -> bool:
	if not player.call("is_grounded"):
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 0.12, 0.5)
	query.shape = box
	query.transform = Transform3D(Basis.IDENTITY, player.global_position + Vector3.DOWN * 0.05)
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	var roles: Array = (MAPS.get(map_id, {"roles": []}) as Dictionary).roles
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, 8):
		var body := hit.collider as Node
		if body == null or int(body.get_meta("progress_stage", -1)) != stage:
			continue
		if roles.is_empty() or str(body.get_meta("surface", "")) in roles:
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
		is_open_best = open_best_time < 0.0 or elapsed < open_best_time
		if is_open_best:
			open_best_time = elapsed
		_save()
	if level.has_method("start_wheel"):
		level.call("start_wheel")
	audio.call("finish")
	hud.call("show_finish", is_best, is_open_best)

func segment_time(i: int) -> float:
	if i >= stage_times.size() or stage_times[i] < 0.0:
		return -1.0
	if i == 0:
		return stage_times[0]
	if practice_stage >= 0 and i == practice_stage:
		return stage_times[i]
	return stage_times[i] - stage_times[i - 1] if stage_times[i - 1] >= 0.0 else -1.0

func split_delta_live(i: int) -> float:
	if not clean_eligible or i >= best_splits.size() or i >= stage_times.size() or stage_times[i] < 0.0:
		return NAN
	return stage_times[i] - best_splits[i]

# --- speed shown to the player ------------------------------------------------------------------

func _sample_speed() -> void:
	# the runner's horizontal travel over its last step, m/s, averaged over 0.1 s of steps.
	_speed_samples.append(float(player.call("get_speed")))
	while _speed_samples.size() > maxi(1, roundi(SPEED_WINDOW_S * physics_hz)):
		_speed_samples.pop_front()
	var total := 0.0
	for value: float in _speed_samples:
		total += value
	display_speed = total / _speed_samples.size()

func display_speed_u() -> float:
	return display_speed / U

func _clear_speed() -> void:
	_speed_samples.clear()
	display_speed = 0.0

# --- input, pause, quit -------------------------------------------------------------------------

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
	else:
		for slot: int in range(1, 6):
			if event.is_action_pressed("r14_preset_%d" % slot):
				select_preset(PRESETS.id_for_slot(slot))
				return

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
	for i: int in 8:
		await get_tree().process_frame
	get_tree().quit(exit_code)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_quit()

func window_title() -> String:
	return "%s · %s · %s · %d Hz" % [BUILD_LABEL, map_name(), str(preset.label), physics_hz]

func _update_title() -> void:
	if set_window_title and is_inside_tree():
		get_window().title = window_title()

# --- settings and records -----------------------------------------------------------------------

func change_setting(key: String, value: Variant) -> void:
	settings[key] = _setting_value(key, value)
	_apply_settings()
	_save()

func _apply_settings() -> void:
	match str(preset.family):
		"source":
			var current: Dictionary = player.get("settings")
			current = current.duplicate()
			current["sensitivity"] = float(settings.source_sensitivity)
			current["fov"] = float(settings.source_fov)
			current["wheel_jump"] = true
			player.call("apply_settings", current)
		"r13":
			# r13's original defaults: 0.0022 rad/count at 1.0, literal horizontal fov, its
			# speed fov and landing dip, autohop on.
			player.set("mouse_sensitivity", 0.0022 * float(settings.r13_sensitivity))
			player.set("fov_horizontal", float(settings.r13_fov))
			player.set("comfort", false)
			player.set("autohop", true)
	if audio != null:
		audio.call("set_volume", float(settings.volume))

## the view settings the active family is using, in its own units, for the hud.
func look_description() -> String:
	if str(preset.family) == "source":
		var cvars: Dictionary = player.get("settings")
		return "Source sensitivity %.2f × m_yaw %.3f = %.4f °/count · FOV %d (4:3 reference)" % [float(cvars.sensitivity), float(cvars.m_yaw), float(cvars.sensitivity) * float(cvars.m_yaw), roundi(float(cvars.fov))]
	return "R13 mouse %.2f × 0.0022 = %.5f rad/count · %d° literal horizontal FOV" % [float(settings.r13_sensitivity), float(player.get("mouse_sensitivity")), roundi(float(settings.r13_fov))]

func _geometry_id() -> String:
	if level.has_method("geometry_hash"):
		return str(level.call("geometry_hash"))
	var layout: Array = [level.get("spawn"), level.get("finish_position")]
	for point: Dictionary in level.get("checkpoints"):
		layout.append([point.get("pose"), point.get("bounds")])
	return var_to_str(layout).sha256_text()

## the physics configuration that enters the record key, from the runner actually running.
func physics_fingerprint() -> Dictionary:
	if str(preset.family) == "source":
		return PRESETS.physics_fingerprint(player.get("settings"))
	return {"policy": player.get("air_policy"), "air": player.get("air_tuning"), "ground": player.get("tuning"), "autohop": player.get("autohop")}

func record_identity() -> Array:
	var titles: Array = []
	for i: int in stage_count():
		titles.append(segment_title(i))
	var family: Dictionary = PRESETS.FAMILIES[str(preset.family)]
	var map_identity := [map_id, level.get("level_id"), level.get("level_version"), level.get("variant")]
	return [TIMING_RULES, map_identity, course_geometry, titles, preset_id, str(preset.family), str(family.version), physics_hz, JSON.stringify(physics_fingerprint(), "", true)]

func _course_key() -> String:
	return JSON.stringify(record_identity()).sha256_text().left(16)

func _section() -> String:
	return "course_" + course_key

## the active key's bests, and nothing from any other key. bests of keys already visited in
## this process are kept in memory, so switching back finds them even with records off.
func _refresh_records() -> void:
	if not course_key.is_empty():
		_record_cache[course_key] = {"best": best_time, "open": open_best_time, "splits": best_splits.duplicate(), "segments": best_segments.duplicate()}
	course_key = _course_key()
	best_time = -1.0
	open_best_time = -1.0
	previous_best = -1.0
	best_splits.clear()
	best_segments.clear()
	if _record_cache.has(course_key):
		var cached: Dictionary = _record_cache[course_key]
		best_time = cached.best
		open_best_time = cached.open
		best_splits.assign(cached.splits)
		best_segments.assign(cached.segments)
		return
	_load_records()

func _load_settings() -> void:
	if not persist:
		profile_state = "off"
		return
	var config := ConfigFile.new()
	if config.load(profile_path) != OK:
		profile_state = "new"
		return
	profile_state = "loaded"
	for key: String in settings:
		settings[key] = _setting_value(key, config.get_value("settings", key, settings[key]))

func _load_records() -> void:
	if not persist:
		return
	var config := ConfigFile.new()
	if config.load(profile_path) != OK:
		return
	var section := _section()
	if not config.has_section(section) or str(config.get_value(section, "geometry", "")) != course_geometry or int(config.get_value(section, "stages", 0)) != stage_count() or str(config.get_value(section, "preset", "")) != preset_id:
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
		"source_sensitivity":
			return clampf(float(value), 0.2, 10.0)
		"r13_sensitivity":
			return clampf(float(value), 0.3, 2.5)
		"source_fov", "r13_fov":
			return clampf(float(value), 70.0, 110.0)
		"volume":
			return clampf(float(value), 0.0, 1.0)
	return bool(value)

func _save() -> void:
	last_save_ok = false
	if not persist:
		return
	var config := ConfigFile.new()
	# keep every other key's records; only this key's section is rewritten.
	config.load(profile_path)
	config.set_value("profile", "format", PROFILE_FORMAT)
	config.set_value("profile", "build", BUILD_ID)
	for key: String in settings:
		if not (key == "source_sensitivity" and source_sensitivity_override > 0.0):
			config.set_value("settings", key, settings[key])
	var section := _section()
	config.set_value(section, "map", map_id)
	config.set_value(section, "map_name", map_name())
	config.set_value(section, "geometry", course_geometry)
	config.set_value(section, "rules", TIMING_RULES)
	config.set_value(section, "preset", preset_id)
	config.set_value(section, "preset_label", str(preset.label))
	config.set_value(section, "family", str(preset.family))
	config.set_value(section, "family_version", str((PRESETS.FAMILIES[str(preset.family)] as Dictionary).version))
	config.set_value(section, "physics_hz", physics_hz)
	config.set_value(section, "physics", JSON.stringify(physics_fingerprint(), "", true))
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
