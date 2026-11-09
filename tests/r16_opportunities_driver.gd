extends "res://tests/r15_whiteout_driver.gd"
## labelled, state-aware input execution on the old r15 host plus the optional overlay.
## only the authored spawn/stage-practice API places the runner; all subsequent control is
## ordinary key edges and relative mouse counts. no velocity, pose, progress or hull restores.

const OVERLAY := preload("res://scripts/r16_style_opportunities.gd")
const STYLE := preload("res://scripts/r16_style.gd")
const SAMPLE := preload("res://tests/r16_style_probe.gd")
var style: RefCounted
var scored: Array = []
var rows := PackedStringArray()
var trial := ""
var setup := {}
var opportunity := Vector3.ZERO
var overlay_report := {}
var jump_at := -1
var passage_tick := -1
var blocking: Array = []
var near_contacts: Array = []
var takeoff := {}
var crossing: Array = []
var capture_labels := {}
var captures: Array = []
var capture_busy := false

func _start() -> void:
	trial = str(opts.get("case", "breakwater-crouch"))
	max_ticks = 2200
	amp = deg_to_rad(8.0)
	game = MAIN.new()
	game.map_id = "whiteout-relay" if trial.begins_with("whiteout") else "breakwater"
	game.motor = str(opts.get("preset", "server128"))
	game.seed_from_r14 = false
	game.set_window_title = false
	root.add_child(game)
	lab = game
	level = game.level
	player = game.player
	source = true
	hz = Engine.physics_ticks_per_second
	warmup = 33
	radians_per_count = float(player.tape_radians_per_count)
	turn_cap = deg_to_rad(600.0) / hz
	overlay_report = OVERLAY.apply(level)
	style = STYLE.new()
	style.call("reset", {"map": game.map_id, "preset": game.preset_id})
	if game.map_id == "breakwater":
		game.practise_stage(3)
		setup = {"kind": "authored stage practice", "stage": 3, "movement_writes_after_setup": 0}
		opportunity = Vector3(-81.3, 0, -198 if trial.contains("thread") else -166)
		nodes = [{"p": Vector2(-81.3, -126), "r": 0.3}]
		if trial.contains("thread"):
			# approach the west lane after the separate crouch frame, then earn a strafe hop.
			amp = deg_to_rad(3.0)
			nodes = [{"p": Vector2(-78, -174), "r": 0.2}, {"p": Vector2(-81.3, -183), "r": 0.2},
				{"p": Vector2(-81.3, -194), "hop": true, "vt": 430.0, "r": 0.3}]
		elif trial.contains("normal"):
			opportunity.x = -74
			nodes = [{"p": Vector2(-74, -145), "hop": true, "vt": 450.0}]
	else:
		setup = {"kind": "normal map spawn", "movement_writes_after_setup": 0}
		opportunity = Vector3(-8, 0, -28)
		nodes = [{"p": Vector2(-4.5, -18.5), "r": 0.25}, {"p": Vector2(-8, -22.5), "r": 0.2}]
		if trial.contains("normal"):
			opportunity.x = 0
			nodes = [{"p": Vector2(0, -22.5), "r": 0.2}]
	node_from = Vector2(player.global_position.x, player.global_position.z)
	var hook := Hook.new()
	hook.driver = self
	hook.process_physics_priority = 1000
	hook.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(hook)
	if str(opts.get("capture", "")) == "yes":
		root.size = Vector2i(1280, 720)
		game.hud.visible = true
	print("opportunity trial ", trial, " setup=", setup, " overlay=", overlay_report.hash)

func _control_source(tick: int) -> void:
	if node_index < nodes.size():
		super._control_source(tick)
		return
	var p := player.global_position
	var here := Vector2(p.x, p.z)
	var target := Vector2(opportunity.x, opportunity.z - 12.0)
	var grounded: bool = player.is_grounded()
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	var distance := p.z - opportunity.z
	var want := {}
	if trial.contains("thread"):
		# coast through at the earned speed, make heading corrections with A/D + mouse in air.
		if grounded:
			_look(here, target)
			want = {"w": true, "space": true}
		else:
			want = _air(here, target, 0.0, false)
			want["space"] = true
	else:
		if jump_at < 0:
			_look(here, target)
			want = {"w": true}
			# centre the 28 cm frame around the jump apex; the actual 32 u hull has depth.
			if grounded and distance <= speed * float(opts.get("jump-time", "0.375")) and distance > 0.0:
				want["space"] = true
				jump_at = tick
				takeoff = {"tick": tick, "p": _v(p), "speed_ups": speed / U, "yaw": player.yaw}
		else:
			if grounded and tick > jump_at + 5 and p.z > opportunity.z:
				want = {"w": true}
			if not grounded and trial.ends_with("crouch") and tick >= jump_at + 2:
				want["ctrl"] = true
	_want(want, tick)
	if opts.has("capture") and distance < 11.0 and not capture_labels.has("approach"):
		_capture("approach", tick)
	if opts.has("capture") and absf(distance) < 0.4 and not capture_labels.has("passage"):
		_capture("passage", tick)
	if distance < -3.0:
		if passage_tick < 0:
			passage_tick = tick
		if opts.has("capture") and not capture_labels.has("exit"):
			_capture("exit", tick)
	if passage_tick >= 0 and tick > passage_tick + 40:
		_end("passed", tick)
	elif jump_at >= 0 and tick > jump_at + 180 and distance >= -1.0:
		_end("blocked", tick)

