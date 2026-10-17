extends Node

func _ready() -> void: call_deferred("run")

func measure(label: String, frames: int) -> void:
	for frame in range(45):
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	var times: Array[float] = []
	for frame in range(frames):
		var start: int = Time.get_ticks_usec()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		times.append(float(Time.get_ticks_usec() - start) / 1000.0)
	times.sort()
	print("ANDROID_RENDER_BENCH ", label, " median_ms=", times[frames / 2], " p95_ms=", times[int(frames * 0.95)], " renderer=", RenderingServer.get_current_rendering_method(), " viewport=", get_viewport().get_visible_rect().size)

func run() -> void:
	seed(74)
	var game: Node = preload("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	for actor in [game.get_node("Player"), game.get_node("Monster"), game.get_node("SecondMonster")]: actor.set_physics_process(false)
	game.set_process(false)
	var player: Node2D = game.get_node("Player")
	player.global_position = game.get_node("Maze").cell_position(48)
	player.reset_physics_interpolation()
	player.set("facing_angle", 1.2)
	player.set("flashlight_reveal", 1.0)
	player.set("flashlight_strength", 1.0)
	player.get_node("Camera").position_smoothing_enabled = false
	player.get_node("Camera").force_update_scroll()
	get_tree().root.get_node("RuntimeBudget").set_process(false)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await measure("native_canvas", 150)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	await measure("viewport_720", 150)
	get_tree().quit()
