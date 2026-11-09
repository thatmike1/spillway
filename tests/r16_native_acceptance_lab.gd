extends "res://tests/r16_delivery_lab.gd"
## actual R16 host in the real authored lab; input-only established plans, no fixture surfaces.
var captures: Array = []
var captured := {}
var capture_pending := false
var episode_name := ""

class ReadOnlyOverlay:
	extends Label
	var host: Node
	func _process(_delta: float) -> void:
		var state: Dictionary = host.player.get_motion_state().experiment
		text = "ACCEPTANCE OBSERVER (test UI)\n%s\nwall kicks left %d / %d | kicks %d\nslide %s | armed %s | held Space ignored %s\nheld A %s / D %s / Space %s / Shift %s\n%s" % [
			"authored chamber practice" if host.practice_stage >= 0 else "normal spawn; input-earned movement",
			state.wall_jump.budget, state.wall_jump.budget_max, state.counts.wall_jump,
			state.slide.active, state.slide.armed, state.slide.held_space_ignored,
			Input.is_action_pressed("move_left"), Input.is_action_pressed("move_right"), Input.is_action_pressed("jump"), Input.is_action_pressed("r15_slide"),
			"events " + str(state.events)]

func make_game(runner_kind: String, map: String = "experiment") -> void:
	await super(runner_kind, map)
	if DisplayServer.get_name() != "headless":
		var layer := CanvasLayer.new()
		layer.layer = 30
		game.add_child(layer)
		var label := ReadOnlyOverlay.new()
		label.host = game
		label.position = Vector2(800, 100)
		label.add_theme_font_size_override("font_size", 13)
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.02, 0.04, 0.06, 0.8)
		box.set_content_margin_all(6.0)
		label.add_theme_stylebox_override("normal", box)
		layer.add_child(label)

func _main() -> void:
	_group = "native_lab"
	var chain := await _chain("r16", false, {}, 40, true, 96)
	var measure := _slide_measure(chain)
	check("descent Shift then held-Space landing slide then fresh hop", int(measure.slide_ticks) > 20 and bool(measure.slide_ducked) and int(measure.first_jump_after_land) > int(measure.slide_tick), measure)
	await drop_game()
	var chamber := await _chamber_ad("r16", 6, true)
	check("real chamber A/D held through two kicks reaches mezzanine", bool(chamber.up) and rows_with(chamber, "wall_jump").size() == 2, chamber.end)
	var refuses := rows_with(chamber, "wall_refused")
	check("third face refused budget spent", refuses.any(func(r: Dictionary) -> bool: return r.lab.refusal == "budget spent"))
	check("landing refilled two kicks", rows_with(chamber, "wall_refill").size() > 0)
	if capture_pending and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	var file := FileAccess.open(out_dir.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_plain({"label": "actual R16 host, real lab, labelled authored chamber practice and normal-spawn slide chain; engine injected inputs",
		"checks": results, "slide": measure, "captures": captures, "chamber_end": chamber.end, "chamber_setup": chamber.setup}), " "))
	file.close()
	var failed := results.filter(func(r: Dictionary) -> bool: return not r.ok)
	await drop_game()
	quit(0 if failed.is_empty() else 1)

func begin(name: String, setup: String) -> void:
	episode_name = name
	super(name, setup)

func step() -> void:
	await super()
	if ep.is_empty() or not ep.has("rows") or (ep.rows as Array).is_empty():
		return
	var r: Dictionary = (ep.rows as Array).back()
	if not r.has("lab"):
		return
	if r.t % 128 == 0:
		capture(episode_name + "-moving-%04d" % r.t, r)
	for event: String in ["slide_armed", "slide_landing", "slide_hop", "wall_jump", "wall_refused", "wall_refill"]:
		if event in r.lab.events:
			var suffix := "-%d" % r.lab.budget if event == "wall_jump" else ""
			capture(episode_name + "-" + event + suffix, r)
	if episode_name.begins_with("slide") and "jump" in r.ev and int(r.t) > 100 and bool(captured.get(episode_name + "-slide_landing", false)):
		capture(episode_name + "-fresh-hop", r)

func capture(tag: String, row: Dictionary) -> void:
	if captured.has(tag):
		return
	captured[tag] = true
	if DisplayServer.get_name() == "headless" or capture_pending:
		return
	capture_pending = true
	await RenderingServer.frame_post_draw
	var camera: Camera3D = runner().camera
	root.get_texture().get_image().save_jpg(out_dir.path_join(tag + ".jpg"), 0.88)
	captures.append({"file": tag + ".jpg", "row": _plain(row), "camera": _plain(camera.global_position),
		"actual_player_camera": root.get_camera_3d() == camera, "captured_p": _plain(runner().global_position)})
	capture_pending = false
