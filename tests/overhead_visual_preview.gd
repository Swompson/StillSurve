extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	set_meta("hard_mode", false)
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(6): await process_frame
	Engine.max_fps = 0
	var game: Node2D = current_scene
	var player: Node2D = game.get_node("Player")
	var fixture: Node2D = get_nodes_in_group("ceiling_fixtures")[0]
	player.set_physics_process(false)
	for hunter in game.get("monsters"):
		hunter.set_physics_process(false)
		hunter.global_position = fixture.global_position + Vector2(95, 15)
		hunter.get_node("Visual").rotation = PI * 0.5
	game.get("monsters")[1].global_position = fixture.global_position + Vector2(1000, 0)
	player.global_position = fixture.global_position + Vector2(-25, 95)
	player.set("facing_angle", -PI * 0.5)
	player.set("flashlight_on", false)
	player.set("flashlight_strength", 0.0)
	player.set("flashlight_reveal", 0.0)
	player.reset_physics_interpolation()
	var camera: Camera2D = player.get_node("Camera")
	camera.position_smoothing_enabled = false
	camera.zoom = Vector2(2.4, 2.4)
	camera.position = Vector2(25, -65)
	camera.force_update_scroll()
	game.get_node("HUD").hide()
	game.get_node("Haze").hide()
	fixture.set("blink_timer", 0.0)
	fixture.call("_process", 0.01)
	fixture.set_process(false)
	fixture.set("light_power", 0.95)
	fixture.get_node("Housing/Glow").modulate.a = 0.6
	var sparks: CPUParticles2D = fixture.get_node("Housing/Sparks")
	sparks.preprocess = 0.15
	sparks.speed_scale = 0.12
	sparks.restart()
	sparks.emitting = true
	for frame in range(6):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/visuals/ceiling_sparks.png")
	game.get_node("Visibility").hide()
	player.hide()
	for hunter in game.get("monsters"): hunter.hide()
	camera.position = -player.position + Vector2(14,46)
	camera.zoom = Vector2(0.19, 0.19)
	camera.force_update_scroll()
	for frame in range(5):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/visuals/overhead_map.png")
	print("Saved fixture sparks and full-map overhead previews")
	quit()
