extends RefCounted
## p / remaining course, authored against 8.5 m/s running and 7.2 m/s jumping.
## every coordinate is a feet/floor position, in metres; no controller changes.

var _level: Node3D


func build(level: Node3D) -> void:
	if level.has_meta("spillway_course_built"):
		return
	level.set_meta("spillway_course_built", true)
	_level = level
	_open_crest_exit()
	_make_yard()
	_make_filter_house()
	_make_outflow()
	_define_routes()
	var checkpoints: Array = level.get("checkpoints")
	checkpoints.clear()
	checkpoints.append_array([
		{"pose": level.get("spawn"), "title": "Crest"},
		{"pose": Transform3D(Basis.IDENTITY, Vector3(10, 4.04, -65)), "title": "Sluice yard", "hint": "the sluice yard", "radius": 4.0, "bounds": AABB(Vector3(6.5, 3.5, -74.5), Vector3(7.5, 3.0, 12.5))},
		{"pose": Transform3D(Basis(Vector3.UP, -PI * .5), Vector3(-28, 3.04, -104)), "title": "Outflow", "hint": "the filter-house roof or its run-up", "radius": 4.0, "bounds": AABB(Vector3(-39.5, 2.85, -109.5), Vector3(23.0, 3.0, 12.2))},
	])
	level.set("finish_position", Vector3(24, -3, -64.5))
	level.set("finish_radius", 2.0)
	var bounds: Array = level.get("segment_bounds")
	bounds.append(AABB(Vector3(-44, -9, -110), Vector3(61, 18, 54)))
	bounds.append(AABB(Vector3(-43, -10, -115), Vector3(87, 19, 59)))


func _open_crest_exit() -> void:
	# the crest slice's south rail is closed; replace only that beam with a gate.
	var opened: bool = false
	for child: Node in _level.get_children():
		if not child is Node3D:
			continue
		var p: Vector3 = (child as Node3D).position
		var beam: bool = child is StaticBody3D and absf(p.x - 2.5) < .02 and absf(p.z + 62) < .02 and (absf(p.y - 5.05) < .02 or absf(p.y - 4.51) < .02)
		var post: bool = str(child.name).begins_with("Detail") and p.x > 7 and p.x < 15 and absf(p.z + 62) < .02 and p.y > 4 and p.y < 5.1
		if beam or post:
			_level.remove_child(child)
			child.free()
			opened = opened or beam
	if opened:
		_level.call("_rail", Vector3(-12, 4, -62), Vector3(7, 4, -62))
		_level.call("_rail", Vector3(15, 4, -62), Vector3(17, 4, -62))
	_stage(_walk("YardEntryRamp", Vector3(10, 4, -62), Vector3(10, 4, -74), 6.0, true), 1)


