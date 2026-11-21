extends Control
## surveyed equipment zones expose height, inventory and experimental options before running.
const LAYOUT := preload("res://scripts/plan/layout.gd")
const PIECES := preload("res://scripts/plan/pieces.gd")
const UI := preload("res://scripts/r18_ui_theme.gd")
const SEA := Color("a9cfc6")
const SEA_LINE := Color(1,1,1,0.10)
const SEA_DEEP := Color("23705f")
const DECK := Color("efe7d4")
const CROWN := Color("e2d3b4")
const PALE := Color("f3ead7")
const PALE_DEEP := Color("e6d8bc")
const INK := Color("18272e")
const INK_SOFT := Color(0.094,0.153,0.18,0.66)
const RULE := Color(0.094,0.153,0.18,0.18)
const STEEL := Color(0.094,0.153,0.18,0.55)
const STEEL_SOFT := Color(0.094,0.153,0.18,0.30)
const EDGE := Color("e15a2b")
const EDGE_DEEP := Color("a9471f")
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
	# one survey drawing in the look's language: sea-glass basin, cream quays with ink edges,
	# steel gantry lines the sockets hang from, orange sockets you chose and the line they make.
	# click areas and point() are unchanged, so every row and socket sits where it always did.
	var map := level()
	var title := UI.font("title")
	var label := UI.font("label")
	var body := UI.font("body")
	var small := UI.font("small")
	var s := scale_factor()
	draw_rect(Rect2(Vector2.ZERO,size),SEA)
	for y: int in range(0,int(size.y),18):
		draw_line(Vector2(430,y),Vector2(size.x,y),SEA_LINE,1.0)
	# the basin: quays and caisson crowns as plan shapes with their heights printed on them.
	var decks := [[Rect2(-18,5,36,15),"+3 m"],[Rect2(-18,-55,36,21),"+3 m  far quay"],[Rect2(-18,-34,7,39),"+3"],[Rect2(11,-34,7,39),"+3"],[Rect2(-5,-18,10,10),"+7 m"],[Rect2(-5,-30,10,9),"+9 m"]]
	for i: int in decks.size():
		var rect: Rect2 = decks[i][0]
		var r := Rect2(point(Vector3(rect.position.x,0,rect.position.y)),rect.size*s)
		draw_rect(r,CROWN if i >= 4 else DECK)
		draw_rect(r,INK,false,2.0 if i >= 4 else 1.5)
		var mark: String = decks[i][1]
		var corner := r.position+Vector2(6,16) if i in [1,2,3] else r.position+Vector2(6,r.size.y-7)
		draw_string(small,corner,mark,HORIZONTAL_ALIGNMENT_LEFT,-1,13,INK_SOFT)
	# overhead steel: four gantry beams and three travelling rails carry every socket.
	for z: float in [1,-11,-25,-49]:
		draw_line(point(Vector3(-20,0,z)),point(Vector3(20,0,z)),STEEL,2.0)
		for x: float in [-20,20]:
			draw_rect(Rect2(point(Vector3(x,0,z))-Vector2(4,4),Vector2(8,8)),STEEL)
	for x: float in [-12,0,12]:
		draw_dashes(point(Vector3(x,0,1)),point(Vector3(x,0,-49)),STEEL_SOFT,1.0,6.0)
	# finish threshold and spawn.
	draw_line(point(Vector3(-18,0,-46)),point(Vector3(18,0,-46)),INK,3.0)
	draw_string(label,point(Vector3(-17,0,-47)),"Finish",HORIZONTAL_ALIGNMENT_LEFT,-1,16,INK)
	draw_circle(point(map.spawn.origin),7,INK)
	draw_string(label,point(Vector3(-17,0,17)),"Spawn",HORIZONTAL_ALIGNMENT_LEFT,-1,16,INK)
	# the planned line: spawn, each chosen anchor in running order, then the far quay.
	var chosen: Array = map.plan.duplicate()
	chosen.sort_custom(func(i: int, j: int) -> bool: return LAYOUT.SOCKETS[i].z > LAYOUT.SOCKETS[j].z)
	var line := PackedVector2Array([point(map.spawn.origin)])
	for index: int in chosen:
		line.append(point(LAYOUT.SOCKETS[index]))
	var last_x: float = LAYOUT.SOCKETS[chosen[chosen.size()-1]].x if not chosen.is_empty() else map.spawn.origin.x
	line.append(point(Vector3(last_x,0,-48)))
	if line.size() > 1:
		draw_polyline(line,INK,3.0,true)
	if map.block_slot >= 0:
		var p := point(PIECES.BLOCKS[map.block_slot])
		var r := Rect2(p-Vector2.ONE*3.5*s,Vector2.ONE*7*s)
		draw_rect(r,PALE)
		draw_rect(r,INK,false,2.0)
		draw_string(small,r.position+Vector2(4,14),"block +%dm" % int(PIECES.BLOCKS[map.block_slot].y),HORIZONTAL_ALIGNMENT_LEFT,-1,12,INK)
	if map.pad_slot >= 0:
		draw_circle(point(PIECES.PADS[map.pad_slot]),14,EDGE,false,3)
	var positions := {}
	if brush == "anchor":
		for i: int in LAYOUT.SOCKETS.size():
			positions[i] = LAYOUT.SOCKETS[i]
	else:
		positions = PIECES.BLOCKS if brush == "block" else PIECES.PADS
	var ghost: Dictionary = runner.best_plan
	if not ghost.is_empty() and not map.envelope_enabled:
		for index: int in ghost.anchors:
			draw_circle(point(LAYOUT.SOCKETS[index]),19,SEA_DEEP,false,2.5)
		if ghost.block >= 0:
			var p := point(PIECES.BLOCKS[ghost.block])
			draw_rect(Rect2(p-Vector2.ONE*3.5*s,Vector2.ONE*7*s),SEA_DEEP,false,2.5)
		if ghost.pad >= 0:
			draw_circle(point(PIECES.PADS[ghost.pad]),20,SEA_DEEP,false,2.5)
	# sockets: a numbered ring per position; the chosen ones are filled orange.
	for i: int in positions:
		var at: Vector3 = positions[i]
		var p := point(at)
		var on: bool = (brush == "anchor" and i in map.plan) or (brush == "block" and i == map.block_slot) or (brush == "pad" and i == map.pad_slot)
		draw_circle(p,13,EDGE if on else PALE)
		draw_circle(p,13,INK,false,2.0)
		var digit := str(i+1)
		var width := label.get_string_size(digit,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
		draw_string(label,p+Vector2(-width*0.5,6),digit,HORIZONTAL_ALIGNMENT_LEFT,-1,16,PALE if on else INK)
		# every socket shows its height beside it; chosen pieces carry theirs on a cream ticket.
		var tag := "%s%d  +%dm" % [brush.substr(0,1).to_upper(),i+1,int(at.y)] if on else "+%dm" % int(at.y)
		var tag_size := small.get_string_size(tag,HORIZONTAL_ALIGNMENT_LEFT,-1,12)
		# tags sit above the rail on the socket's outer side; centre ones go right, clear of the
		# caisson height labels that sit under them.
		var box := tag_size+Vector2(8,4)
		var tag_at := p+Vector2(17,-box.y-3)
		if at.x < -0.5:
			tag_at = p+Vector2(-17-box.x,-box.y-3)
		if on:
			draw_rect(Rect2(tag_at,box),PALE)
			draw_rect(Rect2(tag_at,box),INK,false,1.0)
		draw_string(small,tag_at+Vector2(4,tag_size.y-1),tag,HORIZONTAL_ALIGNMENT_LEFT,-1,12,INK if on else INK_SOFT)
	# the left sheet: same rows and click areas as before, set in the menu's type.
	draw_rect(Rect2(0,0,420,size.y),PALE)
	draw_rect(Rect2(420,0,3,size.y),EDGE)
	draw_string(title,Vector2(30,44),"Plan Yard  survey",HORIZONTAL_ALIGNMENT_LEFT,-1,28,INK)
	draw_string(body,Vector2(30,74),"Pick sockets, then Enter runs the line.",HORIZONTAL_ALIGNMENT_LEFT,-1,15,INK_SOFT)
	draw_string(body,Vector2(30,94),"Tab restarts here to plan again.",HORIZONTAL_ALIGNMENT_LEFT,-1,13,INK_SOFT)
	var names := {"anchor":"Rope anchors", "block":"Raised block", "pad":"Launch pad"}
	var kinds := ["anchor","block","pad"]
	for i: int in 3:
		var kind: String = kinds[i]
		var y := 135.0+i*46
		if brush == kind:
			draw_rect(Rect2(24,y-26,375,38),PALE_DEEP)
			draw_rect(Rect2(24,y-26,4,38),EDGE)
		var state := ""
		if kind == "block":
			state = "on" if map.blocks_enabled else "off"
		elif kind == "pad":
			state = "on" if map.pads_enabled else "off"
		_key(Vector2(36,y-19),kind.substr(0,1).to_upper())
		draw_string(label,Vector2(76,y),names[kind],HORIZONTAL_ALIGNMENT_LEFT,-1,19,INK)
		draw_string(body,Vector2(330,y),state,HORIZONTAL_ALIGNMENT_LEFT,-1,16,INK_SOFT)
	_key(Vector2(36,256),"F8")
	draw_string(label,Vector2(76,275),"Budget: %d piece%s" % [map.budget,"" if map.budget == 1 else "s"],HORIZONTAL_ALIGNMENT_LEFT,-1,19,INK)
	draw_string(body,Vector2(76,297),"Changing it removes extra pieces.",HORIZONTAL_ALIGNMENT_LEFT,-1,14,INK_SOFT)
	_key(Vector2(36,321),"Del")
	draw_string(label,Vector2(76,340),"Clear plan",HORIZONTAL_ALIGNMENT_LEFT,-1,18,INK)
	draw_line(Vector2(30,356),Vector2(398,356),RULE,1.0)
	draw_string(body,Vector2(30,378),"Click a socket or press 1–9 to toggle it.",HORIZONTAL_ALIGNMENT_LEFT,-1,15,INK)
	# the rule steps aside while the same warning is live at the foot of the sheet.
	if notice.is_empty():
		draw_string(body,Vector2(30,402),"Budget full: remove a piece first.",HORIZONTAL_ALIGNMENT_LEFT,-1,15,INK)
	draw_string(body,Vector2(30,426),"Every piece costs one; one block, one pad.",HORIZONTAL_ALIGNMENT_LEFT,-1,15,INK)
	draw_string(body,Vector2(30,450),"Shift+B / Shift+P turn those options off.",HORIZONTAL_ALIGNMENT_LEFT,-1,15,INK)
	draw_string(body,Vector2(30,474),"Launch pad: 300+ u/s toward the far quay.",HORIZONTAL_ALIGNMENT_LEFT,-1,15,INK)
	draw_line(Vector2(30,496),Vector2(398,496),RULE,1.0)
	_key(Vector2(36,515),"[ ]")
	draw_string(label,Vector2(80,534),"Slot %d" % (active_slot+1),HORIZONTAL_ALIGNMENT_LEFT,-1,17,INK)
	_key(Vector2(160,515),"F6")
	draw_string(label,Vector2(196,534),"Save",HORIZONTAL_ALIGNMENT_LEFT,-1,17,INK)
	_key(Vector2(285,515),"F7")
	draw_string(label,Vector2(321,534),"Load",HORIZONTAL_ALIGNMENT_LEFT,-1,17,INK)
	if not ghost.is_empty() and not map.envelope_enabled:
		var matching: bool = ghost == map.physical_design()
		draw_circle(Vector2(42,572),7,SEA_DEEP,false,2.5)
		draw_string(body,Vector2(58,578),"Best ghost: this plan" if matching else "Ringed: your best plan so far",HORIZONTAL_ALIGNMENT_LEFT,-1,16,SEA_DEEP)
	_key(Vector2(36,595),"Q")
	draw_string(label,Vector2(76,614),"Envelope practice: " + ("on" if map.envelope_enabled else "off"),HORIZONTAL_ALIGNMENT_LEFT,-1,17,INK)
	draw_string(body,Vector2(30,size.y-65),notice,HORIZONTAL_ALIGNMENT_LEFT,384,15,EDGE_DEEP)
	draw_string(label,Vector2(30,size.y-30),"%d / %d pieces placed" % [PIECES.count(map.plan,map.block_slot,map.pad_slot),map.budget],HORIZONTAL_ALIGNMENT_LEFT,-1,19,INK)
func _key(at: Vector2, text: String) -> void:
	# a small ink key cap, the same mark for every shortcut on the sheet.
	var font := UI.font("small")
	var width := maxf(28.0,font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x+14.0)
	draw_rect(Rect2(at,Vector2(width,24)),INK)
	draw_string(font,at+Vector2((width-font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x)*0.5,17),text,HORIZONTAL_ALIGNMENT_LEFT,-1,13,PALE)
func draw_dashes(a: Vector2, b: Vector2, color: Color, width: float, dash: float) -> void:
	var length := a.distance_to(b)
	var step := 0.0
	while step < length:
		draw_line(a.lerp(b,step/length),a.lerp(b,minf(step+dash,length)/length),color,width)
		step += dash*2.0
func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if Rect2(24,588,375,36).has_point(event.position):
		var map := level()
		map.envelope_enabled = not map.envelope_enabled
		map.apply_design(map.plan,map.block_slot,map.pad_slot,map.budget,map.blocks_enabled,map.pads_enabled)
		runner.envelope.reset()
		notice = "K leaves your first body waiting. E delivers; you control it again." if map.envelope_enabled else "Envelope off. Ordinary plan times again."
		queue_redraw()
		accept_event()
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
