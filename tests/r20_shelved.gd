extends SceneTree
## verify production selection, rejected direct calls and retained source, without editing the motor.
const SCENE := preload("res://scenes/r20.tscn")
const OLD := preload("res://scripts/r19_map_catalog.gd")
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var game := SCENE.instantiate()
	game.persist = false
	game.record_runs = false
	game.seed_from_r15 = false
	game.set_window_title = false
	root.add_child(game)
	await process_frame
	game.hud.dismiss_title()
	game.set_paused(true)
	await process_frame
	var ok := true
	for id: String in ["line-drive", "fall-line"]:
		ok = ok and id not in game.map_ids() and not game.hud.map_buttons.has(id)
		ok = ok and OLD.make().catalog.has(id)
		var before: String = game.map_id
		game.select_map(id)
		ok = ok and game.map_id == before
	print("R20 shelved production selection, absent cards, rejected direct calls, retained R19 catalog: ", ok)
	game.queue_free()
	await process_frame
	quit(0 if ok else 1)
