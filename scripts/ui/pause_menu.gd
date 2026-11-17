extends "res://scripts/r20_hud.gd"
## r21 adds tuning controls and displays the runner's authoritative prospective anchor.
const MAP_PREVIEW := preload("res://scripts/ui/map_preview.gd")
const RUN_REVIEW_PRACTICE := preload("res://scripts/recordings/run_review_practice.gd")
const RUN_REVIEW := preload("res://scripts/ui/run_review.gd")
const R21_TUNING_NOTES := {
	"elastic-soft": "Soft catch · less outward damping; more room to swing.",
	"elastic-firm": "Firm line · a firmer spring when the line stretches.",
	"elastic-arc": "Long arc · slower reel; keeps a longer swinging line."}
var anchor_assist_switch: CheckButton
var anchor_readout: Label
var displayed_anchor: Dictionary = {}
var map_preview: PanelContainer
var pause_header: VBoxContainer
var mail_section: VBoxContainer
var mail_views := {}
var mail_groups := {}
var feedback_switches := {}
var review_practice_status: Label
var review_button: Button
var review_screen: Control
var review_host_input := true
var map_controls: Label

func attach(main: Node) -> void:
	super(main)
	map_controls = _small(pause_pages["Practice"], "")
	map_controls.name = "CurrentMapInstructions"
	pause_pages["Practice"].move_child(map_controls, 0)
	_heading(tether_section, "Elastic tuning")
	for id: String in R21_TUNING_NOTES:
		var button := _button(tether_section, R21_TUNING_NOTES[id], _choose_model.bind(id))
		button.name = "TetherModel_" + id
		button.toggle_mode = true
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tether_models[id] = button
	anchor_assist_switch = CheckButton.new()
	anchor_assist_switch.name = "TetherAnchorAssist"
	anchor_assist_switch.text = "Anchor assist for Elastic ropes"
	anchor_assist_switch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	anchor_assist_switch.toggled.connect(func(on: bool) -> void: game.change_setting("tether_anchor_assist", on))
	tether_section.add_child(anchor_assist_switch)
	_small(tether_section, "Wider in-view acquisition. Switch off to compare the original aim. Classic and Pendulum keep their original aim.")
	tether_note.text = "Changing model, reel or assist restarts the attempt. Release mouse buttons after the menu; a fresh LMB press arms the line. Classic: 3 s. Others: 5 s. LMB release coasts; RMB reels."
	anchor_readout = Label.new()
	anchor_readout.name = "TetherProspectiveAnchor"
	anchor_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.ticket(anchor_readout, "small", 13, SIDE_BOTTOM, 0.9)
	overlay.add_child(anchor_readout)
	anchor_readout.hide()
	_attach_mail_preferences()
	_attach_feedback_preferences()
	review_button = _button(pause_pages["Runs"], "Review local runs", _open_run_review)
	review_button.name = "ReviewLocalRuns"
	pause_pages["Runs"].move_child(review_button, 0)
	review_button.tooltip_text = "Read recorded attempts, compare splits and scrub the speed trace."
	review_practice_status = _small(pause_pages["Runs"], "")
	review_practice_status.name = "ReviewPracticeStatus"
	pause_pages["Runs"].move_child(review_practice_status, 1)
	review_practice_status.hide()
	_pin_pause_header()
	map_preview = MAP_PREVIEW.new()
	map_preview.name = "MapPreview"
	pause_panel.add_child(map_preview)
	_wire_map_previews()
	map_preview.show_map(str(game.map_id), game.map_entry())
	map_preview.visible = pause_destination == "Maps"
	_layout_pause(get_viewport().get_visible_rect().size)
	_refresh_tether()

func _wire_map_previews() -> void:
	if map_preview == null:
		return
	for id: String in map_buttons:
		var button: Button = map_buttons[id]
		if button.has_meta("preview_connected"):
			continue
		button.set_meta("preview_connected", true)
		var show_view: Callable = map_preview.show_map.bind(id, game.map_entry(id))
		button.mouse_entered.connect(show_view)
		button.focus_entered.connect(show_view)

func _build_map_cards() -> void:
	super()
	_wire_map_previews()

func show_pause_destination(destination: String, focus_tab: bool = true) -> void:
	super(destination, focus_tab)
	if map_preview != null:
		map_preview.visible = destination == "Maps"
		if destination == "Maps":
			map_preview.show_map(str(game.map_id), game.map_entry())

