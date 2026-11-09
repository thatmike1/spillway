extends "res://tests/r14_practice_driver.gd"
## full earned route or saved-input replay on actual R19 host/session.
const FALL_HOST := preload("res://tests/r19_fall_line_host.gd")
const RUN_READER := preload("res://scripts/r16_run_reader.gd")
var game: Node3D
var telemetry := PackedStringArray()
var _closing := false
const GEO_AUDIT := preload("res://tests/r19_fall_line_geometry.gd")
func _start() -> void:
	Engine.physics_ticks_per_second = 128
	if DisplayServer.get_name() == "headless":
		RenderingServer.render_loop_enabled = false
	max_ticks = int(opts.get("max-ticks", "12000"))
	amp = deg_to_rad(20.0)
	game = FALL_HOST.new()
	game.name = "R19"
	game.motor = "server128"
	game.seed_from_r15 = false
	game.source_sensitivity_override = 2.5
	game.set_window_title = false
	game.persist = true
	game.profile_path = out_dir.path_join("profile.cfg")
	game.record_runs = true
	game.recordings_dir = out_dir.path_join("recordings")
	game.ghosts_directory = out_dir.path_join("ghosts")
	game.ghost_share_storage = out_dir.path_join("ghost-selection.cfg")
	root.add_child(game)
	lab = game
	level = game.level
	player = game.player
	source = true
	hz = Engine.physics_ticks_per_second
	warmup = 33
	radians_per_count = float(player.tape_radians_per_count)
	turn_cap = deg_to_rad(480.0) / hz
	node_from = Vector2(player.position.x, player.position.z)
	nodes = []
	for i: int in 10:
		var x := [-1.5,1.5,0.0][i % 3] as float
		var z := -3.0 - 13.0*i
		nodes.append({"land":Vector2(x,z-2),"e":Vector2(x,z+3.5),"drop":0.35})
	nodes.append({"p":Vector2(0,-139)})
	if str(opts.get("route","")) == "recovery":
		nodes = [{"p":Vector2(0,-9),"fall":0.0},{"p":Vector2(14,-20)},{"p":Vector2(14,-112)},{"p":Vector2(14,-149)},{"p":Vector2(2,-149)}]
	var geometry := GEO_AUDIT.audit(level)
	_write("geometry.json",geometry)
	assert(geometry.ok, str(geometry.errors))
	if opts.has("tape"):
		_load_tape(str(opts.tape))
	var hook := Hook.new()
	hook.driver = self
	hook.process_physics_priority = 1000
	hook.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(hook)
	print("fall-line: actual R19 component host, frozen source F2, normal spawn; input only")

func _route_finished(_tick: int) -> bool:
	return finish_tick >= 0
func _observe(tick: int) -> void:
	super._observe(tick)
	telemetry.append(JSON.stringify({"tick":tick,"p":plain(player.position),"v":plain(player.velocity),"grounded":player.is_grounded(),"motion":plain(player.get_motion_state()),"platforms":level.platform_state(),"clock":level.clock_tick,"elapsed":game.elapsed,"checkpoint":game.checkpoint_index,"respawns":game.respawn_count},"",false,true))
	if game.respawn_count > 0:
		_end("fell",tick+1)
func _end(reason: String, tick: int) -> void:
	if _closing:
		return
	_closing = true
	done = true
	_want({},tick)
	await process_frame
	await process_frame
	var reads: Array = []
	for sealed: Dictionary in game.session.sealed:
		var run: Dictionary = RUN_READER.read(str(sealed.path))
		reads.append({"path":sealed.path,"ok":run.ok,"errors":run.errors,"clean_finish":RUN_READER.clean_finish(run)})
	var passed: bool = game.finished and game.finish_kind == "clean" and game.respawn_count == 0 and reads.any(func(r: Dictionary) -> bool: return r.ok and r.clean_finish.ok)
	_write("summary.json",{"pass":passed,"reason":reason,"finished":game.finished,"finish_kind":game.finish_kind,"elapsed":game.elapsed,"respawns":game.respawn_count,"node":node_index,"p":plain(player.position),"runner":player.get_script().resource_path,"identity":game.motion_identity(),"geometry":level.geometry_hash(),"transitions":level.transitions,"recordings":reads,"actual_v_mismatches":game.session.actual_v_mismatches,"rate_mismatch_ticks":game.rate_mismatch_ticks,"supports":supports,"hops":hops,"style":game.session.style.summary(),"look":game.look_layer.report})
	_write("events.tape.json",{"format":"spillway-momentum-tape","version":2,"physics_hz":hz,"duration_ticks":tick,"events":events})
	var file := FileAccess.open(out_dir.path_join("trace.jsonl.gz"),FileAccess.WRITE)
	file.store_buffer(("\n".join(telemetry)+"\n").to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	file.close()
	print("fall-line pass=",passed," time=",game.elapsed," reason=",reason," node=",node_index," p=",player.position)
	await game.request_quit(0 if passed else 1)
static func plain(value: Variant) -> Variant:
	if value is Vector3:
		return [value.x,value.y,value.z]
	if value is Array:
		return value.map(func(v: Variant) -> Variant: return plain(v))
	if value is Dictionary:
		var result := {}
		for key: Variant in value:
			result[key] = plain(value[key])
		return result
	return value
