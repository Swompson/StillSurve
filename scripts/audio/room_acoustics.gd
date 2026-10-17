extends Node

@export var wall_probe_distance: float = 1000.0
@export_range(0.0, 0.5) var reverb_wet: float = 0.18
var probe_timer: float = 0.0
var reflection_delay: float = 72.0
var desired_delay: float = 72.0
var target_room: float = 0.90

func _physics_process(delta: float) -> void:
	var player: Node2D = get_parent().get_node("Player")
	probe_timer -= delta
	if probe_timer <= 0.0:
		probe_timer = 0.35
		var total: float = 0.0
		var space: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
		for index in range(8):
			var direction: Vector2 = Vector2.from_angle(float(index) * TAU / 8.0)
			var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(player.global_position, player.global_position + direction * wall_probe_distance, 2)
			var hit: Dictionary = space.intersect_ray(query)
			total += wall_probe_distance if hit.is_empty() else player.global_position.distance_to(hit.position)
		var average: float = total / 8.0
		desired_delay = clampf(average * 0.25, 32.0, 130.0)
		target_room = clampf(0.78 + average / wall_probe_distance * 0.18, 0.78, 0.96)
	reflection_delay = lerpf(reflection_delay, desired_delay, 1.0 - exp(-delta * 2.0))
	if AudioServer.get_bus_effect_count(0) < 2:
		return
	var reflections: AudioEffectDelay = AudioServer.get_bus_effect(0, 0) as AudioEffectDelay
	var hall: AudioEffectReverb = AudioServer.get_bus_effect(0, 1) as AudioEffectReverb
	if reflections:
		reflections.tap1_delay_ms = reflection_delay
		reflections.tap2_delay_ms = reflection_delay * 1.65
	if hall:
		hall.room_size = lerpf(hall.room_size, target_room, 1.0 - exp(-delta * 2.0))
		hall.wet = reverb_wet
