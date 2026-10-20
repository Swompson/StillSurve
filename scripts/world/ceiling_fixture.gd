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
var flicker_cooldown: float = 0.0
var clock: float = 0.0
var hunters: Array[Node2D] = []

@onready var housing: Node2D = $Housing
@onready var lens: Sprite2D = $Housing/Lens
@onready var glow: Sprite2D = $Housing/Glow
@onready var sparks: CPUParticles2D = $Housing/Sparks
@onready var hum: AudioStreamPlayer2D = $Hum
@onready var flicker_sound: AudioStreamPlayer2D = $Flicker
@onready var spark_sound: AudioStreamPlayer2D = $Arc


func _ready() -> void:
	set_process(not Engine.is_editor_hint())
	if Engine.is_editor_hint():
		return
	blink_timer = randf_range(0.7, 2.4)
	# Stagger distance probes and loop phases instead of starting all ballasts together.
	danger_probe = float(get_index()) * 0.025
	cache_hunters()
	var loop: AudioStreamWAV = hum.stream as AudioStreamWAV
	if loop:
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_end = int(loop.get_length() * loop.mix_rate)
	hum.play(fmod(float(get_index()) * 0.37, hum.stream.get_length()))


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	clock += delta
	danger_probe -= delta
	spark_cooldown = maxf(0.0, spark_cooldown - delta)
	flicker_cooldown = maxf(0.0, flicker_cooldown - delta)
	if danger_probe <= 0.0:
		danger_probe = 0.16
		update_danger()
	blink_timer -= delta
	dark_remaining = maxf(0.0, dark_remaining - delta)
	if blink_timer <= 0.0:
		begin_blink()
	var dim_power: float = 0.18 if danger else 0.76
	var shimmer: float = sin(clock * (13.0 if danger else 1.7) + float(get_index()))
	var target_power: float = dim_power if dark_remaining > 0.0 else 0.90 + shimmer * (0.045 if danger else 0.018)
	light_power = move_toward(light_power, target_power, delta * (10.0 if danger else 1.4))
	# The opaque upper casing stays readable; the halo carries the electrical flicker.
	lens.modulate = Color.WHITE * (0.72 + light_power * 0.28)
	glow.modulate = Color(light_tint, light_power * 0.60)
	hum.volume_db = move_toward(hum.volume_db, -25.0 + (light_power - 0.9) * 8.0 + (2.0 if danger else 0.0), delta * 24.0)
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera:
		var offset: Vector2 = ((global_position - camera.get_screen_center_position()) * mount_elevation).clamp(Vector2(-20, -20), Vector2(20, 20))
		housing.position = global_transform.basis_xform_inv(offset) if fixture_kind != "bunker" else Vector2.ZERO
		housing.rotation = 0.0
		if fixture_kind == "shade":
			var swing: float = sin(clock * 1.25 + get_index() * 1.7)
			housing.rotation = swing * 0.035
			housing.position += Vector2(swing * 2.8, sin(clock * 2.5) * 0.7)


func update_danger() -> void:
	if hunters.is_empty():
		cache_hunters()
	light_state = 0
	for hunter in hunters:
		if not is_instance_valid(hunter) or not hunter.get("active"):
			continue
		var distance_squared: float = global_position.distance_squared_to(hunter.global_position)
		if distance_squared < 150.0 * 150.0:
			light_state = 2
			break
		if distance_squared < 430.0 * 430.0:
			light_state = 1
	danger = light_state > 0
	if light_state < 2:
		sparks.emitting = false


func cache_hunters() -> void:
	var game: Node = get_tree().current_scene
	if not is_instance_valid(game):
		return
	for hunter_name in ["Monster", "SecondMonster", "Stalker"]:
		var hunter: Node2D = game.get_node_or_null(hunter_name) as Node2D
		if is_instance_valid(hunter):
			hunters.append(hunter)


func begin_blink() -> void:
	dark_remaining = randf_range(0.045, 0.11) if danger else randf_range(0.07, 0.15)
	blink_timer = randf_range(0.20, 0.38) if light_state == 2 else (randf_range(0.28, 0.65) if danger else randf_range(1.8, 4.2))
	# One voice per event prevents crackle queues when several enemies share a lamp.
	if flicker_cooldown <= 0.0 and not flicker_sound.playing:
		flicker_sound.play()
		flicker_cooldown = 0.28
	if light_state == 2 and spark_cooldown <= 0.0 and not spark_sound.playing:
		sparks.restart()
		sparks.emitting = true
		spark_sound.play()
		spark_cooldown = randf_range(0.72, 1.12)
