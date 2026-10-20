@tool
extends Node2D

## Bare skin cutouts share the survivor's connected overhead projection.
## Gaunt shoulders mask the upper legs; sinew folds cover the skin connections.
const ARM_UPPER: float = 21.0
const ARM_LOWER: float = 27.0
const TORSO_SIZE: Vector2 = Vector2(44.0, 38.0)
const HEAD_SIZE: Vector2 = Vector2(20.0, 24.0)

@export var preview_animation: bool = false:
	set(value):
		preview_animation = value
		apply_editor_pose()
@export_enum("idle", "walk", "run", "stalk", "flee", "leap", "grab") var preview_state: String = "idle":
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
var movement: float = 0.0
var running: float = 0.0
var travel_direction: Vector2 = Vector2.DOWN
var parts: Dictionary = {}
var joints: Dictionary = {}
var breath_clock: float = 0.0
var attack_release: float = 0.0
var previous_attack: bool = false
var last_attack_arms: Dictionary = {}

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

func setup(body: CharacterBody2D, _is_monster: bool = true) -> void:
	actor = body
	cache_parts()
	pose()

func apply_editor_pose() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	preview_mode = true
	movement = 1.0 if preview_state in ["walk", "run", "stalk", "flee"] else 0.0
	running = 1.0 if preview_state in ["run", "flee"] else 0.0
	travel_direction = preview_direction.normalized() if preview_direction.length_squared() > 0.001 else Vector2.DOWN
	phase = preview_cycle * TAU
	if not parts.is_empty():
		pose()

func _process(delta: float) -> void:
	if not Engine.is_editor_hint() or not preview_animation or parts.is_empty():
		return
	var rate: float = lerpf(7.8, 11.0, running)
	if preview_state == "leap":
		rate = TAU / 0.75
	elif preview_state == "grab":
		rate = TAU / 3.0
	phase = fposmod(phase + delta * rate, TAU)
	breath_clock += delta
	pose()

func advance(delta: float) -> void:
	if not is_instance_valid(actor):
		return
	var attacking: bool = String(actor.get("state")) in ["leap", "grab"]
	if previous_attack and not attacking:
		attack_release = 1.0
	attack_release = move_toward(attack_release, 0.0, delta / 0.16)
	previous_attack = attacking
	var pace: float = actor.velocity.length() if bool(actor.get("active")) else 0.0
	var response: float = 1.0 - exp(-10.0 * delta)
	movement = lerpf(movement, minf(pace / 75.0, 1.0), response)
	running = lerpf(running, 1.0 if bool(actor.get("sprinting")) and bool(actor.get("active")) else 0.0, response)
	phase = fposmod(phase + pace * delta * TAU / lerpf(144.0, 175.0, running), TAU)
	breath_clock += delta
	if pace > 1.0:
		var local_direction: Vector2 = actor.velocity.rotated(-(float(actor.get("facing_angle")) - PI * 0.5)).normalized()
		var blended: Vector2 = travel_direction.lerp(local_direction, response)
		travel_direction = blended.normalized() if blended.length_squared() > 0.0001 else local_direction
	pose()

func pose_state() -> String:
	if preview_mode or Engine.is_editor_hint() or not is_instance_valid(actor):
		return preview_state
	return String(actor.get("state"))

func leap_amount() -> float:
	if preview_mode or Engine.is_editor_hint() or not is_instance_valid(actor):
		return clampf(phase / TAU, 0.0, 1.0)
	return clampf(float(actor.get("leap_progress")), 0.0, 1.0)

func grab_clock() -> float:
	if preview_mode or Engine.is_editor_hint() or not is_instance_valid(actor):
		return phase / TAU * 3.0
	return float(actor.get("attack_elapsed"))

func set_part(key: String, point: Vector2, size: Vector2, angle: float = 0.0) -> void:
	if not parts.has(key):
		return
	var sprite: Sprite2D = parts[key]
	if not is_instance_valid(sprite) or sprite.texture == null:
		return
	sprite.position = point
	sprite.rotation = angle
	sprite.scale = size / sprite.texture.get_size()

