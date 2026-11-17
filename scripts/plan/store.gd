extends RefCounted
## bounded plan slots reuse the project's checked atomic profile backend.
const BACKEND := preload("res://scripts/persistence/profile_store.gd")
const LAYOUT := preload("res://scripts/plan/layout.gd")
const PIECES := preload("res://scripts/plan/pieces.gd")
const FORMAT := "spillway-plan-yard-1"
const MAX_BYTES := 16384
var path := "user://plan-yard-plans.cfg"
var backend := BACKEND.new()
static func integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high and float(value) == int(value)
static func normalize(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {"ok":false,"error":"Saved plan is not a plan."}
	var keys := ["version","anchors","block","pad","budget","blocks_enabled","pads_enabled"]
	if value.size() != keys.size() or not keys.all(func(key: String) -> bool: return value.has(key)):
		return {"ok":false,"error":"Saved plan has an unsupported shape."}
	if value.version != PIECES.VERSION or not integer(value.budget,1,3) or int(value.budget) not in [1,3]:
		return {"ok":false,"error":"Saved plan uses an unsupported version or budget."}
	if not value.blocks_enabled is bool or not value.pads_enabled is bool or not LAYOUT.valid(value.anchors,int(value.budget)):
		return {"ok":false,"error":"Saved plan has invalid pieces or settings."}
	if not integer(value.block,-1,8) or not integer(value.pad,-1,8):
		return {"ok":false,"error":"Saved equipment zone is invalid."}
	var block := int(value.block)
	var pad := int(value.pad)
	if block >= 0 and (not value.blocks_enabled or not PIECES.BLOCKS.has(block)):
		return {"ok":false,"error":"Saved block is not in an enabled block zone."}
	if pad >= 0 and (not value.pads_enabled or not PIECES.PADS.has(pad)):
		return {"ok":false,"error":"Saved pad is not on an enabled deck."}
	if PIECES.count(value.anchors,block,pad) > int(value.budget):
		return {"ok":false,"error":"Saved plan exceeds its piece budget."}
	return {"ok":true,"design":{"version":PIECES.VERSION,"anchors":LAYOUT.canonical(value.anchors),"block":block,"pad":pad,
		"budget":int(value.budget),"blocks_enabled":value.blocks_enabled,"pads_enabled":value.pads_enabled}}
static func from_physical(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size() != 4:
		return {"ok":false}
	var full: Dictionary = value.duplicate(true)
	full["budget"] = 3
	full["blocks_enabled"] = full.get("block",-1) != -1
	full["pads_enabled"] = full.get("pad",-1) != -1
	return normalize(full)
func read_slots() -> Dictionary:
	for candidate: String in [path,path+".bak"]:
		if FileAccess.file_exists(candidate):
			var file := FileAccess.open(candidate,FileAccess.READ)
			if file == null:
				return {"ok":false,"error":"Saved plans could not be read; your current plan is unchanged."}
			var size := file.get_length()
			file.close()
			if size > MAX_BYTES:
				return {"ok":false,"error":"Saved plans could not be read; your current plan is unchanged."}
	var read: Dictionary = backend.read_profile(path)
	if read.error != OK:
		return {"ok":false,"error":"Saved plans could not be read; your current plan is unchanged."}
	var config: ConfigFile = read.config
	if read.state != "new" and config.get_value("plan-yard","format","") != FORMAT:
		return {"ok":false,"error":"Saved plans use an unsupported format."}
	var slots: Array = [null,null,null]
	for i: int in 3:
		if not config.has_section_key("slot_%d" % i,"design"):
			continue
		var checked := normalize(config.get_value("slot_%d" % i,"design"))
		if not checked.ok:
			return checked
		slots[i] = checked.design
	return {"ok":true,"slots":slots,"config":config,"recovered":read.state == "restored backup"}
func save_slot(index: int, value: Dictionary) -> Dictionary:
	if index < 0 or index >= 3:
		return {"ok":false,"error":"Choose a slot from 1 to 3."}
	var checked := normalize(value)
	if not checked.ok:
		return checked
	var read := read_slots()
	if not read.ok:
		return read
	var config: ConfigFile = read.config
	config.set_value("plan-yard","format",FORMAT)
	config.set_value("slot_%d" % index,"design",checked.design)
	var folder := ProjectSettings.globalize_path(path).get_base_dir()
	if DirAccess.make_dir_recursive_absolute(folder) != OK or backend.write_profile(path,config) != OK:
		return {"ok":false,"error":"Plan could not be saved. The earlier save is kept."}
	return {"ok":true,"recovered":read.recovered}
func load_slot(index: int) -> Dictionary:
	if index < 0 or index >= 3:
		return {"ok":false,"error":"Choose a slot from 1 to 3."}
	var read := read_slots()
	if not read.ok:
		return read
	if read.slots[index] == null:
		return {"ok":false,"error":"Slot %d is empty. F6 saves this plan." % (index+1)}
	return {"ok":true,"design":read.slots[index].duplicate(true),"recovered":read.recovered}
