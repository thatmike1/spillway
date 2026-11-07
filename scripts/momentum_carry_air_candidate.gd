extends "res://scripts/momentum_carry_player.gd"
## p / r13 carry air candidate: one original air law on the unchanged carry runner. ground,
## slope, take-off, landing, body, contact, camera, input, gravity, jump and the safety
## envelope are carry's own code; only the airborne horizontal step is replaced. it is not a
## cs or source reconstruction and keeps no projection allowance.
##
## the rule, in words: held keys bend the flight toward where they point, at a bounded
## sideways acceleration that never changes speed. w points at the view, a/d at the view's
## side, w+a between. no key keeps the line, so looking around is free. s brakes the travel
## along the view. a side key held while the view turns its way and the flight follows is a
## carve: each radian both of them turn pays a small, capped speed gain, whatever the mouse
## delivery rate. height and clean hops remain the main source of earned speed.

const AIR_POLICY := "carry-air-candidate"
# p / every value is a tuning hypothesis. tests may change a copy for diagnostics.
const AIR := {
	# sideways acceleration toward the wish (m/s^2), full while the wish is within 90 degrees
	# of travel and fading with its sideways share beyond that, so a wish far behind the
	# flight still bends it, gently, and never brakes it.
	"bend": 14.0,
	# a side key alone bends less, so a/d correct the line while w and the view stay the main
	# way to turn. a wish mixing both blends by each key's share.
	"side_bend": 9.0,
	# turn rate ceiling at low speed (rad/s).
	"bend_turn_max": 4.0,
	# a synchronised carve pays this much speed per radian of flight turn (m/s per rad),
	# in full up to carve_full and fading to nothing at carve_zero (m/s).
	"carve": 1.0,
	"carve_full": 12.0,
	"carve_zero": 16.0,
	# the view turn a carve can hold in reserve, and the opposite turn it can owe (rad). the
	# reserve makes the pay independent of how the mouse delivers the same turn.
	"carve_bank": 0.6,
	# positive synchronization credit lives for at most 0.1 s; counterturns cancel reuse.
	"carve_memory": 0.1,
	# s brakes the part of travel along the view (m/s^2) and never reverses it.
	"brake": 5.0,
	# below run speed any held key can bring a flight up to it, so held hops from rest get
	# going; never above, so it is no overspeed source.
	"floor": 8.5,
	"push": 6.0,
	# diagnostic only, rejected: pay any side-key flight turn without the view turning with it.
	# a fixed-view a/d weave then farms speed; the tests prove they detect it.
	"carve_unsynced": false,
}

## the air law actually running, for the hud, the tape executor and every trace.
var air_policy: String = AIR_POLICY
var air_tuning: Dictionary = AIR.duplicate()
var carve_total: float = 0.0
var _view_prev: float = 0.0
var _carve_bank: float = 0.0
var _carve_side: int = 0
var _carve_forward: int = 0
var _carve_history: Array[Vector2] = []
var _carve_debt: float = 0.0
var _air_tick: int = -2
var _view_turn: float = 0.0

func reset_to(pose: Transform3D) -> void:
	super(pose)
	_view_prev = yaw
	_carve_bank = 0.0
	_carve_side = 0
	_carve_forward = 0
	_carve_history.clear()
	_carve_debt = 0.0
	_air_tick = -2
	carve_total = 0.0

func _physics_process(delta: float) -> void:
	super(delta)
	# the view turn between motor steps, whichever device or event cadence produced it.
	_view_prev = yaw

