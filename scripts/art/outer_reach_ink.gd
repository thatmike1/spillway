extends RefCounted
## thin near-field contours follow the actual caps, piles and structural boxes.
const CONTOURS := preload("res://scripts/r17_contours.gd")
const MATERIALS := preload("res://scripts/art/sluice_six_materials.gd")
static func dress(level: Node3D) -> void:
	var edges := CONTOURS.new()
	edges.lines.begin(Mesh.PRIMITIVE_TRIANGLES)
	for deck: Dictionary in level.decks:
		var points: Array[Vector3] = [Vector3(deck.x-deck.width/2,0.025,deck.near),Vector3(deck.x+deck.width/2,0.025,deck.near),Vector3(deck.x+deck.width/2,0.025,deck.far),Vector3(deck.x-deck.width/2,0.025,deck.far)]
		for i: int in 4:
			edges.line(points[i],points[(i+1)%4],0.018)
			edges.line(points[i],Vector3(points[i].x,-7.0 if deck.id in ["start","pump_court"] else -0.5,points[i].z),0.022)
	for piece: Dictionary in level.manifest:
		if piece.role not in ["support","obstacle"]:
			continue
		var points: Array = piece.points
		for i: int in 4:
			edges.line(points[i],points[(i+1)%4],0.018)
			edges.line(points[i],points[i+4],0.018)
	for child: Node in level.get_children():
		if not child is MeshInstance3D or not child.mesh is BoxMesh or not child.get_meta("sluice_structural",false):
			continue
		var points: Array[Vector3] = []
		for i: int in 8:
			points.append(child.transform*(Vector3(1 if (i & 1) != 0 else -1,1 if (i & 2) != 0 else -1,1 if (i & 4) != 0 else -1)*child.mesh.size*0.5))
		for i: int in 8:
			for axis: int in 3:
				var other := i ^ (1 << axis)
				if other > i:
					edges.line(points[i],points[other],0.022)
	var ink := MeshInstance3D.new()
	ink.name = "OuterReachInk"
	ink.mesh = edges.lines.commit()
	ink.material_override = MATERIALS.ink()
	ink.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(ink)