func _make_yard() -> void:
	# a common valve apron has a real retaining foundation, not floating obstacles.
	_stage(_level.call("_solid", "SluiceYardFoundation", Vector3(-34.5, -3.25, -84.5), Vector3(11, 9.5, 25), "old_concrete"), 1)
	# p / open culverts support the east apron without blocking the recovery basin.
	for x: float in [-25, -18, -12]:
		for z: float in [-74, -84.5, -95]:
			_level.call("_solid", "YardCulvertPier", Vector3(x, -3.75, z), Vector3(1, 9.5, 1.5), "old_concrete")
	_stage(_level.call("_slab", "SluiceYardApron", Vector3(-25.5, 1.5, -84.5), Vector2(29, 25), .55, "concrete"), 1)
	_stage(_walk("YardEntryCrossing", Vector3(11, 4, -74), Vector3(-12, 4, -74), 7.0, false), 1)
	_stage(_walk("YardApronDescent", Vector3(-12, 4, -74), Vector3(-18, 1.5, -74), 7.0, false), 1)
	_level.call("_rail", Vector3(6.5, 4, -70.6), Vector3(-12, 4, -70.6))
	_level.call("_rail", Vector3(11, 4, -77.4), Vector3(-9, 4, -77.4))
	# two gate machinery rooms leave a direct low opening and wide side approaches.
	for x: float in [-36.5, -18.5]:
		_level.call("_solid", "SluiceGateMachinery", Vector3(x, 3.1, -82), Vector3(7, 3.2, 5.5), "terracotta")
		_stage(_level.call("_slab", "GateMachineryCap", Vector3(x, 4.9, -82), Vector2(7.6, 6.1), .2, "concrete"), 1)
		_level.call("_cylinder", Vector3(x, 4.9, -82), Vector3(x, 5.9, -82), .16, "steel")
		_level.call("_wheel", Vector3(x, 5.9, -82), .75, "ochre", true)
		_level.call("_box", Vector3(x, 3.2, -79.21), Vector3(3, 1.4, .08), "shadow")
	# floor 1.5, underside 2.77: 1.27 m permits crouching but denies standing.
	_level.call("_solid", "HalfOpenSluiceGate", Vector3(-27.5, 4.17, -82), Vector3(11, 2.8, 1.1), "steel")
	_level.call("_box", Vector3(-27.5, 2.82, -81.42), Vector3(11, .1, .12), "ochre")
	for x: float in [-33.2, -21.8]:
		_level.call("_solid", "GateGuide", Vector3(x, 3.6, -82), Vector3(.3, 4.2, 1.4), "steel")
		_level.call("_cylinder", Vector3(x, 5.7, -82), Vector3(x, 7.1, -82), .1, "steel")
	_level.call("_beam", Vector3(-33.7, 7.1, -82), Vector3(-21.3, 7.1, -82), .3, "steel")
	# broad east bypass bends around the working housings, then returns to the roof.
	for z: float in [-76]:
		_stage(_level.call("_solid", "ValvePlinth", Vector3(-35, 2.1, z), Vector3(4, 1.2, 4), "old_concrete"), 1)
		_level.call("_cylinder", Vector3(-35, 2.7, z), Vector3(-35, 3.7, z), .3, "pipe")
		_level.call("_wheel", Vector3(-35, 3.8, z), .9, "ochre", true)
	# p / the low apron does not feed the high outflow run-up; its edge is guarded.
	_level.call("_rail", Vector3(-19, 1.5, -96.9), Vector3(-13, 1.5, -96.9))
	_level.call("_rail", Vector3(-19, 1.5, -96.9), Vector3(-19, 1.5, -99))
	_level.call("_rail", Vector3(-13, 1.5, -96.9), Vector3(-11, 1.5, -93))
	_level.call("_rail", Vector3(-11, 1.5, -78), Vector3(-11, 1.5, -93))
	_level.call("_rail", Vector3(-40, 1.5, -72), Vector3(-40, 1.5, -85))
	# visible water works continue under the apron, with foundation-depth openings.
	for x: float in [-36.5, -18.5]:
		_level.call("_box", Vector3(x, -.5, -97.04), Vector3(4, 2.2, .08), "shadow")
		for offset: float in [-1.5, -.75, 0, .75, 1.5]:
			_level.call("_beam", Vector3(x + offset, -1.5, -97.1), Vector3(x + offset, .5, -97.1), .08, "grate")


