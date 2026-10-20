extends SceneTree

func _initialize() -> void: call_deferred("run")

func save_frame(path: String) -> void:
	for frame in range(12): await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(path) == OK)

func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.position = Vector2i(-1400, -1000)
	set_meta("hard_mode", false)
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(6): await physics_frame
	var game: Node = current_scene
	game.finished = true
	var hero: CharacterBody2D = game.player
	hero.set_physics_process(false)
	for hunter in game.monsters: hunter.set_physics_process(false)
	var patches: Array[Node] = get_nodes_in_group("glass_patches")
	var point: Vector2 = patches[8].global_position
	hero.global_position = point + Vector2(0, 120)
	hero.facing_angle = -PI * 0.5
	hero.flashlight_on = true
	hero.flashlight_strength = 1.0
	hero.flashlight_reveal = 1.0
	hero.reset_physics_interpolation()
	hero.get_node("Camera").position_smoothing_enabled = false
	hero.get_node("Camera").reset_smoothing()
	hero.get_node("Camera").force_update_scroll()
	hero.call("update_flashlight")
	game.get_node("Visibility").pose_initialized = false
	game.get_node("Visibility").capture_pose()
	await save_frame("res://.godot/subtle_glass_game.png")
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 30
	root.add_child(layer)
	var floor: TextureRect = TextureRect.new()
	floor.texture = load("res://assets/textures/concrete_floor.png")
	floor.stretch_mode = TextureRect.STRETCH_TILE
	floor.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	floor.modulate = Color(0.52, 0.52, 0.52)
	floor.size = Vector2(1280, 720)
	layer.add_child(floor)
	var textures: Dictionary = {}
	for patch in patches:
		var shards: Sprite2D = patch.get_node("Shards")
		if not textures.has(shards.texture.resource_path): textures[shards.texture.resource_path] = shards
	var index: int = 0
	for original in textures.values():
		var shards: Sprite2D = original.duplicate()
		shards.position = Vector2(300 + index % 2 * 640, 180 + index / 2 * 360)
		shards.scale *= 2.5
		layer.add_child(shards)
		index += 1
	await save_frame("res://.godot/subtle_glass_variants.png")
	print("RESULT real in-game glass and all four enlarged decal previews saved")
	quit()
