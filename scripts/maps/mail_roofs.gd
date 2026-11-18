extends "res://scripts/maps/mail_run.gd"
## a connected postal roof quarter around a tidal atrium, with an unordered five-slot loop.
const ROOF_MATERIAL := preload("res://scripts/art/mail_roof_material.gd")
const ROOF_ID := "mail-roofs"
const ROOF_ENTRY := {"name": "Mail Roofs", "theme": "Five slots. Your order.", "kind": "experiment", "experimental": true, "mail_delivery": true,
	"runner": "res://scripts/movement/mail_roofs_runner.gd", "script": "res://scripts/maps/mail_roofs.gd", "reticle": true,
	"instructions": "F2 bhop. Required goal: all five slots in any order, then Dispatch. Optional goal: reach Dispatch without mail. LMB throws, mouse steers, RMB recalls. 03: throw close to the window; pass the chimney, then left. V view, B body, N goal; changes restart."}

func _init() -> void:
	level_id = "r22-mail-roofs"
	level_name = "Mail Roofs"
	level_version = 6
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
		box("post_house_%d" % i, at + Vector3(0, -7.5, -0.9), Vector3(5.4, 20, 2), Color("53666a"))
		box("post_crown_%d" % i, at + Vector3(0, 2.6, -0.9), Vector3(6.4, 0.35, 2.4), Color("ded8c2"))
		box("opening_%d" % i, at + Vector3(0, 0, 0.15), Vector3(2.5, 1.8, 0.12), Color("172d32"))
		for edge: int in [-1, 1]:
			box("jamb_%d_%d" % [i, edge], at + Vector3(edge * 1.25, 0, 0.24), Vector3(0.12, 1.8, 0.2), Color("ded8c2"))
		box("sill_%d" % i, at + Vector3(0, -0.85, 0.24), Vector3(2.6, 0.12, 0.25), Color("bc713e"))
		box("number_board_%d" % i, at + Vector3(0, 1.7, 0.25), Vector3(2.3, 1.2, 0.12), Color("ded8c2"))
		label("number_%d" % i, at + Vector3(0, 1.7, 0.33), "%02d" % (i + 1), 0.022)
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
	box("window_number_board", Vector3(6, 14.3, -65.55), Vector3(3.6, 2.6, 0.1), Color("ded8c2"))
	for side: int in [-1, 1]:
		box("window_jamb_%d" % side, Vector3(6 + side * 0.9, 12, -65.5), Vector3(0.14, 1.14, 0.16), Color("ded8c2"))
	label("window_number", Vector3(6, 14.8, -65.4), "03", 0.025)
	label("window_cue", Vector3(6, 13.6, -65.4), "PASS CHIMNEY\nTHEN LEFT", 0.008)
	# this founded chimney occludes the direct flight from the east approach to slot 03.
	box("post_chimney", Vector3(3, 8, -70), Vector3(3.2, 24, 3), Color("53666a"))
	box("post_chimney_cap", Vector3(3, 20.1, -70), Vector3(3.8, 0.35, 3.6), Color("ded8c2"))
	box("flue_dark", Vector3(3, 20.29, -70), Vector3(2.4, 0.03, 2.2), Color("172d32"))
	# one continuous wharf and its crane give the western sea edge a working-waterfront context.
	box("post_harbour_wharf", Vector3(-78, -3, -28), Vector3(18, 6, 136), Color("53666a"))
	box("post_harbour_store", Vector3(-81, 2, -28), Vector3(12, 10, 94), Color("53666a"))
	box("harbour_store_roof", Vector3(-81, 7.15, -28), Vector3(13, 0.3, 95), Color("aaa897"))
	for z: float in [-68, -35]:
		box("post_harbour_crane_pier_%s" % z, Vector3(-72, 8, z), Vector3(1.1, 18, 1.1), Color("53666a"))
	box("post_harbour_crane_beam", Vector3(-72, 17, -51.5), Vector3(1.8, 1.4, 35), Color("53666a"))
	box("harbour_quay_edge", Vector3(-68.8, 0.12, -28), Vector3(0.3, 0.24, 136), Color("ded8c2"))
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
	box("bell_hanger", Vector3(0, 34.3, -85), Vector3(0.2, 3.2, 0.2), Color("aaa897"))
	for side: int in [-1, 1]:
		for z: int in range(-60, 12, 8):
			box("facade_pier_%s_%s" % [side, z], Vector3(side * 10, 1, z), Vector3(0.5, 17, 0.7), Color("aaa897"))
		box("cornice_%s" % side, Vector3(side * 10, 8.9, -32), Vector3(0.7, 0.45, 48), Color("ded8c2"))
	box("post_dispatch_hall", Vector3(-7, 3.4, 18.5), Vector3(14, 18.8, 3), Color("53666a"))
	box("dispatch_door", Vector3(-7, 11.25, 16.94), Vector3(3.2, 2.5, 0.10), Color("172d32"))
	box("dispatch_board", Vector3(-7, 13.2, 16.8), Vector3(6, 1, 0.15), Color("ded8c2"))
	box("dispatch_upper", Vector3(-7, 14.15, 18.5), Vector3(14, 2.7, 3), Color("53666a"))
	get_node("Mail_dispatch_upper").material_override = ROOF_MATERIAL.concrete(Color("53666a"))
	box("dispatch_canopy", Vector3(-7, 14.5, 16), Vector3(8, 0.3, 3), Color("ded8c2"))
	box("dispatch_canopy_lip", Vector3(-7, 14.6, 14.45), Vector3(8.1, 0.1, 0.12), Color("bc713e"))
	for x: float in [-9.8, -4.2]:
		box("dispatch_bracket_%s" % x, Vector3(x, 14.05, 16.7), Vector3(0.25, 0.6, 1.8), Color("aaa897"))
	for x: float in [-12, -2]:
		box("dispatch_window_frame_%s" % x, Vector3(x, 11.6, 16.91), Vector3(2.4, 1.8, 0.15), Color("aaa897"))
		box("dispatch_window_glass_%s" % x, Vector3(x, 11.6, 16.8), Vector3(1.95, 1.35, 0.08), Color("718987"))
	box("dispatch_lamp", Vector3(-7, 14.29, 15.8), Vector3(0.7, 0.12, 0.4), Color("ded8c2"))
	_local_light(Vector3(-7, 14, 15.6), 0.55, 7)
	label("dispatch", Vector3(-7, 13.2, 16.68), "DISPATCH", 0.015, PI)
	for side: int in [-1, 1]:
		box("post_gallery_%s" % side, Vector3(side * 21.5, 5.25, -23), Vector3(3, 18.5, 48), Color("53666a"))
		box("gallery_cornice_%s" % side, Vector3(side * 21.5, 14.6, -23), Vector3(3.4, 0.3, 48), Color("ded8c2"))
		for z: int in range(-44, 1, 4):
			if side == -1 and z == -12:
				continue
			box("gallery_window_%s_%s" % [side, z], Vector3(side * 19.96, 12, z), Vector3(0.08, 1.35, 1.5), Color("29464a"))
	for side: int in [-1, 1]:
		box("dispatch_jamb_%d" % side, Vector3(-7 + side * 1.75, 11.3, 16.78), Vector3(0.17, 2.6, 0.24), Color("aaa897"))
	box("dispatch_lintel", Vector3(-7, 12.6, 16.78), Vector3(3.65, 0.17, 0.24), Color("aaa897"))
	# one service entrance gives the later gallery a functional distinction at running eye height.
	box("service_door", Vector3(-19.94, 11.8, -12), Vector3(0.08, 3.6, 4), Color("52666a"))
	box("service_glazing", Vector3(-19.89, 12.7, -12), Vector3(0.06, 1.2, 3.6), Color("81948f"))
	box("service_seam", Vector3(-19.84, 11.8, -12), Vector3(0.04, 3.3, 0.06), Color("aaa897"))
	for z: float in [-14.1, -9.9]:
		box("service_jamb_%s" % z, Vector3(-19.83, 11.8, z), Vector3(0.35, 3.6, 0.18), Color("aaa897"))
	box("service_lintel", Vector3(-19.83, 13.65, -12), Vector3(0.4, 0.2, 4.5), Color("aaa897"))
	box("service_threshold", Vector3(-19.83, 10.08, -12), Vector3(0.4, 0.12, 4.5), Color("aaa897"))
	box("service_canopy", Vector3(-19.75, 13.82, -12), Vector3(1, 0.2, 4.8), Color("ded8c2"))
	# a supported roof lantern identifies the later sorting gallery without adding route clutter.
	for side: int in [-1, 1]:
		var outside := -21.5 + side * 1.5
		GEO.prism(self, "lantern_%d" % side, [Vector3(outside, 15.2, -30), Vector3(outside, 15.2, -18), Vector3(-21.5, 17, -18), Vector3(-21.5, 17, -30)], 14.5, 0, "architecture", "lantern")
		var roof := get_node("Mesh_lantern_lantern_%d" % side) as MeshInstance3D
		roof.name = "Mail_lantern_%d" % side
		roof.material_override = ROOF_MATERIAL.concrete(Color("53666a"), true)
	for z: int in range(-44, 1, 4):
		box("gallery_mullion_%d" % z, Vector3(-19.89, 12, z), Vector3(0.04, 1.35, 0.07), Color("29464a"))
	for z: int in [-44, -28, -12]:
		box("gallery_lamp_back_%d" % z, Vector3(-19.9, 13.8, z), Vector3(0.2, 0.45, 0.35), Color("29464a"))
		box("gallery_lamp_lens_%d" % z, Vector3(-19.74, 13.7, z), Vector3(0.12, 0.12, 0.3), Color("ded8c2"))
		_local_light(Vector3(-19.5, 13.4, z), 0.35, 8)
	box("chamber_light_mount", Vector3(3, 15.6, -70), Vector3(0.8, 0.15, 0.45), Color("ded8c2"))
	_local_light(Vector3(3, 14.8, -70), 0.8, 8)
	box("post_tower_link", Vector3(0, 15.7, -79.5), Vector3(5, 0.6, 3), Color("ded8c2"))
	for mesh: MeshInstance3D in find_children("Mesh_deck_*", "MeshInstance3D", true, false):
		mesh.name = "Mail_roof_" + str(mesh.name)
		mesh.material_override = ROOF_MATERIAL.concrete(Color("53666a"), true)
	for pattern: String in ["Mail_post_*", "Mail_seawall_*"]:
		for mesh: MeshInstance3D in find_children(pattern, "MeshInstance3D", true, false):
			mesh.material_override = ROOF_MATERIAL.concrete(Color("53666a"))
	for id: String in ["post_tower", "post_bell_pier_-3.6", "post_bell_pier_3.6", "post_bell_roof"]:
		var mesh := get_node_or_null("Mail_" + id) as MeshInstance3D
		if mesh != null:
			mesh.material_override = ROOF_MATERIAL.concrete(Color("aaa897"))
	for i: int in 5:
		get_node("Mail_post_house_%d" % i).material_override = ROOF_MATERIAL.concrete(Color("64736f"))
	for pair: Array in [["post_chamber_west", "6e7b78"], ["post_chamber_east", "617774"], ["post_chamber_roof", "90988b"], ["post_chimney", "7d8278"]]:
		get_node("Mail_" + str(pair[0])).material_override = ROOF_MATERIAL.concrete(Color(str(pair[1])))
	_environment()
	routes = {"basic": [spawn.origin, Vector3(15, 10, 0), Vector3(15, 10, -50), Vector3(0, 10, -59), Vector3(-15, 10, -50), Vector3(-15, 10, 0), finish_position]}

func _roof(id: String, left: float, right: float, back: float, front: float) -> void:
	GEO.deck(self, "roof_" + id, left, right, back, front, 10, 0)
	box("seawall_" + id, Vector3((left + right) * 0.5, 1.9, (back + front) * 0.5), Vector3(right - left, 16, front - back), Color("53666a"))

func route_hint(_stage: int, _feet: Vector3) -> String:
	return "Five collection slots, either direction around the atrium. For 03, throw near the window; pass the chimney, then turn left. Return to Dispatch. B/V/N compare body, view and goal."

func _local_light(at: Vector3, energy: float, distance: float) -> void:
	var lamp := OmniLight3D.new()
	lamp.position = at
	lamp.light_color = Color("fff0cf")
	lamp.light_energy = energy
	lamp.omni_range = distance
	add_child(lamp)
