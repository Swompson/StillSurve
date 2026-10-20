@tool
extends Node2D

## Authored cutouts use the same connected overhead skeleton in editor and game.
## The shaggy back masks limb roots; mane and mask overlap the neck connection.
const TORSO_SIZE: Vector2 = Vector2(68.0, 58.0)
const HEAD_SIZE: Vector2 = Vector2(46.0, 46.0)
const ARM_UPPER: float = 26.0
const ARM_LOWER: float = 34.0
const CONTACT_FRACTION: float = 0.64
const TAIL_SECTIONS: int = 20
const TAIL_IDLE_PERIOD: float = 2.6

@export var tail_region: Rect2 = Rect2(368, 943, 204, 303)

@export var preview_animation: bool = false:
	set(value):
		preview_animation = value
		apply_editor_pose()
@export_enum("idle", "walk", "run") var preview_state: String = "idle":
	set(value):
		preview_state = value
		apply_editor_pose()
@export var preview_direction: Vector2 = Vector2.DOWN:
	set(value):
		preview_direction = value
		apply_editor_pose()
@export_range(0.0, 1.0, 0.001) var preview_cycle: float = 0.0:
	set(value):
		preview_cycle = value
		apply_editor_pose()

var actor: CharacterBody2D
var preview_mode: bool = false
var phase: float = 0.0
var tail_phase: float = 0.0
var movement: float = 0.0
var running: float = 0.0
var travel_direction: Vector2 = Vector2.DOWN
var parts: Dictionary = {}
var joints: Dictionary = {}

func _ready() -> void:
	cache_parts()
	if Engine.is_editor_hint():
		apply_editor_pose()
	else:
		pose()

func cache_parts() -> void:
	parts.clear()
	for child in get_children():
		if child is Sprite2D or child is Polygon2D:
			parts[String(child.name).to_snake_case()] = child

func setup(body: CharacterBody2D, _is_monster: bool = true) -> void:
	actor = body
	cache_parts()
	pose()

func apply_editor_pose() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	preview_mode = true
	movement = 0.0 if preview_state == "idle" else 1.0
	running = 1.0 if preview_state == "run" else 0.0
	travel_direction = preview_direction.normalized() if preview_direction.length_squared() > 0.001 else Vector2.DOWN
	phase = preview_cycle * TAU
	if movement > 0.0:
		phase *= 2.0
	tail_phase = preview_cycle * TAU
	pose()

func _process(delta: float) -> void:
	if not Engine.is_editor_hint() or not preview_animation or parts.is_empty():
		return
	preview_mode = true
	movement = 0.0 if preview_state == "idle" else 1.0
	running = 1.0 if preview_state == "run" else 0.0
	travel_direction = preview_direction.normalized() if preview_direction.length_squared() > 0.001 else Vector2.DOWN
	var pace: float = lerpf(115.0, 340.0, running)
	phase = fposmod(phase + delta * TAU * pace / stride_length() * movement, TAU)
	advance_tail(delta, pace)
	pose()

func advance(delta: float) -> void:
	if not is_instance_valid(actor):
		return
	var moving_allowed: bool = bool(actor.get("active"))
	var pace: float = actor.velocity.length() if moving_allowed else 0.0
	var response: float = 1.0 - exp(-10.0 * delta)
	movement = lerpf(movement, minf(pace / 75.0, 1.0), response)
	running = lerpf(running, 1.0 if bool(actor.get("sprinting")) and moving_allowed else 0.0, response)
	# The gait follows traveled distance, so changing frame rate cannot slide its phase.
	phase = fposmod(phase + pace * delta * TAU / stride_length(), TAU)
	advance_tail(delta, pace)
	if pace > 1.0:
		var local_direction: Vector2 = actor.velocity.rotated(-(float(actor.get("facing_angle")) - PI * 0.5)).normalized()
		var blended: Vector2 = travel_direction.lerp(local_direction, response)
		travel_direction = blended.normalized() if blended.length_squared() > 0.0001 else local_direction
	pose()

func set_part(key: String, point: Vector2, size: Vector2, angle: float = 0.0) -> void:
	if not parts.has(key):
		return
	var sprite: Sprite2D = parts[key]
	if sprite.texture == null:
		return
	sprite.position = point
	sprite.rotation = angle
	sprite.scale = size / sprite.texture.get_size()

