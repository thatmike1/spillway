extends "res://tests/r14_practice_review_contacts.gd"
## p regression: a wall-hugging walker must enter the tail return without a sideways rescue.
## each episode starts once on clear pit floor. only held W acts after that setup.
var failures := 0
var checks: Array = []

func _run() -> void:
	await super._run()
	quit(1 if failures > 0 else 0)

func _locals() -> void:
	for rate: int in [64, 128]:
		for x: float in [-228.28, -228.05, -227.8, -227.4, -226.0]:
			var case_name := "tail_return_%d_x%s" % [rate, x]
			if opts.has("only") and str(opts.only) != case_name:
				continue
			await run_episode({"name": case_name, "hz": rate,
				"p": Vector3(x, -3.9988, -137.4), "yaw": PI, "grounded": true,
				"policy": "run", "ticks": rate * 7})
			var result: Dictionary = results.back()
			var clear: bool = (result.setup.setup_overlaps as Array).is_empty()
			var climbed: bool = rows.any(func(row: Dictionary) -> bool: return float(row.p[1]) > -0.05 and float(row.p[2]) > -118.6)
			var only_forward: bool = rows.all(func(row: Dictionary) -> bool: return (row.keys as Array) == ["w"])
			var ok := clear and climbed and only_forward
			checks.append({"name": result.name, "ok": ok, "initially_clear": clear,
				"climbed": climbed, "only_w": only_forward, "end": result.end})
			if not ok:
				failures += 1
				printerr("FAIL tail return: ", checks.back())
	if checks.is_empty():
		failures += 1
		printerr("FAIL tail return: no case matched --only")
	var file := FileAccess.open(out.path_join("CHECKS.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failed": failures}, "\t"))
	file.close()
	print("tail return: %d cases, %d failed" % [checks.size(), failures])
