extends SceneTree

var capture_viewport: SubViewport

func _initialize() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.position = Vector2i(-1400, -1000)
	call_deferred("capture")

func save_frame(path: String) -> void:
	for frame in range(30): await process_frame
	await RenderingServer.frame_post_draw
	RenderingServer.force_draw(false)
	print("PREVIEW ", path, " size=", root.size, " mode=", root.mode, " position=", root.position, " cap=", Engine.max_fps, " low_usage=", OS.low_processor_usage_mode)
	capture_viewport.get_texture().get_image().save_png(path)

func capture() -> void:
	set_meta("hard_mode", false)
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(6): await process_frame
	capture_viewport = SubViewport.new()
	capture_viewport.size = Vector2i(1280, 720)
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(capture_viewport)
	var game: Node = current_scene
	var hud: Node = game.get_node("HUD")
	game.remove_child(hud)
	capture_viewport.add_child(hud)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.position = Vector2i(-1400, -1000)
	var budget: Node = root.get_node("RuntimeBudget")
	budget.mark_focused()
	budget.set_process(false)
	hud.set_paused(true)
	await save_frame("res://.godot/left_pause.png")
	hud.pause_overlay.show_settings(true)
	await save_frame("res://.godot/left_pause_graphics.png")
	for category in ["Sound", "Game", "Controls"]:
		hud.pause_overlay.select_category(category)
		await save_frame("res://.godot/left_pause_%s.png" % category.to_lower())
	print("Saved left pause and four settings page previews")
	quit()
