extends "res://scripts/maps/tether_yard.gd"
## a crane hall with a continuous wall route and a released swing across its shaft.
const FOUNDRY_ART := preload("res://scripts/art/foundry_hall.gd")
const FOUNDRY_ID := "foundry"
const FOUNDRY_ENTRY := {"name": "Foundry", "theme": "High gallery or committed shaft crossing", "kind": "experiment", "experimental": true, "own_look": true,
	"runner": "res://scripts/movement/grapple_player.gd", "script": "res://scripts/maps/foundry.gd", "reticle": true,
	"grapple": true, "tether_model": "elastic-arc", "key_hint": " · LMB swing / RMB reel",
	"instructions": "Gallery left is continuous. The shaft is the shorter released swing; the lower court and ramps recover misses."}
const FOUNDRY_ANCHORS := [Vector3(0, 29, -8), Vector3(-16, 25, -12), Vector3(0, 21, -44)]

func _init() -> void:
	level_id = "r22-foundry"
	level_name = "Foundry"
	level_version = 4
	variant = FOUNDRY_ID
	spawn = Transform3D(Basis.IDENTITY, Vector3(0, 18.04, 12))
	finish_title = "Tailrace"
	finish_position = Vector3(0, 2, -70)
	finish_bounds = AABB(Vector3(-9, 1.8, -76), Vector3(18, 4, 8))
	kill_bounds = AABB(Vector3(-40, -14, -90), Vector3(80, 70, 130))

func build() -> void:
	if _built:
		return
	_built = true
	GEO.deck(self, "entry_back", -22, 10, 8, 24, 18, 0)
	GEO.deck(self, "gallery_apron", -22, -9, 0, 8, 18, 0)
	GEO.deck(self, "shaft_apron", -3, 10, 0, 8, 18, 0)
	GEO.deck(self, "front_crosswalk", -12, 1, 0, 3, 18, 0)
	_ramp("wall_gallery", -22, -10, 0, -24, 18, 12, 0)
	GEO.deck(self, "rejoin_near", -22, 10, -28, -20, 12, 1)
	GEO.deck(self, "rejoin_exit", -22, 1, -36, -28, 12, 1)
	GEO.deck(self, "tailrace", -10, 10, -78, -50, 2, 2)
	GEO.deck(self, "catch_court", -32, 28, -82, 26, -8, -1, "recovery")
	_ramp("return_ramp", -27, -23, -78, 18, -8, 18, -1)
	GEO.deck(self, "return_bridge", -32, -20, 18, 24, 18, -1, "recovery")
	# a lower continuous spill ledge offers an accessible finish after a missed final catch.
	_ramp("tailrace_recovery", 14, 24, -24, -68, -8, 2, -1)
	GEO.deck(self, "tailrace_bridge", 7, 24, -78, -68, 2, -1, "recovery")
	for row: Array in [[spawn.origin, "Crane gallery", AABB(Vector3(-22,17.8,0),Vector3(32,3,18))],
		[Vector3(0,12.04,-28), "Shaft crossing", AABB(Vector3(-22,11.8,-36),Vector3(32,3,16))],
		[Vector3(0,2.04,-56), "Tailrace", AABB(Vector3(-10,1.8,-78),Vector3(20,3,28))]]:
		checkpoints.append({"pose": Transform3D(Basis.IDENTITY,row[0]), "title": row[1], "bounds":row[2]})
	for i: int in FOUNDRY_ANCHORS.size():
		_foundry_anchor(i, FOUNDRY_ANCHORS[i])
	_environment()
	_sign("entry",Vector3(0,21,-20),"FOUNDRY",0.008)
	_sign("fork",Vector3(-26.97,17,-16),"GALLERY",0.014)
	_sign("direct",Vector3(4,11.6,-19.97),"SHAFT",0.014)
	_sign("court",Vector3(0,-7.94,-17),"COURT\nRETURN LEFT",0.035)
	routes = {"basic": [spawn.origin,Vector3(-16,18,6),Vector3(-16,12,-24),Vector3(0,12,-33),finish_position],
		"advanced": [spawn.origin,Vector3(0,18,0),Vector3(0,12,-28),finish_position],
		"shaft-carry": [spawn.origin,Vector3(0,18,3),Vector3(0,18.8,-8),Vector3(0,12,-24),Vector3(0,12,-36),Vector3(0,2,-66),finish_position]}
	jump_gaps = [{"label":"shaft", "edge":Vector3(0,18,0),"land":Vector3(0,12,-20),"recovery":"court and wall ramp"},
		{"label":"descending catch","edge":Vector3(0,12,-36),"land":Vector3(0,2,-50),"recovery":"court and tailrace ramp"}]
	FOUNDRY_ART.dress(self)

