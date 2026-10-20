@tool
extends Node2D

## Saved sprite parts share the same overhead pose in the editor and in game.
## The torso masks the shortened leg projection; a step reveals cloth and a boot.
const ARM_UPPER: float = 18.0
const ARM_LOWER: float = 21.0
const TORSO_SIZE: Vector2 = Vector2(58.0, 43.0)
const HEAD_SIZE: Vector2 = Vector2(27.0, 28.0)
const ELBOW_SIZE: float = 9.0
const STOW_GRIP: Vector2 = Vector2(-24.0, 2.0)

@export var preview_animation: bool = false:
	set(value):
		preview_animation = value
		apply_editor_pose()
@export_enum("idle", "walk", "run", "idle_unlit", "walk_unlit", "run_unlit", "stow_flashlight", "draw_flashlight") var preview_state: String = "idle":
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
@export_range(0.0, 1.0, 0.001) var preview_flashlight: float = 1.0:
	set(value):
		preview_flashlight = value
		apply_editor_pose()

var actor: CharacterBody2D
var preview_mode: bool = false
var phase: float = 0.0
var movement: float = 0.0
var running: float = 0.0
var travel_direction: Vector2 = Vector2.DOWN
var joints: Dictionary = {}
var parts: Dictionary = {}
var breath_clock: float = 0.0

func _ready() -> void:
	cache_parts()
	if Engine.is_editor_hint():
		apply_editor_pose()
	else:
		pose()

func cache_parts() -> void:
	parts.clear()
	for child in get_children():
		if child is Sprite2D:
			parts[String(child.name).to_snake_case()] = child

func setup(body: CharacterBody2D, _is_monster: bool = false) -> void:
	actor = body
	cache_parts()
	pose()

func apply_editor_pose() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	preview_mode = true
	movement = 1.0 if preview_state.begins_with("walk") or preview_state.begins_with("run") else 0.0
	running = 1.0 if preview_state.begins_with("run") else 0.0
	travel_direction = preview_direction.normalized() if preview_direction.length_squared() > 0.001 else Vector2.DOWN
	phase = preview_cycle * TAU
	if not parts.is_empty():
		pose()

func _process(delta: float) -> void:
	if not Engine.is_editor_hint() or not preview_animation or parts.is_empty():
		return
	preview_mode = true
	movement = 1.0 if preview_state.begins_with("walk") or preview_state.begins_with("run") else 0.0
	running = 1.0 if preview_state.begins_with("run") else 0.0
	travel_direction = preview_direction.normalized() if preview_direction.length_squared() > 0.001 else Vector2.DOWN
	var rate: float = lerpf(7.8, 11.0, running)
	if preview_state in ["stow_flashlight", "draw_flashlight"]:
		rate = TAU / (0.82 if preview_state == "stow_flashlight" else 0.68)
	phase = fposmod(phase + delta * rate, TAU)
	breath_clock += delta
	pose()

func advance(delta: float) -> void:
	if not is_instance_valid(actor):
		return
	var alive: bool = bool(actor.get("alive"))
	var pace: float = actor.velocity.length() if alive else 0.0
	var response: float = 1.0 - exp(-10.0 * delta)
	movement = lerpf(movement, minf(pace / 75.0, 1.0), response)
	running = lerpf(running, 1.0 if bool(actor.get("sprinting")) and alive else 0.0, response)
	phase = fposmod(phase + pace * delta * TAU / lerpf(144.0, 175.0, running), TAU)
	breath_clock += delta
	if pace > 1.0:
		var local_direction: Vector2 = actor.velocity.rotated(-(float(actor.get("facing_angle")) - PI * 0.5)).normalized()
		var blended: Vector2 = travel_direction.lerp(local_direction, response)
		travel_direction = blended.normalized() if blended.length_squared() > 0.0001 else local_direction
	pose()

func flashlight_progress() -> float:
	if not preview_mode and not Engine.is_editor_hint() and is_instance_valid(actor):
		return float(actor.get("flashlight_reveal"))
	if preview_state.ends_with("_unlit"):
		return 0.0
	if preview_state == "stow_flashlight":
		return 1.0 - clampf(phase / TAU, 0.0, 1.0)
	if preview_state == "draw_flashlight":
		return clampf(phase / TAU, 0.0, 1.0)
	return preview_flashlight

func flashlight_reveal() -> float:
	return smoothstep(0.0, 1.0, flashlight_progress())

func flashlight_angle() -> float:
	var raised: float = smoothstep(0.42, 1.0, flashlight_reveal())
	var sway: float = sin(phase) * deg_to_rad(2.2) * running * movement * raised
	return lerpf(-1.7, 0.0, raised) + sway

func flashlight_alpha() -> float:
	return smoothstep(0.30, 0.45, flashlight_reveal())

