extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	for frame in range(6): await process_frame
	EditorInterface.set_main_screen_editor("2D")
	EditorInterface.get_base_control().get_window().size = Vector2i(1400, 900)
	EditorInterface.open_scene_from_path("res://scenes/world/overhead.tscn")
	for frame in range(12): await process_frame
	var scene: Node = EditorInterface.get_edited_scene_root()
	assert(scene != null and scene.has_node("Fixtures"))
	var fixtures: Node = scene.get_node("Fixtures")
	assert(fixtures.get_child_count() == 5)
	for fixture in fixtures.get_children():
		assert(fixture.owner == scene and fixture.scene_file_path.is_empty())
		assert(fixture.get_node("Housing/Lens").owner == scene)
		assert(fixture.get_node("Housing/Lens").is_visible_in_tree())
		assert(not fixture.is_processing())
	print("EDITOR: five native fixture bodies are visible and owned by the edited scene; tool processing disabled")
	var viewport: SubViewport = EditorInterface.get_editor_viewport_2d()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for frame in range(8):
		await process_frame
		await RenderingServer.frame_post_draw
	viewport.global_canvas_transform = Transform2D(Vector2(0.16, 0), Vector2(0, 0.16), Vector2(viewport.size) * 0.5)
	await process_frame
	await RenderingServer.frame_post_draw
	print("EDITOR viewport: ", viewport.size)
	viewport.get_texture().get_image().save_png("res://docs/visuals/editor_fixtures.png")
	for name in ["CeilingLamp1", "WallLamp"]:
		var fixture: Node2D = fixtures.get_node(name)
		viewport.global_canvas_transform = Transform2D(Vector2(2.0, 0), Vector2(0, 2.0), Vector2(viewport.size) * 0.5 - fixture.global_position * 2.0)
		await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://docs/visuals/editor_%s.png" % name)
	quit()