func _carry_air(h: Vector3, stick: Vector2, delta: float) -> Vector3:
	var basis := Basis(Vector3.UP, yaw)
	var forward := basis * Vector3.FORWARD
	var right := basis * Vector3.RIGHT
	var side := stick.x
	var push := -stick.y
	# angles are positive to the left, as yaw is.
	_view_turn = angle_difference(_view_prev, yaw)
	if _air_tick != motion_tick - 1:
		# any ground step ends a carve.
		_carve_bank = 0.0
		_carve_side = 0
		_carve_forward = 0
		_carve_history.clear()
		_carve_debt = 0.0
	_air_tick = motion_tick
	var key_side := 0 if absf(side) <= 0.05 else (1 if side < 0.0 else -1)
	var key_forward := 0 if absf(push) <= 0.05 else (1 if push > 0.0 else -1)
	if key_side != _carve_side or key_forward != _carve_forward:
		_carve_bank = 0.0
		_carve_history.clear()
		_carve_debt = 0.0
		_carve_side = key_side
		_carve_forward = key_forward
	_age_carve(delta)
	var bank: float = air_tuning.carve_bank
	if key_side != 0:
		var credit := clampf(_carve_bank + _view_turn * key_side, -bank, bank) - _carve_bank
		if credit != 0.0:
			_add_carve(credit)
	var current := h
	var wish := forward * maxf(push, 0.0) + right * side
	var amount := minf(wish.length(), 1.0)
	if amount > 0.05:
		var wish_dir := wish.normalized()
		var speed := current.length()
		if speed < air_tuning.floor:
			# throttle adds speed along travel, never an opposing vector that brakes or reverses.
			var direction := current / speed if speed > 0.001 else wish_dir
			var throttle := maxf(direction.dot(wish_dir), 0.0)
			var faster := minf(air_tuning.floor, speed + float(air_tuning.push) * amount * throttle * delta)
			current = _book_step("air_low_push", current, direction * faster)
			speed = current.length()
		if speed > 0.05:
			var angle := (current / speed).signed_angle_to(wish_dir, Vector3.UP)
			var authority := 1.0 if absf(angle) <= PI * 0.5 else sin(absf(angle))
			var share := side * side / (side * side + maxf(push, 0.0) * maxf(push, 0.0))
			var bend := lerpf(air_tuning.bend, air_tuning.side_bend, share)
			var limit := minf(air_tuning.bend_turn_max, bend * amount * authority / speed) * delta
			var turn := clampf(angle, -limit, limit)
			if turn != 0.0:
				current = _book_step("air_bend", current, current.rotated(Vector3.UP, turn), turn)
			if key_side != 0 and turn * key_side > 0.0:
				var used := absf(turn) if air_tuning.carve_unsynced else minf(absf(turn), maxf(_carve_bank, 0.0))
				if used > 0.0:
					_spend_carve(used)
					var room := clampf((float(air_tuning.carve_zero) - speed) / (float(air_tuning.carve_zero) - float(air_tuning.carve_full)), 0.0, 1.0)
					var gain := float(air_tuning.carve) * room * used
					if gain > 0.0:
						carve_total += gain
						current = _book_step("air_carve", current, current * ((speed + gain) / speed))
	if push < -0.05:
		var speed := current.length()
		if speed > 0.0:
			var opposed := maxf(0.0, forward.dot(current / speed)) * -push
			if opposed > 0.0:
				current = _book_step("air_brake", current, current * (move_toward(speed, 0.0, float(air_tuning.brake) * opposed * delta) / speed))
	return current

func _age_carve(delta: float) -> void:
	_carve_bank = _carve_debt
	for i: int in range(_carve_history.size() - 1, -1, -1):
		var sample := _carve_history[i]
		sample.y += delta
		if sample.y > float(air_tuning.carve_memory) + 0.000001:
			_carve_history.remove_at(i)
		else:
			_carve_history[i] = sample
			_carve_bank += sample.x

func _add_carve(turn: float) -> void:
	if turn > 0.0:
		# retracing a counterturn pays its debt before it can count as a new carve.
		var cancel := minf(turn, -_carve_debt)
		_carve_debt += cancel
		turn -= cancel
		_carve_bank += cancel
		if turn > 0.0:
			_carve_history.append(Vector2(turn, 0.0))
			_carve_bank += turn
	else:
		var cancel := minf(-turn, maxf(_carve_bank, 0.0))
		_spend_carve(cancel)
		_carve_debt += turn + cancel
		_carve_bank += turn + cancel

func _spend_carve(amount: float) -> void:
	var remaining := amount
	for i: int in _carve_history.size():
		var sample := _carve_history[i]
		var used := minf(sample.x, remaining)
		sample.x -= used
		remaining -= used
		_carve_history[i] = sample
		if remaining <= 0.0:
			break
	_carve_bank -= amount - remaining

func get_motion_state() -> Dictionary:
	var state := super()
	state.air_policy = air_policy
	# the base runner's projection profile is a constructor prerequisite whose constants this
	# law never reads; the report names the law that ran.
	state.air_profile = air_policy
	state.base_air_profile_unused = air_profile
	state.view_turn = _view_turn
	state.carve_bank = _carve_bank
	state.carve_total = carve_total
	return state
