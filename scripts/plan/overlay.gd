extends Control
## surveyed equipment zones expose height, inventory and experimental options before running.
const LAYOUT := preload("res://scripts/plan/layout.gd")
const PIECES := preload("res://scripts/plan/pieces.gd")
var runner: CharacterBody3D
var brush := "anchor"
var active_slot := 0
var notice := ""
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
func scale_factor() -> float:
	return minf(10,(size.y-160)/75)
func point(at: Vector3) -> Vector2:
	return Vector2(size.x*0.67+at.x*scale_factor(),size.y*0.5+(at.z+17)*scale_factor())
func level() -> Node:
	return runner.get_parent().get("level")
func choose_brush(kind: String, disable := false) -> void:
	var map := level()
	var blocks: bool = map.blocks_enabled
	var pads: bool = map.pads_enabled
	var block: int = map.block_slot
	var pad: int = map.pad_slot
	if kind == "block":
		blocks = not disable
		if disable:
			block = -1
	if kind == "pad":
		pads = not disable
		if disable:
			pad = -1
	map.apply_design(map.plan,block,pad,map.budget,blocks,pads)
	brush = "anchor" if disable else kind
	notice = ""
	queue_redraw()
func save_plan() -> void:
	var saved: Dictionary = runner.plan_store.save_slot(active_slot,level().design())
	notice = "Saved in slot %d." % (active_slot+1) if saved.ok else saved.error
	if saved.ok and saved.recovered:
		notice += " The previous good save was restored first."
	queue_redraw()
func load_plan() -> void:
	var loaded: Dictionary = runner.plan_store.load_slot(active_slot)
	if not loaded.ok:
		notice = loaded.error
	else:
		var d: Dictionary = loaded.design
		var ok: bool = level().apply_design(d.anchors,d.block,d.pad,d.budget,d.blocks_enabled,d.pads_enabled)
		notice = "Loaded slot %d. Enter runs this plan." % (active_slot+1) if ok else "Plan could not be loaded; the current plan is kept."
		brush = "anchor"
		if loaded.recovered:
			notice += " Loaded from the previous good save."
	queue_redraw()
func toggle_budget() -> void:
	var map := level()
	var limit := 1 if map.budget == 3 else 3
	var anchors: Array = map.plan.slice(0,limit)
	var block: int = map.block_slot
	var pad: int = map.pad_slot
	if PIECES.count(anchors,block,pad) > limit:
		pad = -1
	if PIECES.count(anchors,block,pad) > limit:
		block = -1
	map.apply_design(anchors,block,pad,limit,map.blocks_enabled,map.pads_enabled)
	notice = "Budget reduced; kept the first piece." if limit == 1 else "Budget increased; your plan is kept."
	queue_redraw()
func clear_pieces() -> void:
	var map := level()
	map.apply_design([],-1,-1,map.budget,map.blocks_enabled,map.pads_enabled)
	notice = "Plan cleared. Choose equipment before running."
	queue_redraw()
func toggle_socket(index: int) -> void:
	var map := level()
	var anchors: Array = map.plan.duplicate()
	var block: int = map.block_slot
	var pad: int = map.pad_slot
	if brush == "anchor":
		if index < 0 or index >= LAYOUT.SOCKETS.size():
			return
		if index in anchors:
			anchors.erase(index)
		else:
			anchors.append(index)
	elif brush == "block":
		if not PIECES.BLOCKS.has(index):
			notice = "Blocks fit zones 4, 5 and 6."
			queue_redraw()
			return
		block = -1 if block == index else index
	else:
		if not PIECES.PADS.has(index):
			notice = "Pads fit supported decks: zones 4, 5, 6 and 8."
			queue_redraw()
			return
		pad = -1 if pad == index else index
	var ok: bool = map.apply_design(anchors,block,pad,map.budget,map.blocks_enabled,map.pads_enabled)
	notice = "" if ok else "Budget full. Remove a piece first."
	queue_redraw()
