extends "res://scripts/maps/mail_run.gd"
## a connected postal roof quarter around a tidal atrium, with an unordered five-slot loop.
const ROOF_ID := "mail-roofs"
const ROOF_ENTRY := {"name": "Mail Roofs", "theme": "Five slots. Your order.", "kind": "experiment", "experimental": true, "mail_delivery": true,
	"runner": "res://scripts/movement/mail_roofs_runner.gd", "script": "res://scripts/maps/mail_roofs.gd", "reticle": true,
	"instructions": "F2 bhop. Deliver all five in any order, then return to Dispatch. LMB throws, mouse steers, RMB recalls. Slot 03 needs a curved flight around the chimney. V view, B body, N goal; changes restart."}

func _init() -> void:
	level_id = "r22-mail-roofs"
	level_name = "Mail Roofs"
	level_version = 1
	variant = ROOF_ID
	spawn = Transform3D(Basis.IDENTITY, Vector3(0, 10.04, 12))
	finish_position = Vector3(-7, 10, 12)
	finish_bounds = AABB(Vector3(-10, 9.8, 9), Vector3(5, 4, 7))
	kill_bounds = AABB(Vector3(-90, -8, -100), Vector3(180, 100, 160))

func build() -> void:
	if _built:
		return
	_built = true
	_roof("south", -23, 23, -9, 18)
	_roof("east", 10, 23, -55, -9)
	_roof("north", -23, 23, -66, -55)
	_roof("west", -23, -10, -55, -9)
	checkpoints = [{"pose": spawn, "title": "Roof Dispatch", "bounds": AABB(Vector3(-23, 9.8, -66), Vector3(46, 4, 84))}]
	segment_bounds = [checkpoints[0].bounds]
	var slots := [Vector3(17, 12, -5), Vector3(19, 12, -37), Vector3(0, 12, -74), Vector3(-19, 12, -37), Vector3(-17, 12, -5)]
	for i: int in slots.size():
		var at: Vector3 = slots[i]
		mailboxes.append({"id": "mail-roofs-post-%d" % (i + 1), "bounds": AABB(at - Vector3(1.1, 0.8, 0.5), Vector3(2.2, 1.6, 1)), "position": at, "front": 1.0})
		box("post_house_%d" % i, at + Vector3(0, -7.5, -1.6), Vector3(5.4, 20, 2), Color("53666a"))
		box("post_crown_%d" % i, at + Vector3(0, 2.6, -1.6), Vector3(5.8, 0.35, 2.4), Color("ded8c2"))
		box("opening_%d" % i, at + Vector3(0, 0, -0.51), Vector3(2.5, 1.8, 0.12), Color("172d32"))
		for edge: int in [-1, 1]:
			box("jamb_%d_%d" % [i, edge], at + Vector3(edge * 1.25, 0, -0.4), Vector3(0.12, 1.8, 0.2), Color("ded8c2"))
		box("sill_%d" % i, at + Vector3(0, -0.85, -0.4), Vector3(2.6, 0.12, 0.25), Color("bc713e"))
		label("number_%d" % i, at + Vector3(0, 1.7, -0.4), "%02d" % (i + 1), 0.022)
	_roof("sorting_chamber", -10, 10, -78, -66)
	box("post_window_left", Vector3(-2.4, 13, -66), Vector3(15.2, 6, 0.6), Color("53666a"))
	box("post_window_right", Vector3(8.4, 13, -66), Vector3(3.2, 6, 0.6), Color("53666a"))
	box("post_window_sill", Vector3(6, 10.8, -66), Vector3(1.6, 1.6, 0.6), Color("53666a"))
	box("post_window_lintel", Vector3(6, 14.2, -66), Vector3(1.6, 3.6, 0.6), Color("53666a"))
	box("post_chamber_west", Vector3(-10, 13, -72), Vector3(0.6, 6, 12), Color("53666a"))
	box("post_chamber_east", Vector3(10, 13, -72), Vector3(0.6, 6, 12), Color("53666a"))
	box("post_chamber_back", Vector3(0, 13, -78), Vector3(20, 6, 0.6), Color("53666a"))
	box("post_chamber_roof", Vector3(0, 16, -72), Vector3(20.6, 0.5, 12.6), Color("ded8c2"))
	box("window_trim_top", Vector3(6, 12.5, -65.6), Vector3(2, 0.15, 0.15), Color("ded8c2"))
	box("window_trim_bottom", Vector3(6, 11.5, -65.6), Vector3(2, 0.15, 0.15), Color("bc713e"))
	label("window_number", Vector3(6, 14, -65.6), "03", 0.025)
	# this founded chimney occludes the direct flight from the east approach to slot 03.
	box("post_chimney", Vector3(3, 8, -70), Vector3(3.2, 24, 3), Color("53666a"))
	box("post_chimney_cap", Vector3(3, 20.1, -70), Vector3(3.8, 0.35, 3.6), Color("ded8c2"))
	box("flue_dark", Vector3(3, 20.29, -70), Vector3(2.4, 0.03, 2.2), Color("172d32"))
	# a clock and open bell frame form the single skyline landmark.
	box("post_tower", Vector3(0, 12, -85), Vector3(8, 32, 8), Color("ded8c2"))
	box("tower_face", Vector3(0, 23.5, -80.9), Vector3(6.5, 6.5, 0.15), Color("ded8c2"))
	var dial := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 2.9
	disc.bottom_radius = 2.9
	disc.height = 0.12
	dial.mesh = disc
	dial.position = Vector3(0, 23.5, -80.7)
	dial.rotation.x = PI * 0.5
	var face := StandardMaterial3D.new()
	face.albedo_color = Color("ded8c2")
	dial.material_override = face
	add_child(dial)
	for i: int in 12:
		var angle := TAU * i / 12.0
		box("clock_tick_%d" % i, Vector3(sin(angle) * 2.5, 23.5 + cos(angle) * 2.5, -80.55), Vector3(0.13, 0.26, 0.08), Color("172d32"))
	box("clock_hand_hour", Vector3(-0.7, 23.9, -80.45), Vector3(1.6, 0.17, 0.10), Color("172d32"))
	box("clock_hand_minute", Vector3(0, 24.45, -80.45), Vector3(0.14, 2, 0.10), Color("172d32"))
	for x: float in [-3.6, 3.6]:
		box("post_bell_pier_%s" % x, Vector3(x, 32, -85), Vector3(0.8, 8, 8), Color("ded8c2"))
	box("post_bell_roof", Vector3(0, 36, -85), Vector3(8.8, 0.7, 8.8), Color("ded8c2"))
	box("bell", Vector3(0, 31.5, -85), Vector3(2.2, 2.5, 2.2), Color("92836b"))
	for side: int in [-1, 1]:
		for z: int in range(-60, 12, 8):
			box("facade_pier_%s_%s" % [side, z], Vector3(side * 10, 1, z), Vector3(0.5, 17, 0.7), Color("aaa897"))
		box("cornice_%s" % side, Vector3(side * 10, 8.9, -32), Vector3(0.7, 0.45, 48), Color("ded8c2"))
	label("dispatch", Vector3(-7, 12, 15.5), "DISPATCH", 0.015)
	for id: String in ["post_tower", "post_bell_pier_-3.6", "post_bell_pier_3.6", "post_bell_roof"]:
		var mesh := get_node_or_null("Mail_" + id) as MeshInstance3D
		if mesh != null:
			mesh.material_override = MATERIAL.concrete(Color("aaa897"))
	_environment()
	routes = {"basic": [spawn.origin, Vector3(15, 10, 0), Vector3(15, 10, -50), Vector3(0, 10, -59), Vector3(-15, 10, -50), Vector3(-15, 10, 0), finish_position]}

func _roof(id: String, left: float, right: float, back: float, front: float) -> void:
	GEO.deck(self, "roof_" + id, left, right, back, front, 10, 0)
	box("seawall_" + id, Vector3((left + right) * 0.5, 1.9, (back + front) * 0.5), Vector3(right - left, 16, front - back), Color("53666a"))

func route_hint(_stage: int, _feet: Vector3) -> String:
	return "Five collection slots, either direction around the atrium. Bend the flight around the chimney for 03. Return to Dispatch. B/V/N compare body, view and goal."
