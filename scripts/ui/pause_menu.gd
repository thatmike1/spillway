extends "res://scripts/r20_hud.gd"
## r21 adds tuning controls and displays the runner's authoritative prospective anchor.
const RUN_REVIEW := preload("res://scripts/ui/run_review.gd")
const R21_TUNING_NOTES := {
	"elastic-soft": "Soft catch · less outward damping; more room to swing.",
	"elastic-firm": "Firm line · a firmer spring when the line stretches.",
	"elastic-arc": "Long arc · slower reel; keeps a longer swinging line."}
var anchor_assist_switch: CheckButton
var anchor_readout: Label
var displayed_anchor: Dictionary = {}
var pause_header: VBoxContainer
var mail_section: VBoxContainer
var mail_views := {}
var feedback_switches := {}
var review_button: Button
var review_screen: Control
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
	_pin_pause_header()
	_refresh_tether()

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
	_heading(mail_section, "Delivery view")
	_small(mail_section, "LMB throw · mouse steer · RMB recall. Changing view restarts the attempt with its own recording identity.")
	for id: String in ["envelope", "body"]:
		var button := _button(mail_section, "Envelope" if id == "envelope" else "Runner's eyes", func() -> void:
			if game.player.has_method("set_mail_view"):
				game.player.call("set_mail_view", id)
				_refresh_mail())
		button.name = "MailView_" + id
		mail_views[id] = button
	_refresh_mail()

func _refresh_mail() -> void:
	if mail_section == null:
		return
	mail_section.visible = is_instance_valid(game.player) and game.player.has_method("mail_view")
	if mail_section.visible:
		for id: String in mail_views:
			(mail_views[id] as Button).disabled = str(game.player.call("mail_view")) == id

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
	review_screen = RUN_REVIEW.new()
	if not str(game.session.directory).is_empty():
		review_screen.set("directory", str(game.session.directory))
	pause_panel.add_child(review_screen)
	review_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if review_screen.has_method("attach_map"):
		review_screen.call("attach_map", game.level, game.motion_identity())
	review_screen.closed.connect(_close_run_review)
	if review_screen.has_method("attach_map"):
		review_screen.call("attach_map", game.level, game.motion_identity())
	_pause_side.hide()
	_pause_edge.hide()

func _close_run_review() -> void:
	if review_screen != null:
		review_screen.queue_free()
		review_screen = null
	_pause_side.show()
	_pause_edge.show()
	review_button.grab_focus()

func set_paused(value: bool) -> void:
	super(value)
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
	if not attached and not bool(candidate.get("ready", false)):
		return
	anchor_readout.text = "%s: %s · %.1f m" % ["Attached" if attached else "Next", name, float(candidate.get("distance_m", 0.0))]
	anchor_readout.reset_size()
	var view := get_viewport().get_visible_rect().size
	anchor_readout.position = Vector2((view.x - anchor_readout.size.x) * 0.5, view.y * 0.5 + 24.0)
	anchor_readout.show()
	displayed_anchor = candidate.duplicate(true)
