extends Node3D
## p / r15 game: the approved r14 bhop server movement with real crouch, played across themed
## checkpoint maps. it starts on Breakwater (Penstock Yard stands in, labelled, until Breakwater
## exists) with F2, the cs:go bhop-server preset. F5 is the same server at AA 1000. F4 (quake
## iii-inspired) and F3 (the unchanged r13 runner) are advanced comparisons. vanilla64 is not in
## r15. docs/r15/PLAYABLE.md is the player and integration contract.
##
## self-contained beside r14_main.gd: it does not extend it, so neither build id, save path nor
## record namespace can leak either way. it reads r14's preset table, strafe stats, audio and
## art passes, and r12's static key bindings.
##
## runner policy: the source family plays res://scripts/r15_source_player.gd. when that module is
## absent the game says so and does not start; it never borrows another runner quietly. the
## delivered r14 runner can be chosen on purpose (`source_runner = "standin-r14"` or
## --r15-standin-runner=r14): the hud says STAND-IN and its records have their own identity.
##
## records live in user://spillway_r15.cfg, one section per record identity (timing rules, map
## id/kind/level id/version/variant, geometry, stage titles, preset, family and runner, rate,
## the running body's physics, hull and mechanics). persistence is off unless the launch scene
## asks for it. a first launch may read look settings from spillway_r14.cfg; it never writes it
## and never imports an r14 best.
## godot --path . res://scenes/r15.tscn [-- --no-records] [-- --r15-profile=PATH]
##   [-- --r15-preset=ID] [-- --r15-map=ID] [-- --r15-source-sensitivity=S] [-- --r15-standin-runner=r14]
## godot --path . --script res://scripts/r15_launch.gd   (same scene, rate set before the world)
## tape hook: --game-script res://scripts/r15_main.gd --game-class '' --motor <preset alias>

const BUILD_ID := "spillway-2026.11.08-r15"
const BUILD_LABEL := "Spillway R15"
const SAVE_PATH := "user://spillway_r15.cfg"
const R14_SAVE_PATH := "user://spillway_r14.cfg"
const PROFILE_FORMAT := 1
## p / integer physics ticks are the only stored time; floats in the file are readable copies.
const RECORD_TICKS_VERSION := 1
const MAX_RECORD_TICKS := 9007199254740991
## p / bump when what counts as a finish, a split or a clean run changes.
const TIMING_RULES := "r15-timing-1"
const PRESETS := preload("res://scripts/r15_presets.gd")
const MAPS := preload("res://scripts/r15_maps.gd")
const STATS := preload("res://scripts/r14_strafe_stats.gd")
const HUD := preload("res://scripts/r15_hud.gd")
const AUDIO := preload("res://scripts/momentum_overflow_audio.gd")
const ART := preload("res://scripts/momentum_overflow_art.gd")
const READABILITY := preload("res://scripts/r14_practice_readability.gd")
const R12_MAIN := preload("res://scripts/spillway_main.gd")
const U := 0.0254
const DEFAULT_PRESET := "server128"
const STANDIN := "standin-r14"
## the r14 look defaults; the two families' settings stay separate.
const DEFAULT_SETTINGS := {"source_sensitivity": 2.5, "source_fov": 90.0, "r13_sensitivity": 1.0, "r13_fov": 90.0, "volume": 0.70, "show_ms": true}
## r14's dam-sized fallback, kept for the two r14 maps so their runs stay what they were.
const R14_KILL_BOUNDS := AABB(Vector3(-180, -8.3, -400), Vector3(360, 400, 460))
## a new map without kill_bounds falls this far below its lowest solid before a respawn.
const DERIVED_KILL_DROP := 12.0
const DERIVED_KILL_MARGIN := 40.0
## p / speed shown to the player: mean horizontal travel over the last 0.1 s of steps.
const SPEED_WINDOW_S := 0.1
const R13_PITCH_LIMIT := 1.40
const RATE_LOG_LIMIT := 96
const START_DISTANCE := 0.5

