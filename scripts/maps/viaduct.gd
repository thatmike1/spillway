extends Node3D
## a continuous flood-control gantry carrying three offset swing bays.
const GEO := preload("res://scripts/r19_course_geometry.gd")
const RUNNER := preload("res://scripts/movement/grapple_player.gd")
const MAP_ID := "viaduct"
const MAP_ENTRY := {"name": "Viaduct", "theme": "Chain Arc swings beneath the flood-control bridge", "kind": "experiment", "experimental": true,
	"runner": "res://scripts/movement/grapple_player.gd", "script": "res://scripts/maps/viaduct.gd", "reticle": true,
	"key_hint": " · LMB hold / RMB reel / release to transfer", "tether_model": "elastic-arc", "grapple": true,
	"instructions": "Chain the three offset rings. Hold LMB to attach, RMB to reel, release toward the next pale terrace. Lower maintenance court and ramps recover missed swings."}
const V_ANCHORS := [Vector3(4,12,-8), Vector3(8,12,-38), Vector3(-4,12,-68)]
const V_DECKS := [[-7.0,7.0,0.0,18.0], [1.0,15.0,-30.0,-16.0], [-7.0,7.0,-60.0,-46.0], [-30.0,-1.0,-104.0,-74.0]]
const V_HEIGHTS := [4.0,3.0,3.0,2.0]

var level_id := "r22-viaduct"
var level_name := "Viaduct"
var level_version := 1
var variant := MAP_ID
var spawn := Transform3D(Basis.IDENTITY,Vector3(0,4.04,12))
var finish_title := "West abutment"
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
		var pose := spawn if i == 0 else Transform3D(Basis.IDENTITY,Vector3((d[0]+d[1])/2,h+0.04,d[3]-2))
		checkpoints.append({"pose":pose,"title":["Intake","East pier","Central pier","West abutment"][i],"bounds":AABB(Vector3(d[0],h-0.2,d[2]),Vector3(d[1]-d[0],3,d[3]-d[2]))})
		_box("Art_paint_orange_lip_%d" % i,Vector3((d[0]+d[1])/2,h+0.02,d[2]+0.15),Vector3(d[1]-d[0],0.03,0.22),Color("b5683c"))
		var x: float = d[1]+3
		var z: float = d[3]-4
		var top: Array[Vector3] = [Vector3(x-3,h,z),Vector3(x+3,h,z),Vector3(x+3,-5,z+28),Vector3(x-3,-5,z+28)]
		GEO.prism(self,"viaduct_return_%d" % i,top,-5.8,-1,"recovery","recovery")
		GEO.deck(self,"viaduct_return_landing_%d" % i,d[1]-1,x+3,z-4,z,h,-1,"recovery")
	GEO.deck(self,"viaduct_maintenance_court",-36,29,-110,44,-5,-1,"recovery")
	for i: int in 3:
		_viaduct_anchor(i)
	_environment()
	_sign("entry",Vector3(0,7,17),"VIADUCT\nLMB HOLD / RMB REEL / RELEASE",0.006)
	_sign("finish",Vector3(-20,5,-104),"WEST ABUTMENT",0.009)
	routes = {"basic":[spawn.origin,Vector3(8,3,-22),Vector3(0,3,-52),finish_position]}
	routes["advanced"] = routes.basic

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
	ring.material_override = RUNNER._flat(Color("b5683c"))
	anchor.add_child(ring)
	_box("viaduct_crossbeam_%d" % i,at+Vector3(0,1.6,0),Vector3(42,1.2,1.8),Color("40565a"))
	for side: float in [-21.0,21.0]:
		_box("viaduct_pier_%d_%s" % [i,side],Vector3(at.x+side,3.5,at.z),Vector3(2.8,21.4,3.2),Color("566563"))
		_box("viaduct_foot_%d_%s" % [i,side],Vector3(at.x+side,-5.6,at.z),Vector3(5,1.2,7),Color("40565a"))
	_box("viaduct_hanger_%d" % i,at+Vector3(0,0.8,0),Vector3(0.16,1.6,0.16),Color("29464a"))
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

func route_hint(stage: int, _feet: Vector3) -> String:
	return "Aim at bay %d. Hold LMB, reel with RMB, then release toward the pale terrace. Lower court ramps return to the course." % mini(stage+1,3)

func geometry_hash() -> String:
	return JSON.stringify([level_id,level_version,V_ANCHORS,V_DECKS,V_HEIGHTS,manifest,spawn,finish_bounds,kill_bounds],"",false,true).sha256_text()

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

func _sign(id: String, at: Vector3, text: String, pixels: float) -> void:
	var label := Label3D.new()
	label.name = "Sign_" + id
	label.position = at
	label.text = text
	label.font_size = 48
	label.pixel_size = pixels
	label.modulate = Color("263d45")
	label.outline_size = 0
	add_child(label)

static func _v(p: Vector3) -> Array:
	return [p.x, p.y, p.z]

func is_finish_at(feet: Vector3) -> bool:
	return finish_bounds.has_point(feet)