func segment(key: String, start: Vector2, finish: Vector2, width: float, overlap: float = 8.0) -> void:
	# Joint folds and proximal cloth overlap the painted open ends of each cutout.
	set_part(key, (start + finish) * 0.5, Vector2(width, start.distance_to(finish) + overlap), (finish - start).angle() - PI * 0.5)

func step_sample(cycle: float) -> Vector2:
	# A planted foot pushes back for 60% of the cycle before the lifted return.
	var t: float = fposmod(cycle / TAU + 0.25, 1.0)
	if t < 0.6:
		return Vector2(cos(t / 0.6 * PI), 0.0)
	var swing: float = (t - 0.6) / 0.4
	return Vector2(-cos(swing * PI), sin(swing * PI))

func pose_leg(side: String, sign_value: float, cycle: float, mode: String, arc: float, struggle: float) -> void:
	var step: Vector2 = step_sample(cycle)
	var stride: float = lerpf(24.0, 30.0, running) * movement
	var hip: Vector2 = Vector2(sign_value * 9.0, -2.0)
	var foot: Vector2 = Vector2(sign_value * 10.5, 7.5) + travel_direction * step.x * stride
	if mode == "leap":
		foot += Vector2(sign_value * 7.0, -12.0) * arc
	elif mode == "grab":
		foot += Vector2(sign_value * sin(struggle * 23.0) * 2.0, cos(struggle * 19.0 + (0.0 if sign_value < 0.0 else PI)) * 3.0)
	var ankle: Vector2 = foot - Vector2(0.0, 5.0)
	var knee: Vector2 = hip.lerp(ankle, 0.54)
	knee += Vector2(sign_value * (1.0 + 2.4 * step.y * movement), -2.8 * step.y * movement)
	segment(side + "_thigh", hip, knee, 7.5, 6.0)
	segment(side + "_shin", knee, ankle, 6.0, 7.0)
	set_part(side + "_knee", knee, Vector2.ONE * 6.5)
	var toe_turn: float = sign_value * 0.055 + travel_direction.x * step.x * movement * 0.16
	set_part(side + "_foot", foot, Vector2(8.0, 17.0) * (1.0 + step.y * movement * 0.065), toe_turn)
	joints[side + "_hip"] = hip
	joints[side + "_knee"] = knee
	joints[side + "_foot"] = foot

func free_arm_pose(side: float = 1.0, index: int = 1) -> Dictionary:
	# Physical arm lengths stay fixed in 3D; their overhead projection shortens
	# as the arm hangs down and unfolds in counterphase to the same-side foot.
	var shoulder: Vector2 = Vector2(side * 16.0, 1.0)
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
	var hand_size: Vector2 = Vector2(6.5, lerpf(7.0, 17.0, lower.length() / ARM_LOWER))
	return {"shoulder": shoulder, "elbow": elbow, "hand": hand, "hand_size": hand_size, "flexion": flexion, "stride": counter_step}

func clamp_tip(shoulder: Vector2, hand: Vector2) -> Vector2:
	var offset: Vector2 = hand - shoulder
	var minimum: float = sqrt(ARM_UPPER * ARM_UPPER + ARM_LOWER * ARM_LOWER + 2.0 * ARM_UPPER * ARM_LOWER * cos(deg_to_rad(145.0)))
	var maximum: float = sqrt(ARM_UPPER * ARM_UPPER + ARM_LOWER * ARM_LOWER + 2.0 * ARM_UPPER * ARM_LOWER * cos(deg_to_rad(18.0)))
	var direction: Vector2 = offset.normalized() if offset.length_squared() > 0.0001 else Vector2.DOWN
	return shoulder + direction * clampf(offset.length(), minimum, maximum)

func solve_elbow(shoulder: Vector2, hand: Vector2, side: float) -> Vector2:
	var offset: Vector2 = hand - shoulder
	var distance: float = maxf(offset.length(), 0.0001)
	var direction: Vector2 = offset / distance
	var along: float = (ARM_UPPER * ARM_UPPER - ARM_LOWER * ARM_LOWER + distance * distance) / (2.0 * distance)
	var height: float = sqrt(maxf(0.0, ARM_UPPER * ARM_UPPER - along * along))
	var first: Vector2 = shoulder + direction * along + direction.orthogonal() * height
	var second: Vector2 = shoulder + direction * along - direction.orthogonal() * height
	return first if first.x * side > second.x * side else second