func _make_filter_house() -> void:
	_stage(_level.call("_solid", "FilterHouse", Vector3(-29, -1.5, -103.5), Vector3(12, 9, 9), "terracotta"), 2)
	_stage(_level.call("_slab", "FilterHouseRoof", Vector3(-29, 3, -104.5), Vector2(22, 11), .45, "concrete"), 2)
	for x: float in [-38, -20]:
		_level.call("_solid", "FilterRoofCorbel", Vector3(x, -1.6, -105), Vector3(1.2, 8.8, 4), "old_concrete")
	# both access ramps avoid mantle; the direct gate line enters the inner ramp.
	_stage(_walk("WestRoofAccess", Vector3(-37, 1.5, -87), Vector3(-37, 3, -99), 5.0, false), 1)
	_stage(_walk("InnerRoofAccess", Vector3(-27, 1.5, -90), Vector3(-27, 3, -99), 5.0, false), 1)
	for x: float in [-33, -29, -25]:
		_level.call("_box", Vector3(x, 1.1, -98.95), Vector3(2.2, 1.7, .1), "shadow")
	# this inspection apron presents a 1.5 m roof lip beside the low housing.
	_stage(_level.call("_slab", "FilterInspectionApron", Vector3(-21.5, 1.5, -98), Vector2(5, 2), .5, "concrete"), 1)
	for x: float in [-23.5, -19.5]:
		_level.call("_solid", "InspectionApronPier", Vector3(x, -3.5, -98), Vector3(.7, 9, .7), "old_concrete")
	# the low east inspection housing is an optional forgiving roof catch.
	_stage(_level.call("_solid", "FilterInspectionHousing", Vector3(-21, 2.1, -97), Vector3(3, 1.2, 3), "old_concrete"), 1)
	# p / one continuous nosing carries the housing line across the old slot and curb.
	_stage(_level.call("_ramp", "InspectionRoofNosing", Vector3(-21, 2.7, -98.0), Vector3(-21, 3, -98.65), 3.0, 0.2, "concrete"), 1)
	_stage(_level.call("_slab", "InspectionRoofBridge", Vector3(-21, 3, -98.95), Vector2(3, 0.7), 0.25, "concrete"), 2)
	_level.call("_box", Vector3(-21, 3.02, -99.1), Vector3(3, 0.025, 0.12), "ochre")
	_level.call("_rail", Vector3(-40, 3, -110), Vector3(-18, 3, -110))
	_level.call("_rail", Vector3(-40, 3, -110), Vector3(-40, 3, -99))
	# ventilation stacks stay behind the approach, leaving roof and tower readable.
	for x: float in [-35, -31]:
		_level.call("_cylinder", Vector3(x, 3, -108), Vector3(x, 5.5, -108), .4, "pipe")
		_level.call("_box", Vector3(x, 5.55, -108), Vector3(1.2, .16, 1.2), "steel")


func _make_outflow() -> void:
	# outer maintenance gantry goes around the deep tower foundation to its front.
	_stage(_walk("RoofGantryDescent", Vector3(-18, 3, -106), Vector3(-7, 0, -106), 5.0, true), 2)
	_walk("SouthGantry", Vector3(-7, 0, -106), Vector3(37, 0, -106), 5.0, true)
	_level.call("_slab", "SouthGantryTurn", Vector3(37, 0, -106), Vector2(5, 5), .5, "concrete")
	_walk("EastGantryDescent", Vector3(37, 0, -106), Vector3(37, -3, -86), 5.0, true)
	_walk("EastGantry", Vector3(37, -3, -86), Vector3(37, -3, -64), 5.0, true)
	_level.call("_slab", "EastGantryTurn", Vector3(37, -3, -64), Vector2(5, 5), .5, "concrete")
	_walk("FrontGantry", Vector3(37, -3, -64), Vector3(24, -3, -64), 5.0, false)
	_level.call("_rail", Vector3(39.5, -3, -61.5), Vector3(12, -3, -61.5))
	# this loading apron is north of the solid lower hall (its front ends z=-69.5).
	_level.call("_slab", "PumpLoadingApron", Vector3(23, -3, -65), Vector2(22, 8), .7, "concrete")
	for x: float in [14, 24, 32]:
		_level.call("_solid", "LoadingApronPier", Vector3(x, -6.4, -64.5), Vector3(1.3, 6.1, 3), "old_concrete")
	# diagonal sluice abutments are broad landings, with open gaps above real water.
	# p / the run-up admits Outflow from its real deck, e.g. after hopping the apron rail.
	# supports, basin and loading apron do not: one hop from the yard crossing reaches them.
	_stage(_walk("OutflowRunup", Vector3(-18, 3, -100), Vector3(-5, 0, -95), 5.5, false), 2)
	_stage(_walk("OutflowLaunch", Vector3(-5, 0, -95), Vector3(-3, 0, -92), 5.5, false), 2)
	_level.call("_solid", "FirstSluiceSupport", Vector3(2, -3.5, -85.5), Vector3(6.5, 5, 7.5), "old_concrete")
	_level.call("_slab", "FirstSluiceLanding", Vector3(2, -1, -85.5), Vector2(6.5, 7.5), .3, "concrete")
	_walk("SecondSluiceCoping", Vector3(5, -1.6, -78), Vector3(9, -2.6, -73), 6.0, false)
	_level.call("_solid", "SecondSluicePier", Vector3(7, -4.7, -75.5), Vector3(4, 3.6, 4), "old_concrete")
	# painted coping identifies landing edges without a continuous floor trail.
	_level.call("_box", Vector3(2, -.98, -89.15), Vector3(6.4, .025, .12), "ochre")
	_level.call("_beam", Vector3(2.8, -1.58, -76.2), Vector3(7.4, -2.58, -71.1), .07, "ochre")
	_make_basin()


