extends SceneTree


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1200, 540)
	root.position = Vector2i(-1600, -1000)
	root.get_node("RuntimeBudget").mark_focused()
	root.get_node("RuntimeBudget").set_process(false)
	var stage: Node2D = Node2D.new()
	root.add_child(stage)
	current_scene = stage
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1200, 540)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stage.add_child(viewport)
	var floor: Sprite2D = Sprite2D.new()
	floor.texture = load("res://assets/textures/concrete_floor.png")
	floor.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	floor.region_enabled = true
	floor.region_rect = Rect2(0, 0, 1200, 540)
	floor.position = Vector2(600, 270)
	floor.modulate = Color(0.55, 0.55, 0.53)
	viewport.add_child(floor)
	var overhead: Node2D = load("res://scenes/world/overhead.tscn").instantiate()
	viewport.add_child(overhead)
	overhead.set_process(false)
	for layer in ["Pipes", "Beams", "Wires"]:
		overhead.get_node(layer).hide()
	for fixture in overhead.get_node("Fixtures").get_children():
		fixture.set_process(false)
		fixture.hide()
	for index in range(3):
		var fixture: Node2D = overhead.get_node("Fixtures/" + ["CeilingLamp1", "CeilingLamp2", "WallLamp"][index])
		fixture.position = Vector2(205 + index * 395, 270)
		fixture.rotation = 0.0
		fixture.scale = Vector2(3, 3)
		fixture.get_node("Housing").position = Vector2.ZERO
		fixture.get_node("Housing").rotation = 0.0
		fixture.show()
		var label: Label = Label.new()
		label.position = Vector2(index * 395 + 30, 430)
		label.size = Vector2(350, 50)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.text = ["ENAMEL SHADE / TOP", "TWIN TUBE / UPPER CASE", "WALL CAGE / TOP"][index]
		label.add_theme_font_size_override("font_size", 18)
		label.modulate = Color(0.67, 0.70, 0.60)
		viewport.add_child(label)
	for frame in range(12):
		await process_frame
		await RenderingServer.frame_post_draw
	RenderingServer.force_draw(false)
	viewport.get_texture().get_image().save_png("res://.godot/fixture_materials_preview.png")
	print("Saved three authored fixture material previews")
	quit()