## the launch scene sets this; anything built with new() stays read-free and write-free.
@export var persist: bool = false
var profile_path: String = SAVE_PATH
## first launch only: read look settings from the r14 profile (read-only, no records).
var seed_from_r14: bool = true
## the tape hook's preset alias, read once in _ready. empty: --r15-preset= or the default.
var motor: String = ""
## the map to start on; empty: --r15-map= or the registry default.
var map_id: String = ""
## tests: a level Script (or path) with the r14 level interface. it becomes map "fixture".
var level_script: Variant = null
## tests: a registry from r15_maps.gd make(), replacing the real catalog.
var map_registry: Dictionary = {}
## "" plays the r15 runner. "standin-r14" plays the delivered r14 runner, labelled. tests may
## also give a Script or path, which is labelled the same way as a stand-in.
var source_runner: Variant = ""
var set_window_title: bool = true
## a replay's source sensitivity for this run only (--r15-source-sensitivity=), never saved.
var source_sensitivity_override: float = 0.0

var player: CharacterBody3D
var level: Node3D
var hud: CanvasLayer
var audio: Node
var stats: Node
var maps: Dictionary = {}
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
## why the game could not start, or "". a non-empty value means no world was built.
var startup_error: String = ""
var default_map_standin: bool = false

# run state, with the r14 main's meanings
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
## what happened to the active key's stored section: "", "loaded", "absent", "rejected: why".
var record_state: String = ""
var seeded_settings: bool = false

var display_speed: float = 0.0
var last_delta: float = 0.0
var rate_ok: bool = true
var rate_mismatch_ticks: int = 0
var rate_log: Array[Dictionary] = []
var physics_calls: int = 0

var _speed_samples: Array[float] = []
var _started: bool = false
var _spawn_origin: Vector3
## preset purity starts with the first actual movement, before the timer's 0.5 m grace.
var _used_preset_physics: bool = false
var _spawn_jump_count: int = 0
var _recovery_time: float = 0.0
var _quitting: bool = false
var _kill_bounds: AABB = R14_KILL_BOUNDS
var _record_cache: Dictionary = {}
## the runner's cumulative compensation, u, when the feet were last the body reference.
var _compensation_base := Vector3.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	R12_MAIN.bind_inputs()
	_bind_keys()
	var args := OS.get_cmdline_user_args()
	var explicit_profile := false
	var requested := motor
	for arg: String in args:
		if arg.begins_with("--r15-profile="):
			profile_path = arg.trim_prefix("--r15-profile=")
			explicit_profile = true
		elif arg.begins_with("--r15-preset=") and requested.is_empty():
			requested = arg.trim_prefix("--r15-preset=")
		elif arg.begins_with("--r15-map=") and map_id.is_empty():
			map_id = arg.trim_prefix("--r15-map=")
		elif arg.begins_with("--r15-source-sensitivity="):
			source_sensitivity_override = float(arg.trim_prefix("--r15-source-sensitivity="))
		elif arg == "--r15-standin-runner=r14" and str(source_runner).is_empty():
			source_runner = STANDIN
	# p / headless runs are tests or drivers: they persist only into a profile named for them.
	if args.has("--no-records") or (DisplayServer.get_name() == "headless" and not explicit_profile and profile_path == SAVE_PATH):
		persist = false
	preset_id = PRESETS.resolve(requested) if not requested.is_empty() else DEFAULT_PRESET
	if preset_id.is_empty() or not PRESETS.available(preset_id):
		push_error("r15: unknown or unavailable preset '%s'; using %s" % [requested, DEFAULT_PRESET])
		preset_id = DEFAULT_PRESET
	preset = PRESETS.entry(preset_id)
	Engine.physics_ticks_per_second = physics_hz
	maps = map_registry if not map_registry.is_empty() else MAPS.make()
	if level_script != null:
		map_id = "fixture"
	elif not MAPS.available(maps, map_id):
		if not map_id.is_empty():
			push_error("r15: map '%s' is not playable here; using the default" % map_id)
		map_id = MAPS.default_id(maps)
		default_map_standin = MAPS.default_is_standin(maps, map_id)
	startup_error = _runner_problem()
	if startup_error.is_empty() and map_id.is_empty():
		startup_error = "no playable map is registered"
	if not startup_error.is_empty():
		_fail_startup(args)
		return
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
	print("r15: build=%s; map=%s; preset=%s; physics_hz=%d; course_key=%s; records=%s; runner=%s; standin=%s; renderer=%s" % [BUILD_ID, map_id, preset_id, physics_hz, course_key, profile_state, runner_path(), runner_is_standin(), RenderingServer.get_current_rendering_method()])
	if args.has("--verify-startup"):
		await get_tree().physics_frame
		await get_tree().physics_frame
		request_quit()