func _show_current_map_controls() -> void:
	show_pause_destination("Practice")
	var target: Control = map_controls
	if mail_section != null and mail_section.visible:
		target = mail_views["body"] if mail_views["envelope"].disabled else mail_views["envelope"]
	elif tether_section.visible:
		target = reel_automatic if reel_manual.disabled else reel_manual
	elif lab_box.visible:
		target = lab_switches["slide"]
	if target.focus_mode != Control.FOCUS_NONE:
		target.grab_focus()
	_pause_scroll.ensure_control_visible(target)

func _attach_mail_preferences() -> void:
	mail_section = VBoxContainer.new()
	mail_section.name = "MailPreferences"
	mail_section.add_theme_constant_override("separation", 8)
	pause_pages["Practice"].add_child(mail_section)
	_small(mail_section, "LMB throw · mouse steer · RMB recall. Changing a choice restarts the attempt with its own recording identity.")
	_add_mail_group("view", "Delivery view", "mail_view", "set_mail_view", {"envelope": "Envelope", "body": "Runner's eyes"})
	_add_mail_group("body", "Body while steering", "mail_body", "set_mail_body", {"hold": "Held", "run": "Keep running"})
	_add_mail_group("goal", "Dispatch goal", "mail_goal", "set_mail_goal", {"deliver": "Deliver all three", "optional": "Optional mail"})
	mail_views = mail_groups["view"].buttons
	_refresh_mail()

func _add_mail_group(id: String, title: String, getter: String, setter: String, choices: Dictionary) -> void:
	var group := VBoxContainer.new()
	group.name = "MailChoice_" + id
	group.add_theme_constant_override("separation", 8)
	mail_section.add_child(group)
	_heading(group, title)
	var buttons := {}
	for value: String in choices:
		var button := _button(group, str(choices[value]), _set_mail_preference.bind(setter, value))
		button.name = "Mail_" + id + "_" + value
		buttons[value] = button
	mail_groups[id] = {"section": group, "getter": getter, "setter": setter, "buttons": buttons}

func _set_mail_preference(setter: String, value: String) -> void:
	if not is_instance_valid(game.player) or not game.player.has_method(setter):
		return
	var was_paused := bool(game.paused)
	game.player.call(setter, value)
	game.set_paused(was_paused)
	_refresh_mail()

func _refresh_mail() -> void:
	if mail_section == null:
		return
	mail_section.visible = is_instance_valid(game.player) and game.player.has_method("mail_view")
	if not mail_section.visible:
		return
	for id: String in mail_groups:
		var group: Dictionary = mail_groups[id]
		var supported: bool = game.player.has_method(group.getter) and game.player.has_method(group.setter)
		(group.section as Control).visible = supported
		if supported:
			var selected := str(game.player.call(group.getter))
			for value: String in group.buttons:
				(group.buttons[value] as Button).disabled = selected == value

func _attach_feedback_preferences() -> void:
	_heading(tether_section, "Swing feedback")
	_small(tether_section, "Presentation only. These switches keep the current attempt and recording identity.")
	var labels := {
		"tether_rope_visual": "Readable rope", "tether_attach_cue": "Attach flash and click",
		"tether_reel_audio": "Reel sound", "tether_tension_audio": "Rope tension sound",
		"tether_wind_audio": "Swing speed wind", "tether_speed_fov": "Small speed FOV (up to +3°)",
		"tether_anchor_readability": "Anchor ready marker"}
	for key: String in labels:
		var toggle := CheckButton.new()
		toggle.name = "Setting_" + key
		toggle.text = labels[key]
		toggle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		toggle.toggled.connect(func(on: bool) -> void: game.change_setting(key, on))
		tether_section.add_child(toggle)
		feedback_switches[key] = toggle

func _open_run_review() -> void:
	if review_screen != null:
		return
	review_practice_status.hide()
	review_host_input = game.is_processing_input()
	game.set_process_input(false)
	review_screen = RUN_REVIEW.new()
	if not str(game.session.directory).is_empty():
		review_screen.set("directory", str(game.session.directory))
	pause_panel.add_child(review_screen)
	review_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if review_screen.has_method("attach_map"):
		review_screen.call("attach_map", game.level, game.motion_identity())
	review_screen.closed.connect(_close_run_review)
	review_screen.practice_requested.connect(_on_review_practice_requested)
	_pause_side.hide()
	_pause_edge.hide()

func _on_review_practice_requested(request: Dictionary) -> void:
	_close_run_review()
	var result: Dictionary = RUN_REVIEW_PRACTICE.start(game, request)
	if not result.ok:
		review_practice_status.text = str(result.error)
		review_practice_status.show()
		_pause_scroll.scroll_vertical = 0
		notify(str(result.error))

