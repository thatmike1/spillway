extends RefCounted
## each invocation owns its own caller-provided output or isolated userdata child.
static func output() -> String:
	var folder := OS.get_user_data_dir().path_join("run-review-test-%d" % OS.get_process_id())
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): folder = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(folder)
	return folder
