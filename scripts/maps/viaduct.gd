extends Node3D
## a continuous flood-control gantry carrying three offset swing bays.
const GEO := preload("res://scripts/r19_course_geometry.gd")
const RUNNER := preload("res://scripts/movement/grapple_player.gd")
const MAP_ID := "viaduct"
const MAP_ENTRY := {"name": "Viaduct", "theme": "Link Elastic Arc swings beneath the maintenance bridge", "kind": "experiment", "experimental": true,
	"runner": "res://scripts/movement/grapple_player.gd", "script": "res://scripts/maps/viaduct.gd", "reticle": true,
	"key_hint": " · LMB hold / RMB reel / release to transfer", "tether_model": "elastic-arc", "grapple": true,
	"own_look": true,
	"instructions": "Hold LMB + RMB through the low point. Wait until the pale landing is below you, then release on the rise. Looking away keeps the rope attached. Advanced: ride 03 higher and land on UPPER PIER, then rejoin the west FINISH. Court ramps recover misses.",
	"start_controls": "Aim at 01. Space jumps; LMB holds; RMB reels.\nHold both through the low point; rise above the pale landing before release.\nLook ahead while attached. Court ramps recover misses.\nAdvanced: ride 03 higher and land on UPPER PIER, then rejoin the west FINISH."}
const V_ANCHORS := [Vector3(4,12,-8), Vector3(8,12,-38), Vector3(-4,12,-68)]
const V_DECKS := [[-7.0,7.0,0.0,18.0], [1.0,15.0,-30.0,-16.0], [-7.0,7.0,-60.0,-46.0], [-30.0,-1.0,-104.0,-74.0]]
const V_HEIGHTS := [4.0,3.0,3.0,2.0]
const UPPER_LANDING := AABB(Vector3(-17.4,7.9,-71.4),Vector3(4.8,2.8,6.8))

var level_id := "r22-viaduct"
var level_name := "Viaduct"
var level_version := 6
var variant := MAP_ID
var spawn := Transform3D(Basis.IDENTITY,Vector3(0,4.04,12))
var finish_title := "Viaduct finish"
var finish_position := Vector3(-20,2,-94)
var finish_radius := 3.0
var finish_bounds := AABB(Vector3(-30,1.8,-104),Vector3(29,4,18))
var kill_bounds := AABB(Vector3(-38,-12,-110),Vector3(80,60,160))
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
var routes: Dictionary = {}
var _built := false

func build() -> void:
	if _built:
		return
	_built = true
	for i: int in 4:
		var d: Array = V_DECKS[i]
		var h: float = V_HEIGHTS[i]
		GEO.deck(self,"viaduct_terrace_%d" % i,d[0],d[1],d[2],d[3],h,i)
		if i in [1,2]:
			# the next return enters beneath this terrace; keep a clear four-metre arch.
			var passage_x: float = V_DECKS[i+1][1]+3
			for span: Array in [[d[0]+0.4,passage_x-2],[passage_x+2,d[1]-0.4]]:
				GEO.prism(self,"viaduct_plinth_%d_%s" % [i,span[0]],GEO.rectangle(span[0],span[1],d[2]+0.4,d[3]-0.4,h-0.8),-5.8,-1,"structure","support")
		else:
			GEO.prism(self,"viaduct_plinth_%d" % i,GEO.rectangle(d[0]+0.4,d[1]-0.4,d[2]+0.4,d[3]-0.4,h-0.8),-5.8,-1,"structure","support")
		var pose := spawn if i == 0 else Transform3D(Basis.IDENTITY,Vector3((d[0]+d[1])/2,h+0.04,d[3]-2))
		checkpoints.append({"pose":pose,"title":["Intake","East pier","Central pier","West abutment"][i],"bounds":AABB(Vector3(d[0],h-0.2,d[2]),Vector3(d[1]-d[0],3,d[3]-d[2]))})
		_box("Art_paint_orange_lip_%d" % i,Vector3((d[0]+d[1])/2,h+0.02,d[2]+0.15),Vector3(d[1]-d[0],0.03,0.22),Color("c77642"))
		_box("Art_paint_orange_arrival_%d" % i,Vector3((d[0]+d[1])/2,h+0.025,d[3]-0.12),Vector3(d[1]-d[0],0.035,0.22),Color("c77642"))
		var x: float = d[1]+3
		var z: float = d[3]-4
		var top: Array[Vector3] = [Vector3(x-3,h,z),Vector3(x+3,h,z),Vector3(x+3,-5,z+28),Vector3(x-3,-5,z+28)]
		GEO.prism(self,"viaduct_return_%d" % i,top,-5.8,-1,"recovery","recovery")
		GEO.deck(self,"viaduct_return_landing_%d" % i,d[1]-1,x+3,z-4,z,h,-1,"recovery")
	GEO.deck(self,"viaduct_maintenance_court",-36,29,-110,44,-5,-1,"recovery")
	GEO.prism(self,"viaduct_basin_foundation",GEO.rectangle(-36,29,-110,44,-5.8),-11,-1,"structure","basin-foundation")
	# the inspection pier catches an overswing upstream, outside the existing downstream flight.
	GEO.deck(self,"viaduct_upper_inspection",-18,-12,-72,-64,8,2)
	GEO.prism(self,"viaduct_upper_support",GEO.rectangle(-17.6,-12.4,-71.6,-64.4,7.2),-5.8,-1,"structure","support")
	_box("Art_paint_upper_lip",Vector3(-15,8.02,-71.88),Vector3(6,0.03,0.22),Color("c77642"))
	_box("viaduct_upper_board",Vector3(-15,10,-64.15),Vector3(2.8,1.2,0.16),Color("29464a"))
	for x: float in [-16.1,-13.9]:
		_box("viaduct_upper_signpost_%s" % x,Vector3(x,8.7,-64.15),Vector3(0.08,1.4,0.08),Color("557683"))
	for i: int in 3:
		_viaduct_anchor(i)
	_control_house()
	_environment()
	preload("res://scripts/art/viaduct_look.gd").apply(self)
	_sign("entry",Vector3(0,7,17),"VIADUCT\nLMB HOLD / RMB REEL / RELEASE",0.006)
	_sign("finish",Vector3(-25,8.7,-94.76),"WEST ABUTMENT",0.008,Color("eee8d5"))
	_sign("goal",Vector3(-25,9.7,-94.74),"FINISH",0.018,Color("eee8d5"))
	_sign("upper_front",Vector3(-15,10,-64.05),"UPPER PIER",0.008,Color("eee8d5"))
	_sign("upper_back",Vector3(-15,10,-64.25),"UPPER PIER",0.008,Color("eee8d5"))
	get_node("Sign_upper_back").rotation.y = PI
	routes = {"basic":[spawn.origin,Vector3(8,3,-22),Vector3(0,3,-52),finish_position]}
	routes["advanced"] = [spawn.origin,Vector3(8,3,-22),Vector3(0,3,-52),Vector3(-15,8,-68),finish_position]

