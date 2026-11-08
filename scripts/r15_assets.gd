extends RefCounted
## shared placement for the acquired r15 models. original scene transforms and materials
## stay intact; a separate pivot puts the measured horizontal centre at the authored foot.
## these are visuals only. course authors supply intentional collision for reachable props.

const ROOT := "res://assets/r15/library/"
const BOUNDS_PATH := ROOT + "BOUNDS.json"
static var _bounds: Dictionary = {}
static var _scenes: Dictionary = {}

static func _catalog() -> Dictionary:
	if _bounds.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BOUNDS_PATH))
		assert(parsed is Dictionary and parsed.get("models") is Dictionary, "r15 asset bounds are missing or invalid")
		_bounds = parsed.models
	return _bounds

static func _vector(values: Array) -> Vector3:
	assert(values.size() == 3, "r15 asset bounds need three coordinates")
	return Vector3(float(values[0]), float(values[1]), float(values[2]))

static func bounds(model: String) -> AABB:
	var catalog := _catalog()
	assert(catalog.has(model), "unregistered r15 model: " + model)
	var measured: Dictionary = catalog[model].unscaled_bounds
	return AABB(_vector(measured.position), _vector(measured.size))

## feet, yaw and scale are relative to parent. no source mesh is rescaled or rewritten on disk.
## example model key: kenney-space/models/satelliteDish_large.glb.
static func place(parent: Node3D, model: String, feet: Vector3, authored_scale: Vector3 = Vector3.ONE, yaw: float = 0.0) -> Node3D:
	var measured := bounds(model)
	assert(authored_scale.x > 0.0 and authored_scale.y > 0.0 and authored_scale.z > 0.0, "r15 props need positive authored scales")
	if not _scenes.has(model):
		var scene := load(ROOT + model) as PackedScene
		assert(scene != null, "r15 model scene did not import: " + model)
		_scenes[model] = scene
	var visual := (_scenes[model] as PackedScene).instantiate() as Node3D
	assert(visual != null, "r15 imported scene needs a Node3D root")
	var wrapper := Node3D.new()
	wrapper.name = model.get_file().get_basename()
	wrapper.position = feet
	wrapper.rotation.y = yaw
	wrapper.scale = authored_scale
	var pivot := Node3D.new()
	pivot.name = "MeasuredPivot"
	pivot.position = -Vector3(measured.position.x + measured.size.x * 0.5, measured.position.y, measured.position.z + measured.size.z * 0.5)
	wrapper.add_child(pivot)
	pivot.add_child(visual)
	wrapper.set_meta("r15_asset", model)
	wrapper.set_meta("r15_asset_licence", "CC0-1.0")
	wrapper.set_meta("r15_asset_collision", "course-authored separately")
	parent.add_child(wrapper)
	return wrapper

## a uniform instance scale for a desired visible height. authors still decide route dimensions.
static func scale_for_height(model: String, height: float) -> Vector3:
	assert(height > 0.0, "r15 prop height must be positive")
	var source_height := bounds(model).size.y
	assert(source_height > 0.0, "r15 prop has no measured height: " + model)
	return Vector3.ONE * height / source_height
