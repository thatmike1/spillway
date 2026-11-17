extends Node3D
## a surveyed tidal basin; pieces are mounted on supported travelling rails.
const GEO := preload("res://scripts/r19_course_geometry.gd")
const LAYOUT := preload("res://scripts/plan/layout.gd")
const PIECES := preload("res://scripts/plan/pieces.gd")
const RUNNER := preload("res://scripts/movement/grapple_player.gd")
const MAP_ID := "plan-yard"
const MAP_ENTRY := {"name": "Plan Yard", "theme": "Place a line, then run it", "kind": "experiment", "experimental": true, "grapple": true, "tether_model": "elastic-arc", "runner": "res://scripts/movement/plan_runner.gd", "script": "res://scripts/maps/plan_yard.gd", "reticle": true, "instructions": "Tab: plan from above. Click up to three surveyed sockets. Enter: run. LMB: Arc rope, RMB: reel. R: retry the same plan.", "key_hint": " · Tab plans; Enter runs"}
var level_id := "r22-plan-yard"
var level_name := "Plan Yard"
var level_version := 7
var spawn := Transform3D(Basis.IDENTITY, Vector3(-4, 3.04, 13))
var finish_title := "Far quay"
var finish_position := Vector3(0, 3, -48)
var finish_radius := 3.0
var finish_bounds := AABB(Vector3(-18, 2.8, -53), Vector3(36, 4, 7))
var kill_bounds := AABB(Vector3(-40, -7, -65), Vector3(80, 60, 100))
var checkpoints: Array[Dictionary] = []
var segment_bounds: Array[AABB] = []
var progress_roles: Array = ["route"]
var water_regions: Array[Dictionary] = []
var water_audio_sources: Array[Vector3] = []
var mechanics: Array = [RUNNER.TETHER_LAW]
var manifest: Array[Dictionary] = []
var prisms: Array[Dictionary] = []
var art_manifest: Array = []
var jump_gaps: Array[Dictionary] = []
var routes := {}
var plan: Array = LAYOUT.DEFAULT.duplicate()
var block_slot := -1
var pad_slot := -1
var budget := 3
var blocks_enabled := false
var pads_enabled := false
var pad_body: StaticBody3D
var pad_bounds := AABB()
var pieces: Node3D
var _built := false
func build() -> void:
	if _built:
		return
	_built = true
	deck("start", -18, 18, 5, 20, 3)
	deck("finish", -18, 18, -55, -34, 3)
	deck("west", -18, -11, -34, 5, 3)
	deck("east", 11, 18, -34, 5, 3)
	deck("caisson_front", -5, 5, -18, -8, 7)
	deck("caisson_rear", -5, 5, -30, -21, 9)
	deck("caisson_foundation", -5, 5, -21, -18, -3)
	checkpoints.append({"pose": spawn, "title": "Choose your line", "bounds": AABB(Vector3(-18, 2.8, 5), Vector3(36, 3, 15))})
	for z: float in [1, -11, -25]:
		box("gantry_beam", Vector3(0, 15, z), Vector3(40, 0.5, 0.6), Color("344e52"))
		for x: float in [-20, 20]:
			box("gantry_column", Vector3(x, 4, z), Vector3(0.7, 22, 0.9), Color("344e52"))
	for x: float in [-12, 0, 12]:
		box("travelling_rail", Vector3(x,15,-12), Vector3(0.3,0.35,34), Color("344e52"))
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("c5d7d5")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("e1e1ce")
	env.environment.ambient_light_energy = 0.65
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -30, 0)
	sun.light_color = Color("fff0d4")
	add_child(sun)
	box("sea", Vector3(0, -4, -18), Vector3(600, 0.1, 600), Color("729c9b"))
	pieces = Node3D.new()
	pieces.name = "PlanPieces"
	add_child(pieces)
	apply_plan(plan)
func deck(id: String, x0: float, x1: float, z0: float, z1: float, height: float) -> void:
	GEO.prism(self, id, GEO.rectangle(x0, x1, z0, z1, height), -5, 0, "route")
	box(id + "_top", Vector3((x0+x1)/2, height+0.01, (z0+z1)/2), Vector3(x1-x0, 0.02, z1-z0), Color("ddd7bd"))
	box(id + "_lip", Vector3((x0+x1)/2, height+0.025, z0+0.1), Vector3(x1-x0, 0.03, 0.16), Color("b66d43"))
func box(id: String, at: Vector3, size: Vector3, color: Color, parent: Node3D = self) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = id
	mesh.position = at
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = RUNNER._flat(color)
	parent.add_child(mesh)
