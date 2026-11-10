extends SceneTree
## bounded service failures remove only their incomplete output and preserve all source bytes.
const EXPORT := preload("res://scripts/r20_run_export.gd")
var output := ""
var checks: Array = []
class TotalBound extends EXPORT:
	func _hash(_path: String) -> Dictionary:
		return {"ok": true, "size": MAX_FILE, "sha256": "0".repeat(64)}
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks.append({"ok": ok, "check": text})
	print("ok " if ok else "FAIL ", text)
func put(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output.path_join("runs"))
	var source := output.path_join("runs/broken.r16run")
	put(source, PackedByteArray([1, 2, 3, 0, 255]))
	var service := EXPORT.new()
	service.folder_opener = func(_folder: String) -> int: return OK
	var folder := output.path_join("exports")
	var call_export := func() -> Dictionary: return service.collect(output.path_join("runs"), output, "", {}, folder, "Failure fixtures", "r20-fixture")
	var hash := FileAccess.get_sha256(source)
	service.free_space_probe = func(_path: String) -> int: return 1
	var low: Dictionary = call_export.call()
	check(not low.ok and "space" in low.error and not DirAccess.dir_exists_absolute(folder), "actual export-volume estimate fails before output creation")
	service.free_space_probe = Callable()
	service.fail_after_bytes = 1
	var failed: Dictionary = call_export.call()
	check(not failed.ok and DirAccess.get_files_at(folder).is_empty(), "archive write failure cleans incomplete output")
	check(FileAccess.get_sha256(source) == hash, "write failure preserves source bytes")
	service.fail_after_bytes = -1
	service.before_copy = func() -> void: put(source, PackedByteArray([8, 2, 3, 0, 255]))
	var race: Dictionary = call_export.call()
	check(not race.ok and "changed" in race.error and DirAccess.get_files_at(folder).is_empty(), "same-size hash race refuses and cleans output")
	check(FileAccess.get_file_as_bytes(source) == PackedByteArray([8, 2, 3, 0, 255]), "raced source is never deleted renamed or reverted")
	service.before_copy = Callable()
	var big := output.path_join("runs/oversized.r16run")
	var f := FileAccess.open(big, FileAccess.WRITE)
	f.seek(EXPORT.MAX_FILE)
	f.store_8(0)
	f.close()
	var oversized: Dictionary = call_export.call()
	check(not oversized.ok and "64 MiB" in oversized.error, "oversized source fails with explicit limit")
	DirAccess.remove_absolute(big)
	var total_service := TotalBound.new()
	for i: int in 9:
		put(output.path_join("runs/total-%d.r16run" % i), PackedByteArray())
	var total := total_service.inventory(output.path_join("runs"), output, "")
	check(not total.ok and "512 MiB" in total.error, "aggregate 512 MiB inventory bound (explicit size-only fault seam)")
	for i: int in 9:
		DirAccess.remove_absolute(output.path_join("runs/total-%d.r16run" % i))
	for i: int in 4097:
		put(output.path_join("runs/count-%d.r16run" % i), PackedByteArray())
	var many := service.inventory(output.path_join("runs"), output, "")
	check(not many.ok and "4096" in many.error, "actual excessive file count is refused without omission")
	for i: int in 4097:
		DirAccess.remove_absolute(output.path_join("runs/count-%d.r16run" % i))
	var blocked := output.path_join("blocked")
	put(blocked, PackedByteArray([42]))
	var cant_open := service.collect(output.path_join("runs"), output, "", {}, blocked, "IO fixture", "r20")
	check(not cant_open.ok and FileAccess.get_file_as_bytes(blocked) == PackedByteArray([42]), "actual folder creation I/O failure never replaces existing file")
	var recorder := preload("res://scripts/r16_run_recorder.gd").new()
	recorder.begin_run({"map": "fault"}, output.path_join("recorder-fault"))
	recorder.event("pause")
	recorder.fail_after_bytes = int(recorder.get("_bytes"))
	var flush := service.flush_open_attempt(recorder)
	check(not flush.ok and recorder.status == "disk-error" and FileAccess.file_exists(recorder.path), "existing recorder flush failure is candid and preserves partial source")
	check(not service.collect("", output, "", {}, folder, "", "test").ok, "empty player label refused")
	check(not EXPORT.safe_name("../bad") and not EXPORT.safe_name("C:/bad") and not EXPORT.safe_name("a\\b") and not EXPORT.safe_name("CON.txt"), "portable path contract")
	service.free_space_probe = func(_path: String) -> int: return 24 * 1024 * 1024
	var small_volume: Dictionary = call_export.call()
	check(small_volume.ok, "shipping export works with only 24 MiB free on destination (no 15 GB friend HOME requirement)")
	var archive := FileAccess.get_file_as_bytes(small_volume.path)
	var text := JSON.stringify(small_volume.manifest, "", true, true).to_utf8_buffer()
	var bad_path := output.path_join("mutated.zip")
	var truncated := archive.slice(0, archive.size() - 8)
	put(bad_path, truncated)
	check(not service._verify_archive(bad_path, small_volume.manifest.entries, text), "independent archive verifier refuses truncated end record")
	var damaged := archive.duplicate()
	var hex := damaged.hex_encode()
	var at := hex.find("08020300ff") / 2
	check(at >= 0, "actual level-zero archive contains source payload bytes")
	damaged[int(at)] ^= 1
	put(bad_path, damaged)
	check(not service._verify_archive(bad_path, small_volume.manifest.entries, text), "independent streaming SHA check refuses damaged archive payload")
	var central := archive.duplicate()
	var signature := central.hex_encode().find("504b0102") / 2
	central[int(signature) + 16] ^= 1
	put(bad_path, central)
	check(not service._verify_archive(bad_path, small_volume.manifest.entries, text), "independent verifier refuses mismatched local/central CRC metadata")
	DirAccess.remove_absolute(bad_path)
	# sparse/zero fixtures never survive into accepted retained evidence.
	var file := FileAccess.open(output.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": checks.all(func(row: Dictionary) -> bool:return row.ok), "checks": checks}, "\t"))
	file.close()
	quit(0 if checks.all(func(row: Dictionary) -> bool:return row.ok) else 1)
