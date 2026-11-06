extends RefCounted
## p / remaining course, authored against 8.5 m/s running and 7.2 m/s jumping.
## every coordinate is a feet/floor position, in metres; no controller changes.

# p / the run-up's end is the outflow face's start plane; both derive from these points.
const OUTFLOW_RUNUP_START := Vector3(-22, 3, -102.8)
const OUTFLOW_RUNUP_END := Vector3(-13, 3, -97.3)
# p / r12: the outflow S ends with its coping this high, still descending, so even a runner
# riding the coping passes under the yard bank's edge and the yard crossing.
const OUTFLOW_RELEASE_COPING := 1.0

var _level: Node3D


func build(level: Node3D) -> void:
	if level.has_meta("spillway_course_built"):
		return
	level.set_meta("spillway_course_built", true)
	_level = level
	_open_crest_exit()
	_screen_terrace_drop()
	_make_yard()
	_make_filter_house()
	_make_outflow()
	_make_surf_faces()
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
	_make_wheel_guard()
	var bounds: Array = level.get("segment_bounds")
	bounds.append(AABB(Vector3(-44, -9, -110), Vector3(61, 18, 54)))
	bounds.append(AABB(Vector3(-43, -10, -115), Vector3(87, 19, 59)))


func _make_wheel_guard() -> void:
	# p / a real machinery bay keeps the arrival view clear of the rotating spokes.
	# small mesh openings are below capsule width; one thin proxy matches each face.
	var corners: Array[Vector3] = [
		Vector3(20.8, -3, -69.55), Vector3(20.8, -3, -64.5),
		Vector3(27.2, -3, -64.5), Vector3(27.2, -3, -74.1),
	]
	for i: int in corners.size() - 1:
		var a := corners[i]
		var b := corners[i + 1]
		_level.call("_rail", a, b, "ochre")
		var direction := (b - a).normalized()
		var count := ceili(a.distance_to(b) / 0.16)
		for rod: int in count + 1:
			var at := a.lerp(b, float(rod) / float(count))
			_level.call("_beam", at + Vector3.UP * 0.12, at + Vector3.UP * 0.98, 0.018, "steel")
		var size := Vector3(0.035, 1.02, a.distance_to(b))
		var body: StaticBody3D = _level.call("_solid", "WheelMaintenanceGuard", (a + b) * 0.5 + Vector3.UP * 0.53, size, "steel")
		body.rotation.y = atan2(direction.x, direction.z)
		# the visible rods and rails describe this collision face, not a solid panel.
		for child: Node in body.get_children():
			if child is MeshInstance3D:
				child.free()
		_level.call("_beam", a + Vector3.UP * 0.09, b + Vector3.UP * 0.09, 0.055, "steel")


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
		# the exit deck's service joint (x 2..3.6) splits its rail too.
		_level.call("_rail", Vector3(-12, 4, -62), Vector3(1.95, 4, -62))
		_level.call("_rail", Vector3(3.65, 4, -62), Vector3(7, 4, -62))
		_level.call("_rail", Vector3(15, 4, -62), Vector3(17, 4, -62))
	_stage(_walk("YardEntryRamp", Vector3(10, 4, -62), Vector3(10, 4, -74), 6.0, true), 1)


