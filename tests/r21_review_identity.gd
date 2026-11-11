extends "res://tools/r21-pack-probe.gd"
## observe review inputs before the parent freezes them; this grants no release acceptance.

func _identity() -> void:
	await super._identity()
	report["review_menu_registry"] = RUN_READER.json_safe(game.map_registry)
	var titles := {}
	var routes: Array = spec.get("review_routes", [])
	check("sixteen explicit review routes", routes.size() == 16)
	for route: Dictionary in routes:
		# the inherited tour ends in the lab, except the lab tour ends in Breakwater.
		var target := "breakwater" if str(route.map) == "experiment" else "experiment"
		game.select_map(target)
		game.select_preset("server128")
		await _physics(4)
		titles[str(route.name)] = game.window_title()
	report["review_window_titles"] = titles
	var notes := {}
	for map: String in ["saltglass", "tether-yard"]:
		game.select_map(map)
		await _physics(4)
		notes[map] = {"source": "scripts/r21_main.gd", "text": game.map_revision_description()}
	report["review_ghost_revision_notes"] = notes