func _make_basin() -> void:
	_level.call("_slab", "OutflowRecoveryFloor", Vector3(-.5, -6, -82), Vector2(33, 42), .8, "old_concrete")
	_level.call("_water", "ShallowOutflowBasin", Vector3(-.5, -5.73, -82), Vector2(33, 42), "water")
	var water: Array = _level.get("water_regions")
	water.append({"bounds": AABB(Vector3(-17, -6.1, -103), Vector3(33, .65, 42)), "depth": .27})
	(_level.get("water_audio_sources") as Array).append(Vector3(-0.5, -5.73, -82.0))
	# the long dry edge and inclined exit turn a miss into distance, never a reset.
	_walk("BasinWestEdge", Vector3(-16, -5.65, -100), Vector3(-16, -5.65, -80), 3.0, false)
	_walk("BasinEdgeAccess", Vector3(-12, -6, -83), Vector3(-14.5, -5.65, -83), 3.0, false)
	_walk("BasinExitRamp", Vector3(-10, -6, -79), Vector3(-10, -3, -65), 5.0, false)
	# p / painted safety hardware makes the existing ramp read from water level.
	for x: float in [-12.4, -7.6]:
		_level.call("_rail", Vector3(x, -6, -79), Vector3(x, -3, -65), "ochre")
	_level.call("_beam", Vector3(-12.35, -5.95, -78.7), Vector3(-7.65, -5.95, -78.7), 0.08, "ochre")
	_level.call("_solid", "BasinRampHeadstock", Vector3(-12.85, -5.3, -79), Vector3(0.14, 1.4, 0.14), "steel")
	_level.call("_box", Vector3(-12.85, -4.58, -79), Vector3(0.18, 0.1, 0.18), "ochre")
	_level.call("_slab", "BasinExitLanding", Vector3(-10, -3, -63.5), Vector2(5, 3), .5, "concrete")
	_walk("BasinFrontWalk", Vector3(-7.5, -3, -65), Vector3(24, -3, -65), 8.0, false)
	_level.call("_rail", Vector3(-7.5, -3, -62.1), Vector3(7, -3, -62.1))
	_level.call("_rail", Vector3(7, -3, -62.1), Vector3(12, -3, -61.5))
	_level.call("_rail", Vector3(-12.4, -3, -62.1), Vector3(-7.5, -3, -62.1))
	_level.call("_rail", Vector3(-12.4, -3, -65), Vector3(-12.4, -3, -62.1))
	# p / continuous retaining faces close the basin, including below the front walk.
	_level.call("_solid", "BasinNorthRetainingWall", Vector3(-.5, -4.75, -61.3), Vector3(33, 2.5, .6), "wet_concrete")
	_level.call("_solid", "BasinEastReturn", Vector3(15.7, -4.75, -82), Vector3(.6, 2.5, 42.0), "wet_concrete")
	_level.call("_solid", "BasinWestRetainingWall", Vector3(-17.6, -5.1, -82.2), Vector3(1.2, 3.4, 43.6), "old_concrete")
	_level.call("_solid", "BasinSouthRetainingWall", Vector3(0, -5, -103), Vector3(34, 3, 1), "old_concrete")