func segment(key: String, start: Vector2, finish: Vector2, width: float, overlap: float = 7.0) -> void:
	# The upstream cutout and a narrow hide fold cover each painted open end.
	set_part(key, (start + finish) * 0.5, Vector2(width, start.distance_to(finish) + overlap), (finish - start).angle() - PI * 0.5)

func paw_cycle(cycle: float) -> Vector2:
	# Match the return's end velocities to the planted backward motion. The
	# squared lift also leaves and reaches the floor with zero vertical speed.
	var t: float = fposmod(cycle / TAU, 1.0)
	var contact: float = contact_fraction()
	if t < contact:
		return Vector2(lerpf(1.0, -1.0, t / contact), 0.0)
	var swing: float = (t - contact) / (1.0 - contact)
	var tangent: float = -2.0 * (1.0 - contact) / contact
	var reach: float = -1.0 + tangent * swing + (6.0 - 3.0 * tangent) * swing * swing + (-4.0 + 2.0 * tangent) * swing * swing * swing
	return Vector2(reach, pow(sin(swing * PI), 2.0))

func contact_fraction() -> float:
	return lerpf(CONTACT_FRACTION, 0.58, running)

func stride_amplitude() -> float:
	return lerpf(22.0, 28.0, running)

func stride_length() -> float:
	# During contact the planted paw cancels exactly the body's traveled distance.
	return 2.0 * stride_amplitude() / contact_fraction()

func pose_hind_leg(side: String, sign_value: float, cycle: float) -> void:
	var step: Vector2 = paw_cycle(cycle)
	var lift: float = step.y * movement
	var hip: Vector2 = Vector2(sign_value * 9.0, -16.0)
	var foot: Vector2 = Vector2(sign_value * (12.0 + lift * 1.2), -15.0)
	foot += travel_direction * step.x * stride_amplitude() * movement
	var toe_angle: float = sign_value * 0.05 + travel_direction.x * step.x * 0.06 * lift
	var ankle: Vector2 = foot - Vector2.DOWN.rotated(toe_angle) * 5.5
	# Shortening represents the tucked leg's height below the back in an overhead view.
	var knee: Vector2 = hip.lerp(ankle, 0.52) + Vector2(sign_value * (0.8 + lift * 0.8), -lift * 2.0)
	segment(side + "_thigh", hip, knee, 9.0)
	segment(side + "_shin", knee, ankle, 7.5)
	set_part(side + "_knee", knee, Vector2(8.5, 6.0), toe_angle)
	set_part(side + "_ankle_fold", ankle, Vector2(9.5, 12.0), toe_angle)
	set_part(side + "_foot", foot, Vector2(10.0, 16.0) * (1.0 + lift * 0.08), toe_angle)
	joints[side + "_hip"] = hip
	joints[side + "_knee"] = knee
	joints[side + "_ankle"] = ankle
	joints[side + "_foot"] = foot

func pose_foreleg(side: String, sign_value: float, cycle: float) -> void:
	var step: Vector2 = paw_cycle(cycle)
	var lift: float = step.y * movement
	var shoulder: Vector2 = Vector2(sign_value * 24.0, 4.0)
	var wrist: Vector2 = Vector2(sign_value * 33.0, 26.0)
	wrist += travel_direction * step.x * stride_amplitude() * movement
	# Solve the actual crouched arm in height as well as in the overhead plane.
	# This lets a planted hand pass beneath the shoulder without snapping an IK
	# branch or forcing the paw onto a rectangular reach limit.
	var shoulder_3d: Vector3 = Vector3(shoulder.x, shoulder.y, 20.0)
	var wrist_3d: Vector3 = Vector3(wrist.x, wrist.y, lift * 7.0)
	var offset: Vector3 = wrist_3d - shoulder_3d
	var distance: float = maxf(offset.length(), 0.001)
	var direction: Vector3 = offset / distance
	var pole: Vector3 = Vector3(sign_value * 0.4, -1.0, 0.0)
	pole = (pole - direction * pole.dot(direction)).normalized()
	var along: float = (ARM_UPPER * ARM_UPPER - ARM_LOWER * ARM_LOWER + distance * distance) / (2.0 * distance)
	var height: float = sqrt(maxf(0.0, ARM_UPPER * ARM_UPPER - along * along))
	var elbow_3d: Vector3 = shoulder_3d + direction * along + pole * height
	var elbow: Vector2 = Vector2(elbow_3d.x, elbow_3d.y)
	var wrist_angle: float = elbow.direction_to(wrist).angle() - PI * 0.5
	var palm_angle: float = sign_value * 0.035 + sin(cycle) * lift * 0.10
	segment(side + "_upper_arm", shoulder, elbow, 12.0, 7.0)
	segment(side + "_forearm", elbow, wrist, 9.0, 8.0)
	set_part(side + "_shoulder", shoulder, Vector2(17.0, 18.0))
	set_part(side + "_elbow", elbow, Vector2(9.0, 6.0), wrist_angle)
	set_part(side + "_hand", wrist + Vector2.DOWN.rotated(palm_angle) * 7.0, Vector2(18.0, 26.0), palm_angle)
	joints[side + "_shoulder"] = shoulder
	joints[side + "_elbow"] = elbow
	joints[side + "_hand"] = wrist

