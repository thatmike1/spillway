extends SceneTree
## exercise public comparison boundaries on the five-slot runner without modifying mail or body state.
const HOST := preload("res://scripts/game.gd")
var game: Node
var checks: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, description: String) -> void:
	checks.append({"ok": ok, "check": description})
	if not ok:
		push_error("MAIL ROOFS MODE: " + description)

func _run() -> void:
	game = HOST.new()
	game.map_id = "mail-roofs"
	game.persist = false
	game.record_runs = false
	root.add_child(game)
	game.set_paused(true)
	var identities: Dictionary = {}
	for body: String in ["hold", "run"]:
		for view: String in ["envelope", "body"]:
			for goal: String in ["deliver", "optional"]:
				game.player.set_mail_body(body)
				game.player.set_mail_view(view)
				game.player.set_mail_goal(goal)
				var label := "%s/%s/%s" % [body, view, goal]
				_check(game.paused and not game.player.input_enabled, label + " preserves pause")
				_check(game.player.delivery_progress() == Vector2i(0, 5), label + " starts empty with five slots")
				_check(game.player.mail_body() == body and game.player.mail_view() == view and game.player.mail_goal() == goal, label + " getters match setters")
				_check(game.level.is_finish_at(game.level.finish_position) == (goal == "optional"), label + " applies its finish rule")
				_check(not identities.has(game.course_key), label + " has a distinct best/record identity")
				identities[game.course_key] = label
	_check(identities.size() == 8, "all eight comparisons are distinct")
	game.player.set_mail_body("hold")
	game.player.set_mail_view("envelope")
	game.player.set_mail_goal("deliver")
	game.practise_stage(0)
	_check(not game.clean_eligible and game.player.delivery_progress() == Vector2i(0, 5), "full-loop practice stays dirty and requires all five")
	_check(not game.player.delivery_goal_met(), "practice cannot skip the five-slot goal")
	var ok := checks.all(func(row: Dictionary) -> bool: return row.ok)
	print("MAIL ROOFS MODES ", JSON.stringify({"ok": ok, "checks": checks, "identities": identities}))
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if ok else 1)
