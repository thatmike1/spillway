extends "res://scripts/maps/gantry.gd"
## a distinct longer course preserves Gantry's accepted two-slot finish and physical prefix.
const CHAIN_ID := "gantry-chain"
const CHAIN_ENTRY := {"name": "Gantry Chain", "theme": "Carry the dispatch hops straight into a third Arc transfer", "kind": "experiment",
	"experimental": true, "runner": "res://scripts/movement/grapple_player.gd", "script": "res://scripts/maps/gantry_chain.gd",
	"reticle": true, "grapple": true, "own_look": true, "tether_model": "elastic-arc", "key_hint": " · Space hops · LMB swing · RMB reel",
	"instructions": "The original two transfers continue through dispatch into a third, longer water slot. Carry the final hops directly into the high-speed swing. LMB attaches, RMB reels, release onto the outer apron."}
const THIRD_ANCHOR := Vector3(0, 22, -110)
var _chain_built := false

func _init() -> void:
	level_id = "r22-gantry-chain"
	level_name = "Gantry Chain"
	level_version = 1
	variant = CHAIN_ID
	finish_title = "Outer dispatch"
	finish_position = Vector3(0, 4, -169)
	finish_bounds = AABB(Vector3(-8, 3.8, -174), Vector3(16, 3, 8))
	kill_bounds = AABB(Vector3(-90, -5, -215), Vector3(180, 65, 255))

func build() -> void:
	if _chain_built:
		return
	super.build()
	_chain_built = true
	var far := -174.0
	var near := -136.0
	var court_near := far + 3 * (HOP_PAD + HOP_GAP)
	var apron_far := court_near + 4 * (HOP_PAD + HOP_GAP)
	_pad(3, -1, -HALF_WIDTH, HALF_WIDTH, apron_far, near)
	var edge := apron_far - HOP_GAP
	for i: int in 4:
		_pad(3, i, -HALF_WIDTH, HALF_WIDTH, edge - HOP_PAD, edge)
		jump_gaps.append({"label": "gantry-chain-hop-%d" % i, "edge": Vector3(0, 4, edge + HOP_GAP), "land": Vector3(0, 4, edge), "recovery": "restart or checkpoint"})
		edge -= HOP_PAD + HOP_GAP
	for x: float in [-13, 13]:
		GEO.prism(self, "chain_quay_%s" % x, GEO.rectangle(x - 2.5, x + 2.5, -178, -111, 3.9), -5, -1, "structure")
		# the shared hall quay already supplies these exact visual faces; retain only this collider.
		get_child(get_child_count() - 1).visible = false
		_box("Art_chain_rail_%s" % x, Vector3(x, 4.1, -144.5), Vector3(0.18, 0.17, 67), Color("263d45"))
	_anchor(2, THIRD_ANCHOR)
	for i: int in 3:
		var anchor := get_node("Anchor_%d" % (i + 1))
		anchor.set_meta("r21_anchor_id", "gantry-chain-slot-%d" % (i + 1))
		anchor.set_meta("anchor_name", "Gantry Chain slot %d" % (i + 1))
	for x: float in [-13, 13]:
		GEO.prism(self, "chain_gantry_foot_%s" % x, GEO.rectangle(x - 0.85, x + 0.85, THIRD_ANCHOR.z - 0.85, THIRD_ANCHOR.z + 0.85, 4.04), 3.8, -1, "structure", "gantry_bearing")
	var concrete: Material = get_node("Mesh_deck_apron_0_pad_-1").material_override
	var metal: Material = get_node("Mesh_gantry_bearing_bearing_0_-1").material_override
	for pad: Dictionary in hop_pads:
		if pad.stage != 3:
			continue
		GEO.prism(self, "chain_bearing_%d" % pad.index, GEO.rectangle(-13.4, 13.4, pad.far + 0.15, pad.near - 0.15, 3.15), 2.55, -1, "structure", "gantry_bearing")
		get_node("Mesh_deck_apron_3_pad_%d" % pad.index).material_override = concrete
		get_node("Mesh_gantry_bearing_chain_bearing_%d" % pad.index).material_override = metal
		for x: float in [-HALF_WIDTH, HALF_WIDTH]:
			_box("Art_chain_ink_%s_%d" % [x, pad.index], Vector3(x, 4.016, (pad.far + pad.near) * 0.5), Vector3(0.035, 0.018, pad.near - pad.far), Color("405358"))
	_box("Art_chain_receiver", Vector3(0, 4.009, near - 0.2), Vector3(HALF_WIDTH * 2, 0.012, 0.45), Color("cf7746"))
	_box("Art_chain_receiver_face", Vector3(0, 3.85, near + 0.015), Vector3(HALF_WIDTH * 2, 0.28, 0.025), Color("cf7746"))
	var orange: Material = get_node("Art_paint_orange_receiver_1").material_override
	get_node("Art_chain_receiver").material_override = orange
	get_node("Art_chain_receiver_face").material_override = orange
	_box("Art_chain_takeoff", Vector3(0, 4.025, far + 0.12), Vector3(HALF_WIDTH * 2, 0.035, 0.20), Color("b5683c"))
	DRYDOCK.receiving_frame(self, near, 3)
	get_node("Sign_dispatch").text = "TRANSFER 03"
	ARRIVAL.sign_panel(self, -108, 2)
	_sign("outer_dispatch", Vector3(0, 7, far), "OUTER DISPATCH", 0.010)
	ARRIVAL.build(self, -205, court_near, 3, -166)
	# the physical court replaces the distant scenery apron; avoid two coplanar floors.
	get_node("Art_drydock_hall_apron").visible = false
	checkpoints[2].title = "Third transfer takeoff"
	checkpoints.append({"pose": Transform3D(Basis.IDENTITY, Vector3(0, 4.04, near - 3)), "title": "Outer receiver", "bounds": AABB(Vector3(-HALF_WIDTH, 3.8, far), Vector3(HALF_WIDTH * 2, 2, near - far))})
	jump_gaps.append({"label": "gantry-chain-slot-3", "edge": Vector3(0, 4, -108), "land": Vector3(0, 4, near), "recovery": "restart or checkpoint"})
	routes.basic = [spawn.origin, Vector3(0, 4, -10), Vector3(0, 4, -40), Vector3(0, 4, -58), Vector3(0, 4, -90), Vector3(0, 4, -106), Vector3(0, 4, -145), finish_position]
	routes.advanced = routes.basic
	ART.ink(self)

func route_hint(stage: int, feet: Vector3) -> String:
	if stage == 2:
		return "Carry the dispatch hops into ring 3. Hold LMB and reel, then release onto the outer apron."
	return "Keep hopping to outer dispatch." if stage > 2 else super.route_hint(stage, feet)

func geometry_hash() -> String:
	return JSON.stringify([super.geometry_hash(), CHAIN_ID, level_version, _v(THIRD_ANCHOR), "gantry-chain-slot-1/2/3"], "", false, true).sha256_text()
