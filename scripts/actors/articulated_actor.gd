extends Node2D

var actor: CharacterBody2D
var monstrous: bool = false
var phase: float = 0.0
var movement: float = 0.0
var running: float = 0.0
var travel_direction: Vector2 = Vector2.DOWN
var parts: Dictionary = {}
var textures: Dictionary = {}
var joints: Dictionary = {}
var preview_mode: bool = false

func setup(body: CharacterBody2D, is_monster: bool) -> void:
	actor = body
	monstrous = is_monster
	var folder: String = "monster" if monstrous else "player"
	for part in ["torso", "head", "upper_arm", "forearm", "foot", "hand", "flashlight"]:
		textures[part] = load("res://assets/characters/%s/rig/%s.tres" % [folder, part])
	if monstrous:
		textures["hand"] = preload("res://assets/characters/monster/rig/front_paw.svg")
	parts.clear()
	var authored: bool = get_child_count() > 0
	if authored:
		for child in get_children():
			parts[String(child.name).to_snake_case()] = child
	else:
		for side in ["left", "right"]:
			make_part(side + "_foot", "foot", -1)
		make_part("torso", "torso", 0)
		for side in ["left", "right"]:
			make_part(side + "_upper_arm", "upper_arm", 1)
			make_part(side + "_forearm", "forearm", 2)
			make_part(side + "_hand", "hand", 3)
			make_joint(side + "_elbow", "upper_arm", 2)
		make_part("head", "head", 4)
	if not authored:
		set_static_part("torso", Vector2(0, -5), Vector2(46, 66) if monstrous else Vector2(62, 57))
		parts.torso.rotation = PI
		set_static_part("head", Vector2(0, 29) if monstrous else Vector2(0, 23), Vector2(67, 57) if monstrous else Vector2(27, 29))
	pose()

func make_part(key: String, texture_key: String, depth: int) -> void:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = key.to_pascal_case()
	sprite.texture = textures[texture_key]
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.z_index = depth
	add_child(sprite)
	parts[key] = sprite
	if key.begins_with("right_"):
		sprite.flip_h = true

func make_joint(key: String, texture_key: String, depth: int) -> void:
	var source: AtlasTexture = textures[texture_key]
	var patch: AtlasTexture = AtlasTexture.new()
	patch.atlas = source.atlas
	var size: float = minf(source.region.size.x, source.region.size.y) * 0.35
	patch.region = Rect2(source.region.get_center() - Vector2.ONE * size * 0.5, Vector2.ONE * size)
	patch.filter_clip = true
	textures[key] = patch
	make_part(key, key, depth)
	var joint_material: ShaderMaterial = ShaderMaterial.new()
	joint_material.shader = preload("res://shaders/rig_joint.gdshader")
	joint_material.set_shader_parameter("patch_size", patch.region.size)
	parts[key].material = joint_material

func set_static_part(key: String, point: Vector2, size: Vector2) -> void:
	var sprite: Sprite2D = parts[key]
	sprite.position = point
	sprite.scale = size / sprite.texture.get_size()

func segment(key: String, start: Vector2, finish: Vector2, width: float) -> void:
	var sprite: Sprite2D = parts[key]
	sprite.position = (start + finish) * 0.5
	sprite.rotation = (finish - start).angle() - PI * 0.5
	sprite.scale = Vector2(width, start.distance_to(finish) + 5.0) / sprite.texture.get_size()

func clamp_tip(start: Vector2, finish: Vector2, upper: float, lower: float, max_bend: float) -> Vector2:
	var offset: Vector2 = finish - start
	var minimum: float = sqrt(upper * upper + lower * lower + 2.0 * upper * lower * cos(deg_to_rad(max_bend)))
	var maximum: float = sqrt(upper * upper + lower * lower + 2.0 * upper * lower * cos(deg_to_rad(18.0)))
	var direction: Vector2 = offset.normalized() if offset.length_squared() > 0.0001 else Vector2.DOWN
	return start + direction * clampf(offset.length(), minimum, maximum)

