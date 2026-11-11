extends "res://tests/r21_surf_route.gd"
## labelled local route fixture on the real salt quay; speed is earned from rest by input.
var skill_rows: Array = []
var collision_store := false
var skill_landed := false
var branch_tick := -1
var end_tick := -1
var skill_mode := "safe"

func _start() -> void:
	super._start()
	skill_mode = str(opts.get("skill", "safe"))
	assert(skill_mode in ["safe", "outside", "late"])
	# initialization only: authored pan, ordinary standing hull, zero speed; no later rescue.
	player.reset_to(Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(187, 5.64, 52)))
	max_ticks = 1600
	nodes = [{"land": Vector2(207, 52), "e": Vector2(200.4, 52), "drop": 0.3, "vt": 3000.0}, {"land": Vector2(215, 54.0), "e": Vector2(206, 53.5), "drop": 0.0, "vt": 3000.0}, {"p": Vector2(245, 52)}]

func _control_source(tick: int) -> void:
	if node_index == 0:
		super._control_source(tick)
		return
	if branch_tick < 0:
		branch_tick = tick
	if skill_mode == "outside" and node_index < 2:
		super._control_source(tick)
		return
	var here := Vector2(player.position.x, player.position.z)
	var target := Vector2(245, 52)
	if skill_mode == "safe":
		if player.position.x < 214:
			target = Vector2(213, 36)
		elif player.position.x < 225:
			target = Vector2(227, 36)
	elif skill_mode == "outside":
		if player.position.x < 215:
			target = Vector2(217, 55.2)
		elif player.position.x < 219.5:
			target = Vector2(220.8, 54.8)
		else:
			target = Vector2(225, 50)
	if player.is_grounded():
		_look(here, target)
		_want({"w": true, "space": true}, tick)
	else:
		var want := _air(here, target, 0.0, false)
		want["space"] = true
		_want(want, tick)

func _observe(tick: int) -> void:
	var motion: Dictionary = player.get_motion_state()
	for c: Dictionary in motion.contacts:
		if c.body == "salt_store":
			collision_store = true
	skill_rows.append({"tick": tick, "p": plain(player.position), "grounded": player.is_grounded(), "support": _support(player.position) if player.is_grounded() else "", "speed_u": motion.actual_speed_u})
	if player.position.x > (220.5 if skill_mode == "outside" else 223.0) and player.is_grounded() and end_tick < 0:
		skill_landed = true
		end_tick = tick
	if (skill_landed and (skill_mode == "safe" or (player.is_grounded() and player.position.x > 223))) or (collision_store and skill_mode == "late"):
		super._observe(tick)
		_end("skill_done", tick + 1)
		return
	super._observe(tick)

func _accept(summary: Dictionary) -> bool:
	var open_rows := skill_rows.filter(func(r: Dictionary) -> bool: return r.p[0] >= 214.5936 and r.p[0] <= 220.4064)
	var outside := not open_rows.is_empty() and open_rows.all(func(r: Dictionary) -> bool: return not r.grounded and r.p[2] > 54.4064 and r.p[1] < 9.4)
	var ok: bool = collision_store if skill_mode == "late" else summary.reason == "skill_done" and summary.respawns == 0 and skill_landed and not collision_store and (outside if skill_mode == "outside" else true)
	_write("skill.json", {"ok": ok, "mode": skill_mode, "setup": "initial real pan x187 y5.64 z52, rest, yaw -pi/2; every later step is key/mouse input", "branch_tick": branch_tick, "landing_tick": end_tick, "branch_to_landing_s": float(end_tick - branch_tick) / hz, "landed": skill_landed, "store_contact": collision_store, "outside_over_water": outside, "rows": skill_rows, "style": game.session.style.summary(), "flights": flights})
	return ok
