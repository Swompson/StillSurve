extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(8): await process_frame
	var game: Node = current_scene
	var player: Node2D = game.get_node("Player")
	player.set_physics_process(false)
	for hunter in game.get("monsters"):
		hunter.set("active", false)
		hunter.set_physics_process(false)
		hunter.hide()
	for pickup in game.get_node("Maze/Pickups").get_children(): pickup.set_physics_process(false)
	var battery: Node2D = game.get_node("Maze/Pickups/Battery05")
	player.global_position = battery.global_position + Vector2(0, 130)
	player.set("facing_angle", -PI * 0.5)
	player.set("flashlight_on", true)
	player.set("flashlight_strength", 1.0)
	player.set("flashlight_reveal", 1.0)
	player.call("update_flashlight")
	player.reset_physics_interpolation()
	var camera: Camera2D = player.get_node("Camera")
	camera.position_smoothing_enabled = false
	camera.zoom = Vector2(3, 3)
	camera.position = Vector2(0, -80)
	camera.force_update_scroll()
	game.get_node("HUD").hide()
	game.get_node("Haze").hide()
	player.hide()
	for frame in range(8):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/visuals/battery_pickup.png")
	quit()
