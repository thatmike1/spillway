extends Node3D
## sluice six: an original tidal settling race for the unchanged f2 course runner.
const GEO := preload("res://scripts/r19_course_geometry.gd")
const ART := preload("res://scripts/art/sluice_six_art.gd")
const LEVEL_ID := "r22-sluice-six"
const LEVEL_NAME := "Sluice Six"
const LEVEL_VERSION := 2
const MAP_ID := "sluice-six"
const MAP_ENTRY := {"name": LEVEL_NAME, "theme": "Tidal settling decks / pier rhythm / spill tower", "kind":"course", "script":"res://scripts/maps/sluice_six.gd"}
var level_id := LEVEL_ID
var level_name := LEVEL_NAME
var level_version := LEVEL_VERSION
var variant := MAP_ID
var spawn := Transform3D(Basis.IDENTITY, Vector3(0, 0.04, 6))
var finish_title := "Spill tower"
var finish_position := Vector3(0, 0, -135)
var finish_radius := 4.0
var finish_bounds := AABB(Vector3(-7,-0.3,-143),Vector3(14,4,10))
var kill_bounds := AABB(Vector3(-36,-4,-180),Vector3(72,70,200))
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
var _built := false

func build() -> void:
	if _built:
		return
	_built = true
	_deck("start", 0, 14, 10, -14, 0)
	# three rooms share one tidal channel: broad, offset, then narrow on the spill approach.
	for i: int in 14:
		var near_z := -16.0 - i * 9.0 if i < 9 else -97.0 - (i - 9) * 6.0
		var width := 12.0 if i < 4 else (9.0 if i < 9 else 3.2512)
		var offset := 1.5 if i < 9 else 0.8
		var x := 0.0 if i < 4 else (offset if i % 2 == 0 else -offset)
		var length := 6.5 if i < 9 else 3.2512
		_deck("pier_%02d" % i, x, width, near_z, near_z - length, mini(2, (i + 1) / 5))
	_deck("tower_court", 0, 16, -127, -147, 3)
	for i: int in range(1, decks.size()):
		var a: Dictionary = decks[i-1]
		var b: Dictionary = decks[i]
		jump_gaps.append({"label":"sluice_%02d" % i,"edge":Vector3(0,0,a.far),"land":Vector3(0,0,b.near),"recovery":"water returns to the last checkpoint"})
	for i: int in [0, 5, 10, 15]:
		var d: Dictionary = decks[i]
		var pose := Transform3D(Basis.IDENTITY, Vector3(d.x,0.04,d.near-1.2))
		if i == 0:
			pose = spawn
		checkpoints.append({"pose":pose,"title":["Settling apron","Offset piers","Spill race","Tower court"][checkpoints.size()],"bounds":AABB(Vector3(d.x-d.width/2,-0.3,d.far),Vector3(d.width,4,d.near-d.far))})
	routes = {"basic":[spawn.origin,Vector3(0,0,-40),Vector3(1.5,0,-70),Vector3(-1.5,0,-110),finish_position],"fast":[spawn.origin,Vector3(0,0,-120),finish_position]}
	ART.dress(self)

func _deck(id: String, x: float, width: float, near_z: float, far_z: float, stage: int) -> void:
	# the piers extend below water, visibly carrying every landing instead of floating slabs.
	GEO.prism(self,id,GEO.rectangle(x-width/2,x+width/2,far_z,near_z,0),-7,stage,"route")
	decks.append({"id":id,"x":x,"width":width,"near":near_z,"far":far_z})
	segment_bounds.append(AABB(Vector3(-20,-2,far_z),Vector3(40,15,near_z-far_z)))

func is_finish_at(feet: Vector3) -> bool:
	return finish_bounds.has_point(feet)
func segment_at(feet: Vector3) -> int:
	if feet.z < -127:
		return 3
	if feet.z < -97:
		return 2
	if feet.z < -52:
		return 1
	return 0
func route_hint(stage: int, _feet: Vector3) -> String:
	return ["Build speed on the apron; hop the broad settling piers.","Follow the offset caps, or keep the direct water-side line.","Narrow spill piers: keep speed and set the next landing early.","Through the open spill tower to the finish."][clampi(stage,0,3)]
func start_wheel() -> void:
	pass
func reset_state() -> void:
	pass
func geometry_hash() -> String:
	var rows: Array = [LEVEL_ID,LEVEL_VERSION,str(spawn),str(finish_bounds),str(kill_bounds),str(checkpoints)]
	for piece: Dictionary in manifest:
		rows.append([piece.name,piece.stage,piece.role,str(piece.points)])
	return JSON.stringify(rows).sha256_text()
