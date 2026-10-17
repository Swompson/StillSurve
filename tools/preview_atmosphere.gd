extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(8): await process_frame
	var game: Node = current_scene
	var player: Node2D = game.get_node("Player")
	player.set_physics_process(false)
	for hunter in game.get("monsters"):
		hunter.set_physics_process(false)
		hunter.global_position = Vector2(1500, 1500)
	var camera: Camera2D = player.get_node("Camera")
	camera.position_smoothing_enabled = false
	camera.zoom = Vector2(2, 2)
	game.get_node("HUD").hide()
	game.get_node("Haze").hide()
	player.set("flashlight_on", false)
	player.set("flashlight_strength", 0.0)
	for pickup in game.get_node("Maze/Pickups").get_children():
		pickup.set_physics_process(false)
	var clearance: CircleShape2D = CircleShape2D.new()
	clearance.radius = 24.0
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = clearance
	query.collision_mask = 2
	for fixture in game.get_node("Maze/Overhead/Fixtures").get_children():
		for offset in [Vector2(0,100), Vector2(0,-100), Vector2(100,0), Vector2(-100,0)]:
			var candidate: Vector2 = fixture.global_position + offset
			query.transform = Transform2D(0, candidate)
			if player.get_world_2d().direct_space_state.intersect_shape(query).is_empty() and game.get_node("Maze").call("clear_line", candidate, fixture.global_position):
				player.global_position = candidate
				break
		player.reset_physics_interpolation()
		camera.position = (fixture.global_position - player.global_position) * 0.7
		camera.force_update_scroll()
		fixture.set("blink_timer", 100.0)
		fixture.set("dark_remaining", 0.0)
		for frame in range(8):
			await process_frame
			await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/visuals/atmosphere_%s.png" % fixture.name)
	quit()
