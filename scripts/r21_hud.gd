extends "res://scripts/r20_hud.gd"
## r21 adds tuning controls and displays the runner's authoritative prospective anchor.
const R21_TUNING_NOTES := {
	"elastic-soft": "Soft catch · less outward damping; more room to swing.",
	"elastic-firm": "Firm line · a firmer spring when the line stretches.",
	"elastic-arc": "Long arc · slower reel; keeps a longer swinging line."}
var anchor_assist_switch: CheckButton
var anchor_readout: Label
var displayed_anchor: Dictionary = {}

func attach(main: Node) -> void:
	super(main)
	_heading(tether_section, "Elastic tuning")
	for id: String in R21_TUNING_NOTES:
		var button := _button(tether_section, R21_TUNING_NOTES[id], _choose_model.bind(id))
		button.name = "TetherModel_" + id
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tether_models[id] = button
	anchor_assist_switch = CheckButton.new()
	anchor_assist_switch.name = "TetherAnchorAssist"
	anchor_assist_switch.text = "Anchor assist for Elastic ropes"
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
	_refresh_tether()

func _refresh_tether() -> void:
	super()
	if anchor_assist_switch == null or game == null:
		return
	anchor_assist_switch.set_pressed_no_signal(bool(game.settings.get("tether_anchor_assist", true)))
	anchor_assist_switch.disabled = str(game.settings.get("tether_model", "classic")) in ["classic", "pendulum"]

func _process(delta: float) -> void:
	super(delta)
	_refresh_anchor_readout()

func _refresh_anchor_readout() -> void:
	if anchor_readout == null:
		return
	displayed_anchor = {}
	anchor_readout.hide()
	if game == null or game.map_id != "tether-yard" or game.paused or game.finished:
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
