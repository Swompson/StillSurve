extends SceneTree

var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run_checks")

func draw_frame() -> void:
	for frame in range(4):
		await process_frame
		await physics_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw

func run_checks() -> void:
	change_scene_to_file("res://scenes/game.tscn")
	await draw_frame()
	var game: Node2D = current_scene
	var player: CharacterBody2D = game.get_node("Player")
	var visibility: Node2D = game.get_node("Visibility")
	player.set_physics_process(false)
	player.get_node("Sprite").set_process(false)
	game.get_node("Monster").set("active", false)
	game.get_node("Monster").global_position = Vector2(10000, 10000)
	visibility.set_process(false)
	visibility.set_physics_process(false)
	player.set("facing_angle", 0.0)
	player.call("turn_towards", PI * 0.5, 1.0 / 60.0)
	expect(is_equal_approx(float(player.get("facing_angle")), deg_to_rad(1080.0) / 60.0 * 0.81), "Fast turns must be ten percent slower")
	player.set("battery", 10.0)
	player.call("add_battery")
	expect(is_equal_approx(float(player.get("battery")), 30.0), "Default battery refill must be twenty percent")
	player.set("battery", 65.0)
	player.call("add_battery")
	expect(is_equal_approx(float(player.get("battery")), 70.0), "Battery refill must cap at full charge")
	var wall: Node2D
	for candidate in game.get_node("Maze/Walls").get_children():
		if not candidate.get("damaged") and candidate.get("wall_size").x > 200 and candidate.get("wall_size").x < 500:
			wall = candidate
			break
	player.global_position = wall.global_position - Vector2(0, 300)
	player.set("flashlight_on", true)
	player.set("flashlight_strength", 1.0)
	player.set("flashlight_reveal", 1.0)
	player.set("facing_angle", -PI * 0.5)
	player.get_node("Sprite").rotation = -PI
	player.call("update_flashlight")
	var fixed_origin: Vector2 = player.call("get_view_origin")
	visibility.set("pose_initialized", true)
	for key in ["previous_observer", "current_observer"]:
		visibility.set(key, player.global_position)
	for key in ["previous_muzzle", "current_muzzle"]:
		visibility.set(key, fixed_origin)
	var reference_vertices: PackedVector2Array
	var reference_colors: PackedColorArray
	for step in range(96):
		var angle: float = float(step) * TAU / 96.0
		visibility.set("previous_facing", angle)
		visibility.set("current_facing", angle)
		visibility.call("refresh_visibility", true)
		var contact_mesh: ArrayMesh = visibility.get("contact_mesh")
		expect(contact_mesh.get_surface_count() == 1, "Test must exercise actual wall-face geometry")
		var arrays: Array = contact_mesh.surface_get_arrays(0)
		if step == 0:
			reference_vertices = arrays[Mesh.ARRAY_VERTEX]
			reference_colors = arrays[Mesh.ARRAY_COLOR]
		else:
			expect(reference_vertices == arrays[Mesh.ARRAY_VERTEX] and reference_colors == arrays[Mesh.ARRAY_COLOR], "Turning at a fixed muzzle must not rebuild or flicker wall strips")
	expect(wall.z_index < visibility.z_index, "Unseen walls must render under the darkness mask")
	if DisplayServer.get_name() != "headless":
		game.get_node("HUD").hide()
		game.get_node("Haze").hide()
		var camera: Camera2D = player.get_node("Camera")
		camera.position_smoothing_enabled = false
		camera.position = Vector2.ZERO
		camera.force_update_scroll()
		player.reset_physics_interpolation()
		visibility.call("refresh_visibility", false)
		await draw_frame()
		var with_wall: Image = root.get_texture().get_image()
		var screen: Vector2i = Vector2i(root.get_canvas_transform() * wall.global_position)
		wall.hide()
		await draw_frame()
		var without_wall: Image = root.get_texture().get_image()
		var maximum_difference: float = 0.0
		for y in range(screen.y - 3, screen.y + 4):
			for x in range(screen.x - 25, screen.x + 26):
				if x >= 0 and x < with_wall.get_width() and y >= 0 and y < with_wall.get_height():
					maximum_difference = maxf(maximum_difference, absf(with_wall.get_pixel(x, y).get_luminance() - without_wall.get_pixel(x, y).get_luminance()))
		expect(maximum_difference < 0.0001, "A wall outside vision must make no visible contribution to the rendered image")
		print("HIDDEN WALL maximum pixel difference %.6f" % maximum_difference)
		wall.show()
		with_wall.save_png("res://.godot/hidden_wall_check.png")
	print("RESULT slower turns, stable wall faces, hidden walls and 20 percent batteries: %d failure(s)" % failures.size())
	quit(0 if failures.is_empty() else 1)
