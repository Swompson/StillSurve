extends SceneTree
func _initialize() -> void:
	call_deferred("benchmark")
func benchmark() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	set_meta("hard_mode", false)
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(6): await process_frame
	Engine.max_fps = 0
	var game: Node = current_scene
	var player: Node2D = game.get_node("Player")
	player.set_physics_process(false)
	player.global_position = game.get_node("Maze").cell_position(48)
	player.reset_physics_interpolation()
	player.set("flashlight_reveal", 1.0)
	player.set("flashlight_strength", 1.0)
	var camera: Camera2D = player.get_node("Camera")
	camera.position_smoothing_enabled = false
	camera.force_update_scroll()
	for hunter in game.get("monsters"):
		hunter.set_physics_process(false)
		hunter.set("active", false)
	var overhead: Node = game.get_node("Maze/Overhead")
	for enabled in [false, true, true, false]:
		overhead.visible = enabled
		for frame in range(30):
			await process_frame
			await RenderingServer.frame_post_draw
		var times: Array[float] = []
		var draws: float = 0.0
		for frame in range(150):
			var start: int = Time.get_ticks_usec()
			await process_frame
			await RenderingServer.frame_post_draw
			times.append(float(Time.get_ticks_usec() - start) / 1000.0)
			draws += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		times.sort()
		print("OVERHEAD enabled=%s frame median=%.3f ms p95=%.3f ms draws=%.1f" % [enabled, times[75], times[142], draws / 150.0])
	quit()