func _bind_keys() -> void:
	for slot: int in range(1, 6):
		var action := "r15_preset_%d" % slot
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = KEY_F1 + slot - 1
		InputMap.action_add_event(action, event)

# --- runner -------------------------------------------------------------------------------------

## the source runner's script path for this game: the r15 module, or a labelled stand-in.
func runner_path() -> String:
	if str(preset.get("family", "")) != "source":
		return str((PRESETS.FAMILIES[str(preset.family)] as Dictionary).script)
	return _source_script_path()

func _source_script_path() -> String:
	if source_runner is Script:
		return (source_runner as Script).resource_path
	var named := str(source_runner)
	if named.is_empty():
		return PRESETS.SOURCE_PLAYER
	if named == STANDIN:
		return PRESETS.STANDIN_PLAYER
	return named

func runner_is_standin() -> bool:
	return not (source_runner is String and str(source_runner).is_empty())

## "" when the source runner can be built, else a sentence for the player.
func _runner_problem() -> String:
	var path := _source_script_path()
	if source_runner is Script:
		return ""
	if not ResourceLoader.exists(path):
		return "the R15 runner %s is missing, so crouch cannot run. This build is incomplete; nothing falls back to another runner." % path
	var script: Variant = load(path)
	if not script is Script or not (script as Script).can_instantiate():
		return "the runner %s does not load" % path
	return ""

func _fail_startup(args: PackedStringArray) -> void:
	push_error("r15: cannot start: " + startup_error)
	print("r15: build=%s; startup_error=%s" % [BUILD_ID, startup_error])
	var layer := CanvasLayer.new()
	layer.name = "StartupError"
	add_child(layer)
	var label := Label.new()
	label.name = "StartupErrorText"
	label.text = "%s cannot start\n\n%s\n\nEsc or closing the window quits." % [BUILD_LABEL, startup_error]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 40
	label.offset_top = 40
	label.offset_right = -40
	label.add_theme_font_size_override("font_size", 20)
	layer.add_child(label)
	if set_window_title and is_inside_tree():
		get_window().title = "%s · cannot start" % BUILD_LABEL
	if args.has("--verify-startup"):
		await get_tree().process_frame
		request_quit(3)

## a configured runner for an entry, not yet in the tree.
func _make_runner(entry: Dictionary) -> CharacterBody3D:
	var script: Script
	if str(entry.family) == "source":
		script = source_runner if source_runner is Script else load(_source_script_path()) as Script
	else:
		script = load(str((PRESETS.FAMILIES[str(entry.family)] as Dictionary).script)) as Script
	var runner: CharacterBody3D = script.new()
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

## the runner's body-origin compensation since it last stood on the ground: the r15 runner's
## air duck lifts the feet 9 u and an air stand drops them again without any travel
## (docs/r15/CROUCH.md). it reads the runner's cumulative `_duck_compensation_u`; a runner
## without crouch has none, so this is zero and the r14 rules hold unchanged.
func hull_origin_offset() -> Vector3:
	var total := _compensation_total()
	return (total - _compensation_base) * U

