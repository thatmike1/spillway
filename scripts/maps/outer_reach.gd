extends Node3D
## outer reach: an original long-strafe course beside the estuary works, using unchanged f2.
const GEO := preload("res://scripts/r19_course_geometry.gd")
const ART := preload("res://scripts/art/outer_reach_art.gd")
const LEVEL_ID := "r22-outer-reach"
const LEVEL_NAME := "Outer Reach"
const LEVEL_VERSION := 4
const MAP_ID := "outer-reach"
const MAP_ENTRY := {"name": LEVEL_NAME, "theme": "Outer estuary / long air corridors / tidal pump", "kind":"course", "own_look":true, "script":"res://scripts/maps/outer_reach.gd"}
var level_id := LEVEL_ID
var level_name := LEVEL_NAME
var level_version := LEVEL_VERSION
var variant := MAP_ID
var spawn := Transform3D(Basis.IDENTITY, Vector3(-220, 0.04, 6))
var finish_title := "Tidal pump"
var finish_position := Vector3(-220, 0, -199)
var finish_radius := 4.0
var finish_bounds := AABB(Vector3(-229,-0.3,-207),Vector3(18,4,10))
var kill_bounds := AABB(Vector3(-260,-4,-240),Vector3(140,70,260))
var checkpoints: Array[Dictionary] = []
var segment_bounds: Array[AABB] = []
var water_regions: Array[Dictionary] = []
var water_audio_sources: Array[Vector3] = []
var progress_roles := ["route"]
var manifest: Array[Dictionary] = []
var prisms: Array[Dictionary] = []
var jump_gaps: Array[Dictionary] = []
var routes: Dictionary = {}
var decks: Array[Dictionary] = []
var supports: Array[Vector4] = []
var style_opportunities: Array[Dictionary] = []
var _built := false

func build() -> void:
	if _built:
		return
	_built = true
	_deck("start", -220, 18, 10, -55, 0)
	# receiver windows follow measured legal f2 air arcs, not a copied community layout.
	var centres: Array[float] = [-66.5,-81.6,-97.7,-114.4,-132.3,-151.0,-170.3]
	for i: int in centres.size():
		_deck("receiver_%02d" % i,-220,12,centres[i]+2.0,centres[i]-2.0,1 if i<2 else 2)
	_deck("pump_court",-220,20,-188.3,-211.0,3)
	for i: int in range(1,decks.size()):
		var a: Dictionary = decks[i-1]
		var b: Dictionary = decks[i]
		jump_gaps.append({"label":"reach_%02d" % i,"edge":Vector3(-220,0,a.far),"land":Vector3(-220,0,b.near),"recovery":"water returns to the last checkpoint"})
	for i: int in [0,8]:
		var d: Dictionary = decks[i]
		var pose := Transform3D(Basis.IDENTITY,Vector3(d.x,0.04,d.near-1.2))
		if i==0:
			pose=spawn
		checkpoints.append({"pose":pose,"title":["Acceleration quay","Pump court"][checkpoints.size()],"bounds":AABB(Vector3(d.x-d.width/2,-0.3,d.far),Vector3(d.width,4,d.near-d.far))})
	routes={"basic":[spawn.origin,finish_position]}
	# a supported service connection ties the pump station into the actual estuary bank.
	GEO.prism(self,"shore_foundation",GEO.rectangle(-212,-194,-221,-193,1),-7,-1,"obstacle","support")
	GEO.prism(self,"control_house",GEO.rectangle(-207,-193,-217,-197,13),1,-1,"obstacle","service")
	GEO.prism(self,"shore_causeway",GEO.rectangle(-195,-148,-214,-200,1),-7,-1,"obstacle","support")
	GEO.prism(self,"service_gallery",GEO.rectangle(-214,-207,-208.5,-205.5,7),6.6,-1,"obstacle","service")
	GEO.prism(self,"shore_gate",GEO.rectangle(-148.3,-148,-214,-200,4.6),1,-1,"obstacle","service")
	# low quay curbs leave the full centre run-up open.
	for side: int in [-1,1]:
		var edge_x := -220.0+side*8.9
		GEO.prism(self,"quay_curb_%s" % side,GEO.rectangle(edge_x-0.10,edge_x+0.10,-54.8,9.8,0.18),0,-1,"obstacle","support")
	# the pump portal has solid piers and crossmembers, not walk-through scenery.
	for side: int in [-1,1]:
		var pier_x := -220.0+side*8.0
		GEO.prism(self,"pump_pier_%s" % side,GEO.rectangle(pier_x-1,pier_x+1,-212,-202,23),-7,-1,"obstacle","support")
	GEO.prism(self,"pump_crosshead",GEO.rectangle(-229,-211,-212,-202,20.5),17.5,-1,"obstacle","support")
	GEO.prism(self,"pump_bed",GEO.rectangle(-227,-213,-210,-204,7.7),7.1,-1,"obstacle","support")
	ART.dress(self)

