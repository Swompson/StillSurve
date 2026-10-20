extends CharacterBody2D

@export var speed: float = 180.0
@export var sprint_speed: float = 310.0
@export var backward_speed_multiplier: float = 0.6
@export var turn_response: float = 10.2
@export var turn_speed_degrees: float = 612.0
@export_range(0.1, 1.0) var tired_turn_multiplier: float = 0.55
@export var field_of_view: float = 83.16
@export var ambient_view_distance: float = 180.0
@export var view_distance: float = 560.0
@export_range(0.1, 0.95) var beam_fade_start: float = 0.60
@export var stamina_max: float = 100.0
@export var stamina_drain: float = 25.0
@export var stamina_regen: float = 18.0
@export var battery_max: float = 70.0
@export var battery_drain: float = 0.5
@export var flashlight_draw_duration: float = 0.68
@export var flashlight_stow_duration: float = 0.82

@onready var hero_sprite: AnimatedSprite2D = $Sprite
@onready var footsteps: AudioStreamPlayer2D = $Footsteps
@onready var torch: Node2D = $Flashlight

var game: Node
var glass_contact: RefCounted = preload("res://scripts/world/glass_contact.gd").new()
var alive: bool = true
var facing_angle: float = PI * 0.5
var stamina: float = 100.0
var battery: float = 70.0
var muzzle_shape: CircleShape2D = CircleShape2D.new()
var flashlight_on: bool = true
var sprinting: bool = false
var exhausted: bool = false
var grabbed: bool = false
var grab_clock: float = 0.0
var regen_delay: float = 0.0
var stride_phase: float = 0.0
var flashlight_reveal: float = 0.0
var flashlight_strength: float = 0.0
var switch_engaged: bool = false
var flicker_clock: float = 0.0
var flicker_remaining: float = 0.0
var flicker_multiplier: float = 1.0
const SWITCH_ON = preload("res://assets/audio/flashlight/user_switch_on.wav")
const SWITCH_OFF = preload("res://assets/audio/flashlight/user_switch_off.wav")
const SWITCH_ATTACK_TIME: float = 0.12

func _ready() -> void:
	# These visuals follow the interpolated observer at render frequency. Their
	# transforms must not be interpolated a second time by the physics renderer.
	hero_sprite.top_level = true
	hero_sprite.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	hero_sprite.global_position = global_position
	torch.top_level = true
	torch.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	battery = battery_max
	muzzle_shape.radius = 4.0
	$AudioListener.make_current()
	stamina = stamina_max
	footsteps.stepped.connect(_on_step)

func _process(delta: float) -> void:
	var observer: Vector2 = get_render_observer()
	hero_sprite.global_position = observer
	if alive and is_physics_processing():
		update_mouse_aim(delta)
		update_flashlight()
		torch.global_position = get_view_origin_at(observer)

func get_render_observer() -> Vector2:
	if is_instance_valid(game):
		var visibility: Node = game.get_node("Visibility")
		if visibility.get("pose_initialized") and global_position.distance_to(visibility.get("current_observer")) < 128.0:
			return Vector2(visibility.get("previous_observer")).lerp(visibility.get("current_observer"), Engine.get_physics_interpolation_fraction())
	return global_position

func _physics_process(delta: float) -> void:
	if not alive:
		velocity = Vector2.ZERO
		sprinting = false
		return
	var flashlight_duration: float = flashlight_draw_duration if flashlight_on else flashlight_stow_duration
	flashlight_reveal = move_toward(flashlight_reveal, 1.0 if flashlight_on else 0.0, delta / maxf(flashlight_duration, 0.01))
	# The thumb clicks once the flashlight has reached the carrying position.
	if flashlight_on and not switch_engaged and flashlight_reveal >= 0.72:
		switch_engaged = true
		$FlashlightSwitch.stream = SWITCH_ON
		$FlashlightSwitch.play(SWITCH_ATTACK_TIME)
	var beam_target: float = 1.0 if flashlight_on and switch_engaged else 0.0
	update_flicker(delta)
	beam_target *= flicker_multiplier
	flashlight_strength = lerpf(flashlight_strength, beam_target, 1.0 - exp(-16.0 * delta))
	if Input.is_action_just_pressed("flashlight"):
		toggle_flashlight()
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var forward_amount: float = direction.dot(Vector2.from_angle(facing_angle))
	sprinting = not grabbed and Input.is_action_pressed("sprint") and not direction.is_zero_approx() and not exhausted and stamina > 0.0 and forward_amount > -0.2
	var previous_position: Vector2 = global_position
	velocity = direction * get_movement_speed(direction)
	move_and_slide()
	var travelled: float = global_position.distance_to(previous_position)
	glass_contact.update(self, previous_position, global_position, game, true, delta, 77.5 if sprinting else 72.0)
	if travelled < 0.05:
		sprinting = false
	update_resources(delta, sprinting)
	footsteps.set("running", sprinting)
	footsteps.call("add_travel", travelled)
	update_animation(delta)
	update_flashlight()
	grab_clock += delta
	$Camera.offset = Vector2(sin(grab_clock * 87.0), cos(grab_clock * 113.0)) * 11.0 if grabbed else Vector2.ZERO