func _ramp(id: String, x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, stage: int) -> void:
	# keep convex pieces within the same 24 m scale as the shared deck builder.
	var count := ceili(absf(z1-z0)/24.0)
	for i: int in count:
		var a := float(i)/count
		var b := float(i+1)/count
		var za := lerpf(z0,z1,a)
		var zb := lerpf(z0,z1,b)
		var ya := lerpf(y0,y1,a)
		var yb := lerpf(y0,y1,b)
		var top: Array[Vector3] = [Vector3(x0,ya,za),Vector3(x1,ya,za),Vector3(x1,yb,zb),Vector3(x0,yb,zb)]
		GEO.prism(self,"%s_%d" % [id,i],top,-9,stage,"recovery" if stage < 0 else "route","ramp")

func _foundry_anchor(i: int, at: Vector3) -> void:
	var anchor := Node3D.new()
	anchor.name = "FoundryAnchor%d" % i
	anchor.position = at
	anchor.set_meta("r21_anchor_id", "foundry-%d" % i)
	anchor.set_meta("anchor_name", ["Shaft crane", "Gallery crane", "Tailrace crane"][i])
	anchor.add_to_group(RUNNER.ANCHOR_GROUP)
	add_child(anchor)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.65
	torus.outer_radius = 0.85
	ring.mesh = torus
	ring.rotation.x = PI / 2
	ring.material_override = RUNNER._flat(Color("b5683c"))
	anchor.add_child(ring)
	FOUNDRY_ART.box(self,"crane_beam_%d" % i,Vector3(0,at.y+1.5,at.z),Vector3(52,1,1.2),RUNNER._flat(Color("29464a")))
	_box("crane_drop_%d" % i,at+Vector3(0,0.7,0),Vector3(0.18,1.4,0.18),Color("29464a"))
	for x: float in [-26.0,26.0]:
		FOUNDRY_ART.box(self,"crane_column_%d_%s" % [i,x],Vector3(x,(at.y-6)/2,at.z),Vector3(1.5,at.y+10,1.5),RUNNER._flat(Color("29464a")))

func _sign(id: String, at: Vector3, text: String, pixels: float) -> void:
	super._sign(id,at,text,pixels)
	var label: Label3D = get_child(get_child_count()-1)
	label.modulate = Color("e8dfc9")
	label.outline_size = 4
	label.outline_modulate = Color("203c3d")
	if id == "fork":
		label.rotation.y = PI/2
	if id == "court":
		label.rotation.x = -PI/2
		label.modulate = Color("29464a")
		label.outline_size = 0

func route_hint(stage: int, _feet: Vector3) -> String:
	return "Gallery left, shaft ahead. LMB holds, RMB reels; release toward the far deck." if stage < 1 else "Carry shaft speed with hops to skip the next ring, or swing down to Tailrace. Court ramps recover misses."

func geometry_hash() -> String:
	return (super.geometry_hash() + JSON.stringify([level_id, level_version, FOUNDRY_ID, FOUNDRY_ANCHORS])).sha256_text()