func _route_finished(_tick: int) -> bool:
	return false

func _observe(tick: int) -> void:
	super._observe(tick)
	var sample := SAMPLE.sample_of(game, tick)
	var fresh: Array = style.call("step", sample, player, level)
	scored.append_array(fresh)
	var motion: Dictionary = player.get_motion_state()
	for contact: Dictionary in motion.contacts:
		if str(contact.body) in ["Sill", "Lintel", "WestPost", "EastPost", "WestWall", "EastWall"]:
			var record := {"tick": tick, "body": contact.body, "normal": _v(contact.normal), "blocking": contact.blocking, "p": _v(player.global_position)}
			near_contacts.append(record)
			if bool(contact.blocking):
				blocking.append(record)
	if absf(player.global_position.z - opportunity.z) < 1.0:
		crossing.append({"tick": tick, "p": _v(player.global_position), "v": _v(player.velocity), "grounded": player.is_grounded(), "ducked": player.ducked})
	rows.append(JSON.stringify({"tick": tick, "p": _v(player.global_position), "v": _v(player.velocity), "ref": _v(game.body_reference()), "yaw": player.yaw,
		"grounded": player.is_grounded(), "ducked": player.ducked, "motion": plain(motion), "held": held.keys(), "score": (style.call("snapshot") as Dictionary).score, "events": fresh}))

func _capture(label: String, tick: int) -> void:
	if capture_busy:
		return
	capture_labels[label] = tick
	capture_busy = true
	await RenderingServer.frame_post_draw
	var file := out_dir.path_join("%s-%05d.jpg" % [label, tick])
	var image := root.get_texture().get_image()
	image.save_jpg(file, 0.86)
	captures.append({"label": label, "tick_requested": tick, "physics_frame_captured": Engine.get_physics_frames(), "p_captured": _v(player.global_position), "camera": _v(player.camera.global_position), "file": file.get_file()})
	capture_busy = false

func _end(reason: String, tick: int) -> void:
	done = true
	_want({}, tick)
	var opportunity_events := scored.filter(func(e: Dictionary) -> bool: return str(e.kind) in ["crouch_save", "near_miss"] and JSON.stringify(e.geo).contains("R16Opportunities"))
	var result := {"label": "state-aware real key/mouse execution on new R15-host wrapper; not actual R16 acceptance", "case": trial, "reason": reason, "ticks": tick,
		"setup": setup, "physics_hz": hz, "warmup": warmup, "radians_per_count": radians_per_count, "preset": game.preset_id,
		"base_hash": level.geometry_hash(), "overlay": overlay_report, "takeoff": takeoff, "crossing": crossing, "final": _v(player.global_position),
		"blocking_contacts": blocking, "all_overlay_contacts": near_contacts, "style_events": scored, "opportunity_events": opportunity_events,
		"style_snapshot": style.call("snapshot"), "style_sha256": FileAccess.get_sha256("res://scripts/r16_style.gd"), "captures": captures}
	_write("opportunity.json", result)
	var file := FileAccess.open(out_dir.path_join("trace.jsonl.gz"), FileAccess.WRITE)
	file.store_buffer(("\n".join(rows) + "\n").to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	file.close()
	_write("events.tape.json", {"format": "spillway-momentum-tape", "version": 2, "name": trial, "physics_hz": hz, "input_profile": "physics_tick", "duration_ticks": tick + 1, "duration_s": float(tick + 1) / hz, "events": events})
	print("opportunity ", trial, " ", reason, " crossing_ticks=", crossing.size(), " blocking=", blocking.size(), " intended_events=", opportunity_events)
	quit(0)

static func plain(value: Variant) -> Variant:
	if value is Vector3:
		return [value.x, value.y, value.z]
	if value is Dictionary:
		var out := {}
		for key: Variant in value:
			out[key] = plain(value[key])
		return out
	if value is Array:
		return value.map(func(v: Variant) -> Variant: return plain(v))
	return value
