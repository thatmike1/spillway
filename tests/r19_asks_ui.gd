extends SceneTree
## the actual r18 host and controls, with isolated persistence and no fabricated label objects.
const MAIN := preload("res://scripts/r17_main.gd")
const BASE := preload("res://scripts/r16_main.gd")
var game: Node
var checks: Array = []
var output := ""
var asks := "maps"

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
		if arg.begins_with("--asks="):
			asks = arg.trim_prefix("--asks=")
	run.call_deferred()

func check(ok: bool, name: String, detail: Variant = "") -> void:
	checks.append({"pass": ok, "name": name, "detail": str(detail)})
	print("%s %s %s" % ["ok" if ok else "FAIL", name, str(detail)])

func frames(count := 3) -> void:
	for i: int in count:
		await process_frame

func run() -> void:
	assert(output.is_absolute_path())
	DirAccess.make_dir_recursive_absolute(output)
	game = MAIN.new()
	game.persist = false
	game.seed_from_r15 = false
	game.record_runs = false
	root.add_child(game)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	await frames()
	if asks.contains("maps"):
		await maps_check()
	await finish()

func maps_check() -> void:
	game.set_paused(true)
	for id: String in ["practice", "overflow"]:
		var card: Button = game.hud.map_buttons[id]
		check(not card.text.contains("R14") and not card.text.contains("R13"), id + " card has player-facing description", card.text)
		check(card.tooltip_text == game.map_entry(id).theme, id + " tooltip uses same description")
		var frozen: Dictionary = game.MAPS.entry(game.maps, id)
		var shown: Dictionary = game.map_entry(id)
		shown.theme = frozen.theme
		check(shown == frozen, id + " presentation metadata changes only theme")
		game.select_map(id)
		game.set_paused(true)
		await frames()
		var reference := BASE.new()
		reference.map_id = id
		reference.persist = false
		reference.seed_from_r15 = false
		reference.record_runs = false
		root.add_child(reference)
		reference.set_paused(true)
		check(game.course_geometry == reference.course_geometry and game.course_key == reference.course_key and game.motion_identity() == reference.motion_identity(), id + " physical map hashes and time identity match frozen host")
		check(game.map_kind() == "legacy" and game.map_id == id, id + " physical map id and kind preserved")
		reference.set_paused(false)
		reference.request_quit(0)
		root.remove_child(reference)
		reference.free()
		game.set_paused(true)

func finish() -> void:
	var failed := checks.filter(func(row: Dictionary) -> bool: return not row.pass)
	var file := FileAccess.open(output.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failed": failed.size(), "asks": asks}, "\t"))
	file.close()
	game.set_paused(false)
	game.request_quit(0)
	print("r19 asks: %d checks, %d failed" % [checks.size(), failed.size()])
	quit(0 if failed.is_empty() else 1)
