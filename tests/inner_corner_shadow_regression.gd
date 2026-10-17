extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(4): await process_frame
	var game: Node2D = current_scene
	var player: Node2D = game.get_node("Player")
	var visibility: Node2D = game.get_node("Visibility")
	player.set_physics_process(false)
	player.get_node("Sprite").set_process(false)
	game.get_node("Monster").set("active", false)
	for path in ["HUD", "Haze", "Monster"]: game.get_node(path).hide()
	visibility.set_process(false)
	visibility.set_physics_process(false)
	var corner: Vector2 = Vector2(12000, 12000)
	var floor_patch: Polygon2D = Polygon2D.new()
	floor_patch.polygon = PackedVector2Array([Vector2(-600, -600), Vector2(600, -600), Vector2(600, 600), Vector2(-600, 600)])
	floor_patch.position = corner
	floor_patch.z_index = -30
	game.add_child(floor_patch)
	for horizontal in [true, false]:
		var wall: Node2D = load("res://scenes/world/wall.tscn").instantiate()
		wall.set("wall_size", Vector2(320, 24) if horizontal else Vector2(24, 320))
		wall.position = corner + (Vector2(148, 0) if horizontal else Vector2(0, 148))
		game.add_child(wall)
	player.global_position = corner + Vector2(36, 36)
	player.reset_physics_interpolation()
	player.set("flashlight_strength", 1.0)
	player.set("flashlight_reveal", 1.0)
	player.hide()
	var camera: Camera2D = player.get_node("Camera")
	camera.position_smoothing_enabled = false
	camera.zoom = Vector2.ONE
	camera.force_update_scroll()
	for frame in range(4):
		await physics_frame
		await process_frame
	var blocked_samples: int = 0
	var lit_samples: int = 0
	var leaks: int = 0
	var false_shadows: int = 0
	for step in range(48):
		var angle: float = float(step) * TAU / 48.0
		player.set("facing_angle", angle)
		player.get_node("Sprite").rotation = angle - PI * 0.5
		visibility.refresh_visibility(false)
		for frame in range(2):
			await process_frame
			await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		var source: Vector2 = player.call("get_view_origin")
		for y in range(-240, 301, 30):
			for x in range(-240, 301, 30):
				if abs(x) < 30 or abs(y) < 30: continue
				var point: Vector2 = corner + Vector2(x, y)
				var ray: Vector2 = point - source
				if absf(angle_difference(angle, ray.angle())) > deg_to_rad(float(player.get("field_of_view"))) * 0.5 - 0.24: continue
				if ray.length() > 400.0 or ray.length() < 60.0: continue
				var screen: Vector2i = Vector2i(root.get_canvas_transform() * point)
				if screen.x < 1 or screen.y < 1 or screen.x >= image.get_width() - 1 or screen.y >= image.get_height() - 1: continue
				var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(source, point, 2)
				var blocked: bool = not player.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
				var luminance: float = image.get_pixelv(screen).get_luminance()
				if blocked:
					blocked_samples += 1
					if luminance > 0.005: leaks += 1
				else:
					lit_samples += 1
					if luminance < 0.05: false_shadows += 1
		if step == 30: image.save_png("res://.godot/inner_corner_shadow.png")
	print("CORNER GPU blocked=%d clear=%d light leaks=%d false shadows=%d" % [blocked_samples, lit_samples, leaks, false_shadows])
	var passed: bool = blocked_samples > 100 and lit_samples > 100 and leaks == 0 and false_shadows == 0
	print("RESULT moving flashlight at overlapping inner corner: %s" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
