extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	root.position = Vector2i(-1600, -1200)
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(64, 64)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background: ColorRect = ColorRect.new()
	background.size = Vector2(64, 64)
	background.color = Color.WHITE
	viewport.add_child(background)
	var shadow: Polygon2D = Polygon2D.new()
	shadow.polygon = PackedVector2Array([Vector2(-100, -100), Vector2(150, -100), Vector2(-100, 150)])
	shadow.color = Color.BLACK
	viewport.add_child(shadow)
	var jumps: Array[float] = []
	var partial_counts: Array[int] = []
	for mode in [Viewport.MSAA_DISABLED, Viewport.MSAA_4X]:
		viewport.msaa_2d = mode
		var previous: float = 1.0
		var largest_jump: float = 0.0
		var partial: int = 0
		for sample in range(17):
			shadow.position.x = sample * 0.125
			for frame in range(2): await process_frame
			await RenderingServer.frame_post_draw
			var value: float = viewport.get_texture().get_image().get_pixel(25, 25).r
			if value > 0.01 and value < 0.99: partial += 1
			largest_jump = maxf(largest_jump, absf(value - previous))
			previous = value
		jumps.append(largest_jump)
		partial_counts.append(partial)
	var valid: bool = int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_2d")) == Viewport.MSAA_4X and partial_counts[1] > partial_counts[0] and jumps[1] < jumps[0]
	print("RESULT moving shadow edge antialiasing: ", "PASS" if valid else "FAIL", " maximum pixel jump ", jumps[0], " -> ", jumps[1], "; partial coverage frames=", partial_counts)
	quit(0 if valid else 1)