func _compensation_total() -> Vector3:
	var value: Variant = player.get("_duck_compensation_u") if player != null else null
	return value if value is Vector3 else Vector3.ZERO

## on the ground, or after anything that places the body, the feet are the reference again.
func _rebase_compensation() -> void:
	_compensation_base = _compensation_total()

## the point timing and progress use: the feet minus the compensation since the last ground
## contact, so a duck or stand in flight never starts the clock, enters a trigger or crosses a
## finish by itself. landing (real support) makes the feet the reference again.
func body_reference() -> Vector3:
	return player.global_position - hull_origin_offset()

## the duck hull is in use (r15 runner), or the r14 stand-in's crouch key is down.
func is_crouched() -> bool:
	if player == null:
		return false
	var ducked: Variant = player.get("ducked")
	return ducked == true if ducked != null else player.get("crouched") == true

func stand_blocked() -> bool:
	return player != null and player.get("stand_blocked") == true

# --- world --------------------------------------------------------------------------------------

func map_entry(id: String = "") -> Dictionary:
	var key := map_id if id.is_empty() else id
	if key == "fixture":
		return {"id": "fixture", "name": map_name() if key == map_id else "Fixture", "theme": "Labelled test fixture", "kind": "fixture"}
	return MAPS.entry(maps, key)

func map_name() -> String:
	if map_id == "fixture":
		var named: Variant = level.get("level_name") if level != null else null
		return str(named) if named is String else "Fixture"
	return str(MAPS.entry(maps, map_id).get("name", map_id))

func map_kind() -> String:
	return str(map_entry().get("kind", ""))

## playable map ids in menu order; a fixture override is listed last.
func map_ids() -> Array:
	var ids: Array = MAPS.playable(maps)
	if level_script != null:
		ids.append("fixture")
	return ids

func _build_level() -> void:
	if map_id == "fixture":
		var script: Script = level_script if level_script is Script else load(str(level_script))
		level = script.new()
	else:
		level = MAPS.instantiate(maps, map_id)
	level.name = "Map"
	add_child(level)
	level.call("build")
	if bool(map_entry().get("dress", false)):
		ART.apply(level)
		READABILITY.apply(level)
	var declared: Variant = level.get("kill_bounds")
	if declared is AABB:
		_kill_bounds = declared
	elif map_kind() == "legacy" or map_kind() == "fixture":
		_kill_bounds = R14_KILL_BOUNDS
	else:
		_kill_bounds = derived_kill_bounds(level)
	course_geometry = _geometry_id()

## a map without kill_bounds: its solids' extent, widened, with the floor a fixed drop below
## the lowest solid, so a fall respawns at that map's scale rather than the dam's.
static func derived_kill_bounds(world: Node3D) -> AABB:
	var merged := AABB()
	var any := false
	for node: Node in world.find_children("*", "CollisionShape3D", true, false):
		var shape := node as CollisionShape3D
		if shape.shape == null or shape.disabled:
			continue
		var local := shape.shape.get_debug_mesh().get_aabb()
		var box := shape.global_transform * local
		merged = box if not any else merged.merge(box)
		any = true
	if not any:
		return R14_KILL_BOUNDS
	var low := merged.position - Vector3(DERIVED_KILL_MARGIN, DERIVED_KILL_DROP, DERIVED_KILL_MARGIN)
	var high := merged.end + Vector3(DERIVED_KILL_MARGIN, 200.0, DERIVED_KILL_MARGIN)
	return AABB(low, high - low)

func kill_bounds() -> AABB:
	return _kill_bounds

func _build_audio() -> void:
	if audio != null:
		audio.call("stop_all")
		# freed at once: no signal of the runner can reach it outside the tree, and the new
		# player takes the name, so exactly one is listening.
		remove_child(audio)
		audio.free()
	audio = AUDIO.new()
	audio.name = "Audio"
	add_child(audio)
	audio.call("attach", player, level)
	audio.call("set_volume", float(settings.volume))

