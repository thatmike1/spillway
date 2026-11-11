extends "r20-pack-probe.gd"
## r21 preparation retains the r20/r16 observer chain, but has no approved runtime fixtures yet.
## never inherit an r20 success as r21 acceptance or replace its identity strings blindly.

func _start() -> void:
	report["mode"] = str(spec.get("mode", "startup"))
	report["r21"] = {"ok": false, "production_probes_pending": true}
	check("R21 production fixtures require reviewed runtime integration", false)
	printerr("r21 pack probe: pending host identity, Saltglass physics/skill lines, acquisition/occlusion, variant routes/replays and clip-clearance controls")
	# the inherited end path seals a failure report and exits nonzero; no runtime mutation.
	_end("R21 production probes are not implemented; preparation is not release acceptance")
