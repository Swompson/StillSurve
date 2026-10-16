extends CharacterBody2D

@export var speed: float = 180.0
@export var sprint_speed: float = 310.0
@export var backward_speed_multiplier: float = 0.6
@export var turn_response: float = 18.0
@export var turn_speed_degrees: float = 1080.0
@export var field_of_view: float = 92.4
@export var ambient_view_distance: float = 108.0
@export var view_distance: float = 2400.0
@export var stamina_max: float = 100.0
@export var stamina_drain: float = 25.0
@export var stamina_regen: float = 18.0
@export var battery_drain: float = 0.5

@onready var hero_sprite: AnimatedSprite2D = $Sprite
@onready var footsteps: AudioStreamPlayer2D = $Footsteps
@onready var torch: Node2D = $Flashlight

var game: Node
var alive: bool = true
var facing_angle: float = PI * 0.5
var stamina: float = 100.0
var battery: float = 100.0
var flashlight_on: bool = true
var sprinting: bool = false
var exhausted: bool = false
var regen_delay: float = 0.0
var stride_phase: float = 0.0

func _ready() -> void:
	stamina = stamina_max
	footsteps.stepped.connect(_on_step)

func _physics_process(delta: float) -> void:
	if not alive:
		velocity = Vector2.ZERO
		sprinting = false
		return
	if Input.is_action_just_pressed("flashlight"):
		toggle_flashlight()
	update_mouse_aim(delta)
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var forward_amount: float = direction.dot(Vector2.from_angle(facing_angle))
	sprinting = Input.is_action_pressed("sprint") and not direction.is_zero_approx() and not exhausted and stamina > 0.0 and forward_amount > -0.2
	var previous_position: Vector2 = global_position
	velocity = direction * get_movement_speed(direction)
	move_and_slide()
	var travelled: float = global_position.distance_to(previous_position)
	if travelled < 0.05:
		sprinting = false
	update_resources(delta, sprinting)
	footsteps.set("running", sprinting)
	footsteps.call("add_travel", travelled)
	update_animation(delta)
	update_flashlight()

func get_movement_speed(direction: Vector2) -> float:
	var base: float = sprint_speed if sprinting else speed
	if direction.is_zero_approx():
		return base
	var backward: float = maxf(0.0, -direction.normalized().dot(Vector2.from_angle(facing_angle)))
	return base * lerpf(1.0, backward_speed_multiplier, backward)

func update_resources(delta: float, running: bool) -> void:
	if running:
		stamina = maxf(0.0, stamina - stamina_drain * delta)
		regen_delay = 1.0
		if stamina <= 0.0:
			exhausted = true
			sprinting = false
	else:
		regen_delay = maxf(0.0, regen_delay - delta)
		if regen_delay <= 0.0:
			stamina = minf(stamina_max, stamina + stamina_regen * delta)
		if exhausted and stamina >= 28.0:
			exhausted = false
	if flashlight_on:
		battery = maxf(0.0, battery - battery_drain * delta)
		if battery <= 0.0:
			flashlight_on = false

func toggle_flashlight() -> void:
	if flashlight_on:
		flashlight_on = false
	elif battery > 0.0:
		flashlight_on = true

func add_battery(amount: float = 50.0) -> void:
	battery = minf(100.0, battery + amount)
	stamina_max += 10.0
	stamina = minf(stamina_max, stamina + 10.0)

func restore_stamina(fraction: float = 0.25) -> void:
	stamina = minf(stamina_max, stamina + stamina_max * fraction)
	if exhausted and stamina >= 28.0:
		exhausted = false

func update_mouse_aim(delta: float) -> void:
	var offset: Vector2 = get_global_mouse_position() - global_position
	if offset.length_squared() > 256.0:
		turn_towards(offset.angle(), delta)
	hero_sprite.rotation = facing_angle - PI * 0.5

func turn_towards(target_angle: float, delta: float) -> void:
	var next: float = lerp_angle(facing_angle, target_angle, 1.0 - exp(-turn_response * delta))
	facing_angle = rotate_toward(facing_angle, next, deg_to_rad(turn_speed_degrees) * delta)

func update_animation(delta: float) -> void:
	var moving: bool = velocity.length_squared() > 1.0
	var animation_name: String = "run" if sprinting else ("walk" if moving else "idle")
	var backwards: bool = moving and velocity.normalized().dot(Vector2.from_angle(facing_angle)) < -0.3
	hero_sprite.speed_scale = (-1.0 if backwards else 1.0) * (velocity.length() / (sprint_speed if sprinting else speed) if moving else 1.0)
	hero_sprite.play(animation_name)
	stride_phase += delta * (16.0 if sprinting else 10.0)
	hero_sprite.scale = Vector2.ONE * (128.0 / 444.0) * (1.0 + sin(stride_phase) * 0.018 if sprinting else 1.0)

func update_flashlight() -> void:
	torch.global_position = get_view_origin()
	torch.rotation = facing_angle
	torch.set("lit", flashlight_on)
	torch.queue_redraw()

func get_view_origin() -> Vector2:
	var desired: Vector2 = global_position + Vector2.from_angle(facing_angle) * 22.0 + Vector2.from_angle(facing_angle + PI * 0.5) * 17.0
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, desired, 2)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return (hit["position"] as Vector2) - global_position.direction_to(desired) * 3.0
	return desired

func get_effective_fov() -> float:
	return field_of_view if flashlight_on else 360.0

func get_view_distance() -> float:
	if not flashlight_on:
		return ambient_view_distance
	var camera: Camera2D = get_viewport().get_camera_2d()
	var zoom: float = minf(camera.zoom.x, camera.zoom.y) if camera else 1.0
	return maxf(view_distance, get_viewport_rect().size.length() / maxf(zoom, 0.01) + 128.0)

func get_mask_extent() -> float:
	var camera: Camera2D = get_viewport().get_camera_2d()
	var zoom: float = minf(camera.zoom.x, camera.zoom.y) if camera else 1.0
	return maxf(get_view_distance() * 2.0, get_viewport_rect().size.length() / maxf(zoom, 0.01) * 2.0 + 256.0)

func get_view_angle() -> float:
	return facing_angle

func is_point_visible(point: Vector2) -> bool:
	if global_position.distance_to(point) <= ambient_view_distance:
		var ambient_query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, point, 2)
		return get_world_2d().direct_space_state.intersect_ray(ambient_query).is_empty()
	if not flashlight_on:
		return false
	var offset: Vector2 = point - get_view_origin()
	if offset.length() > get_view_distance():
		return false
	if absf(angle_difference(facing_angle, offset.angle())) > deg_to_rad(field_of_view) * 0.5:
		return false
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(get_view_origin(), point, 2)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _on_step() -> void:
	if is_instance_valid(game):
		game.call("emit_player_noise", global_position, 1050.0 if sprinting else 400.0)