# --- presets ------------------------------------------------------------------------------------

## the hot switch: keeps feet, velocity, view and, on the same body, the duck state; a started
## attempt becomes practice.
func select_preset(name: String) -> void:
	var id := PRESETS.resolve(name)
	if id.is_empty():
		return
	if not PRESETS.available(id):
		hud.call("notify", "%s is not available" % str(PRESETS.entry(id).get("label", id)))
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

func select_slot(slot: int) -> void:
	if PRESETS.RETIRED_SLOTS.has(slot):
		hud.call("notify", "F%d: %s" % [slot, str(PRESETS.RETIRED_SLOTS[slot])])
		return
	var id := PRESETS.id_for_slot(slot)
	if not id.is_empty():
		select_preset(id)

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
	_rebase_compensation()
	_build_audio()

## whether the entry's standing hull fits at these feet without touching the world. a new
## body always starts standing, so a crouched runner under a ceiling waits for room.
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
		return "0.81 m square, 1.83 m tall standing box"
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
	default_map_standin = false
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
	_rebase_compensation()
	_spawn_origin = body_reference()
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

## f: practice from the last checkpoint the runner reached. never recorded.
func practice_restart() -> void:
	practise_stage(checkpoint_index)

## p / the one practice path, for F and the pause menu's stage picker (r14 STAGE-PRACTICE.md):
## a new unrecorded attempt from any stage's authored pose. a waiting preset request is
## cancelled, as a map switch cancels it.
func practise_stage(stage: int) -> void:
	var requested := stage
	stage = clampi(stage, 0, stage_count() - 1)
	if stage != requested:
		push_warning("r15: stage %d is outside 0..%d; practising %d" % [requested, stage_count() - 1, stage])
	var note := ""
	if not pending_preset.is_empty():
		note = "%s request cancelled, staying on %s" % [str(PRESETS.entry(pending_preset).label), str(preset.label)]
		pending_preset = ""
		pending_message = ""
	attempts += 1
	clean_eligible = false
	practice_reason = "practice"
	finished = false
	finish_kind = ""
	checkpoint_index = stage
	practice_stage = stage
	respawn_count = 0
	_reset_stage_times()
	elapsed = 0.0
	_started = false
	_restore_checkpoint()
	_spawn_origin = body_reference()
	if level.has_method("reset_state"):
		level.call("reset_state")
	set_paused(false)
	stats.call("reset")
	hud.call("practice_started", stage_title(stage), note)
	print("r15: stage practice; stage=%d/%d; title=%s; map=%s; preset=%s; attempt=%d" % [stage, stage_count(), stage_title(stage), map_id, preset_id, attempts])

func respawn() -> void:
	respawn_count += 1
	clean_eligible = false
	# p / a fall during stage practice stays labelled stage practice.
	if practice_stage < 0:
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
	_rebase_compensation()
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
	if bool(player.call("is_grounded")):
		_rebase_compensation()
	var body := body_reference()
	if not _started and body.distance_to(_spawn_origin) > START_DISTANCE:
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
				_rebase_compensation()
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
	_collect_checkpoints(body)
	if level.call("is_finish_at", body):
		_finish()

## spawn settling can move down a few centimetres. horizontal travel, upward movement or a real
## jump means the current law has acted, even before the timer's 0.5 m start threshold. a duck
## alone moves no body reference, so it does not.
func _note_preset_physics() -> void:
	if _used_preset_physics or player == null:
		return
	var offset := body_reference() - _spawn_origin
	_used_preset_physics = Vector2(offset.x, offset.z).length() > 0.0001 \
		or Vector2(player.velocity.x, player.velocity.z).length() > 0.0001 \
		or player.velocity.y > 0.0001 or offset.y > 0.01 \
		or int(player.get("jump_count")) != _spawn_jump_count

## the callback's actual delta against the preset's rate. a started clean attempt that sees a
## stale one becomes practice.
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