func _close_run_review() -> void:
	if review_screen != null:
		review_screen.queue_free()
		review_screen = null
		game.set_process_input(review_host_input)
	_pause_side.show()
	_pause_edge.show()
	review_button.grab_focus()

func set_paused(value: bool) -> void:
	super(value)
	if value and map_preview != null and pause_destination == "Maps":
		map_preview.show_map(str(game.map_id), game.map_entry())
	if not value and review_screen != null:
		_close_run_review()

func _pin_pause_header() -> void:
	pause_header = VBoxContainer.new()
	pause_header.name = "PauseHeader"
	pause_header.add_theme_constant_override("separation", 9)
	_pause_side.add_child(pause_header)
	for child: Node in _pause_column.get_children():
		if child not in pause_pages.values():
			child.reparent(pause_header)
	_layout_pause(get_viewport().get_visible_rect().size)

func _layout_pause(size: Vector2) -> void:
	super(size)
	if pause_header == null:
		return
	pause_header.position = _pause_scroll.position
	pause_header.custom_minimum_size.x = _pause_scroll.size.x - 16.0
	pause_header.size = Vector2(pause_header.custom_minimum_size.x, 0)
	var header_height := pause_header.get_combined_minimum_size().y + 9.0
	_pause_scroll.position.y += header_height
	_pause_scroll.size.y = maxf(80.0, _pause_scroll.size.y - header_height)
	if map_preview != null:
		map_preview.arrange(size, _pause_side.get_global_rect())

func lab_controls_text() -> String:
	var instructions := super()
	if game != null and is_instance_valid(game.player) and game.player.has_method("mail_goal") and str(game.player.call("mail_goal")) == "optional":
		instructions = instructions.replace("Deliver all three before Dispatch.", "Mail is optional; reach Dispatch to finish.")
	return instructions

func _refresh_pause() -> void:
	super()
	_refresh_mail()
	if map_controls != null:
		map_controls.text = str(game.preset.get("controls", "")) + "\n" + lab_controls_text() if game.is_lab() or game.is_experiment_map() else str(game.preset.get("controls", ""))

func _refresh_tether() -> void:
	super()
	_refresh_mail()
	if anchor_assist_switch == null or game == null:
		return
	for key: String in feedback_switches:
		(feedback_switches[key] as CheckButton).set_pressed_no_signal(bool(game.settings.get(key, false)))
	anchor_assist_switch.set_pressed_no_signal(bool(game.settings.get("tether_anchor_assist", true)))
	anchor_assist_switch.disabled = game.tether_model() in ["classic", "pendulum"]

func _process(delta: float) -> void:
	super(delta)
	if game != null and game.map_has_capability("mail_delivery"):
		controls.modulate.a = 0.0
		hint.modulate.a = 0.0
		keys_line.modulate.a = 0.0
	elif game != null and game.map_has_capability("grapple"):
		controls.text = "LMB hold to swing · RMB reel · release to coast\nEsc map controls"
		keys_line.modulate.a = 0.0
	_refresh_anchor_readout()

func _lab_text() -> void:
	super()
	if game != null and game.map_has_capability("grapple") and is_instance_valid(game.player):
		var recent: Variant = game.player.get("release_notice")
		if recent is String:
			lab_panel.text = tether_history_text(lab_panel.text, recent)

static func tether_history_text(status: String, recent: String) -> String:
	return status.replace("\n" + recent, "\nRecent: " + recent) if not recent.is_empty() else status

func _refresh_anchor_readout() -> void:
	if anchor_readout == null:
		return
	displayed_anchor = {}
	anchor_readout.hide()
	if game == null or not game.map_has_capability("grapple") or game.paused or game.finished:
		return
	if not is_instance_valid(game.player) or not game.player.has_method("r21_acquisition_snapshot"):
		return
	var candidate: Dictionary = game.player.call("r21_acquisition_snapshot")
	if str(candidate.get("state", "none")) != "ok":
		return
	var name := str(candidate.get("name", ""))
	if name.is_empty():
		return
	var attached := bool(candidate.get("attached", false))
	if attached and "attempt restarted" in message.text and "release mouse buttons" in message.text:
		_message_time = 0.0
		message.modulate.a = 0.0
	if not attached and not bool(candidate.get("ready", false)):
		return
	anchor_readout.text = "%s: %s · %.1f m" % ["Attached" if attached else "Next", name, float(candidate.get("distance_m", 0.0))]
	anchor_readout.reset_size()
	var view := get_viewport().get_visible_rect().size
	anchor_readout.position = Vector2((view.x - anchor_readout.size.x) * 0.5, view.y * 0.5 + 24.0)
	anchor_readout.show()
	displayed_anchor = candidate.duplicate(true)
