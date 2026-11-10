extends "res://scripts/r19_tether_level.gd"
## the complete original collision/art course; only its control lettering and hints change.
func _sign(id: String, at: Vector3, text: String, pixels: float) -> void:
	var copy := text.replace("HOLD E TO REEL IN", "LMB HOLD / RMB REEL").replace("RELEASE E, AIM, HOLD AGAIN", "RELEASE LMB, AIM, HOLD AGAIN").replace("HOLD E", "HOLD LMB")
	super(id, at, copy, pixels)

func route_hint(stage: int, _feet: Vector3) -> String:
	if stage < 3:
		return "Hold LMB at a ring to swing; RMB reels (or use automatic reel in Esc). Release LMB to coast. Jump to lift; aim at the next ring."
	return "Land on the dispatch deck and cross its far end. The catch court and return ramps stay open."
