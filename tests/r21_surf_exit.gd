extends "res://tests/r21_surf_route.gd"
## matched authored entries compare steering and actual supports. only the east fixture starts at cp2.
var first_contact := {}
var first_support := {}
var crossed := {}
var translated_old_east := false
var fixture_setup := "normal west spawn, rest"

func _start() -> void:
	super._start()
	max_ticks = 4000
	var east: bool = opts.get("fin", "west") == "east"
	var old: bool = opts.get("exit-geometry", "r21") == "r20"
	var centre := 132.0
	if east and old:
		# initial geometry translation puts both east fixtures in the same float32 world coordinates.
		game.level.position.x = 48.0
		translated_old_east = true
	var height := 14.2 if old else 7.2
	if east:
		# labelled fixture initialization only, before input tick zero; no subsequent state rescue.
		player.reset_to(Transform3D(Basis(Vector3.UP, PI), Vector3(centre - 9.7, 15.54, -178)))
		fixture_setup = "initial east authored headrace pose, rest; R20 geometry translated +48m to common world coordinates; no later pose/view/velocity writes" if old else "initial east authored headrace pose, rest; common world coordinates; no later pose/view/velocity writes"
		nodes = [{"entry": "east", "end": -167.4, "heading": PI}, {"surf": "east", "end": 0.0, "heading": PI}, {"p": Vector2(centre - 6, 18), "fall": height}]
	else:
		nodes = [{"entry": "west", "end": -0.6, "heading": 0.0}, {"surf": "west", "end": -168.0, "heading": 0.0}, {"p": Vector2(6, -186), "fall": height}]

func _control_source(tick: int) -> void:
	var original: String = str(opts.get("exit-geometry", "r21"))
	if translated_old_east:
		opts["exit-geometry"] = "r21"
	super._control_source(tick)
	opts["exit-geometry"] = original

func _observe(tick: int) -> void:
	var motion: Dictionary = player.get_motion_state()
	var east: bool = opts.get("fin", "west") == "east"
	if first_contact.is_empty():
		for c: Dictionary in motion.contacts:
			if str(c.body).begins_with("Surf_") and c.normal.y > 0.45 and c.normal.y < 0.65:
				first_contact = {"tick": tick, "p": plain(player.position), "v": plain(player.velocity), "contact": plain(c.position), "speed_u": motion.actual_speed_u, "normal": plain(c.normal)}
	if crossed.is_empty() and (player.position.z >= 0 if east else player.position.z <= -168):
		crossed = {"tick": tick, "p": plain(player.position), "v": plain(player.velocity), "speed_u": motion.actual_speed_u}
	if not crossed.is_empty() and player.is_grounded() and first_support.is_empty():
		first_support = {"tick": tick, "p": plain(player.position), "v": plain(player.velocity), "speed_u": motion.actual_speed_u, "body": _support(player.position), "normal": plain(_ground_hit(player.position).get("normal", Vector3.ZERO)), "surface_point": plain(_ground_hit(player.position).get("position", Vector3.ZERO))}
		super._observe(tick)
		_end("exit_support", tick + 1)
		return
	super._observe(tick)

func _accept(summary: Dictionary) -> bool:
	var failed_low_old: bool = opts.get("exit-geometry", "r21") == "r20" and float(opts.get("exit-target", "5.3")) < 6
	var ok: bool = not first_contact.is_empty() and first_contact.p[1] >= 14.4 and first_contact.contact[1] >= 14.4 and not crossed.is_empty()
	ok = ok and (first_support.is_empty() and summary.reason == "failed" if failed_low_old else not first_support.is_empty() and first_support.normal[1] > 0.999)
	_write("exit.json", {"ok": ok, "geometry": opts.get("exit-geometry", "r21"), "target": opts.get("exit-target", "5.3"), "fin": opts.get("fin", "west"), "setup": fixture_setup, "old_geometry_translation_m": [48, 0, 0] if translated_old_east else [0, 0, 0], "first_contact": first_contact, "crossed": crossed, "support": first_support, "failure_expected": failed_low_old, "source": "actual F2 controller, real input after fixture start; steering differences explicit"})
	return ok
