@tool
extends Node2D

@export var light_radius: float = 245.0
@export var light_tint: Color = Color(1.0, 0.91, 0.66)
@export_enum("shade", "fluorescent", "bunker") var fixture_kind: String = "shade"
@export var mount_elevation: float = 0.035
var light_state: int = 0
var blink_timer: float = 1.0
var dark_remaining: float = 0.0
var light_power: float = 0.9
var danger: bool = false
var danger_probe: float = 0.0
var spark_cooldown: float = 0.0
var clock: float = 0.0

func _ready() -> void:
	set_process(not Engine.is_editor_hint())
	if not Engine.is_editor_hint():
		blink_timer = randf_range(0.7, 2.4)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	clock += delta
	danger_probe -= delta
	spark_cooldown = maxf(0.0, spark_cooldown - delta)
	if danger_probe <= 0.0:
		danger_probe = 0.12
		danger = false
		light_state = 0
		var game: Node = get_tree().current_scene
		var hunter: Node2D = game.get_node_or_null("Monster") if is_instance_valid(game) else null
		if is_instance_valid(hunter) and hunter.get("active"):
			var distance: float = global_position.distance_to(hunter.global_position)
			if distance < 430.0: light_state = 1
			if distance < 150.0: light_state = 2
		danger = light_state > 0
		if light_state < 2: $Housing/Sparks.emitting = false
	blink_timer -= delta
	dark_remaining = maxf(0.0, dark_remaining - delta)
	if blink_timer <= 0.0:
		dark_remaining = randf_range(0.035, 0.12) if danger else randf_range(0.07, 0.18)
		blink_timer = randf_range(0.13, 0.38) if danger else randf_range(1.8, 4.2)
		if light_state == 2 and spark_cooldown <= 0.0:
			$Housing/Sparks.restart()
			$Housing/Sparks.emitting = true
			spark_cooldown = randf_range(0.45, 0.95)
	var dim_power: float = 0.12 if danger else 0.76
	var target_power: float = dim_power if dark_remaining > 0.0 else 0.90 + sin(clock * (19.0 if danger else 1.7) + float(get_index())) * (0.09 if danger else 0.025)
	light_power = move_toward(light_power, target_power, delta * (16.0 if danger else 1.4))
	$Housing/Lens.modulate = light_tint * (0.35 + light_power * 0.65)
	$Housing/Glow.modulate.a = light_power * 0.65
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera:
		var offset: Vector2 = ((global_position - camera.get_screen_center_position()) * mount_elevation).clamp(Vector2(-20, -20), Vector2(20, 20))
		$Housing.position = global_transform.basis_xform_inv(offset) if fixture_kind != "bunker" else Vector2.ZERO
		$Housing.rotation = 0.0
		if fixture_kind == "shade":
			var swing: float = sin(clock * 1.65 + get_index() * 1.7)
			$Housing.rotation = swing * 0.14
			$Housing.position += Vector2(swing * 8.0, sin(clock * 3.3) * 2.0)

	# Observer fog and the shared fixture shadow map clip both body and halo.