func _viaduct_anchor(i: int) -> void:
	var at: Vector3 = V_ANCHORS[i]
	var anchor := Node3D.new()
	anchor.position = at
	anchor.name = "ViaductRing%d" % (i+1)
	anchor.set_meta("r21_anchor_id","viaduct-bay-%d" % (i+1))
	anchor.set_meta("anchor_name","Viaduct bay %d" % (i+1))
	anchor.add_to_group(RUNNER.ANCHOR_GROUP)
	add_child(anchor)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.6
	torus.outer_radius = 0.85
	ring.mesh = torus
	ring.rotation.x = PI/2
	var ring_material := RUNNER._flat(Color("c77642"))
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = ring_material
	anchor.add_child(ring)
	var rim := MeshInstance3D.new()
	var rim_mesh := TorusMesh.new()
	rim_mesh.inner_radius = 0.57
	rim_mesh.outer_radius = 0.91
	rim.mesh = rim_mesh
	rim.rotation.x = PI/2
	rim.position.z = -0.18
	rim.material_override = RUNNER._flat(Color("263d45"))
	anchor.add_child(rim)
	_sign("bay_%d" % i,at+Vector3(0,1.55,1.05),"%02d" % (i+1),0.015,Color("eee8d5"))
	_box("viaduct_crossbeam_%d" % i,at+Vector3(0,1.6,0),Vector3(42,1.2,1.8),Color("40565a"))
	for side: float in [-21.0,21.0]:
		_box("viaduct_pier_%d_%s" % [i,side],Vector3(at.x+side,2.6,at.z),Vector3(2.8,23.2,3.2),Color("566563"))
		_box("viaduct_foot_%d_%s" % [i,side],Vector3(at.x+side,-7.25,at.z),Vector3(5,4.5,7),Color("40565a"))
		# the post front is z+1.6; plates and bolt heads must stand outside that face.
		_box("viaduct_joint_%d_%s" % [i,side],at+Vector3(side,1.6,1.69),Vector3(3.5,1.5,0.16),Color("879ba0"))
		for bolt_x: float in [-1.2,1.2]:
			for bolt_y: float in [1.15,2.05]:
				_box("viaduct_fastener_%d_%s_%s_%s" % [i,side,bolt_x,bolt_y],at+Vector3(side+bolt_x,bolt_y,1.83),Vector3(0.16,0.16,0.10),Color("c0c2b0"))
	_box("viaduct_hanger_%d" % i,at+Vector3(0,1.05,0),Vector3(0.32,1.1,0.5),Color("aab0a3"))
	_box("viaduct_clevis_pin_%d" % i,at+Vector3(0,0.7,0.15),Vector3(0.65,0.14,0.62),Color("738280"))
	if i < 2:
		var next: Vector3 = V_ANCHORS[i+1]+Vector3(0,2.5,0)
		var here := at+Vector3(0,2.5,0)
		for side: float in [-19.0,19.0]:
			var beam := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(1,1.4,here.distance_to(next)+2)
			beam.mesh = box
			beam.position = (here+next)/2+Vector3(side,0,0)
			beam.rotation.y = atan2(next.x-here.x,next.z-here.z)
			beam.material_override = RUNNER._flat(Color("40565a"))
			add_child(beam)

