extends SceneTree

var viewport: SubViewport

func _initialize() -> void: call_deferred("run")

func capture() -> Image:
	for frame in range(3): await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func changed_pixels(first: Image, second: Image, bounds: Rect2i) -> int:
	var count: int = 0
	for y in range(bounds.position.y, bounds.end.y, 2):
		for x in range(bounds.position.x, bounds.end.x, 2):
			var a: Color = first.get_pixel(x, y)
			var b: Color = second.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.003: count += 1
	return count

func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(960, 640)
	root.position = Vector2i(-1400, -1000)
	viewport = SubViewport.new()
	viewport.size = Vector2i(960, 640)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var floor: TextureRect = TextureRect.new()
	floor.texture = load("res://assets/textures/concrete_floor.png")
	floor.stretch_mode = TextureRect.STRETCH_TILE
	floor.modulate = Color(0.45, 0.45, 0.45)
	floor.size = Vector2(960, 640)
	viewport.add_child(floor)
	var glass: Node2D = load("res://scenes/world/floor_glass.tscn").instantiate()
	viewport.add_child(glass)
	var mat: ShaderMaterial = glass.material
	var shown: Array[Sprite2D] = []
	for index in range(glass.get_child_count()):
		var patch: Node2D = glass.get_child(index)
		patch.visible = index < 4
		if index >= 4: continue
		patch.position = Vector2(240 + index % 2 * 480, 170 + index / 2 * 250)
		patch.scale = Vector2.ONE * 1.7
		shown.append(patch.get_node("Shards"))
		assert(patch.use_parent_material and patch.get_node("Shards").use_parent_material)
	mat.set_shader_parameter("light_origin", Vector2(480, 640))
	mat.set_shader_parameter("light_angle", -PI * 0.5)
	mat.set_shader_parameter("light_range", 1000.0)
	mat.set_shader_parameter("fade_start", 700.0)
	mat.set_shader_parameter("half_fov", 1.25)
	mat.set_shader_parameter("light_power", 1.0)
	mat.set_shader_parameter("reflection_strength", 0.0)
	var before: Image = await capture()
	before.save_png("res://.godot/glass_flashlight_before.png")
	mat.set_shader_parameter("reflection_strength", 1.2)
	var after: Image = await capture()
	after.save_png("res://.godot/glass_flashlight_after.png")
	var counts: Array[int] = []
	for index in range(4):
		var bounds: Rect2i = Rect2i(130 + index % 2 * 480, 60 + index / 2 * 250, 220, 220)
		var changed: int = changed_pixels(before, after, bounds)
		counts.append(changed)
		assert(changed > 40, "Every texture catches the flashlight")
	for shards in shown:
		var source: Image = shards.texture.get_image()
		var bounds: Rect2i = Rect2i(shards.get_global_transform() * shards.get_rect()).intersection(Rect2i(0, 0, 960, 640))
		for y in range(bounds.position.y, bounds.end.y, 3):
			for x in range(bounds.position.x, bounds.end.x, 3):
				var uv: Vector2 = (shards.to_local(Vector2(x + 0.5, y + 0.5)) - shards.get_rect().position) / shards.get_rect().size
				if shards.flip_h: uv.x = 1.0 - uv.x
				if uv.x < 0.0 or uv.y < 0.0 or uv.x >= 1.0 or uv.y >= 1.0: continue
				var sample: Vector2i = Vector2i(uv * Vector2(source.get_size()))
				# Ignore the filtered one-pixel rim; empty interiors cannot glow.
				if source.get_pixelv(sample).a > 0.0: continue
				var expanded: bool = false
				for offset in [Vector2i(10, 0), Vector2i(-10, 0), Vector2i(0, 10), Vector2i(0, -10)]:
					var adjacent: Vector2i = (sample + offset).clamp(Vector2i.ZERO, source.get_size() - Vector2i.ONE)
					if source.get_pixelv(adjacent).a > 0.0: expanded = true
				if expanded: continue
				assert(absf(after.get_pixel(x, y).get_luminance() - before.get_pixel(x, y).get_luminance()) < 0.003, "Transparent gaps never form a glow")
	mat.set_shader_parameter("light_power", 0.0)
	var off: Image = await capture()
	off.save_png("res://.godot/glass_flashlight_off.png")
	assert(changed_pixels(before, off, Rect2i(0, 0, 960, 640)) == 0, "Flashlight off preserves the original subtle decal")
	mat.set_shader_parameter("light_power", 1.0)
	mat.set_shader_parameter("light_angle", PI * 0.5)
	assert(changed_pixels(off, await capture(), Rect2i(0, 0, 960, 640)) == 0, "Turning away removes all reflections")
	mat.set_shader_parameter("light_angle", -PI * 0.5)
	mat.set_shader_parameter("light_range", 30.0)
	mat.set_shader_parameter("fade_start", 15.0)
	assert(changed_pixels(off, await capture(), Rect2i(0, 0, 960, 640)) == 0, "Out-of-range glass does not reflect")
	mat.set_shader_parameter("light_range", 1000.0)
	mat.set_shader_parameter("fade_start", 700.0)
	var segments: Array[Vector4] = [Vector4(0, 560, 960, 560)]
	segments.resize(256)
	mat.set_shader_parameter("occluder_segments", segments)
	mat.set_shader_parameter("occluder_count", 1)
	var blocked: Image = await capture()
	blocked.save_png("res://.godot/glass_flashlight_blocked.png")
	assert(changed_pixels(off, blocked, Rect2i(0, 0, 960, 640)) == 0, "A wall blocks reflected light even without fog")
	mat.set_shader_parameter("occluder_count", 0)
	mat.set_shader_parameter("light_origin", Vector2(520, 640))
	assert(changed_pixels(after, await capture(), Rect2i(0, 0, 960, 640)) > 40, "Highlights respond to flashlight movement")
	viewport.free()
	set_meta("hard_mode", false)
	assert(change_scene_to_file("res://scenes/game.tscn") == OK)
	for frame in range(6):
		await process_frame
		await physics_frame
	var game: Node = current_scene
	game.player.set_physics_process(false)
	for hunter in game.monsters: hunter.set_physics_process(false)
	var visibility: Node2D = game.get_node("Visibility")
	visibility.set_process(false)
	visibility.set_physics_process(false)
	game.player.flashlight_on = true
	game.player.flashlight_strength = 0.65
	game.player.facing_angle = 0.42
	visibility.refresh_visibility(false)
	var live: ShaderMaterial = game.get_node("Maze/FloorGlass").material
	assert(live == visibility.glass_material and live != mat)
	assert(is_equal_approx(live.get_shader_parameter("light_power"), 0.65))
	assert(live.get_shader_parameter("light_origin").is_equal_approx(game.player.get_view_origin()))
	assert(is_equal_approx(live.get_shader_parameter("light_angle"), 0.42))
	assert(visibility.glass_occlusion_valid and int(live.get_shader_parameter("occluder_count")) > 0)
	game.player.flashlight_strength = 0.0
	game.player.flashlight_on = false
	visibility.refresh_visibility(false)
	assert(is_zero_approx(live.get_shader_parameter("light_power")))
	print("RESULT glass reflections: four variants %s changed pixels; off, cone, range, alpha, walls, movement and live flashlight sync passed" % str(counts))
	quit()