func get_movement_speed(direction: Vector2) -> float:
	var base: float = speed * 0.3 if grabbed else (sprint_speed if sprinting else speed)
	if direction.is_zero_approx():
		return base
	var backward: float = maxf(0.0, -direction.normalized().dot(Vector2.from_angle(facing_angle)))
	return base * lerpf(1.0, backward_speed_multiplier, backward)

func drain_flashlight(amount: float) -> void:
	battery = maxf(0.0, battery - amount)
	if battery <= 0.0 and flashlight_on:
		toggle_flashlight()

func set_grabbed(value: bool) -> void:
	grabbed = value
	if value:
		sprinting = false
		grab_clock = 0.0
	else:
		$Camera.offset = Vector2.ZERO

func update_resources(delta: float, running: bool) -> void:
	if running:
		stamina = maxf(0.0, stamina - stamina_drain * delta)
		regen_delay = 1.0
		if stamina <= 0.0:
			if not exhausted and is_instance_valid(game):
				game.get_node("HUD").call("notify", "выдохся", 2.4)
			exhausted = true
			sprinting = false
	else:
		regen_delay = maxf(0.0, regen_delay - delta)
		if regen_delay <= 0.0:
			stamina = minf(stamina_max, stamina + stamina_regen * delta)
		if exhausted and stamina >= minf(28.0, stamina_max):
			exhausted = false
	if flashlight_on:
		battery = maxf(0.0, battery - battery_drain * delta)
		if battery <= 0.0:
			flashlight_on = false
			switch_engaged = false
			flashlight_strength = 0.0
			$FlashlightSwitch.stream = SWITCH_OFF
			$FlashlightSwitch.play(SWITCH_ATTACK_TIME)

func toggle_flashlight() -> void:
	var previous: bool = flashlight_on
	if flashlight_on:
		flashlight_on = false
	elif battery > 0.0:
		flashlight_on = true
	if previous != flashlight_on:
		switch_engaged = false
		if not flashlight_on:
			flashlight_strength = 0.0
			$FlashlightSwitch.stream = SWITCH_OFF
			$FlashlightSwitch.play(SWITCH_ATTACK_TIME)

func add_battery(amount: float = 20.0) -> void:
	battery = minf(battery_max, battery + amount)
	stamina_max += 10.0
	stamina = minf(stamina_max, stamina + 10.0)

func restore_stamina(fraction: float = 0.25) -> void:
	stamina = minf(stamina_max, stamina + stamina_max * fraction)
	if exhausted and stamina >= minf(28.0, stamina_max):
		exhausted = false

func update_mouse_aim(delta: float) -> void:
	var offset: Vector2 = get_global_mouse_position() - global_position
	if offset.length_squared() > 256.0:
		turn_towards(offset.angle(), delta)
	hero_sprite.rotation = facing_angle - PI * 0.5

func turn_towards(target_angle: float, delta: float) -> void:
	var energy: float = clampf(stamina / maxf(stamina_max, 0.001), 0.0, 1.0)
	var pace: float = lerpf(tired_turn_multiplier, 1.0, smoothstep(0.0, 1.0, energy))
	var next: float = lerp_angle(facing_angle, target_angle, 1.0 - exp(-turn_response * pace * delta))
	facing_angle = rotate_toward(facing_angle, next, deg_to_rad(turn_speed_degrees) * pace * delta)