func _screen_terrace_drop() -> void:
	# p / the tower is a landmark beyond the yard, not the first terrace's next landing.
	# mesh guards close only the inviting direct drop; the broad westward crossing stays open.
	_stage(_level.call("_slab", "YardEntryTurn", Vector3(10, 4, -74), Vector2(6.2, 7), 0.5, "concrete"), 1)
	_level.call("_solid", "YardEntryTurnPier", Vector3(12.6, -2.5, -76.8), Vector3(0.65, 12, 0.85), "old_concrete")
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/spillway_screen.gdshader")
	var corners: Array[Vector3] = [
		Vector3(17.05, 4, -56), Vector3(17.05, 4, -62.1),
		Vector3(13.05, 4, -62.1), Vector3(13.05, 4, -77.4), Vector3(11, 4, -77.4),
	]
	for i: int in corners.size() - 1:
		var a := corners[i]
		var b := corners[i + 1]
		var length := a.distance_to(b)
		var direction := (b - a).normalized()
		var body: StaticBody3D = _level.call("_solid", "TerraceMaintenanceScreen", (a + b) * 0.5 + Vector3.UP * 1.35,
			Vector3(0.045, 2.7, length), "steel")
		body.rotation.y = atan2(direction.x, direction.z)
		for child: Node in body.get_children():
			if child is MeshInstance3D:
				child.material_override = material
				child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for y: float in [0.12, 1.35, 2.7]:
			_level.call("_beam", a + Vector3.UP * y, b + Vector3.UP * y, 0.055, "steel")
		var count := ceili(length / 2.5)
		for post: int in count + 1:
			var point := a.lerp(b, float(post) / float(count))
			_level.call("_solid", "MaintenanceScreenPost", point + Vector3.UP * 1.35,
				Vector3(0.09, 2.7, 0.09), "steel")
			_level.call("_box", point + Vector3.UP * 0.025, Vector3(0.22, 0.05, 0.22), "steel")


