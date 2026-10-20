extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	root.position = Vector2i(-1600, -1200)
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	# Encode texture coordinates in color to measure the rendered UV derivatives.
	var gradient: Image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in range(128):
		for x in range(128): gradient.set_pixel(x, y, Color(float(x) / 127.0, float(y) / 127.0, 0.0, 1.0))
	var mask: Image = Image.create(352, 224, false, Image.FORMAT_RGBA8)
	mask.fill(Color.WHITE)
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(mask)
	sprite.position = Vector2(128, 128)
	sprite.scale = Vector2(0.375, 0.1875)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://shaders/warehouse_top.gdshader")
	material.set_shader_parameter("use_detail_texture", true)
	material.set_shader_parameter("editor_preview", true)
	material.set_shader_parameter("detail_texture", ImageTexture.create_from_image(gradient))
	material.set_shader_parameter("detail_tint", Color.WHITE)
	sprite.material = material
	viewport.add_child(sprite)
	var valid: bool = true
	for angle in [0.0, 0.37, 1.11]:
		material.set_shader_parameter("detail_uv_angle", angle)
		for frame in range(4): await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		var left: Color = image.get_pixel(126, 128)
		var right: Color = image.get_pixel(130, 128)
		var top: Color = image.get_pixel(128, 126)
		var bottom: Color = image.get_pixel(128, 130)
		var dx: Vector2 = Vector2(right.r - left.r, right.g - left.g)
		var dy: Vector2 = Vector2(bottom.r - top.r, bottom.g - top.g)
		var ratio: float = dx.length() / maxf(dy.length(), 0.0001)
		var skew: float = absf(dx.normalized().dot(dy.normalized()))
		valid = valid and absf(ratio - 1.0) < 0.04 and skew < 0.04
		print("UV angle=", angle, " axis ratio=", ratio, " skew=", skew)
	print("RESULT uniform texture scale on stretched and rotated stones: ", "PASS" if valid else "FAIL")
	quit(0 if valid else 1)