func _collect_checkpoints(body: Vector3) -> void:
	var points: Array = level.get("checkpoints")
	for stage: int in range(points.size() - 1, checkpoint_index, -1):
		var point: Dictionary = points[stage]
		var reached := false
		if point.get("bounds") is AABB:
			reached = (point["bounds"] as AABB).has_point(body)
		else:
			reached = body.distance_to((point["pose"] as Transform3D).origin) < float(point.get("radius", 5.0))
		if reached or _stands_on_stage(stage):
			var skipped := stage - checkpoint_index - 1
			checkpoint_index = stage
			stage_times[stage - 1] = elapsed
			hud.call("stage_reached", stage - 1, skipped)
			return

func _progress_roles() -> Array:
	var declared: Variant = level.get("progress_roles")
	if declared is Array:
		return declared
	return map_entry().get("roles", [])

## progress follows decks the runner stands on, read with a thin box under its feet.
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
	var roles := _progress_roles()
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
			var segment := _record_seconds(_record_ticks(stage_times[i]) - _record_ticks(previous))
			previous = stage_times[i]
			split_deltas.append(segment - best_segments[i] if i < best_segments.size() and best_segments[i] > 0.0 else NAN)
			if i >= best_segments.size():
				best_segments.append(segment)
			elif best_segments[i] <= 0.0 or _record_faster(segment, best_segments[i]):
				best_segments[i] = segment
		is_best = _record_faster(elapsed, best_time)
		if is_best:
			best_time = _record_seconds(_record_ticks(elapsed))
			best_splits.assign(_record_times(_record_tick_array(stage_times)))
	if finish_kind == "clean" or finish_kind == "open":
		is_open_best = _record_faster(elapsed, open_best_time)
		if is_open_best:
			open_best_time = _record_seconds(_record_ticks(elapsed))
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
	# the runner's horizontal actual travel over its last step, m/s, averaged over 0.1 s of steps.
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
	if not startup_error.is_empty():
		if event.is_action_pressed("pause"):
			request_quit(3)
		return
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
			if event.is_action_pressed("r15_preset_%d" % slot):
				select_slot(slot)
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
		request_quit(0 if startup_error.is_empty() else 3)

func window_title() -> String:
	return "%s · %s · %s · %d Hz%s" % [BUILD_LABEL, map_name(), str(preset.label), physics_hz, " · STAND-IN runner" if runner_is_standin() else ""]

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
			player.set("mouse_sensitivity", 0.0022 * float(settings.r13_sensitivity))
			player.set("fov_horizontal", float(settings.r13_fov))
			player.set("comfort", false)
			player.set("autohop", true)
	if audio != null:
		audio.call("set_volume", float(settings.volume))

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

## the running body's motor version: the r15 runner's MOTOR_VERSION, never r14's family version.
func family_version() -> String:
	if str(preset.family) == "source" and runner_is_standin():
		return str(PRESETS.STANDIN_FAMILY.version)
	var own: Variant = (player.get_script() as Script).get_script_constant_map().get("MOTOR_VERSION") if player != null else null
	return str(own) if own != null else str((PRESETS.FAMILIES[str(preset.family)] as Dictionary).version)

## the collision body the run used. the duck values also sit in the physics fingerprint; they
## are repeated here so a section says plainly which hulls it was run with.
func hull_identity() -> Dictionary:
	if str(preset.family) == "source":
		var cvars: Dictionary = player.get("settings")
		return {"shape": "box", "width_u": cvars.get("hull_width"), "height_u": cvars.get("hull_height"),
			"duck_height_u": cvars.get("duck_hull_height"), "duck_air_anchor": cvars.get("duck_air_anchor")}
	return {"shape": "capsule", "radius_m": 0.30, "height_m": 1.8}

## mechanics beyond the preset that change what a run means (the lab's slide, wall jump, grapple).
func mechanics() -> Array:
	var out: Array = []
	var declared: Variant = level.get("mechanics") if level != null else null
	if declared is Array:
		out.append_array(declared)
	var own: Variant = player.get("mechanics") if player != null else null
	if own is Array:
		out.append_array(own)
	return out