func _walk(label: String, a: Vector3, b: Vector3, width: float, rails: bool) -> StaticBody3D:
	var deck: StaticBody3D = _level.call("_ramp", label, a, b, width, .5, "concrete")
	var side: Vector3 = Vector3(b.x - a.x, 0, b.z - a.z).normalized().cross(Vector3.UP) * (width * .5 - .1)
	if rails:
		var rail_a: Vector3 = a
		var rail_b: Vector3 = b
		if label == "SouthGantry":
			rail_b = b.move_toward(a, 3.0)
		if label == "EastGantryDescent":
			rail_a = a.move_toward(b, 3.0)
		if label == "EastGantry":
			rail_b = b.move_toward(a, 3.0)
		_level.call("_rail", rail_a - side, rail_b - side)
		_level.call("_rail", rail_a + side, rail_b + side)
	if label == "YardEntryCrossing":
		# p / a higher crossing preserves jump headroom and an unobstructed lower basin.
		for sign_value: float in [-1.0, 1.0]:
			var edge_a := a + side * sign_value
			var edge_b := b + side * sign_value
			_level.call("_beam", edge_a - Vector3.UP * 1.25, edge_b - Vector3.UP * 1.25, .24, "steel", true)
			for section: int in 8:
				var left := edge_a.lerp(edge_b, float(section) / 8.0)
				var right := edge_a.lerp(edge_b, float(section + 1) / 8.0)
				_level.call("_beam", left - Vector3.UP * .5, right - Vector3.UP * 1.25, .12, "steel", true)

	var count: int = 1 if label == "YardEntryRamp" else maxi(1, ceili(a.distance_to(b) / 7.0))
	for i: int in count + 1:
		var p: Vector3 = a.lerp(b, float(i) / count)
		var bottom: float = -8.5
		var supports: Array[Vector3] = []
		if label != "YardEntryCrossing":
			supports.append(p)
		if label == "YardEntryRamp":
			# leave the lower crossing and final approach clear beneath the entrance.
			supports = [p + side * .85]
			_level.call("_beam", p + side * .85 - Vector3.UP * 2.6, p - side * .85 - Vector3.UP * .5, .35, "steel")
		for support: Vector3 in supports:
			_level.call("_solid", label + "Pier", Vector3(support.x, (support.y - .5 + bottom) * .5, support.z), Vector3(.85, support.y - .5 - bottom, .85), "old_concrete")
	_level.call("_beam", a - side - Vector3.UP * .4, b - side - Vector3.UP * .4, .2, "steel")
	_level.call("_beam", a + side - Vector3.UP * .4, b + side - Vector3.UP * .4, .2, "steel")
	return deck


func _stage(body: StaticBody3D, stage: int) -> void:
	# p / grounded contact with a tagged deck admits that stage when it is the next one.
	body.set_meta("progress_stage", stage)


