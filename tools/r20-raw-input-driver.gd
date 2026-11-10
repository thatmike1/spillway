extends RefCounted
## ordered reader-derived input only; the file is a parent-verified private probe fixture.
var frames: Dictionary = {}
var duration := 0
var held: Dictionary = {}
var omit_right := false

func configure(path: String, automatic: bool = false) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 4 * 1024 * 1024:
		return false
	var text := file.get_as_text()
	file.close()
	var value: Variant = JSON.parse_string(text)
	if value is not Dictionary or int(value.get("version", 0)) != 2 or int(value.get("physics_hz", 0)) != 128:
		return false
	duration = int(value.get("duration_ticks", 0))
	if duration <= 0 or duration > 80000 or value.get("events") is not Array:
		return false
	omit_right = automatic
	for item: Variant in value.events:
		if item is not Dictionary or item.get("raw") is not Dictionary or int(item.get("tick", -1)) < 0 or int(item.tick) >= duration:
			return false
		var row: Dictionary = item.raw
		if int(row.get("kind", 0)) not in [1, 2, 3]:
			return false
		if not frames.has(int(item.tick)):
			frames[int(item.tick)] = []
		frames[int(item.tick)].append(row)
	return true

func step(tick: int) -> void:
	for row: Dictionary in frames.get(tick, []):
		if omit_right and int(row.kind) == 2 and int(row.code) == MOUSE_BUTTON_RIGHT:
			continue
		dispatch(row)

func dispatch(row: Dictionary) -> void:
	var event: InputEvent
	if int(row.kind) == 1:
		var key := InputEventKey.new()
		key.keycode = int(row.code)
		key.physical_keycode = int(row.aux)
		key.pressed = (int(row.flags) & 1) != 0
		key.echo = (int(row.flags) & 2) != 0
		event = key
	elif int(row.kind) == 2:
		var button := InputEventMouseButton.new()
		button.button_index = int(row.code)
		button.pressed = (int(row.flags) & 1) != 0
		button.double_click = (int(row.flags) & 4) != 0
		button.factor = float(row.x)
		event = button
	else:
		var motion := InputEventMouseMotion.new()
		motion.screen_relative = Vector2(float(row.x), float(row.y))
		motion.relative = Vector2(float(row.x2), float(row.y2))
		event = motion
	if int(row.kind) in [1, 2]:
		var id := "%d:%d" % [int(row.kind), int(row.code)]
		if (int(row.flags) & 1) != 0:
			held[id] = row.duplicate()
		else:
			held.erase(id)
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func release() -> void:
	for row: Dictionary in held.values().duplicate():
		row = row.duplicate()
		row.flags = 0
		dispatch(row)