func record_identity() -> Array:
	var titles: Array = []
	for i: int in stage_count():
		titles.append(segment_title(i))
	var map_identity := [map_id, map_kind(), level.get("level_id"), level.get("level_version"), level.get("variant")]
	return [TIMING_RULES, map_identity, course_geometry, titles, preset_id, str(preset.family), family_version(), runner_path(), physics_hz,
		JSON.stringify(physics_fingerprint(), "", true), JSON.stringify(hull_identity(), "", true), JSON.stringify(mechanics(), "", true)]

func record_identity_text() -> String:
	return JSON.stringify(record_identity())

func _course_key() -> String:
	return record_identity_text().sha256_text().left(16)

func _section() -> String:
	return "course_" + course_key

## the active key's bests, and nothing from any other key. keys already visited in this
## process are kept in memory, so switching back finds them even with records off.
func _refresh_records() -> void:
	if not course_key.is_empty():
		_record_cache[course_key] = {"best": best_time, "open": open_best_time, "splits": best_splits.duplicate(), "segments": best_segments.duplicate(), "state": record_state}
	course_key = _course_key()
	best_time = -1.0
	open_best_time = -1.0
	previous_best = -1.0
	best_splits.clear()
	best_segments.clear()
	record_state = ""
	if _record_cache.has(course_key):
		var cached: Dictionary = _record_cache[course_key]
		best_time = cached.best
		open_best_time = cached.open
		best_splits.assign(cached.splits)
		best_segments.assign(cached.segments)
		record_state = str(cached.state)
		return
	_load_records()

func _load_settings() -> void:
	if not persist:
		profile_state = "off"
		return
	var config := ConfigFile.new()
	if config.load(profile_path) == OK:
		profile_state = "loaded"
		for key: String in settings:
			settings[key] = _setting_value(key, config.get_value("settings", key, settings[key]))
		return
	profile_state = "new"
	if not seed_from_r14 or FileAccess.file_exists(profile_path):
		return
	# p / first launch: the r14 look settings only, read-only. records are never read from it.
	var r14 := ConfigFile.new()
	if r14.load(R14_SAVE_PATH) != OK:
		return
	for key: String in settings:
		if r14.has_section_key("settings", key):
			settings[key] = _setting_value(key, r14.get_value("settings", key))
			seeded_settings = true
	if seeded_settings:
		profile_state = "new, look settings read from R14"

func _load_records() -> void:
	if not persist:
		return
	var config := ConfigFile.new()
	if config.load(profile_path) != OK:
		return
	var section := _section()
	if not config.has_section(section):
		record_state = "absent"
		return
	var why := _load_tick_records(config, section)
	record_state = "loaded" if why.is_empty() else "rejected: " + why
	if not why.is_empty():
		push_warning("r15: records in %s ignored: %s" % [section, why])
		best_time = -1.0
		open_best_time = -1.0
		best_splits.clear()
		best_segments.clear()

## tick-domain comparisons keep an equal replay equal after configfile's float formatting.
func _record_ticks(seconds: float) -> int:
	if not is_finite(seconds) or seconds < 0.0 or seconds * physics_hz > float(MAX_RECORD_TICKS):
		return -1
	return roundi(seconds * physics_hz)

func _record_seconds(ticks: int) -> float:
	return float(ticks) / physics_hz if ticks >= 0 else -1.0

func _record_faster(candidate: float, incumbent: float) -> bool:
	var ticks := _record_ticks(candidate)
	var best := _record_ticks(incumbent)
	return ticks >= 0 and (best < 0 or ticks < best)

func _record_tick_array(times: Array[float]) -> Array[int]:
	var ticks: Array[int] = []
	for seconds: float in times:
		ticks.append(_record_ticks(seconds))
	return ticks

