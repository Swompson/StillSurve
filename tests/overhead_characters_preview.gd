extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1280, 820)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var backdrop: ColorRect = ColorRect.new()
	backdrop.z_index = -10
	backdrop.size = Vector2(viewport.size)
	backdrop.color = Color(0.055, 0.06, 0.055)
	viewport.add_child(backdrop)
	var font: Font = load("res://assets/fonts/sjz/Sjz.otf")
	var kinds: Array[String] = ["player", "monster", "stalker"]
	var captions: Array[String] = ["ИГРОК", "ОХОТНИК", "СТАЛКЕР"]
	var actors: Array[CharacterBody2D] = []
	for index in range(3):
		var title: Label = Label.new()
		title.text = captions[index]
		title.position = Vector2(index * 420 + 70, 36)
		title.size = Vector2(300, 50)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_override("font", font)
		title.add_theme_font_size_override("font_size", 32)
		viewport.add_child(title)
		for row in range(2):
			var actor: CharacterBody2D = CharacterBody2D.new()
			actors.append(actor)
			var rig: Node2D = load("res://scenes/actors/%s_body.tscn" % kinds[index]).instantiate()
			rig.preview_mode = true
			rig.setup(actor, index > 0)
			rig.movement = 1.0
			rig.phase = PI * (0.25 if row == 0 else 1.1)
			rig.pose()
			rig.position = Vector2(index * 420 + 220, 255 + row * 360)
			rig.scale = Vector2.ONE * 3.0
			if row == 1: rig.rotation = -PI * 0.5
			viewport.add_child(rig)
	for frame in range(5): await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://docs/visuals/overhead_characters_v2.png")
	for actor in actors: actor.free()
	print("Saved native overhead character scene preview")
	quit()
