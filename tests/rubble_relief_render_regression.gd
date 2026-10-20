extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	root.position = Vector2i(-1600, -1200)
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = load("res://assets/textures/rubble/stone_mask_0.svg")
	sprite.position = Vector2(128, 128)
	sprite.scale = Vector2.ONE * 0.5
	var material: ShaderMaterial = load("res://assets/textures/rubble/broken_concrete_0_material.tres").duplicate()
	material.set_shader_parameter("editor_preview", false)
	material.set_shader_parameter("ambient_radius", 1000.0)
	material.set_shader_parameter("ambient_softness", 1.0)
	material.set_shader_parameter("surface_origin", Vector2(40, 72))
	material.set_shader_parameter("surface_axis_x", Vector2(176, 0))
	material.set_shader_parameter("surface_axis_y", Vector2(0, 112))
	sprite.material = material
	viewport.add_child(sprite)
	var frames: Array[Image] = []
	for source in [Vector2(-40, 128), Vector2(300, 128)]:
		material.set_shader_parameter("light_origin", source)
		for frame in range(4): await process_frame
		await RenderingServer.frame_post_draw
		frames.append(viewport.get_texture().get_image())
	var lit: float = 0.0
	var unlit: float = 0.0
	for y in range(122, 132):
		for x in range(63, 69):
			lit += frames[0].get_pixel(x, y).get_luminance()
			unlit += frames[1].get_pixel(x, y).get_luminance()
	var valid: bool = lit > unlit * 1.15
	for y in range(256):
		for x in range(256):
			valid = valid and is_equal_approx(frames[0].get_pixel(x, y).a, frames[1].get_pixel(x, y).a)
	frames[0].save_png("res://.godot/stone_relief_left.png")
	frames[1].save_png("res://.godot/stone_relief_right.png")
	print("RESULT sculpted stone lighting and unchanged silhouette: ", "PASS" if valid else "FAIL", " illuminated rim=", lit, " opposite light=", unlit)
	quit(0 if valid else 1)
