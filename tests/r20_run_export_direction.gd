extends "res://tests/r20_pack_direction_route.gd"
## earned backwards chain on authored Penstock, exported while paused, then banked normally.
var export_checks: Array = []
var did_export := false
func late() -> void:
	super()
	if game == null or did_export:
		return
	var snap: Dictionary = game.session.style.snapshot()
	if int(snap.direction.pending) >= 1600:
		did_export = true
		game.set_paused(true)
		game.run_export_directory = output.path_join("exports")
		game.run_export_folder_opener = func(_folder: String) -> int: return OK
		var before: Dictionary = game.session.style.snapshot().duplicate(true)
		var inputs: Array = game.session.pending.duplicate(true)
		var physical := [game.player.position, game.player.velocity, game.player.motion_tick, game.elapsed, game.session.tick, game.attempts, game.checkpoint_index, game.respawn_count]
		game.hud.export_name.text = "Earned backwards stack"
		game.hud.export_button.pressed.emit()
		var result: Dictionary = game.last_run_export
		export_checks.append({"ok": result.get("ok", false), "check": "actual production button exports earned pending chain", "result": result})
		export_checks.append({"ok": before == game.session.style.snapshot() and int(before.direction.pending) > 0,
			"check": "earned directional stack remains exactly pending during paused export", "direction": before.direction})
		export_checks.append({"ok": inputs == game.session.pending and physical == [game.player.position, game.player.velocity, game.player.motion_tick, game.elapsed, game.session.tick, game.attempts, game.checkpoint_index, game.respawn_count] and game.session.recorder.is_open(), "check": "inputs physics clock progress and recorder untouched"})
		game.set_paused(false)
		var file := FileAccess.open(output.path_join("export-direction.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"ok": export_checks.all(func(row: Dictionary) -> bool:return row.ok), "checks": export_checks}, "\t"))
		file.close()
