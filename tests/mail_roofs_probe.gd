extends Node
## inspect the same late-physics state a forced capture sees, before idle-process presentation.
var game: Node
var flight_checks := 0
var finish_checks := 0

func clear_counts() -> void:
	flight_checks = 0
	finish_checks = 0

func _physics_process(_dt: float) -> void:
	if not is_instance_valid(game) or game.is_queued_for_deletion() or game.paused:
		return
	var runner: Node = game.player
	if not is_instance_valid(runner):
		return
	if game.finished:
		finish_checks += 1
		if runner._status.visible:
			_fail("finish ticket remains visible")
		return
	if not runner.input_enabled:
		return
	if runner.mail_flight.active:
		flight_checks += 1
		var text: String = runner._status.text
		var body := "Body held" if runner.body_mode == "hold" else "Body running"
		var camera := "Envelope camera" if runner.view_mode == "envelope" else "Runner camera"
		if not "STEERING" in text or not body in text or not camera in text:
			_fail("flight ticket was overwritten before the captured physics sample")
	for i: int in 5:
		if runner.mail_flight.delivered.has("mail-roofs-post-%d" % (i + 1)):
			if game.level.get_node("Mail_number_%d" % i).text != "SENT":
				_fail("completed slot plate was not updated")

	var cue: Label3D = game.level.get_node("Mail_window_cue")
	var sent_03: bool = runner.mail_flight.delivered.has("mail-roofs-post-3")
	if cue.visible == sent_03 or not "PASS CHIMNEY" in cue.text or not "THEN LEFT" in cue.text:
		_fail("window turn cue is missing or contradicts the delivered state")

func _fail(reason: String) -> void:
	push_error("MAIL ROOFS late physics UI: " + reason)
	set_physics_process(false)
	get_tree().quit(1)
