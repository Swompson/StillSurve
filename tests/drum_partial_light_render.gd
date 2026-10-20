extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	root.position = Vector2i(-1600, -1200)
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(512, 256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage: Node2D = Node2D.new()
	viewport.add_child(stage)
	var drum: Sprite2D = Sprite2D.new()
	drum.texture = load("res://assets/textures/warehouse/steel_drum_top.svg")
	drum.position = Vector2(256, 128)
	drum.scale = Vector2.ONE * 3.0
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://shaders/warehouse_top.gdshader")
	drum.material = material
	stage.add_child(drum)
	var size: Vector2 = drum.texture.get_size()
	material.set_shader_parameter("surface_origin", drum.to_global(-size * 0.5))
	material.set_shader_parameter("surface_axis_x", drum.global_transform.x * size.x)
	material.set_shader_parameter("surface_axis_y", drum.global_transform.y * size.y)
	material.set_shader_parameter("light_origin", Vector2(0, 128))
	material.set_shader_parameter("facing_angle", -0.23)
	material.set_shader_parameter("half_fov", 0.23)
	material.set_shader_parameter("beam_strength", 1.0)
	material.set_shader_parameter("ambient_radius", 0.0)
	material.set_shader_parameter("ambient_softness", 0.0)
	material.set_shader_parameter("beam_range", 1000.0)
	material.set_shader_parameter("beam_fade_start", 900.0)
	# A nearby ceiling lamp must not reveal the unlit half of the texture.
	material.set_shader_parameter("lamp_position", drum.position)
	material.set_shader_parameter("lamp_power", 1.0)
	for frame in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	image.save_png("res://.godot/drum_partial_light.png")
	var lit: Color = image.get_pixel(256, 95)
	var dark: Color = image.get_pixel(256, 160)
	var passed: bool = lit.a > 0.05 and dark.a < 0.01
	material.set_shader_parameter("beam_strength", 0.0)
	for frame in range(3): await process_frame
	await RenderingServer.frame_post_draw
	image = viewport.get_texture().get_image()
	passed = passed and image.get_pixel(256, 95).a < 0.01
	print("RESULT partial drum cone with ceiling lamp: ", "PASS" if passed else "FAIL", " lit=", lit, " dark=", dark)
	quit(0 if passed else 1)
