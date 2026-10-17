extends SceneTree

func _initialize() -> void:
	call_deferred("compare_floor")

func frame_image() -> Image:
	for frame in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func compare_floor() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(5): await process_frame
	var game: Node = current_scene
	var player: Node2D = game.get_node("Player")
	var visibility: Node2D = game.get_node("Visibility")
	player.set_physics_process(false)
	player.get_node("Sprite").set_process(false)
	game.get_node("Monster").set("active", false)
	for path in ["HUD", "Haze", "Monster", "Maze/Pickups"]: game.get_node(path).hide()
	player.global_position = game.get_node("Maze").cell_position(60)
	player.reset_physics_interpolation()
	player.set("facing_angle", PI * 0.5)
	player.set("flashlight_reveal", 1.0)
	player.set("flashlight_strength", 1.0)
	player.hide()
	var camera: Camera2D = player.get_node("Camera")
	camera.position_smoothing_enabled = false
	camera.zoom = Vector2(0.48, 0.48)
	camera.force_update_scroll()
	visibility.set_process(false)
	visibility.set_physics_process(false)
	visibility.refresh_visibility(false)
	for frame in range(5):
		await physics_frame
		await process_frame
	camera.force_update_scroll()
	paused = true
	# Let render interpolation settle before the three otherwise identical frames.
	await frame_image()
	var surface: ShaderMaterial = game.get_node("Maze/Floor").material
	var original_strength: Variant = surface.get_shader_parameter("normal_strength")
	surface.set_shader_parameter("normal_strength", 0.0)
	var flat: Image = await frame_image()
	surface.set_shader_parameter("normal_strength", 0.6)
	var normal: Image = await frame_image()
	surface.set_shader_parameter("normal_strength", 0.0)
	var repeat: Image = await frame_image()
	surface.set_shader_parameter("normal_strength", original_strength)
	var timings: Array[float] = []
	for strength in [0.0, 0.6, 0.6, 0.0]:
		surface.set_shader_parameter("normal_strength", strength)
		await frame_image()
		var start: int = Time.get_ticks_usec()
		for frame in range(90):
			await process_frame
			await RenderingServer.frame_post_draw
		timings.append(float(Time.get_ticks_usec() - start) / 90000.0)
	print("RENDER frame wall time ms OFF/ON/ON/OFF: ", timings)
	surface.set_shader_parameter("normal_strength", original_strength)
	flat.save_png("res://.godot/floor_normal_off.png")
	normal.save_png("res://.godot/floor_normal_on.png")
	var difference: Image = Image.create(flat.get_width(), flat.get_height(), false, Image.FORMAT_RGB8)
	var maximum: float = 0.0
	var total: float = 0.0
	var affected: int = 0
	var repeat_error: float = 0.0
	for y in range(flat.get_height()):
		for x in range(flat.get_width()):
			var a: Color = flat.get_pixel(x, y)
			var b: Color = normal.get_pixel(x, y)
			var c: Color = repeat.get_pixel(x, y)
			var delta: Vector3 = Vector3(absf(a.r - b.r), absf(a.g - b.g), absf(a.b - b.b))
			var peak: float = maxf(delta.x, maxf(delta.y, delta.z))
			maximum = maxf(maximum, peak)
			repeat_error = maxf(repeat_error, maxf(absf(a.r - c.r), maxf(absf(a.g - c.g), absf(a.b - c.b))))
			if peak > 0.001:
				affected += 1
				total += (delta.x + delta.y + delta.z) / 3.0
			difference.set_pixel(x, y, Color(delta.x * 20.0, delta.y * 20.0, delta.z * 20.0))
	difference.save_png("res://.godot/floor_normal_difference_x20.png")
	print("NORMAL MAP affected pixels=%d, max RGB delta=%.5f, mean affected delta=%.5f, off-repeat error=%.6f" % [affected, maximum, total / maxf(affected, 1), repeat_error])
	var passed: bool = affected > 1000 and maximum > 0.005 and repeat_error < 0.0001
	print("RESULT floor normal comparison: %s" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