func _make_yard() -> void:
	# a common valve apron has a real retaining foundation, not floating obstacles.
	_stage(_level.call("_solid", "SluiceYardFoundation", Vector3(-34.5, -3.25, -84.5), Vector3(11, 9.5, 25), "old_concrete"), 1)
	# p / open culverts support the east apron without blocking the recovery basin.
	for x: float in [-25, -18, -12]:
		for z: float in [-74, -84.5, -95]:
			# the outflow berm now occupies the old southeast apron corner and its pier.
			if x == -12 and z == -95:
				continue
			# p / the east junction pier stands under the descent deck, outside the exit ramp's rail.
			var pier_x: float = -13.75 if x == -12 and z == -74 else x
			_level.call("_solid", "YardCulvertPier", Vector3(pier_x, -3.75, z), Vector3(1, 9.5, 1.5), "old_concrete")
	# p / the apron stops short of the outflow berm: a square notch, guarded on both edges.
	_stage(_level.call("_slab", "SluiceYardApron", Vector3(-25.5, 1.5, -81.5), Vector2(29, 19), .55, "concrete"), 1)
	_stage(_level.call("_slab", "SluiceYardApron", Vector3(-28.5, 1.5, -94), Vector2(23, 6), .55, "concrete"), 1)
	# r12 / a steel grating covers the intake slot between the roof ramps. the 2 m slot under
	# the roof lip dropped a hop that drifted off the inner ramp out of bounds; the lip itself
	# still stands 1.5 m above the apron, so it remains a mantle and not a step.
	_stage(_level.call("_slab", "IntakeSlotGrating", Vector3(-32, 1.5, -98), Vector2(5, 2), .2, "grate"), 1)
	# p / a 1.6 m joint in the crossing, clear of the fast line's yard turn, is a simple hop.
	_stage(_walk("YardEntryCrossing", Vector3(11, 4, -74), Vector3(-1.4, 4, -74), 7.0, false), 1)
	_stage(_walk("YardEntryCrossing", Vector3(-3, 4, -74), Vector3(-12, 4, -74), 7.0, false), 1)
	_stage(_walk("YardApronDescent", Vector3(-12, 4, -74), Vector3(-18, 1.5, -74), 7.0, false), 1)
	for span: Vector2 in [Vector2(6.5, -1.3), Vector2(-3.1, -12)]:
		_level.call("_rail", Vector3(span.x, 4, -70.6), Vector3(span.y, 4, -70.6))
	for span: Vector2 in [Vector2(2, -1.3), Vector2(-3.1, -9)]:
		_level.call("_rail", Vector3(span.x, 4, -77.4), Vector3(span.y, 4, -77.4))
	# two gate machinery rooms leave a direct low opening and wide side approaches.
	_level.call("_solid", "SluiceGateMachinery", Vector3(-36.5, 3.1, -82), Vector3(7.0, 3.2, 5.5), "terracotta")
	_stage(_level.call("_slab", "GateMachineryCap", Vector3(-36.5, 4.9, -82), Vector2(7.6, 6.1), .2, "concrete"), 1)
	_level.call("_cylinder", Vector3(-36.5, 4.9, -82), Vector3(-36.5, 5.9, -82), .16, "steel", true)
	_level.call("_wheel", Vector3(-36.5, 5.9, -82), .75, "ochre", true)
	_level.call("_box", Vector3(-36.5, 3.2, -79.21), Vector3(3, 1.4, .08), "shadow")
	# p / r12: the east house is turned 45 degrees to run along the yard bank's foot instead of
	# standing square across the apron. a hop that misses the bank wide now meets its long side
	# at a glance and turns southwest along it, where the square end wall stopped it dead
	# (14.7 to 4.4 m/s); the channel between house and foot widens from 1.3 m to about 4 m.
	# the gate's east end and its guide stay inside the house's southwest end, and the cap,
	# valve and door turn with it. its north corner stays south of z -78, so a rider carried
	# along the crossing's south rail and down the descent passes it as before.
	var east := Transform3D(Basis(Vector3.UP, PI * .25), Vector3(-20.35, 0, -81.27))
	var house: StaticBody3D = _level.call("_solid", "SluiceGateMachinery", east * Vector3(0, 3.1, 0), Vector3(2.8, 3.2, 6.4), "terracotta")
	house.basis = east.basis
	var cap: StaticBody3D = _level.call("_solid", "GateMachineryCap", east * Vector3(0, 4.8, 0), Vector3(3.0, .2, 6.6), "concrete")
	cap.basis = east.basis
	_stage(cap, 1)
	_level.call("_cylinder", east * Vector3(0, 4.9, 0), east * Vector3(0, 5.9, 0), .16, "steel", true)
	_level.call("_wheel", east * Vector3(0, 5.9, 0), .75, "ochre", true)
	var door: Node3D = _level.call("_box", east * Vector3(-1.41, 3.2, 0), Vector3(.08, 1.4, 3), "shadow")
	door.basis = east.basis
	# floor 1.5, underside 2.77: 1.27 m permits crouching but denies standing.
	_level.call("_solid", "HalfOpenSluiceGate", Vector3(-27.5, 4.17, -82), Vector3(11, 2.8, 1.1), "steel")
	_level.call("_box", Vector3(-27.5, 2.82, -81.42), Vector3(11, .1, .12), "ochre")
	for x: float in [-33.2, -21.8]:
		_level.call("_solid", "GateGuide", Vector3(x, 3.6, -82), Vector3(.3, 4.2, 1.4), "steel")
		_level.call("_cylinder", Vector3(x, 5.7, -82), Vector3(x, 7.1, -82), .1, "steel", true)
	_level.call("_beam", Vector3(-33.7, 7.1, -82), Vector3(-21.3, 7.1, -82), .3, "steel", true)
	# broad east bypass bends around the working housings, then returns to the roof.
	for z: float in [-76]:
		_stage(_level.call("_solid", "ValvePlinth", Vector3(-35, 2.1, z), Vector3(4, 1.2, 4), "old_concrete"), 1)
		_level.call("_cylinder", Vector3(-35, 2.7, z), Vector3(-35, 3.7, z), .3, "pipe", true)
		_level.call("_wheel", Vector3(-35, 3.8, z), .9, "ochre", true)
	# p / the low apron does not feed the high outflow run-up; its edge is guarded.
	_level.call("_rail", Vector3(-19, 1.5, -96.9), Vector3(-17.1, 1.5, -96.9))
	_level.call("_rail", Vector3(-19, 1.5, -96.9), Vector3(-19, 1.5, -99))
	_level.call("_rail", Vector3(-17.1, 1.5, -96.9), Vector3(-17.1, 1.5, -90.9))
	_level.call("_rail", Vector3(-17.1, 1.5, -90.9), Vector3(-11.1, 1.5, -90.9))
	# p / the yard bank's foot meets a narrow toe shelf at apron level, so a rider who slips
	# low on the bank rolls off onto the apron instead of into its edge. the apron's east rail
	# starts where the bank face covers that edge.
	_stage(_level.call("_slab", "YardBankToe", Vector3(-9.1, 1.5, -80.3), Vector2(3.8, 4.6), .55, "concrete"), 1)
	# its pier stands under the shelf's east edge, outside the basin exit's walking lanes.
	_level.call("_solid", "YardBankToePier", Vector3(-7.45, -2.5, -81.2), Vector3(.5, 6.9, .7), "old_concrete")
	_level.call("_rail", Vector3(-11.1, 1.5, -82.7), Vector3(-11.1, 1.5, -90.9))
	_level.call("_rail", Vector3(-40, 1.5, -72), Vector3(-40, 1.5, -85))
	# r12 / the apron's north edge dropped straight into the void beside the safe route.
	_level.call("_rail", Vector3(-40, 1.5, -72.1), Vector3(-18.2, 1.5, -72.1))
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
	# p / r12: the inner ramp starts just past the yard bank's tail. the bank's foot runs out on
	# flat apron to its end, and a low rider leaving the tail meets the ramp head on. a ramp
	# rising under the foot made a floor-to-face crease that stopped walkers and low riders
	# dead, with its corner exposed beside the foot.
	_stage(_walk("InnerRoofAccess", Vector3(-25.95, 1.5, -95.2), Vector3(-25.95, 3, -99), 7.1, false), 1)
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
	# r12 / the roof's south rail stopped 1.6 m short of the gantry's: a wide turn over the
	# roof slipped off its southeast corner.
	_level.call("_rail", Vector3(-18, 3, -110), Vector3(-18, 3, -108.45))
	# ventilation stacks stay behind the approach, leaving roof and tower readable.
	for x: float in [-35, -31]:
		_level.call("_cylinder", Vector3(x, 3, -108), Vector3(x, 5.5, -108), .4, "pipe", true)
		_level.call("_solid", "FilterRoofVentCap", Vector3(x, 5.55, -108), Vector3(1.2, .16, 1.2), "steel")