func _deck(id: String, x: float, width: float, near_z: float, far_z: float, stage: int) -> void:
	# aprons are quay plinths; each race cap rests on transverse beams and waterline piles.
	var top := GEO.rectangle(x-width/2,x+width/2,far_z,near_z,0)
	# support progress uses checkpoint indices; physical sections are reported separately.
	var checkpoint_stage := 1 if id == "pump_court" else 0
	if id in ["start","pump_court"]:
		GEO.prism(self,id,top,-7,checkpoint_stage,"route")
		supports.append(Vector4(x,(near_z+far_z)*0.5,width*0.5,(near_z-far_z)*0.5))
	else:
		GEO.prism(self,id,top,-0.5,checkpoint_stage,"route")
		var columns: Array[float] = []
		if width < 4.0:
			columns.append(x)
		else:
			columns.append(x-width*0.5+0.9)
			columns.append(x+width*0.5-0.9)
		for row: int in 2:
			var z := near_z-0.85 if row == 0 else far_z+0.85
			GEO.prism(self,id+"_beam_%d" % row,GEO.rectangle(x-width*0.5+0.2,x+width*0.5-0.2,z-0.5,z+0.5,-0.5),-1.0,-1,"support","support")
			for col: int in columns.size():
				var px: float = columns[col]
				GEO.prism(self,id+"_pile_%d_%d" % [row,col],GEO.rectangle(px-0.4,px+0.4,z-0.4,z+0.4,-0.5),-7,-1,"support","support")
				supports.append(Vector4(px,z,0.4,0.4))
	decks.append({"id":id,"x":x,"width":width,"near":near_z,"far":far_z,"stage":stage})
	segment_bounds.append(AABB(Vector3(-240,-2,far_z),Vector3(40,15,near_z-far_z)))

func is_finish_at(feet: Vector3) -> bool:
	return finish_bounds.has_point(feet)
func segment_at(feet: Vector3) -> int:
	if feet.z < -188.3:
		return 3
	if feet.z < -95.7:
		return 2
	if feet.z < -64.5:
		return 1
	return 0
func route_hint(stage: int, _feet: Vector3) -> String:
	return ["Use the acceleration quay to earn speed with F2 air strafes before the first reach.","Release W in the air; carry speed across the broad receivers.","Longer water gaps reward sustained speed and an early landing plan.","Finish on the tidal pump court."][clampi(segment_at(_feet),0,3)]
func start_wheel() -> void:
	pass
func reset_state() -> void:
	pass
func geometry_hash() -> String:
	var rows: Array = [LEVEL_ID,LEVEL_VERSION,str(spawn),str(finish_bounds),str(kill_bounds),str(checkpoints)]
	for piece: Dictionary in manifest:
		rows.append([piece.name,piece.stage,piece.role,str(piece.points)])
	return JSON.stringify(rows).sha256_text()
