extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func sample(label: String) -> void:
	for frame in range(35):
		await process_frame
		await RenderingServer.frame_post_draw
	var durations: Array[float] = []
	for frame in range(180):
		var started: int = Time.get_ticks_usec()
		await process_frame
		await RenderingServer.frame_post_draw
		durations.append(float(Time.get_ticks_usec() - started) / 1000.0)
	durations.sort()
	print("ENCOUNTER RENDER %s median=%.3f ms p95=%.3f ms max=%.3f ms" % [label, durations[90], durations[171], durations[-1]])

func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.get_node("RuntimeBudget").set_process(false)
	root.get_node("RuntimeBudget").set_process_input(false)
	root.focus_entered.disconnect(root.get_node("RuntimeBudget").mark_focused)
	root.focus_exited.disconnect(root.get_node("RuntimeBudget").request_background)
	root.get_node("RuntimeBudget").mark_focused()
	root.get_node("RuntimeBudget").set_fps(0, false)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	set_meta("hard_mode", true)
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(8): await physics_frame
	var game: Node = current_scene
	game.immortal = true
	var player: CharacterBody2D = game.player
	player.set_physics_process(false)
	player.flashlight_reveal = 1.0
	player.flashlight_strength = 1.0
	var fixture: Node2D = get_nodes_in_group("ceiling_fixtures")[0]
	var offsets: Array[Vector2] = [Vector2(80, -50), Vector2(-80, -50), Vector2(0, 95)]
	for scenario in ["distant", "near_lamps", "near_warehouse"]:
		player.global_position = game.maze.cell_position(71 if scenario == "near_warehouse" else game.maze.cell_at(fixture.global_position))
		player.reset_physics_interpolation()
		player.get_node("Camera").reset_smoothing()
		for index in range(game.monsters.size()):
			var hunter: CharacterBody2D = game.monsters[index]
			hunter.global_position = player.global_position + offsets[index] * (12.0 if scenario == "distant" else 1.0)
			hunter.reset_physics_interpolation()
			hunter.active = true
		await sample(scenario)
	print("RESULT native encounter rendering benchmark complete")
	quit()
