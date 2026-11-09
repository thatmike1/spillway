extends RefCounted
## playtest-backed collision edits are explicit revisions of the inherited optional geometry.

const VERSION := "r19-breakwater-flow-1"
const META := "r19_course_revision"

static func apply(level: Node3D) -> Dictionary:
	if level.has_meta(META):
		return (level.get_meta(META) as Dictionary).duplicate(true)
	if str(level.get("level_id")) != "r15-breakwater":
		return {}
	var installation := level.get_node_or_null("R16Opportunities/RunwayThread") as Node3D
	if installation == null:
		return {}
	var before: Dictionary = (level.get_meta("r16_opportunities") as Dictionary).duplicate(true)
	var report := before.duplicate(true)
	report["previous_version"] = before.version
	report["previous_hash"] = before.hash
	report["version"] = VERSION
	report["reason"] = "widen_optional_thread_after_repeated_front_contacts"
	for side: int in [-1, 1]:
		var body := installation.get_node("WestWall" if side < 0 else "EastWall") as StaticBody3D
		body.position.x = side * 1.175
	# the visual cue follows the widened west wall; it does not change the collision identity.
	(installation.get_node("Cue") as Node3D).position.x = -1.175
	for opportunity: Dictionary in report.opportunities:
		if str(opportunity.name) != "RunwayThread":
			continue
		opportunity.opening_m.width = 2.05
		for solid: Dictionary in opportunity.solids:
			var body := installation.get_node(str(solid.name)) as StaticBody3D
			solid.world_origin_m = [body.global_position.x, body.global_position.y, body.global_position.z]
	report.erase("hash")
	report["hash"] = JSON.stringify(report).sha256_text()
	level.set_meta(META, report.duplicate(true))
	return report
