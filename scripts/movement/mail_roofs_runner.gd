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