func clamp_tip(start: Vector2, finish: Vector2) -> Vector2:
	var offset: Vector2 = finish - start
	var minimum: float = sqrt(ARM_UPPER * ARM_UPPER + ARM_LOWER * ARM_LOWER + 2.0 * ARM_UPPER * ARM_LOWER * cos(deg_to_rad(135.0)))
	var maximum: float = sqrt(ARM_UPPER * ARM_UPPER + ARM_LOWER * ARM_LOWER + 2.0 * ARM_UPPER * ARM_LOWER * cos(deg_to_rad(18.0)))
	var direction: Vector2 = offset.normalized() if offset.length_squared() > 0.0001 else Vector2.DOWN
	return start + direction * clampf(offset.length(), minimum, maximum)

func flashlight_grip() -> Vector2:
	return left_arm_pose().hand

func solve_elbow(shoulder: Vector2, hand: Vector2, side: float, projection: float = 1.0) -> Vector2:
	var offset: Vector2 = hand - shoulder
	var distance: float = maxf(offset.length(), 0.0001)
	var direction: Vector2 = offset / distance
	var upper: float = ARM_UPPER * projection
	var lower: float = ARM_LOWER * projection
	var along: float = (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var height: float = sqrt(maxf(0.0, upper * upper - along * along))
	var first: Vector2 = shoulder + direction * along + direction.orthogonal() * height
	var second: Vector2 = shoulder + direction * along - direction.orthogonal() * height
	return first if first.x * side > second.x * side else second

func set_part(key: String, point: Vector2, size: Vector2, angle: float = 0.0) -> void:
	var sprite: Sprite2D = parts[key]
	sprite.position = point
	sprite.rotation = angle
	sprite.scale = size / sprite.texture.get_size()

func segment(key: String, start: Vector2, finish: Vector2, width: float, overlap: float = 8.0) -> void:
	# Upstream cloth and joint caps cover the painted open ends of each cutout.
	set_part(key, (start + finish) * 0.5, Vector2(width, start.distance_to(finish) + overlap), (finish - start).angle() - PI * 0.5)

func step_sample(cycle: float) -> Vector2:
	# A planted boot travels backward for 60% of the stride, then swings forward.
	var t: float = fposmod(cycle / TAU + 0.25, 1.0)
	if t < 0.6:
		return Vector2(cos(t / 0.6 * PI), 0.0)
	var swing: float = (t - 0.6) / 0.4
	return Vector2(-cos(swing * PI), sin(swing * PI))

func pose_leg(side: String, sign_value: float, cycle: float) -> void:
	var step: Vector2 = step_sample(cycle)
	var stride: float = lerpf(24.0, 30.0, running) * movement
	var hip: Vector2 = Vector2(sign_value * 10.0, -1.0)
	var foot: Vector2 = Vector2(sign_value * 11.5, 8.0) + travel_direction * step.x * stride
	# The projected leg remains short: the upper limb is mostly beneath the jacket.
	var ankle: Vector2 = foot - Vector2(0.0, 5.0)
	var knee: Vector2 = hip.lerp(ankle, 0.54)
	knee += Vector2(sign_value * (1.0 + 2.4 * step.y * movement), -2.8 * step.y * movement)
	segment(side + "_thigh", hip, knee, 13.0)
	segment(side + "_shin", knee, ankle, 12.0, 10.0)
	set_part(side + "_knee", knee, Vector2.ONE * 11.0)
	var toe_turn: float = sign_value * 0.055 + travel_direction.x * step.x * movement * 0.16
	set_part(side + "_foot", foot, Vector2(11.5, 18.0) * (1.0 + step.y * movement * 0.065), toe_turn)
	joints[side + "_hip"] = hip
	joints[side + "_knee"] = knee
	joints[side + "_foot"] = foot

func free_arm_pose(side: float = 1.0, index: int = 1) -> Dictionary:
	# Project a connected, fixed-length arm onto the overhead plane. The omitted
	# height component folds naturally as the upper arm swings and the elbow bends.
	var shoulder: Vector2 = Vector2(side * 22.0, 1.0)
	var counter_step: float = -step_sample(phase + PI * float(index)).x
	var upper_angle: float = deg_to_rad(-7.0 + counter_step * lerpf(28.0, 38.0, running) * movement)
	var flexion: float = deg_to_rad(lerpf(22.0, lerpf(50.0, 72.0, running), movement))
	var abduction: float = deg_to_rad(15.0)
	var adduction: float = deg_to_rad(12.0)
	var upper_swing: float = ARM_UPPER * cos(abduction) * sin(upper_angle)
	var upper: Vector2 = Vector2(side * ARM_UPPER * sin(abduction), 0.0)
	upper += Vector2(travel_direction.x * 0.20, travel_direction.y) * upper_swing
	var lower_angle: float = flexion + upper_angle * travel_direction.y
	var lower: Vector2 = Vector2(-side * ARM_LOWER * sin(adduction), ARM_LOWER * cos(adduction) * sin(lower_angle))
	var elbow: Vector2 = shoulder + upper
	var hand: Vector2 = elbow + lower
	var hand_size: Vector2 = Vector2(8.8, lerpf(5.8, 10.5, lower.length() / ARM_LOWER))
	return {"shoulder": shoulder, "elbow": elbow, "hand": hand, "hand_size": hand_size, "flexion": flexion, "stride": counter_step}

func left_arm_pose() -> Dictionary:
	var natural: Dictionary = free_arm_pose(-1.0, 0)
	var reveal: float = flashlight_reveal()
	var raise_amount: float = smoothstep(0.42, 1.0, reveal)
	var carry: float = smoothstep(0.05, 0.28, reveal)
	var control: Vector2 = Vector2(-38.0, 20.0)
	var raised: Vector2 = Vector2(-17.0, 25.0)
	var reach: Vector2 = STOW_GRIP.lerp(control, raise_amount).lerp(control.lerp(raised, raise_amount), raise_amount)
	reach += Vector2(sin(phase) * 0.7, cos(phase * 2.0) * 0.6) * movement * raise_amount
	# The connected arm absorbs each running step while the wrist rocks the beam.
	reach += Vector2(sin(phase) * 1.4, cos(phase * 2.0) * 0.9) * running * movement * raise_amount
	var projection: float = lerpf(0.32, 1.0, smoothstep(3.0, 22.0, reach.distance_to(natural.shoulder)))
	var reach_elbow: Vector2 = solve_elbow(natural.shoulder, reach, -1.0, projection)
	var hand: Vector2 = Vector2(natural.hand).lerp(reach, carry)
	var elbow: Vector2 = Vector2(natural.elbow).lerp(reach_elbow, carry)
	if not preview_mode and is_instance_valid(actor) and bool(actor.get("grabbed")):
		hand += Vector2(sin(float(actor.get("grab_clock")) * 24.0) * 3.0, cos(float(actor.get("grab_clock")) * 27.0) * 3.0) * carry
	var size: Vector2 = Vector2(natural.hand_size).lerp(Vector2(9.5, 11.5), carry)
	return {"shoulder": natural.shoulder, "elbow": elbow, "hand": hand, "hand_size": size}

func pose() -> void:
	if parts.is_empty():
		return
	var struggling: bool = not preview_mode and is_instance_valid(actor) and bool(actor.get("grabbed"))
	var struggle_clock: float = float(actor.get("grab_clock")) if struggling else 0.0
	var breath: float = sin(breath_clock * 2.3) * (1.0 - movement) * 0.004
	var sway: float = sin(phase * 2.0) * movement * lerpf(0.28, 0.55, running)
	set_part("torso", Vector2(sin(struggle_clock * 29.0) * 2.5, -3.0 + sway), TORSO_SIZE * Vector2(1.0 + breath, 1.0), sin(struggle_clock * 19.0) * (0.07 if struggling else 0.0))
	set_part("head", Vector2(0.0, 8.0 + sway * 0.35), HEAD_SIZE, sin(struggle_clock * 23.0) * (0.13 if struggling else 0.0))
	for index in range(2):
		var sign_value: float = -1.0 if index == 0 else 1.0
		var side: String = "left" if index == 0 else "right"
		var cycle: float = phase + PI * float(index)
		pose_leg(side, sign_value, cycle)
		var arm: Dictionary = left_arm_pose() if index == 0 else free_arm_pose()
		var shoulder: Vector2 = arm.shoulder
		var hand: Vector2 = arm.hand
		var elbow: Vector2 = arm.elbow
		var hand_size: Vector2 = arm.hand_size
		if index == 1 and struggling:
			hand += Vector2(sin(struggle_clock * 24.0) * 6.0, -8.0 + cos(struggle_clock * 23.0) * 5.0)
			elbow = shoulder.lerp(hand, 0.45) + Vector2(4.0, 0.0)
		segment(side + "_upper_arm", shoulder, elbow, 16.0)
		segment(side + "_forearm", elbow, hand, 12.0)
		set_part(side + "_shoulder", shoulder, Vector2(18.0, 18.0))
		var hand_angle: float = elbow.direction_to(hand).angle() - PI * 0.5
		# A short cloth fold follows the forearm instead of a round joint cap.
		set_part(side + "_elbow", elbow, Vector2(ELBOW_SIZE + 1.5, ELBOW_SIZE * 0.7), hand_angle)
		if index == 0:
			# Fingers close across the barrel; wrist and held prop share one axis.
			hand_angle = lerp_angle(hand_angle, flashlight_angle(), smoothstep(0.05, 0.28, flashlight_reveal()))
		var palm_offset: Vector2 = Vector2.DOWN.rotated(hand_angle) * 2.5
		set_part(side + "_hand", hand + palm_offset, hand_size, hand_angle)
		joints[side + "_shoulder"] = shoulder
		joints[side + "_elbow"] = elbow
		joints[side + "_hand"] = hand
	var torch_angle: float = flashlight_angle()
	set_part("flashlight", flashlight_grip() + Vector2.DOWN.rotated(torch_angle) * 6.0, Vector2(6.0, 19.0), torch_angle)
	parts.flashlight.modulate.a = flashlight_alpha()