func attack_arm_pose(natural: Dictionary, side: float, index: int, mode: String, leap: float, struggle: float) -> Dictionary:
	if mode not in ["leap", "grab"]:
		if not preview_mode and attack_release > 0.0 and last_attack_arms.has(index):
			var previous: Dictionary = last_attack_arms[index]
			return {
				"shoulder": natural.shoulder,
				"elbow": Vector2(natural.elbow).lerp(previous.elbow, attack_release),
				"hand": Vector2(natural.hand).lerp(previous.hand, attack_release),
				"hand_size": Vector2(natural.hand_size).lerp(previous.hand_size, attack_release),
			}
		return natural
	var shoulder: Vector2 = natural.shoulder
	var target: Vector2 = Vector2(side * 31.0, 47.0)
	var reach: float = smoothstep(0.0, 0.26, leap) if mode == "leap" else 1.0
	if mode == "leap":
		target += Vector2(side * 5.0, 3.0) * sin(leap * PI)
	else:
		target += Vector2(side * sin(struggle * 24.0 + float(index)) * 2.5, cos(struggle * 21.0 + float(index)) * 2.5)
	target = clamp_tip(shoulder, target)
	var elbow: Vector2 = solve_elbow(shoulder, target, side)
	var result: Dictionary = {
		"shoulder": shoulder,
		"elbow": Vector2(natural.elbow).lerp(elbow, reach),
		"hand": Vector2(natural.hand).lerp(target, reach),
		"hand_size": Vector2(natural.hand_size).lerp(Vector2(8.5, 25.0), reach),
	}
	if not preview_mode:
		last_attack_arms[index] = result
	return result

func pose() -> void:
	if parts.is_empty():
		return
	var mode: String = pose_state()
	var leap: float = leap_amount() if mode == "leap" else 0.0
	var arc: float = sin(leap * PI)
	var struggle: float = grab_clock() if mode == "grab" else 0.0
	scale = Vector2.ONE * (1.0 + arc * 0.18)
	var breath: float = sin(breath_clock * 2.3) * (1.0 - movement) * 0.004
	var sway: float = sin(phase * 2.0) * movement * lerpf(0.28, 0.55, running)
	set_part("torso", Vector2(0.0, -4.0 + sway), TORSO_SIZE * Vector2(1.0 + breath, 1.0), sin(struggle * 19.0) * 0.025)
	set_part("head", Vector2(sin(struggle * 23.0) * 0.7, 10.0 + sway * 0.35), HEAD_SIZE, sin(struggle * 27.0) * 0.04)
	for index in range(2):
		var sign_value: float = -1.0 if index == 0 else 1.0
		var side: String = "left" if index == 0 else "right"
		var cycle: float = phase + PI * float(index)
		pose_leg(side, sign_value, cycle, mode, arc, struggle)
		var natural: Dictionary = free_arm_pose(sign_value, index)
		var arm: Dictionary = attack_arm_pose(natural, sign_value, index, mode, leap, struggle)
		var shoulder: Vector2 = arm.shoulder
		var elbow: Vector2 = arm.elbow
		var hand: Vector2 = arm.hand
		var hand_angle: float = elbow.direction_to(hand).angle() - PI * 0.5
		segment(side + "_upper_arm", shoulder, elbow, 7.5, 5.0)
		segment(side + "_forearm", elbow, hand, 5.5, 5.0)
		set_part(side + "_shoulder", shoulder, Vector2(11.0, 11.0))
		set_part(side + "_elbow", elbow, Vector2(6.5, 5.0), hand_angle)
		set_part(side + "_hand", hand + Vector2.DOWN.rotated(hand_angle) * 4.0, arm.hand_size, hand_angle)
		joints[side + "_shoulder"] = shoulder
		joints[side + "_elbow"] = elbow
		joints[side + "_hand"] = hand