func update_animation(delta: float) -> void:
	var moving: bool = velocity.length_squared() > 1.0
	var animation_name: String = "run" if sprinting else ("walk" if moving else "idle")
	# The saved 2D rig owns the continuous, blended overhead gait.
	hero_sprite.animation = animation_name
	hero_sprite.stop()
	stride_phase += delta * (16.0 if sprinting else 10.0)
	hero_sprite.scale = Vector2.ONE

func update_flashlight() -> void:
	torch.global_position = get_view_origin()
	var reveal: float = smoothstep(0.0, 1.0, flashlight_reveal)
	torch.rotation = facing_angle + float(hero_sprite.call("get_flashlight_angle"))
	torch.modulate.a = float(hero_sprite.call("get_flashlight_alpha"))
	torch.scale = Vector2.ONE * lerpf(0.75, 1.0, reveal)
	torch.set("lit", flashlight_on and flashlight_strength > 0.2)
	torch.queue_redraw()

func get_view_origin() -> Vector2:
	return get_view_origin_at(global_position)

func get_view_origin_at(observer: Vector2) -> Vector2:
	var grip: Vector2 = hero_sprite.call("get_flashlight_grip")
	var torch_angle: float = facing_angle + float(hero_sprite.call("get_flashlight_angle"))
	var desired: Vector2 = observer + grip.rotated(facing_angle - PI * 0.5) + Vector2.from_angle(torch_angle) * 15.0
	return resolve_view_origin(observer, desired)

func resolve_view_origin(observer: Vector2, desired: Vector2) -> Vector2:
	# Sweep a small lens volume: a ray can leave the lens inside the adjoining wall.
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = muzzle_shape
	query.transform = Transform2D(0.0, observer)
	query.motion = desired - observer
	query.collision_mask = 2
	query.margin = 0.5
	var fractions: PackedFloat32Array = get_world_2d().direct_space_state.cast_motion(query)
	return observer + query.motion * maxf(0.0, fractions[0] - 0.002)

func get_effective_fov() -> float:
	return field_of_view if flashlight_on else 360.0

func get_view_distance() -> float:
	if not flashlight_on:
		return ambient_view_distance
	return get_beam_distance()

func get_beam_distance() -> float:
	return view_distance

func get_mask_extent() -> float:
	var camera: Camera2D = get_viewport().get_camera_2d()
	var zoom: float = minf(camera.zoom.x, camera.zoom.y) if camera else 1.0
	return maxf(get_view_distance() * 2.0, get_viewport_rect().size.length() / maxf(zoom, 0.01) * 2.0 + 256.0)

func get_view_angle() -> float:
	return facing_angle + float(hero_sprite.call("get_flashlight_angle"))

func is_point_visible(point: Vector2) -> bool:
	if global_position.distance_to(point) <= ambient_view_distance:
		var ambient_query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, point, 2)
		return get_world_2d().direct_space_state.intersect_ray(ambient_query).is_empty()
	if not flashlight_on:
		return false
	var offset: Vector2 = point - get_view_origin()
	if offset.length() > get_view_distance():
		return false
	if absf(angle_difference(get_view_angle(), offset.angle())) > deg_to_rad(field_of_view) * 0.5:
		return false
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(get_view_origin(), point, 2)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _on_step() -> void:
	if is_instance_valid(game):
		game.call("emit_player_noise", global_position, 1050.0 if sprinting else 400.0)

func update_flicker(delta: float) -> void:
	var danger: bool = false
	if is_instance_valid(game):
		for hunter in game.get("monsters"):
			if hunter.get("active") and global_position.distance_squared_to(hunter.global_position) < 260.0 * 260.0:
				danger = true
	var weak: bool = battery <= battery_max * 0.25
	if not flashlight_on or not (weak or danger):
		flicker_clock = 0.0
		flicker_remaining = 0.0
		flicker_multiplier = 1.0
		return
	flicker_clock -= delta
	flicker_remaining = maxf(0.0, flicker_remaining - delta)
	if flicker_clock <= 0.0:
		flicker_remaining = randf_range(0.06, 0.18)
		flicker_clock = randf_range(0.22, 0.8) if danger else randf_range(0.6, 2.2)
	flicker_multiplier = 0.08 if flicker_remaining > 0.0 else 1.0
