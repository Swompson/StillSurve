extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	set_meta("hard_mode", true)
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(8): await process_frame
	var game: Node = current_scene
	for hunter in game.get("monsters"): hunter.set_physics_process(false)
	game.get_node("Player").set_physics_process(false)
	var budget: Node = root.get_node("RuntimeBudget")
	budget.mark_focused()
	budget.set_process(false)
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background: ColorRect = ColorRect.new()
	background.size = Vector2(1280, 720)
	background.color = Color("151719")
	viewport.add_child(background)
	var hud: Node = game.get_node("HUD")
	hud.reparent(viewport)
	root.mode = Window.MODE_WINDOWED
	root.size = viewport.size
	root.position = Vector2i(-1400, -1000)
	var stalker: Node = game.get_node("Stalker")
	stalker.begin_grab()
	hud.notify("БОНУС: ЗАРЯД ФОНАРЯ +20", 10.0)
	hud.notify("БОНУС: ВЫНОСЛИВОСТЬ +30", 10.0)
	hud.notify("НАЙДЕНА ФИГУРКА", 10.0)
	for stage in range(3):
		stalker.check_phase = stalker.green_center - 0.15
		for frame in range(12): await process_frame
		await RenderingServer.frame_post_draw
		RenderingServer.force_draw(false)
		viewport.get_texture().get_image().save_png("res://.godot/stalker_skill_%d.png" % stage)
		stalker.submit_check(stalker.green_center)
	print("Saved three skill-check sizes below bonus notifications")
	quit()