func _define_routes() -> void:
	var common: Array = [
		_p(Vector3(11, 4, -74)),
		_p(Vector3(-2, 4, -74)), _p(Vector3(-12, 4, -74)), _p(Vector3(-18, 1.5, -74)),
	]
	var safe: Array = common.duplicate()
	safe.append_array([
		_p(Vector3(-18, 1.5, -78)), _p(Vector3(-14, 1.5, -78)), _p(Vector3(-14, 1.5, -87)),
		_p(Vector3(-37, 1.5, -87)), _p(Vector3(-37, 3, -101)),
		_p(Vector3(-28, 3, -104)), _p(Vector3(-18.5, 3, -106)),
		_p(Vector3(-5, 0, -106)), _p(Vector3(37, 0, -106)),
		_p(Vector3(37, -3, -85)), _p(Vector3(37, -3, -64)), _p(Vector3(23.8, -3, -68.8)),
	])
	var fast: Array = common.duplicate()
	fast.append_array([
		_p(Vector3(-27, 1.5, -75)), _p(Vector3(-27, 1.5, -79.5), .85),
		_p(Vector3(-27, 1.5, -84), .9, true), _p(Vector3(-27, 1.5, -90)),
		_p(Vector3(-27, 3, -101)), _p(Vector3(-28, 3, -104)),
		_p(Vector3(-18, 3, -100), 1.3), _p(Vector3(-5.5, .12, -95.2), 1, true),
		_p(Vector3(-3.4, 0, -92.6), .95, true, true), _p(Vector3(2, -1, -86), 1.4, true),
		_p(Vector3(3.5, -1, -84.5), 1.2, true, true), _p(Vector3(7.6, -2.25, -74.7), 2.5, true),
		_p(Vector3(8.6, -2.5, -73.5), 1.5, true, true), _p(Vector3(16, -3, -65), 1.6),
		_p(Vector3(23.8, -3, -68.8)),
	])
	var recovery: Array = common.duplicate()
	recovery.append_array([
		_p(Vector3(-27, 1.5, -75)), _p(Vector3(-27, 1.5, -79.5), .85),
		_p(Vector3(-27, 1.5, -84), .9, true), _p(Vector3(-27, 1.5, -90)),
		_p(Vector3(-27, 3, -101)), _p(Vector3(-28, 3, -104)),
		_p(Vector3(-18, 3, -100), 1.3), _p(Vector3(-5.5, .12, -95.2)),
		_p(Vector3(-7, -6, -91), 1.8), _p(Vector3(-10, -6, -80)),
		_p(Vector3(-10, -3, -63.5), 1.3), _p(Vector3(15, -3, -65)), _p(Vector3(23.8, -3, -68.8)),
	])
	var routes: Dictionary = _level.get("routes")
	routes["safe"].append_array(safe)
	routes["fast"].append_array(fast)
	routes["recovery"].append_array(recovery)
	# input regression for the ordinary west corner that missed the original sphere.
	var corner: Array = routes["safe"].duplicate(true)
	corner[10] = _p(Vector3(-9, 4, -56.5))
	corner[11] = _p(Vector3(7.7, 4, -62.8), .8)
	corner.insert(12, _p(Vector3(9.9, 4, -69.5)))
	routes["safe_corner"] = corner
	# input regression for heading straight to the wheel rather than the front box.
	var direct: Array = routes["fast"].duplicate(true)
	# retain the r7 regression name; the direct wheel approach is now canonical.
	routes["fast_direct_finish"] = direct
	var housing: Array = routes["fast"].duplicate(true)
	var first: int = -1
	var last: int = -1
	for i: int in housing.size():
		if housing[i].pos == Vector3(-27, 3, -101):
			first = i
		if housing[i].pos == Vector3(-18, 3, -100):
			last = i
	if first >= 0 and last >= first:
		for i: int in last - first + 1:
			housing.remove_at(first)
		var via: Array = [
			_p(Vector3(-21, 1.5, -90)), _p(Vector3(-21, 1.5, -93.7), .55, false, true),
			_p(Vector3(-21, 3, -98.6), 1.6), _p(Vector3(-16, 2.5, -98.6), .8),
		]
		for i: int in via.size():
			housing.insert(first + i, via[i])
	routes["fast_housing_turn"] = housing
	# ordinary rail-hop line from the normal Crest spawn, then honest basin recovery.
	var rail_hop: Array = routes["fast"].slice(0, routes["fast"].size() - fast.size())
	rail_hop.append_array(common)
	rail_hop.append_array([
		_p(Vector3(-14, 1.5, -78)), _p(Vector3(-14, 1.5, -90)),
		_p(Vector3(-14, 1.5, -94.9), .55, false, true), _p(Vector3(-14, 2.2, -100.2), 1.6),
		_p(Vector3(-7, -6, -91), 1.8),
		_p(Vector3(-10, -6, -82)), _p(Vector3(-10, -3, -63.5), 1.3),
		_p(Vector3(15, -3, -65)), _p(Vector3(23.8, -3, -68.8)),
	])
	routes["rail_hop_recovery"] = rail_hop


func _p(pos: Vector3, radius: float = 1.0, crouch: bool = false, jump: bool = false) -> Dictionary:
	return {"pos": pos, "radius": radius, "crouch": crouch, "jump": jump}