func _make_outflow() -> void:
	# outer maintenance gantry goes around the deep tower foundation to its front.
	_stage(_walk("RoofGantryDescent", Vector3(-18, 3, -106), Vector3(-7, 0, -106), 5.0, true), 2)
	# p / service joints ask for ordinary hops; carried bhop speed clears them easily.
	for span: Vector2 in [Vector2(-7, 7.5), Vector2(9.5, 24), Vector2(26, 37)]:
		_walk("SouthGantry", Vector3(span.x, 0, -106), Vector3(span.y, 0, -106), 5.0, true)
	_level.call("_slab", "SouthGantryTurn", Vector3(37, 0, -106), Vector2(5, 5), .5, "concrete")
	_walk("EastGantryDescent", Vector3(37, 0, -106), Vector3(37, -3, -86), 5.0, true)
	_walk("EastGantry", Vector3(37, -3, -86), Vector3(37, -3, -76), 5.0, true)
	_walk("EastGantry", Vector3(37, -3, -74), Vector3(37, -3, -64), 5.0, true)
	_level.call("_slab", "EastGantryTurn", Vector3(37, -3, -64), Vector2(5, 5), .5, "concrete")
	_walk("FrontGantry", Vector3(37, -3, -64), Vector3(24, -3, -64), 5.0, false)
	_level.call("_rail", Vector3(39.5, -3, -61.5), Vector3(12, -3, -61.5))
	# this loading apron is north of the solid lower hall (its front ends z=-69.5).
	_level.call("_slab", "PumpLoadingApron", Vector3(23, -3, -65), Vector2(22, 8), .7, "concrete")
	for x: float in [14, 24, 32]:
		_level.call("_solid", "LoadingApronPier", Vector3(x, -6.4, -64.5), Vector3(1.3, 6.1, 3), "old_concrete")
	# p / the run-up leaves the roof on the line a right-hand bhop u-turn naturally exits.
	_stage(_walk("OutflowRunup", OUTFLOW_RUNUP_START, OUTFLOW_RUNUP_END, 5.0, false), 2)

	_make_basin()