func _control_house() -> void:
	# the house stands on the existing abutment; its wall is beyond the finish approach.
	GEO.prism(self,"viaduct_control_house",GEO.rectangle(-29,-21,-103,-95,13),2,-1,"structure","building")
	_box("viaduct_house_panel",Vector3(-25,6.2,-94.94),Vector3(7.1,7.6,0.08),Color("59777d"))
	_box("viaduct_house_window",Vector3(-25,11.3,-94.92),Vector3(6.5,1.8,0.10),Color("293f47"))
	for x: float in [-27.2,-25.0,-22.8]:
		_box("viaduct_house_mullion_%s" % x,Vector3(x,11.3,-94.84),Vector3(0.10,1.9,0.12),Color("aab0a3"))
	_box("viaduct_house_door",Vector3(-22.8,3.4,-94.85),Vector3(1.2,2.6,0.10),Color("354c54"))
	_box("viaduct_house_handle",Vector3(-22.4,3.3,-94.76),Vector3(0.06,0.4,0.06),Color("b8b5a5"))
	for x: float in [-29.1,-20.9]:
		_box("viaduct_house_coping_x_%s" % x,Vector3(x,13.04,-99),Vector3(0.16,0.10,8.4),Color("c77642"))
	for z: float in [-103.1,-94.9]:
		_box("viaduct_house_coping_z_%s" % z,Vector3(-25,13.04,z),Vector3(8.4,0.10,0.16),Color("c77642"))

func route_hint(stage: int, feet: Vector3) -> String:
	if stage >= 3:
		return "Cross the west abutment to finish. Missed the landing? The lower court and return ramps remain open."
	if stage == 2:
		if UPPER_LANDING.has_point(feet):
			return "Upper pier: settle on the pale top, then run across the pier and drop toward the west FINISH house."
		return "Bay 3: release toward the west abutment, or ride higher onto the upper inspection pier, then rejoin the west FINISH."
	return "Bay %d: LMB + RMB through the low point. Keep reeling until the pale top is below you; release on the rise toward it. Look ahead while attached." % mini(stage+1,3)

func geometry_hash() -> String:
	var data: Array = [level_id,level_version,MAP_ID,V_DECKS,V_HEIGHTS,progress_roles]
	for i: int in V_ANCHORS.size():
		data.append(["viaduct-bay-%d" % (i+1),_v(V_ANCHORS[i])])
	for piece: Dictionary in manifest:
		var points: Array = []
		for point: Vector3 in piece.points:
			points.append(_v(point))
		data.append([piece.name,piece.stage,piece.role,piece.kind,points])
	for checkpoint: Dictionary in checkpoints:
		data.append([checkpoint.title,_v(checkpoint.pose.origin),_v(checkpoint.bounds.position),_v(checkpoint.bounds.size)])
	data.append([_v(spawn.origin),_v(spawn.basis.x),_v(spawn.basis.y),_v(spawn.basis.z),_v(finish_position),finish_radius,_v(finish_bounds.position),_v(finish_bounds.size),_v(kill_bounds.position),_v(kill_bounds.size),_v(UPPER_LANDING.position),_v(UPPER_LANDING.size)])
	return JSON.stringify(data,"",false,true).sha256_text()

func _environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("b7cacc")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("bdd0ce")
	env.ambient_light_energy = 0.5
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -110, 0)
	sun.light_color = Color("fff0d2")
	sun.light_energy = 0.7
	add_child(sun)
	_box("Water", Vector3(0, -8, -40), Vector3(600, 0.05, 600), Color("789f9c"))

func _box(id: String, at: Vector3, size: Vector3, color: Color) -> void:
	art_manifest.append([id, _v(at), _v(size), color.to_html()])
	var node := MeshInstance3D.new()
	node.name = id
	node.position = at
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = RUNNER._flat(color)
	add_child(node)

func _sign(id: String, at: Vector3, text: String, pixels: float, color: Color = Color("263d45")) -> void:
	var label := Label3D.new()
	label.name = "Sign_" + id
	label.position = at
	label.text = text
	label.font_size = 48
	label.pixel_size = pixels
	label.modulate = color
	label.outline_size = 0
	add_child(label)

static func _v(p: Vector3) -> Array:
	return [p.x, p.y, p.z]

func is_finish_at(feet: Vector3) -> bool:
	return finish_bounds.has_point(feet)
