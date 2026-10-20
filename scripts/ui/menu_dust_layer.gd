@tool
extends MultiMeshInstance2D

@export var depth: float = 1.0
@export var amount: int = 80
@export var radius_range: Vector2 = Vector2(0.4, 1.0)
@export var opacity: float = 0.35

var positions: PackedVector2Array = []
var velocities: PackedVector2Array = []
var phases: PackedFloat32Array = []
var radii: PackedFloat32Array = []
var field_size: Vector2 = Vector2.ZERO
var clock: float = 0.0
var camera_offset: Vector2 = Vector2.ZERO
var pending_start: Vector2 = Vector2.ZERO
var pending_end: Vector2 = Vector2.ZERO
var pending_motion: Vector2 = Vector2.ZERO
var has_motion: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 1733 + int(depth * 100.0)
	# Each saved layer owns its mesh data and shader parameters in editor and game.
	multimesh = multimesh.duplicate()
	material = material.duplicate()
	material.set_shader_parameter("opacity", opacity)
	get_viewport().size_changed.connect(resize_field)
	resize_field()

func resize_field() -> void:
	var next_size: Vector2 = get_viewport_rect().size
	if next_size == field_size and positions.size() == amount: return
	field_size = next_size
	positions.resize(amount)
	velocities.resize(amount)
	phases.resize(amount)
	radii.resize(amount)
	multimesh.instance_count = amount
	material.set_shader_parameter("field_width", field_size.x)
	for index in range(amount):
		positions[index] = Vector2(rng.randf_range(-60, field_size.x + 60), rng.randf_range(-60, field_size.y + 60))
		velocities[index] = Vector2.ZERO
		phases[index] = rng.randf() * TAU
		radii[index] = rng.randf_range(radius_range.x, radius_range.y)
		multimesh.set_instance_custom_data(index, Color(phases[index], 0, 0, 0))
		update_instance(index)

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not event is InputEventMouseMotion: return
	if event.relative.length_squared() < 0.01: return
	# Coalesce high polling rate mouse events; disturb particles once per frame.
	if not has_motion:
		pending_start = event.position - event.relative - camera_offset
	pending_end = event.position - camera_offset
	pending_motion += event.relative
	has_motion = true

func _process(delta: float) -> void:
	clock += delta
	material.set_shader_parameter("clock", clock)
	var damping: float = exp(-delta * 1.6)
	var reach: float = 60.0 + depth * 16.0
	var motion: Vector2 = pending_motion.limit_length(60.0)
	var input_strength: float = minf(motion.length() / maxf(delta, 0.001) * 0.0025, 5.0) * minf(depth, 1.6)
	for index in range(positions.size()):
		var point: Vector2 = positions[index]
		var velocity: Vector2 = velocities[index]
		if has_motion and input_strength > 0.0:
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(point, pending_start, pending_end)
			var away: Vector2 = point - closest
			if away.length_squared() < reach * reach:
				var falloff: float = 1.0 - away.length() / reach
				var breeze: Vector2 = (motion.normalized() * 0.75 + away.normalized() * 0.25) * input_strength * falloff * falloff
				# Approach gentle airflow instead of stacking impulses per input event.
				velocity = velocity.lerp(breeze, 1.0 - exp(-delta * 7.0))
		var phase: float = phases[index]
		var drift: Vector2 = Vector2(sin(clock * 0.23 + phase) * 2.2 + cos(clock * 0.11 + phase * 3.0),
			-0.6 + cos(clock * 0.19 + phase * 2.0) * 1.6) * depth
		# Integrate drag analytically so airflow stays smooth at any FPS.
		point += drift * delta + velocity * ((1.0 - damping) / 1.6)
		velocities[index] = velocity * damping
		positions[index] = Vector2(wrapf(point.x, -70.0, field_size.x + 70.0), wrapf(point.y, -70.0, field_size.y + 70.0))
		update_instance(index)
	pending_motion = Vector2.ZERO
	has_motion = false

func update_instance(index: int) -> void:
	var radius: float = radii[index]
	multimesh.set_instance_transform_2d(index, Transform2D(Vector2(radius, 0), Vector2(0, radius), positions[index] + camera_offset))
