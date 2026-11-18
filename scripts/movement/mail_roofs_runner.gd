extends "res://scripts/movement/mail_runner.gd"
## the roof loop has five unordered slots and one full-loop practice stage.
func movement_version() -> String:
	return "mail-roofs-1/%s/%s/%s" % [body_mode, view_mode, goal_mode]

func delivery_progress() -> Vector2i:
	var level: Variant = get_parent().get("level")
	if level == null:
		return Vector2i(0, 5)
	var count := 0
	for slot: Dictionary in level.mailboxes:
		if mail_flight.delivered.has(str(slot.id)):
			count += 1
	return Vector2i(count, level.mailboxes.size())

func _physics_process(delta: float) -> void:
	super(delta)
	_refresh_roof_ticket()

func _process(delta: float) -> void:
	super(delta)
	if bool(get_parent().get("finished")):
		_status.visible = false

func _refresh_roof_ticket() -> void:
	var host := get_parent()
	if not input_enabled or bool(host.get("finished")):
		_status.visible = false
		return
	var level: Variant = host.get("level")
	if level == null:
		return
	var open: Array[String] = []
	for i: int in 5:
		var sent: bool = mail_flight.delivered.has("mail-roofs-post-%d" % (i + 1))
		if not sent:
			open.append("%02d" % (i + 1))
		var plate: Label3D = level.get_node_or_null("Mail_number_%d" % i)
		if plate != null:
			plate.text = "SENT" if sent else "%02d" % (i + 1)
			plate.pixel_size = 0.014 if sent else 0.022
		if i == 2:
			level.get_node("Mail_window_cue").visible = not sent
			level.get_node("Mail_window_number").text = "SENT" if sent else "03"
			level.get_node("Mail_window_number").pixel_size = 0.014 if sent else 0.025
	_status.text = "MAIL %d / 5    MISSES %d" % [mail_flight.delivered.size(), mail_flight.misses]
	var view := "Envelope camera" if view_mode == "envelope" else "Runner camera"
	var body := "Body held" if body_mode == "hold" else "Body running"
	if mail_flight.active:
		_status.text += "\nSTEERING · " + body
		_status.text += "\n%s · RMB recall · %.1fs" % [view, maxf(0, FLIGHT.DURATION - mail_flight.age)]
		if body_mode == "hold":
			_status.text += "\nKEPT %.0f u/s" % (control_speed() / U)
	else:
		_status.text += "\n" + ("RETURN TO DISPATCH" if open.is_empty() else ("Optional open: " if goal_mode == "optional" else "Open slots: ") + " ".join(open))
		_status.text += "\n%s · %s" % [view, body]
		if not bool(host.get("_started")):
			_status.text += "\nLMB throw · mouse steer · RMB recall"
