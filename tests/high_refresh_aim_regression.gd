extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(4): await process_frame
	var player: CharacterBody2D = current_scene.get_node("Player")
	player.set_process(false)
	var target: float = (player.get_global_mouse_position() - player.global_position).angle()
	player.facing_angle = target - 1.0
	var changes: int = 0
	var previous: float = player.get_node("Sprite").rotation
	var physics_before: int = Engine.get_physics_frames()
	for frame in range(48):
		player._process(1.0 / 144.0)
		var angle: float = player.get_node("Sprite").rotation
		if absf(angle_difference(previous, angle)) > 0.0001: changes += 1
		previous = angle
	var visibility: Node = current_scene.get_node("Visibility")
	visibility.capture_pose()
	player.facing_angle += 0.3
	visibility.refresh_visibility(true)
	var shader_angle: float = visibility.fog_material.get_shader_parameter("facing_angle")
	var success: bool = changes == 48 and physics_before == Engine.get_physics_frames() and is_equal_approx(shader_angle, player.facing_angle)
	print("RENDER AIM: %d distinct poses in 48 render frames, zero physics ticks; flashlight follows current aim=%s" % [changes, is_equal_approx(shader_angle, player.facing_angle)])
	print("RESULT high refresh player and flashlight aim: ", "PASS" if success else "FAIL")
	quit(0 if success else 1)