func _record_times(ticks: Array) -> Array[float]:
	var times: Array[float] = []
	for value: int in ticks:
		times.append(_record_seconds(value))
	return times

static func _is_tick(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= 0 and value <= MAX_RECORD_TICKS

## reads one section into the bests; "" when accepted, otherwise why it was refused. nothing is
## partially loaded: a refused section leaves every best empty.
func _load_tick_records(config: ConfigFile, section: String) -> String:
	if str(config.get_value(section, "identity", "")) != record_identity_text():
		return "identity differs"
	var version: Variant = config.get_value(section, "time_ticks_version", null)
	var rate: Variant = config.get_value(section, "physics_hz", null)
	if typeof(version) != TYPE_INT or version != RECORD_TICKS_VERSION:
		return "tick version"
	if typeof(rate) != TYPE_INT or rate != physics_hz:
		return "physics rate"
	var clean: Variant = config.get_value(section, "clean_best_ticks", null)
	var open: Variant = config.get_value(section, "open_best_ticks", null)
	var splits: Variant = config.get_value(section, "clean_split_ticks", null)
	var segments: Variant = config.get_value(section, "clean_segment_ticks", null)
	if typeof(clean) != TYPE_INT or typeof(open) != TYPE_INT or clean < -1 or open < -1 or clean > MAX_RECORD_TICKS or open > MAX_RECORD_TICKS:
		return "best ticks"
	if not splits is Array or not segments is Array or (splits as Array).any(func(t: Variant) -> bool: return not _is_tick(t)) or (segments as Array).any(func(t: Variant) -> bool: return not _is_tick(t)):
		return "split or segment ticks"
	if clean >= 0:
		if (splits as Array).size() != stage_count() or (segments as Array).size() != stage_count() or splits.back() != clean:
			return "incomplete splits"
		var previous := 0
		var sum := 0
		for i: int in (splits as Array).size():
			var split: int = splits[i]
			var segment: int = segments[i]
			# a best segment is never slower than the best run's own segment.
			if split <= previous or segment <= 0 or segment > split - previous:
				return "splits out of order"
			previous = split
			sum += segment
		if sum > clean:
			return "segments exceed the best"
		if open < 0 or open > clean:
			return "open line slower than the clean best"
	elif not (splits as Array).is_empty() or not (segments as Array).is_empty():
		return "splits without a best"
	best_time = _record_seconds(clean)
	open_best_time = _record_seconds(open)
	best_splits.assign(_record_times(splits))
	best_segments.assign(_record_times(segments))
	return ""

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
	if config.has_section(section):
		config.erase_section(section)
	config.set_value(section, "identity", record_identity_text())
	config.set_value(section, "map", map_id)
	config.set_value(section, "map_name", map_name())
	config.set_value(section, "map_kind", map_kind())
	config.set_value(section, "geometry", course_geometry)
	config.set_value(section, "rules", TIMING_RULES)
	config.set_value(section, "preset", preset_id)
	config.set_value(section, "preset_label", str(preset.label))
	config.set_value(section, "family", str(preset.family))
	config.set_value(section, "family_version", family_version())
	config.set_value(section, "runner", runner_path())
	config.set_value(section, "standin", runner_is_standin())
	config.set_value(section, "physics_hz", physics_hz)
	config.set_value(section, "stages", stage_count())
	config.set_value(section, "time_ticks_version", RECORD_TICKS_VERSION)
	config.set_value(section, "clean_best_ticks", _record_ticks(best_time))
	config.set_value(section, "open_best_ticks", _record_ticks(open_best_time))
	config.set_value(section, "clean_split_ticks", _record_tick_array(best_splits))
	config.set_value(section, "clean_segment_ticks", _record_tick_array(best_segments))
	config.set_value(section, "clean_best", best_time)
	config.set_value(section, "open_best", open_best_time)
	last_save_ok = config.save(profile_path) == OK
	profile_state = "saved" if last_save_ok else "save failed"
