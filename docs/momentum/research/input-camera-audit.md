# Input and camera audit

Root source inspection, 7 November 2026. This separates presentation facts from unmeasured
feel hypotheses. It does not establish end-to-end mouse latency or desktop performance.

- R12 mouse events change `yaw`/`pitch` in `_unhandled_input`; `_update_eye` applies those
  angles directly in `_process`. There is no yaw spring or mouse-look smoothing in this
  path. The camera position interpolates previous/current physics positions; bob, landing
  dip and up to 5 degrees of speed FOV are presentation additions. FLOW inherits this path.
- The project requests 120 Hz physics and VSync. Those settings are not measurements of
  rendered frame cadence, physical input latency or GPU throughput.
- `tools/visual-play.gd` already sends a fraction of the requested mouse displacement on
  every rendered frame during an active batch. At fixed 30 fps this is a constant-rate
  turn, not a single flick followed by a key hold. Root's earlier council description was
  misleading and is corrected. The helper still pauses between decisions, supports only
  one constant key set and turn rate per batch, and uses at most three simulation seconds.
- R12's exact-state course drivers and the lab's position-aware steps know world positions.
  Input-only motion ownership does not make their perception equivalent to a player's.

Godot's [manual interpolation documentation](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/advanced_physics_interpolation.html#mouse-look)
explicitly discusses interpolated first-person position with uninterpolated mouse rotation.
The current camera follows that separation. This rules out an obvious rotation spring in
our code; it does not rule out frame pacing, input accumulation, collision-driven camera
motion, poor scale cues or an unsuitable movement policy.

Next useful checks are continuous time-varying input tapes, actual displacement beside
authoritative velocity, moving native footage and separate control/camera/course changes.
The AI-testing research examines how to make those checks practical. Camera changes should
be compared separately rather than bundled into a controller claim.
