extends SceneTree
func _initialize() -> void: call_deferred("benchmark")
func benchmark() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(8): await process_frame
	var game: Node = current_scene
	game.set("immortal", true)
	var player: Node2D = game.get_node("Player")
	player.set_physics_process(false)
	player.global_position = game.get_node("Maze").cell_position(48)
	player.reset_physics_interpolation()
	player.get_node("Camera").position_smoothing_enabled = false
	player.get_node("Camera").force_update_scroll()
	for hunter in game.get("monsters"):
		hunter.set_physics_process(false)
		hunter.set("active", false)
	var budget: Node = root.get_node("RuntimeBudget")
	for phase in ["unlimited", "active", "paused", "background"]:
		paused = false
		budget.set("focused", true)
		budget.call("set_paused", false)
		if phase == "unlimited":
			Engine.max_fps = 0
		elif phase == "paused":
			game.get_node("HUD").set_paused(true)
		elif phase == "background":
			budget.set("focused", false)
			budget.call("apply_budget")
		var file: FileAccess = FileAccess.open("res://.godot/cpu_benchmark_phase.txt", FileAccess.WRITE)
		file.store_string(phase)
		file.close()
		var start: int = Time.get_ticks_usec()
		var frames: int = 0
		while Time.get_ticks_usec() - start < 3000000:
			await process_frame
			frames += 1
		print("BUDGET %s rendered %.1f frames/s" % [phase, float(frames) * 1000000.0 / (Time.get_ticks_usec() - start)])
	paused = false
	quit()