func design() -> Dictionary:
	return {"version": PIECES.VERSION, "anchors": plan.duplicate(), "block": block_slot, "pad": pad_slot,
		"budget":budget, "blocks_enabled":blocks_enabled, "pads_enabled":pads_enabled}
func physical_design() -> Dictionary:
	return {"version": PIECES.VERSION, "anchors":plan.duplicate(), "block":block_slot, "pad":pad_slot}
func apply_plan(next: Array) -> bool:
	return apply_design(next,block_slot,pad_slot,budget,blocks_enabled,pads_enabled)
func apply_design(next: Array, block: int, pad: int, limit: int, blocks_on: bool, pads_on: bool) -> bool:
	if limit not in [1,3] or not LAYOUT.valid(next,limit) or PIECES.count(next,block,pad) > limit:
		return false
	if block != -1 and (not blocks_on or not PIECES.BLOCKS.has(block)):
		return false
	if pad != -1 and (not pads_on or not PIECES.PADS.has(pad)):
		return false
	plan = LAYOUT.canonical(next)
	block_slot = block
	pad_slot = pad
	budget = limit
	blocks_enabled = blocks_on
	pads_enabled = pads_on
	mechanics = [RUNNER.TETHER_LAW,{"id":"plan-yard-design","version":PIECES.VERSION,"design":physical_design()}]
	if pad_slot >= 0:
		mechanics.append({"id":"plan-launch","on":true,"tuning":PIECES.LAUNCH.LAUNCH_LAW})
	if pieces == null:
		return true
	for child: Node in pieces.get_children():
		pieces.remove_child(child)
		child.free()
	pad_body = null
	for index: int in plan:
		var at: Vector3 = LAYOUT.SOCKETS[index]
		var anchor := Node3D.new()
		anchor.name = "PlanAnchor%d" % index
		anchor.position = at
		anchor.set_meta("r21_anchor_id", "plan-yard-socket-%d" % index)
		anchor.set_meta("anchor_name", "Socket %d" % (index+1))
		anchor.add_to_group(RUNNER.ANCHOR_GROUP)
		pieces.add_child(anchor)
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.5
		torus.outer_radius = 0.7
		ring.mesh = torus
		ring.rotation.x = PI/2
		ring.material_override = RUNNER._flat(Color("c17846"))
		anchor.add_child(ring)
		box("hanger", Vector3(at.x, (at.y+15)/2, at.z), Vector3(0.12, 15-at.y, 0.12), Color("344e52"), pieces)
	if block_slot >= 0:
		var top: Vector3 = PIECES.BLOCKS[block_slot]
		_solid_piece("PlanLift",Vector3(top.x,(top.y-5)/2,top.z),Vector3(7,top.y+5,7),Color("687b7b"))
		box("lift_top",top+Vector3.UP*0.012,Vector3(7,0.025,7),Color("ddd7bd"),pieces)
		box("lift_lip",top+Vector3(0,0.03,-3.4),Vector3(7,0.04,0.16),Color("b66d43"),pieces)
	if pad_slot >= 0:
		var at: Vector3 = PIECES.PADS[pad_slot]
		pad_body = _solid_piece("PlanPad",at+Vector3.UP*0.04,Vector3(4,0.08,4),Color("d9d3b8"))
		pad_bounds = AABB(at+Vector3(-2,-0.1,-2),Vector3(4,0.8,4))
		box("pad_lip",at+Vector3(0,0.09,-1.9),Vector3(4,0.03,0.16),Color("b66d43"),pieces)
		var label := Label3D.new()
		label.position = at+Vector3(0,0.1,0)
		label.rotation_degrees.x = -90
		label.text = "LAUNCH\n300+ / FAR QUAY"
		label.font_size = 36
		label.pixel_size = 0.016
		label.modulate = Color("29464a")
		label.outline_size = 0
		pieces.add_child(label)
	return true
func _solid_piece(id: String, at: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = id
	body.set_meta("surface","route")
	body.set_meta("progress_stage",0)
	body.position = at
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	pieces.add_child(body)
	box(id+"_mesh",Vector3.ZERO,size,color,body)
	return body

func is_finish_at(feet: Vector3) -> bool:
	return finish_bounds.has_point(feet)
func route_hint(_stage: int, _feet: Vector3) -> String:
	return "Tab plans at spawn. Left and right quays are safe; the central caisson needs height."
func geometry_hash() -> String:
	return JSON.stringify([level_id, level_version, physical_design(), LAYOUT.SOCKETS, PIECES.BLOCKS, PIECES.PADS, PIECES.LAUNCH.LAUNCH_LAW], "", false, true).sha256_text()
