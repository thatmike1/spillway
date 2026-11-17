extends Node3D
## mike's uncertain single-handoff spitball; control switches bodies, never clean bests.
var runner: CharacterBody3D
var phase := "first"
var transferring := false
var waiting := {}
var first_seconds := 0.0
var misses := 0
var throws := 0
var flying := false
var flight_seconds := 0.0
var cooldown := 0.0
var projectile_position := Vector3.ZERO
var projectile_velocity := Vector3.ZERO
var notice := ""
var waiting_body: MeshInstance3D
var delivery_body: MeshInstance3D
var envelope_mesh: MeshInstance3D
var readout: Control
func game() -> Node:
	return runner.get_parent()
func map() -> Node:
	return game().get("level")
func active() -> bool:
	return map() != null and bool(map().envelope_enabled)
func _ready() -> void:
	waiting_body = body(Color(0.12,0.44,0.53,0.75))
	delivery_body = body(Color(0.8,0.65,0.45,0.45))
	var recipient := Label3D.new()
	recipient.text = "YOUR WAITING BODY"
	recipient.position.y = 1.22
	recipient.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	recipient.font_size = 40
	recipient.pixel_size = 0.006
	recipient.modulate = Color("b4e6ed")
	recipient.outline_modulate = Color("203d45")
	recipient.outline_size = 5
	waiting_body.add_child(recipient)
	var target_ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.61
	target_ring.mesh = torus
	target_ring.position.y = -0.85
	target_ring.material_override = material(Color("64bbc9"))
	target_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	waiting_body.add_child(target_ring)
	envelope_mesh = MeshInstance3D.new()
	var paper := BoxMesh.new()
	paper.size = Vector3(0.25,0.16,0.025)
	envelope_mesh.mesh = paper
	envelope_mesh.material_override = material(Color("efe8cf"))
	envelope_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(envelope_mesh)
	for direction: float in [-1,1]:
		var seam := MeshInstance3D.new()
		var strip := BoxMesh.new()
		strip.size = Vector3(0.135,0.006,0.028)
		seam.mesh = strip
		seam.position = Vector3(direction*0.06,0.022,0)
		seam.rotation.z = direction*0.58
		seam.material_override = material(Color("31555e"))
		envelope_mesh.add_child(seam)
	var layer := CanvasLayer.new()
	layer.layer = 31
	add_child(layer)
	readout = Readout.new()
	readout.relay = self
	layer.add_child(readout)
	reset()
