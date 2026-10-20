extends SceneTree

var label: String = "sample"

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--label="): label = argument.trim_prefix("--label=")
	call_deferred("run")

func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.position = Vector2i(-1400, -1000)
	var budget: Node = root.get_node("RuntimeBudget")
	budget.set_process(false)
	root.focus_entered.disconnect(budget.mark_focused)
	root.focus_exited.disconnect(budget.request_background)
	budget.mark_focused()
	budget.set_fps(0, false)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	set_meta("hard_mode", false)
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(8):
		await process_frame
		await physics_frame
	var game: Node = current_scene
	game.finished = true
	game.set_process(false)
	var player: CharacterBody2D = game.player
	player.set_physics_process(false)
	player.set_process(false)
	player.get_node("Sprite").set_process(false)
	player.flashlight_on = true
	player.flashlight_reveal = 1.0
	player.flashlight_strength = 1.0
	for hunter in game.monsters:
		hunter.set_physics_process(false)
		hunter.hide()
	for fixture in get_nodes_in_group("ceiling_fixtures"):
		fixture.set_process(false)
		fixture.light_power = 0.9
		fixture.get_node("Housing/Sparks").emitting = false
	var visibility: Node2D = game.get_node("Visibility")
	visibility.set_process(false)
	visibility.set_physics_process(false)
	var overhead: Node = game.get_node("Maze/Overhead")
	overhead.set_process(false)
	var haze: CanvasLayer = game.get_node("Haze")
	haze.set_process(false)
	game.get_node("HUD").hide()
	var camera: Camera2D = player.get_node("Camera")
	camera.position_smoothing_enabled = false
	var report: Dictionary = {"label": label, "resolution": "1280x720", "scenarios": {}}
	for scenario in ["corridor", "warehouse", "glass"]:
		var center: Vector2 = game.maze.cell_position(71 if scenario == "warehouse" else 60)
		if scenario == "glass": center = game.maze.get_node("FloorGlass/Patch08").global_position + Vector2(0, 120)
		player.global_position = center
		player.reset_physics_interpolation()
		camera.reset_smoothing()
		camera.force_update_scroll()
		for frame in range(20):
			player.facing_angle = float(frame) * 0.03
			visibility.refresh_visibility(false)
			overhead._process(0.0)
			haze._process(1.0 / 60.0)
			await process_frame
			await RenderingServer.frame_post_draw
		var timings: Array[float] = []
		for frame in range(90):
			var started: int = Time.get_ticks_usec()
			player.facing_angle = float(frame) * 0.035
			visibility.refresh_visibility(false)
			overhead._process(0.0)
			haze._process(1.0 / 60.0)
			await process_frame
			await RenderingServer.frame_post_draw
			timings.append(float(Time.get_ticks_usec() - started) / 1000.0)
		timings.sort()
		var started: int = Time.get_ticks_usec()
		for sample in range(180):
			player.facing_angle = float(sample) * TAU / 180.0
			visibility.refresh_visibility(false)
		var cpu_ms: float = float(Time.get_ticks_usec() - started) / 180000.0
		report.scenarios[scenario] = {"frame_median_ms": timings[45], "frame_p95_ms": timings[85], "visibility_cpu_ms": cpu_ms}
		print("VISUAL %s %s median=%.3f p95=%.3f visibility_cpu=%.3f ms" % [label, scenario, timings[45], timings[85], cpu_ms])
		player.facing_angle = -PI * 0.5
		visibility.refresh_visibility(false)
		overhead._process(0.0)
		haze.drift_time = 3.0
		haze._process(0.0)
		for frame in range(3): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/visual_%s_%s.png" % [label, scenario])
	var output: FileAccess = FileAccess.open("res://.godot/visual_pipeline_%s.json" % label, FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print("RESULT visual pipeline benchmark complete: ", label)
	quit()