func solve_joint(start: Vector2, finish: Vector2, upper: float, lower: float, bend: float) -> Vector2:
	var offset: Vector2 = finish - start
	var distance: float = offset.length()
	var direction: Vector2 = offset.normalized() if offset.length() > 0.01 else Vector2.DOWN
	var along: float = (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var height: float = sqrt(maxf(0.0, upper * upper - along * along))
	return start + direction * along + direction.orthogonal() * height * bend

func advance(delta: float) -> void:
	if not is_instance_valid(actor):
		return
	var moving_allowed: bool = bool(actor.get("active")) if monstrous else bool(actor.get("alive"))
	var pace: float = actor.velocity.length() if moving_allowed else 0.0
	var response: float = 1.0 - exp(-10.0 * delta)
	movement = lerpf(movement, minf(pace / 75.0, 1.0), response)
	running = lerpf(running, 1.0 if actor.get("sprinting") and moving_allowed else 0.0, response)
	phase = fposmod(phase + pace * delta * TAU / lerpf(144.0, 175.0, running), TAU)
	if pace > 1.0:
		var local_direction: Vector2 = actor.velocity.rotated(-(float(actor.get("facing_angle")) - PI * 0.5)).normalized()
		travel_direction = travel_direction.lerp(local_direction, response).normalized()
	pose()

func flashlight_grip() -> Vector2:
	var reveal: float = 1.0 if preview_mode else smoothstep(0.0, 1.0, float(actor.get("flashlight_reveal")))
	var tucked: Vector2 = Vector2(-40, 19)
	var control: Vector2 = Vector2(-54, 30)
	var raised: Vector2 = Vector2(-22, 35)
	var hand: Vector2 = tucked.lerp(control, reveal).lerp(control.lerp(raised, reveal), reveal)
	hand += Vector2(sin(phase) * 0.7, cos(phase * 2.0) * 0.6) * movement * reveal
	if not preview_mode and is_instance_valid(actor) and actor.get("grabbed"):
		hand += Vector2(sin(float(actor.get("grab_clock")) * 24.0) * 3.0, cos(float(actor.get("grab_clock")) * 27.0) * 3.0)
	return clamp_tip(Vector2(-25, 10), hand, 20.0, 23.0, 135.0)

func pose() -> void:
	if monstrous:
		pose_quadruped()
		return
	var struggling: bool = not preview_mode and is_instance_valid(actor) and bool(actor.get("grabbed"))
	var struggle_clock: float = float(actor.get("grab_clock")) if struggling else 0.0
	parts.torso.position = Vector2(sin(struggle_clock * 29.0) * 2.5, -5)
	parts.torso.rotation = PI + sin(struggle_clock * 19.0) * (0.07 if struggling else 0.0)
	parts.head.rotation = sin(struggle_clock * 23.0) * (0.13 if struggling else 0.0)
	for side_index in range(2):
		var sign_value: float = -1.0 if side_index == 0 else 1.0
		var side: String = "left" if side_index == 0 else "right"
		var cycle: float = phase + PI * float(side_index)
		# In an overhead view the torso occludes the legs; only feet emerge during steps.
		var foot: Vector2 = Vector2(sign_value * 13.0, -35.0 if monstrous else -31.0)
		foot += travel_direction * sin(cycle) * lerpf(10.0, 15.0, running) * movement
		set_static_part(side + "_foot", foot, Vector2(12, 18) if monstrous else Vector2(14, 19))
		joints[side + "_foot"] = foot
		var shoulder: Vector2 = Vector2(sign_value * (22.0 if monstrous else 25.0), 10.0)
		var hand: Vector2
		if monstrous:
			hand = Vector2(sign_value * (42.0 + cos(cycle) * 2.0 * movement), 40.0 + sin(cycle) * 13.0 * movement)
		elif side_index == 0:
			hand = flashlight_grip()
		else:
			hand = shoulder + Vector2(9.0 + cos(cycle) * 2.0 * movement, 26.0 + sin(cycle) * 10.0 * movement)
			if struggling: hand += Vector2(sin(struggle_clock * 24.0) * 6.0, -8.0 + cos(struggle_clock * 23.0) * 5.0)
		var upper_arm: float = 29.0 if monstrous else 20.0
		var lower_arm: float = 32.0 if monstrous else 23.0
		hand = clamp_tip(shoulder, hand, upper_arm, lower_arm, 135.0)
		var elbow: Vector2 = solve_joint(shoulder, hand, upper_arm, lower_arm, -sign_value)
		if not monstrous:
			var alternate: Vector2 = solve_joint(shoulder, hand, upper_arm, lower_arm, sign_value)
			if alternate.x * sign_value > elbow.x * sign_value:
				elbow = alternate
		segment(side + "_upper_arm", shoulder, elbow, 9.5 if monstrous else 17.0)
		segment(side + "_forearm", elbow, hand, 7.0 if monstrous else 12.0)
		var palm: Sprite2D = parts[side + "_hand"]
		var wrist_direction: Vector2 = elbow.direction_to(hand)
		palm.position = hand + wrist_direction * (10.0 if monstrous else 4.0)
		palm.scale = (Vector2(14, 26) if monstrous else Vector2(10, 12)) / palm.texture.get_size()
		palm.rotation = wrist_direction.angle() - PI * 0.5
		set_static_part(side + "_elbow", elbow, Vector2.ONE * (9.0 if monstrous else 13.0))
		joints[side + "_shoulder"] = shoulder
		joints[side + "_elbow"] = elbow
		joints[side + "_hand"] = hand

func paw_cycle(cycle: float) -> Vector2:
	# Ground contact occupies 64% of a stride; the paw plants and pushes backward.
	var t: float = fposmod(cycle / TAU, 1.0)
	if t < 0.64:
		return Vector2(lerpf(1.0, -1.0, t / 0.64), 0.0)
	var swing: float = (t - 0.64) / 0.36
	return Vector2(lerpf(-1.0, 1.0, smoothstep(0.0, 1.0, swing)), sin(swing * PI))

func pose_quadruped() -> void:
	for side_index in range(2):
		var sign_value: float = -1.0 if side_index == 0 else 1.0
		var side: String = "left" if side_index == 0 else "right"
		var cycle: float = phase + PI * float(side_index)
		# Diagonal trot: each forepaw pairs with the opposite hind paw.
		var fore: Vector2 = paw_cycle(cycle)
		var hind: Vector2 = paw_cycle(cycle + PI)
		var stride: float = lerpf(15.0, 23.0, running) * movement
		var foot: Vector2 = Vector2(sign_value * 17.0, -34.0) + travel_direction * hind.x * stride
		set_static_part(side + "_foot", foot, Vector2(13, 18) * (1.0 + hind.y * movement * 0.12))
		parts[side + "_foot"].rotation = sign_value * 0.1 + hind.y * sign_value * 0.12 * movement
		joints[side + "_foot"] = foot
		var shoulder: Vector2 = Vector2(sign_value * 19.0, 9.0)
		var paw: Vector2 = Vector2(sign_value * (25.0 - fore.y * movement * 3.0), 41.0) + travel_direction * fore.x * stride
		paw = clamp_tip(shoulder, paw, 27.0, 29.0, 145.0)
		# Fold the forelegs backward beside the rib cage rather than splaying arms outward.
		var elbow: Vector2 = solve_joint(shoulder, paw, 27.0, 29.0, sign_value)
		segment(side + "_upper_arm", shoulder, elbow, 11.0)
		segment(side + "_forearm", elbow, paw, 8.0)
		set_static_part(side + "_elbow", elbow, Vector2.ONE * 10.0)
		set_static_part(side + "_hand", paw + Vector2(0, 5), Vector2(15, 17) * (1.0 + fore.y * movement * 0.12))
		parts[side + "_hand"].rotation = sign_value * 0.08
		joints[side + "_shoulder"] = shoulder
		joints[side + "_elbow"] = elbow
		joints[side + "_hand"] = paw
