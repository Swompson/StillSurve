extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	set_meta("hard_mode", false)
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(8): await process_frame
	var game: Node = current_scene
	for hunter in game.get("monsters"):
		hunter.set_physics_process(false)
		hunter.hide()
	var player: Node2D = game.get_node("Player")
	player.set_physics_process(false)
	player.hide()
	game.get_node("HUD").hide()
	game.get_node("Visibility").hide()
	game.get_node("Haze").hide()
	root.get_node("RuntimeBudget").mark_focused()
	root.get_node("RuntimeBudget").set_process(false)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(900, 700)
	root.position = Vector2i(-1400, -1000)
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(900, 700)
	viewport.world_2d = root.world_2d
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera: Camera2D = Camera2D.new()
	camera.zoom = Vector2(2.5, 2.5)
	viewport.add_child(camera)
	game.get_node("Vignette").reparent(viewport)
	for fixture in game.get_node("Maze/Overhead/Fixtures").get_children():
		camera.global_position = fixture.global_position
		camera.force_update_scroll()
		player.global_position = fixture.global_position
		player.get_node("Camera").position_smoothing_enabled = false
		player.get_node("Camera").force_update_scroll()
		for frame in range(12): await process_frame
		await RenderingServer.frame_post_draw
		RenderingServer.force_draw(false)
		viewport.get_texture().get_image().save_png("res://.godot/mounted_%s.png" % fixture.name)
		if fixture.fixture_kind != "bunker":
			var shown: Color = viewport.get_texture().get_image().get_pixelv(viewport.size / 2)
			var support: CanvasItem = game.get_node("Maze/Overhead").get_node(fixture.get_meta("mount_support"))
			support.hide()
			for frame in range(5): await process_frame
			await RenderingServer.frame_post_draw
			RenderingServer.force_draw(false)
			var hidden: Color = viewport.get_texture().get_image().get_pixelv(viewport.size / 2)
			var difference: float = Vector3(shown.r - hidden.r, shown.g - hidden.g, shown.b - hidden.b).length()
			if difference < 0.01:
				push_error("Support must visibly occlude the lamp center: " + fixture.name)
				quit(1)
				return
			print("PASS support occludes ", fixture.name, " center difference=", difference)
			support.show()
	var grid: Node2D = Node2D.new()
	grid.position = Vector2(12000, 12000)
	root.add_child(grid)
	var backdrop: ColorRect = ColorRect.new()
	backdrop.position = Vector2(-200, -150)
	backdrop.size = Vector2(400, 300)
	backdrop.color = Color("222722")
	grid.add_child(backdrop)
	for index in range(4):
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = load("res://assets/textures/rubble/broken_concrete_%d.svg" % index)
		sprite.position = Vector2(-85 + (index % 2) * 170, -62 + (index / 2) * 124)
		grid.add_child(sprite)
	camera.global_position = grid.global_position
	camera.force_update_scroll()
	for frame in range(12): await process_frame
	await RenderingServer.frame_post_draw
	RenderingServer.force_draw(false)
	viewport.get_texture().get_image().save_png("res://.godot/rubble_variants.png")
	print("Saved six fixture previews; all four ceiling lamps are occluded by their supports")
	quit()
