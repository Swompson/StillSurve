extends SceneTree

func _initialize() -> void:
	var frames: SpriteFrames = load("res://assets/characters/player/player_frames.tres")
	for animation_name in ["walk", "run"]:
		var sheet: Image = Image.create(444 * 8, 444, false, Image.FORMAT_RGBA8)
		for index in range(8):
			var frame: AtlasTexture = frames.get_frame_texture(animation_name, index) as AtlasTexture
			var source: Image = frame.atlas.get_image()
			if source.is_compressed():
				source.decompress()
			sheet.blit_rect(source, Rect2i(frame.region), Vector2i(index * 444, 0) + Vector2i(frame.margin.position))
		sheet.save_png("res://assets/characters/player/smooth_%s.png" % animation_name)
	print("Built padded, unclipped animation atlases")
	quit()
