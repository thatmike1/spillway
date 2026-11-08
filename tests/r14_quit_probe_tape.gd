extends "res://tools/momentum-tape.gd"
## p / r14 quit investigation only: the unchanged tape executor plus a marker when the
## engine finalizes the main loop, the last point script code runs before engine cleanup.

func _finalize() -> void:
	var path := str(opts.get("quit-markers", ""))
	if path.is_empty():
		return
	var file := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if file != null:
		file.seek_end()
		file.store_line("%d %d main loop finalize" % [Time.get_ticks_usec(), Engine.get_process_frames()])
		file.close()
