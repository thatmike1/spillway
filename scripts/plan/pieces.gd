extends RefCounted
## fixed-height equipment zones keep overhead placement unambiguous.
const VERSION := "plan-pieces-1"
const LAUNCH := preload("res://scripts/r19_line_drive_player.gd")
const BLOCKS := {3: Vector3(-8,3,-19.5), 4: Vector3(0,8,-16.5), 5: Vector3(8,3,-19.5)}
const PADS := {3: Vector3(-14,3,-11), 4: Vector3(0,7,-13), 5: Vector3(14,3,-11), 7: Vector3(0,9,-25.5)}
static func count(anchors: Array, block: int, pad: int) -> int:
	return anchors.size() + int(block >= 0) + int(pad >= 0)