func _make_surf_faces() -> void:
	var sections: Array = _level.get("surf_sections")
	var geometry := preload("res://scripts/spillway_surf_geometry.gd")
	# p / banked sluice aprons follow the dam's plan rather than freestanding trick ramps.
	# p / the yard bank starts 8 degrees into its plan. a 4 degree lead with a knife-edge slab
	# catches an early hop on the face instead of its end, and still leaves the outflow release
	# 1.1 m of headroom (the original first 12 degrees were cut for that release). its foot is
	# at apron height, so a low rider rolls onto the toe shelf or apron, and over the apron
	# (from 24 degrees) it is a solid bank with no crawlspace beneath.
	var yard_plan := {"origin": Vector3(6, -2.5, -83), "yaw": PI * .5, "bend": 1.0, "radius": 30.0,
		"arc": deg_to_rad(60.0), "drop_start": 0.0, "drop_end": 0.0}
	var yard_start := deg_to_rad(8.0)
	sections.append(geometry.build(_level, "YardSurf", geometry.point(yard_plan, yard_start, 30.0),
		geometry.tangent_yaw(yard_plan, yard_start), 1, 30, 52, 14, 0, 1, -1, 1, 4.0, 6.0, 28.0))
	# r12 / the YardSurfEntry jetty that ran from the crossing out over the outflow release is
	# gone: every measured yard takeoff already leaves from the crossing deck itself. its
	# north edge, open between the rails, is painted where the hop onto the bank starts.
	_level.call("_box", Vector3(5.6, 4.012, -77.36), Vector3(6.8, .025, .22), "ochre")
	# p / outflow is a left-hand (A) sluice face, sunlit, alternating with the three D banks.
	# it opens as a banked right sweep beside the run-up's end, then curves left (hold A) under
	# the yard bank and releases toward the wheel.
	var heading := (OUTFLOW_RUNUP_END - OUTFLOW_RUNUP_START).normalized()
	var left := Vector3(heading.z, 0, -heading.x)
	# p / r12: the berm's coping stands 4 m above the deck, so a roof hop that meets it still
	# rising runs out of lift below the top instead of sailing over the S.
	var coping := 7.0
	# p / r12: the face meets deck height 1.2 m outboard of the run-up's left edge, so leaving
	# the deck's end, even at its corner, drops onto the face instead of running into its foot.
	var top := OUTFLOW_RUNUP_END + left * (2.5 + 1.2 + (coping - OUTFLOW_RUNUP_END.y) / tan(deg_to_rad(60.0)))
	# a 12 degree lead-in raises the coping from deck height, so the bank's start face is never
	# a wall beside the deck: drifting left off the run-up meets a rising face instead.
	# r12 / the lead lies on the berm's own plane (face_height): its rising coping only trims
	# that plane. the earlier lead kept its coping on the sweep radius, which twisted its face
	# into a 37 degree crease at the sweep and stopped a 19 m/s arrival dead.
	# its tip starts a metre below the deck, so a runner leaving the deck's left edge passes
	# over it instead of catching the coping's knife edge.
	var lead: Dictionary = geometry.build(_level, "OutflowLead", Vector3(top.x, -6, top.z),
		atan2(-heading.x, -heading.z), 1, 20, 12, OUTFLOW_RUNUP_END.y + 5, 0, 2, coping + 6, -1, 0, 0, 360, coping + 6)
	sections.append(lead)
	# p / r12: the outflow descends on one smooth grade with no step at any joint. the berm
	# drops only 2 m from level, less than a rider pressed into it sinks anyway, so its
	# coping never falls away beneath them; the S, whose face is inside its turn, takes the
	# rest: a rider who loses that face falls back onto it lower. the release is still
	# descending (grade .25), so it passes under the yard bank's leading edge and the yard
	# crossing and lands on the outfall apron. a 38 degree berm aims that release 1.9 m clear
	# of the pump hall's corner, onto the front walk.
	var berm_drop := 2.0
	var berm_grade := .35
	var sweep: Dictionary = geometry.build(_level, "OutflowSweep", geometry.point(lead, lead.arc, lead.radius),
		geometry.tangent_yaw(lead, lead.arc), 1, 20, 38, coping + 6, -berm_drop, 2, -1, -1, 0, 0, 360, -1, [0.0, -berm_grade])
	sections.append(sweep)
	var bend_start := geometry.point(sweep, sweep.arc, sweep.radius)
	sections.append(geometry.build(_level, "OutflowSurf", bend_start, geometry.tangent_yaw(sweep, sweep.arc),
		-1, 20, 30, coping + 6, OUTFLOW_RELEASE_COPING + berm_drop - coping, 2, -1, -1, 0, 0, 360, -1, [-berm_grade, -.25]))
	# p / the face releases southeast toward the gap between hall and front rail; a real
	# outfall apron at walk height, on piers over the basin corner, takes the landing.
	_level.call("_slab", "OutfallApron", Vector3(7.5, -3, -73), Vector2(11.6, 8), .5, "concrete")
	for x: float in [3, 7.5, 12]:
		_level.call("_solid", "OutfallApronPier", Vector3(x, -5.75, -76), Vector3(.9, 5, .9), "old_concrete")
	# r12 / the low release crosses the apron's north edge, so that edge is painted, not
	# railed: a rail there sat in the landing flight. a walker who steps off drops into the
	# shallow basin beside the recovery ramp.
	_level.call("_box", Vector3(4.8, -2.988, -76.86), Vector3(6.2, .025, .22), "ochre")
	# p / a missed outflow bank drops the runner into the basin heading this way: a full-height
	# ramp climbs from the water straight onto the outfall apron, 12 m short of the wheel,
	# instead of a wade back west to the basin exit. r12 / it spans the apron's whole north
	# edge, so a slow release that sinks below the apron lands on the ramp and runs up, and
	# nobody wades into the low space under the apron. the low release flies well above it.
	_level.call("_wedge", "OutfallRecoveryRamp", Vector3(7.45, -6, -83), Vector3(7.45, -3, -77), 11.5, "concrete")
	for x: float in [1.8, 13.1]:
		_level.call("_beam", Vector3(x, -5.988, -83), Vector3(x, -2.988, -77), .12, "ochre")
	_level.call("_beam", Vector3(1.7, -5.97, -83), Vector3(13.2, -5.97, -83), .08, "ochre")