func pose() -> void:
	if parts.is_empty():
		return
	set_part("torso", Vector2(0.0, -6.0), TORSO_SIZE)
	set_part("head", Vector2(0.0, 30.0), HEAD_SIZE)
	set_part("neck_mane", Vector2(0.0, 8.0), Vector2(52.0, 32.0))
	pose_tail()
	for index in range(2):
		var sign_value: float = -1.0 if index == 0 else 1.0
		var side: String = "left" if index == 0 else "right"
		var cycle: float = phase + PI * float(index)
		# Each forepaw travels together with the opposite hind paw.
		pose_hind_leg(side, sign_value, cycle + PI)
		pose_foreleg(side, sign_value, cycle)

func pose_tail() -> void:
	if not parts.has("tail"):
		return
	var tail: Polygon2D = parts.tail
	var points: PackedVector2Array = PackedVector2Array()
	var coordinates: PackedVector2Array = PackedVector2Array()
	var faces: Array[PackedInt32Array] = []
	var controls: PackedVector2Array = tail_controls()
	for index in range(TAIL_SECTIONS + 1):
		var t: float = float(index) / TAIL_SECTIONS
		var center: Vector2 = controls[0].bezier_interpolate(controls[1], controls[2], controls[3], t)
		var tangent: Vector2 = controls[0].bezier_derivative(controls[1], controls[2], controls[3], t).normalized()
		var normal: Vector2 = Vector2(-tangent.y, tangent.x)
		var radius: float = lerpf(9.0, 0.45, pow(t, 1.7))
		points.append(center - normal * radius)
		points.append(center + normal * radius)
		var source_y: float = tail_region.position.y + tail_region.size.y * lerpf(0.12, 0.94, t)
		coordinates.append(Vector2(tail_region.position.x, source_y))
		coordinates.append(Vector2(tail_region.end.x, source_y))
		if index < TAIL_SECTIONS:
			var start: int = index * 2
			faces.append(PackedInt32Array([start, start + 1, start + 3, start + 2]))
	tail.polygon = points
	tail.uv = coordinates
	tail.polygons = faces
	joints["tail_base"] = tail_point(0.0)
	joints["tail_first"] = tail_point(1.0 / 3.0)
	joints["tail_second"] = tail_point(2.0 / 3.0)
	joints["tail_tip"] = tail_point(1.0)

func advance_tail(delta: float, pace: float) -> void:
	# One relaxed sweep spans two strides; the tail keeps moving while standing.
	var frequency: float = lerpf(1.0 / TAIL_IDLE_PERIOD, pace / (2.0 * stride_length()), movement)
	tail_phase = fposmod(tail_phase + delta * TAU * frequency, TAU)

func tail_controls() -> PackedVector2Array:
	var base: Vector2 = Vector2(0.0, -22.0)
	var strength: float = lerpf(0.7, 1.0, movement)
	# Increasing angles and phase delay carry the bend from the root to the tip.
	return PackedVector2Array([
		base,
		base + Vector2(0.0, -18.0).rotated(sin(tail_phase) * 0.25 * strength),
		base + Vector2(0.0, -34.0).rotated(sin(tail_phase - 0.2) * 0.65 * strength),
		base + Vector2(0.0, -46.0).rotated(sin(tail_phase - 0.4) * 0.9 * strength),
	])

func tail_point(t: float) -> Vector2:
	var controls: PackedVector2Array = tail_controls()
	return controls[0].bezier_interpolate(controls[1], controls[2], controls[3], t)

