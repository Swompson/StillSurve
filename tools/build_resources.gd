extends SceneTree

func _initialize() -> void:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation("default")
	for animation_name in ["walk", "run"]:
		var texture: Texture2D = load("res://assets/characters/player/survivor_%s.png" % animation_name)
		var image: Image = texture.get_image()
		if image.is_compressed():
			image.decompress()
		var cell_size: Vector2 = texture.get_size() / Vector2(4, 2)
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, 16.0 if animation_name == "run" else 10.0)
		for row in range(2):
			for column in range(4):
				var start: Vector2i = Vector2i((Vector2(column, row) * cell_size).floor())
				var end: Vector2i = Vector2i((Vector2(column + 1, row + 1) * cell_size).floor())
				var region: Rect2i = image.get_region(Rect2i(start, end - start)).get_used_rect()
				var frame: AtlasTexture = AtlasTexture.new()
				frame.atlas = texture
				frame.region = Rect2(Vector2(start + region.position), Vector2(region.size))
				var padding: Vector2 = Vector2(444, 444) - Vector2(region.size)
				frame.margin = Rect2(padding * 0.5, padding)
				frame.filter_clip = true
				frames.add_frame(animation_name, frame)
	frames.add_animation("idle")
	frames.add_frame("idle", frames.get_frame_texture("walk", 0))
	var save_error: Error = ResourceSaver.save(frames, "res://assets/characters/player/player_frames.tres")
	assert(save_error == OK)
	var keys: Dictionary = {"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN], "move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "sprint": [KEY_SHIFT], "flashlight": [KEY_F], "restart": [KEY_R]}
	for action in keys:
		var events: Array[InputEventKey] = []
		for key in keys[action]:
			var event: InputEventKey = InputEventKey.new()
			event.device = -1
			event.physical_keycode = key
			events.append(event)
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.2, "events": events})
	ProjectSettings.save()
	print("Built editable player frames: idle / walk / run. Input actions saved.")
	quit()