func _make_basin() -> void:
	_level.call("_slab", "OutflowRecoveryFloor", Vector3(-.5, -6, -82), Vector2(33, 42), .8, "old_concrete")
	_level.call("_water", "ShallowOutflowBasin", Vector3(-.5, -5.73, -82), Vector2(33, 42), "water")
	var water: Array = _level.get("water_regions")
	water.append({"bounds": AABB(Vector3(-17, -6.1, -103), Vector3(33, .65, 42)), "depth": .27})
	(_level.get("water_audio_sources") as Array).append(Vector3(-0.5, -5.73, -82.0))
	# the long dry edge and inclined exit turn a miss into distance, never a reset.
	# p / the dry edge stops where the outflow berm's foot meets the basin floor.
	_walk("BasinWestEdge", Vector3(-16, -5.65, -94.5), Vector3(-16, -5.65, -80), 3.0, false)
	_walk("BasinEdgeAccess", Vector3(-12, -6, -83), Vector3(-14.5, -5.65, -83), 3.0, false)
	_walk("BasinExitRamp", Vector3(-10, -6, -79), Vector3(-10, -3, -65), 5.0, false)
	# r12 / a culvert sill across the pocket mouth was tried and removed: the basin exit is
	# walkable from every lane without a jump, and a sill made that hop compulsory.
	# p / painted safety hardware makes the existing ramp read from water level.
	for x: float in [-12.4, -7.6]:
		_level.call("_rail", Vector3(x, -6, -79), Vector3(x, -3, -65), "ochre")
	_level.call("_beam", Vector3(-12.35, -5.95, -78.7), Vector3(-7.65, -5.95, -78.7), 0.08, "ochre")
	_level.call("_solid", "BasinRampHeadstock", Vector3(-12.85, -5.3, -79), Vector3(0.14, 1.4, 0.14), "steel")
	_level.call("_box", Vector3(-12.85, -4.58, -79), Vector3(0.18, 0.1, 0.18), "ochre")
	_level.call("_slab", "BasinExitLanding", Vector3(-10, -3, -63.5), Vector2(5, 3), .5, "concrete")
	# p / a 1.6 m service joint over the basin breaks the long walk from the west exit; a
	# missed hop drops back into the shallow water, beside the outfall ramp.
	_walk("BasinFrontWalk", Vector3(-7.5, -3, -65), Vector3(1.2, -3, -65), 8.0, false)
	_walk("BasinFrontWalk", Vector3(2.8, -3, -65), Vector3(24, -3, -65), 8.0, false)
	_level.call("_rail", Vector3(-7.5, -3, -62.1), Vector3(1.15, -3, -62.1))
	_level.call("_rail", Vector3(2.85, -3, -62.1), Vector3(7, -3, -62.1))
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
		# p / a shallow girder crossing: its fascia hangs only 0.7 m, so the outflow release
		# passes beneath with headroom and the lower basin stays open.
		for sign_value: float in [-1.0, 1.0]:
			var edge_a := a + side * sign_value
			var edge_b := b + side * sign_value
			_level.call("_beam", edge_a - Vector3.UP * .7, edge_b - Vector3.UP * .7, .24, "steel", true)
			var bays := ceili(a.distance_to(b) / 2.9)
			for section: int in bays:
				var left := edge_a.lerp(edge_b, float(section) / bays)
				var right := edge_a.lerp(edge_b, float(section + 1) / bays)
				_level.call("_beam", left - Vector3.UP * .5, right - Vector3.UP * .7, .12, "steel", true)

	var count: int = 1 if label == "YardEntryRamp" else maxi(1, ceili(a.distance_to(b) / 7.0))
	for i: int in count + 1:
		var p: Vector3 = a.lerp(b, float(i) / count)
		var bottom: float = -8.5
		var supports: Array[Vector3] = []
		if label != "YardEntryCrossing":
			supports.append(p)
		if label == "OutflowRunup" and i == count:
			# the berm starts at the deck end; its pier stands back from the face.
			supports = [b.move_toward(a, 1.2)]
		if label == "YardApronDescent" and i == 0:
			# share the relocated culvert pier; the basin exit ramp keeps its full width below.
			supports = [a.lerp(b, 1.75 / 6.0)]
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
		# south of the entry ramp's rail end, so the westward turn never clips it.
		_p(Vector3(8.5, 4, -75)),
		# p / keep aiming along the landing deck after the joint: the redundant near marker
		# made a W-only hop circle back when its carried sideways speed passed that marker.
		_p(Vector3(-.9, 4, -74), .45, false, true), _p(Vector3(-12, 4, -74)),
		_p(Vector3(-18, 1.5, -74), 1.0, true),
	]
	# p / the beginner line cuts diagonally through the opened gate instead of two square turns.
	# r12 / every stage-0 line turns through the gate's middle, clear of the canopy columns.
	for name: String in ["safe", "wet", "brake", "recovery"]:
		var level_route: Array = _level.get("routes")[name]
		if level_route[-1].pos == Vector3(11, 4, -59):
			level_route.remove_at(level_route.size() - 1)
			level_route.append_array([_p(Vector3(10.3, 4, -59.2), 1.2),
				_p(Vector3(9.9, 4, -69.5))])
	var safe: Array = common.duplicate()
	safe.append_array([
		_p(Vector3(-27, 1.5, -75)), _p(Vector3(-27, 1.5, -79.5), .85),
		_p(Vector3(-27, 1.5, -84), .9, true), _p(Vector3(-27, 1.5, -90)),
		_p(Vector3(-27, 3, -101)),
		_p(Vector3(-28, 3, -104)), _p(Vector3(-18.5, 3, -106)),
		_p(Vector3(-5, 0, -106), 1.0, true),
		_p(Vector3(6.3, 0, -106), .45, false, true), _p(Vector3(12, 0, -106)),
		_p(Vector3(22.8, 0, -106), .45, false, true), _p(Vector3(28, 0, -106)), _p(Vector3(37, 0, -106)),
		_p(Vector3(37, -.6, -102), 1.5), _p(Vector3(37, -3, -85), 1.0, true), _p(Vector3(37, -3, -77.2), .45, false, true),
		_p(Vector3(37, -3, -71.5)), _p(Vector3(37, -3, -64)), _p(Vector3(23.8, -3, -68.8)),
	])
	var recovery: Array = common.duplicate()
	recovery.append_array([
		_p(Vector3(-27, 1.5, -75)), _p(Vector3(-27, 1.5, -79.5), .85),
		_p(Vector3(-27, 1.5, -84), .9, true), _p(Vector3(-27, 1.5, -90)),
		_p(Vector3(-25.5, 3, -100.5)),
		_p(Vector3(-17.5, 3, -100.05), 1.3), _p(Vector3(-14.4, 3, -98.2), .8, false, true),
		# the miss: a straight hop off the run-up's end sails over the bank's low lead. slide
		# through the shallow water to the foot of the west exit, climb it and hop the front
		# walk's joint to the wheel.
		_p(Vector3(-10.8, -6, -84.6), 2.4, true), _p(Vector3(-10.2, -6, -79.6), 1.0, true),
		_p(Vector3(-10, -3, -64.5), 1.3), _p(Vector3(0.0, -3, -64.6), .45, false, true),
		_p(Vector3(5, -3, -64.8)), _p(Vector3(15, -3, -65)), _p(Vector3(23.8, -3, -68.8)),
	])
	var routes: Dictionary = _level.get("routes")
	routes["safe"].append_array(safe)
	routes["recovery"].append_array(recovery)
	routes["brake"].append_array(safe)
	routes["wet"].append_array(safe)
	# input regression for the ordinary west corner that missed the original sphere.
	var corner: Array = routes["safe"].duplicate(true)
	for i: int in corner.size():
		if corner[i].pos == Vector3(-9, 4, -58.8):
			corner[i] = _p(Vector3(-9, 4, -56.5))
			break
	routes["safe_corner"] = corner
	# r12 / fast uses spillway_surf_driver; the old stepping blocks and apron/run-up
	# rail-hop junction are gone. those waypoint variants are explicitly retired.
	routes.erase("fast")


func _p(pos: Vector3, radius: float = 1.0, crouch: bool = false, jump: bool = false) -> Dictionary:
	return {"pos": pos, "radius": radius, "crouch": crouch, "jump": jump}