func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return result
func body(color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.28
	capsule.height = 1.75
	mesh.mesh = capsule
	mesh.material_override = material(color)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	mesh.top_level = true
	return mesh
func reset() -> void:
	if transferring or (active() and bool(game().finished) and phase == "resumed"):
		if active():
			mark_practice()
		return
	phase = "first"
	waiting = {}
	first_seconds = 0.0
	misses = 0
	throws = 0
	flying = false
	cooldown = 0.0
	notice = ""
	if map() != null:
		map().envelope_delivered = false
	if waiting_body != null:
		waiting_body.hide()
		delivery_body.hide()
		envelope_mesh.hide()
	if active():
		mark_practice()
func mark_practice() -> void:
	game().clean_eligible = false
	game().practice_reason = "envelope prototype"
	game().practice_stage = 0
func park() -> void:
	if phase != "first" or game().finished:
		notice = "One handoff. R restarts both legs."
		return
	if not runner.is_grounded() or runner.ducked:
		notice = "Land, release Space, then K."
		return
	first_seconds = float(game().elapsed)
	waiting = {"position":runner.global_position,"yaw":runner.yaw,"pitch":runner.pitch,
		"velocity":runner.velocity,"state":runner.state.duplicate(true),"pad_used":runner.used_pad,"launches":runner.launch_events.duplicate(true)}
	runner.block_tether("envelope_wait")
	waiting_body.global_position = runner.global_position+Vector3.UP*0.875
	waiting_body.show()
	phase = "carry"
	transferring = true
	runner.reset_to(map().spawn)
	transferring = false
	mark_practice()
	game()._rebase_compensation()
	game()._clear_speed()
	game().stats.watch(runner)
	game().session.lifecycle("practice",{"phase":"plan_envelope_wait","position":map().spawn.origin,"waiting":waiting.position,"first_seconds":first_seconds},"envelope_wait",true)
	notice = ""
func throw_envelope() -> void:
	if phase != "carry" or flying or cooldown > 0 or game().finished:
		return
	var heading := Basis(Vector3.UP,float(runner.yaw))*Basis(Vector3.RIGHT,float(runner.pitch))
	projectile_position = runner.global_position+Vector3.UP*float(runner._eye_u)*runner.U
	projectile_velocity = -heading.z*18.0+runner.velocity*0.25
	flying = true
	flight_seconds = 0.0
	throws += 1
	notice = ""
	game().session.lifecycle("plan_envelope_throw",{"position":projectile_position,"velocity":projectile_velocity})
func miss() -> void:
	flying = false
	cooldown = 0.35
	misses += 1
	notice = "Miss. E retries."
	game().session.lifecycle("plan_envelope_miss",{"misses":misses})
func step(delta: float) -> void:
	if not active() or runner.planning or game().paused:
		return
	cooldown = maxf(0,cooldown-delta)
	if not flying:
		return
	flight_seconds += delta
	var next := projectile_position+projectile_velocity*delta+Vector3.DOWN*4.9*delta*delta
	var centre: Vector3 = waiting.position+Vector3.UP
	var nearest := Geometry3D.get_closest_point_to_segment(centre,projectile_position,next)
	var space := runner.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(projectile_position,next,1,[runner.get_rid()])
	var hit := space.intersect_ray(ray)
	var sight := space.intersect_ray(PhysicsRayQueryParameters3D.create(projectile_position,centre,1,[runner.get_rid()]))
	if nearest.distance_to(centre) <= 1.6 and sight.is_empty() and (hit.is_empty() or projectile_position.distance_to(nearest) < projectile_position.distance_to(hit.position)):
		resume_waiting()
		return
	if not hit.is_empty() or flight_seconds >= 3.0:
		miss()
		return
	projectile_position = next
	projectile_velocity += Vector3.DOWN*9.8*delta
func resume_waiting() -> void:
	flying = false
	delivery_body.global_position = runner.global_position+Vector3.UP*0.875
	delivery_body.show()
	waiting_body.hide()
	transferring = true
	runner.block_tether("envelope_handoff")
	runner.reset_to(Transform3D(Basis.IDENTITY,waiting.position))
	runner.state = waiting.state.duplicate(true)
	runner.velocity = waiting.velocity
	var onward: Vector3 = map().finish_position-waiting.position
	runner.yaw = atan2(-onward.x,-onward.z) if Vector2(onward.x,onward.z).length_squared() > 0.000001 else float(waiting.yaw)
	runner.pitch = 0.0
	runner._tick_yaw = runner.yaw
	runner.used_pad = waiting.pad_used
	runner.launch_events.assign(waiting.launches)
	transferring = false
	phase = "resumed"
	map().envelope_delivered = true
	mark_practice()
	game()._rebase_compensation()
	game()._clear_speed()
	game().stats.watch(runner)
	game().session.lifecycle("practice",{"phase":"plan_envelope_catch","position":waiting.position,"throws":throws},"envelope_handoff",true)
	notice = ""
func snapshot() -> Dictionary:
	return {"version":"plan-envelope-3","phase":phase,"waiting":waiting.get("position",Vector3.ZERO),
		"first_seconds":first_seconds,"throws":throws,"misses":misses,"flying":flying,"projectile":projectile_position}
func _process(_delta: float) -> void:
	var visible_now: bool = active() and not runner.planning and not game().paused and not game().finished
	readout.visible = visible_now
	envelope_mesh.visible = visible_now and phase == "carry"
	if envelope_mesh.visible:
		if flying:
			envelope_mesh.global_position = projectile_position
		else:
			var camera: Camera3D = runner.camera
			envelope_mesh.global_transform = camera.global_transform
			envelope_mesh.global_position += camera.global_basis.x*0.35-camera.global_basis.y*0.32-camera.global_basis.z*0.65
	readout.queue_redraw()
class Readout extends Control:
	var relay: Node3D
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var x := 30.0
		var y := 275.0
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(x,y,350,64),Color("203d45"))
		var detail := "K parks you; then bring the envelope."
		var title := "Envelope spitball · first body"
		if relay.phase == "carry":
			title = "You carry the envelope"
			detail = "Flying to your waiting body." if relay.flying else "E throws to your waiting body · %.1f m" % relay.runner.global_position.distance_to(relay.waiting.position)
		elif relay.phase == "resumed":
			title = "You are the first body again"
			detail = "Envelope received. Finish ahead."
		if not relay.notice.is_empty():
			detail = relay.notice
		draw_string(font,Vector2(x+12,y+23),title,HORIZONTAL_ALIGNMENT_LEFT,326,16,Color("efe8cf"))
		draw_string(font,Vector2(x+12,y+47),detail,HORIZONTAL_ALIGNMENT_LEFT,326,16,Color("efe8cf"))