func _draw() -> void:
	var map := level()
	var font := ThemeDB.fallback_font
	var ink := Color("efe8cf")
	draw_rect(Rect2(Vector2.ZERO,size),Color("203d45"))
	draw_string(font,Vector2(30,42),"Plan Yard / survey",HORIZONTAL_ALIGNMENT_LEFT,-1,26,ink)
	draw_string(font,Vector2(30,74),"Choose a plan, then Enter runs. Tab returns here at spawn.",HORIZONTAL_ALIGNMENT_LEFT,-1,18,ink)
	var names := {"anchor":"A  Rope anchors", "block":"B  Raised block", "pad":"P  Launch pad"}
	var kinds := ["anchor","block","pad"]
	for i: int in 3:
		var kind: String = kinds[i]
		var y := 135.0+i*46
		if brush == kind:
			draw_rect(Rect2(24,y-26,375,38),Color("31555e"))
		var state := ""
		if kind == "block":
			state = "  on" if map.blocks_enabled else "  off"
		elif kind == "pad":
			state = "  on" if map.pads_enabled else "  off"
		draw_string(font,Vector2(34,y),names[kind]+state,HORIZONTAL_ALIGNMENT_LEFT,-1,21,ink)
	draw_string(font,Vector2(30,275),"F8  Budget: %d piece%s" % [map.budget,"" if map.budget == 1 else "s"],HORIZONTAL_ALIGNMENT_LEFT,-1,21,ink)
	draw_string(font,Vector2(30,299),"Changing budget removes extra pieces.",HORIZONTAL_ALIGNMENT_LEFT,-1,16,ink)
	draw_string(font,Vector2(30,340),"Delete  Clear plan",HORIZONTAL_ALIGNMENT_LEFT,-1,18,ink)
	draw_string(font,Vector2(30,370),"Click/number toggles a piece (1–9).",HORIZONTAL_ALIGNMENT_LEFT,-1,17,ink)
	draw_string(font,Vector2(30,400),"Remove one first if the budget is full.",HORIZONTAL_ALIGNMENT_LEFT,-1,17,ink)
	draw_string(font,Vector2(30,430),"One item costs one; one block/pad max.",HORIZONTAL_ALIGNMENT_LEFT,-1,17,ink)
	draw_string(font,Vector2(30,460),"Shift+B / Shift+P turn those options off.",HORIZONTAL_ALIGNMENT_LEFT,-1,17,ink)
	draw_string(font,Vector2(30,534),"[ / ] Slot %d" % (active_slot+1),HORIZONTAL_ALIGNMENT_LEFT,-1,18,ink)
	draw_string(font,Vector2(160,534),"F6 Save",HORIZONTAL_ALIGNMENT_LEFT,-1,18,ink)
	draw_string(font,Vector2(285,534),"F7 Load",HORIZONTAL_ALIGNMENT_LEFT,-1,18,ink)
	draw_string(font,Vector2(30,490),"Launch: 300+ u/s toward the far quay.",HORIZONTAL_ALIGNMENT_LEFT,-1,17,ink)
	for rect: Rect2 in [Rect2(-18,5,36,15),Rect2(-18,-55,36,21),Rect2(-18,-34,7,39),Rect2(11,-34,7,39),Rect2(-5,-18,10,10),Rect2(-5,-30,10,9)]:
		draw_rect(Rect2(point(Vector3(rect.position.x,0,rect.position.y)),rect.size*scale_factor()),Color("b9b8a5"))
	for index: int in map.plan:
		draw_circle(point(LAYOUT.SOCKETS[index]),12,Color("cd854f"))
	if map.block_slot >= 0:
		var p := point(PIECES.BLOCKS[map.block_slot])
		draw_rect(Rect2(p-Vector2.ONE*3.5*scale_factor(),Vector2.ONE*7*scale_factor()),Color("ddd7bd"))
	if map.pad_slot >= 0:
		draw_circle(point(PIECES.PADS[map.pad_slot]),13,Color("cd854f"),false,3)
	var positions := {}
	if brush == "anchor":
		for i: int in LAYOUT.SOCKETS.size():
			positions[i] = LAYOUT.SOCKETS[i]
	else:
		positions = PIECES.BLOCKS if brush == "block" else PIECES.PADS
	for i: int in positions:
		var at: Vector3 = positions[i]
		var p := point(at)
		draw_circle(p,13,Color("6c8f95"),false,2)
		draw_rect(Rect2(p+Vector2(-29,15),Vector2(58,21)),Color("ddd7bd"))
		draw_string(font,p+Vector2(-26,30),"%s%d +%dm" % [brush.substr(0,1).to_upper(),i+1,at.y],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("203d45"))
	var ghost: Dictionary = runner.best_plan
	if not ghost.is_empty():
		var color := Color("7ec4d0")
		for index: int in ghost.anchors:
			draw_circle(point(LAYOUT.SOCKETS[index]),18,color,false,3)
		if ghost.block >= 0:
			var p := point(PIECES.BLOCKS[ghost.block])
			draw_rect(Rect2(p-Vector2.ONE*3.5*scale_factor(),Vector2.ONE*7*scale_factor()),color,false,3)
		if ghost.pad >= 0:
			draw_circle(point(PIECES.PADS[ghost.pad]),19,color,false,3)
		var matching: bool = ghost == map.physical_design()
		draw_string(font,Vector2(30,578),"Best ghost: this plan" if matching else "Ghost reference: previous plan",HORIZONTAL_ALIGNMENT_LEFT,-1,18,color)
	for marker: Array in [[Vector3(-4.8,0,-12.5),"7m"],[Vector3(-4.8,0,-26.5),"9m"],[Vector3(-17.4,0,-15),"3m"],[Vector3(12,0,-15),"3m"]]:
		draw_string(font,point(marker[0]),marker[1],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("203d45"))
	draw_circle(point(map.spawn.origin),6,Color("203d45"))
	draw_string(font,point(Vector3(-17,0,17)),"SPAWN",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("203d45"))
	draw_string(font,point(Vector3(-17,0,-47)),"FINISH",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("203d45"))
	draw_string(font,Vector2(30,size.y-65),notice,HORIZONTAL_ALIGNMENT_LEFT,-1,17,ink)
	draw_string(font,Vector2(30,size.y-30),"%d / %d pieces · elevations: quays +3m, caisson +7/+9m, sea -4m" % [PIECES.count(map.plan,map.block_slot,map.pad_slot),map.budget],HORIZONTAL_ALIGNMENT_LEFT,-1,19,ink)
func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	for i: int in 3:
		if Rect2(24,109+i*46,375,38).has_point(event.position):
			var kind: String = ["anchor","block","pad"][i]
			choose_brush(kind,brush == kind and kind != "anchor")
			accept_event()
			return
	if Rect2(24,260,375,42).has_point(event.position):
		toggle_budget()
		accept_event()
		return
	if Rect2(24,312,375,38).has_point(event.position):
		clear_pieces()
		accept_event()
		return
	if Rect2(24,510,375,34).has_point(event.position):
		if event.position.x < 140:
			active_slot = posmod(active_slot+1,3)
			notice = "Slot %d selected." % (active_slot+1)
		elif event.position.x < 270:
			save_plan()
		else:
			load_plan()
		queue_redraw()
		accept_event()
		return
	var positions := {}
	if brush == "anchor":
		for i: int in LAYOUT.SOCKETS.size():
			positions[i] = LAYOUT.SOCKETS[i]
	else:
		positions = PIECES.BLOCKS if brush == "block" else PIECES.PADS
	for i: int in positions:
		if point(positions[i]).distance_to(event.position) < 18:
			toggle_socket(i)
			accept_event()
			return
