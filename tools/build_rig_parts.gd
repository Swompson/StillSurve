extends SceneTree

func opaque_bounds(image: Image) -> Rect2i:
	var low: Vector2i = image.get_size()
	var high: Vector2i = Vector2i(-1, -1)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.20:
				low = low.min(Vector2i(x, y))
				high = high.max(Vector2i(x, y))
	if high.x < 0:
		return Rect2i()
	return Rect2i(low, high - low + Vector2i.ONE).grow(2).intersection(Rect2i(Vector2i.ZERO, image.get_size()))

func _initialize() -> void:
	var names: Array[String] = ["torso", "head", "upper_arm", "forearm", "thigh", "shin", "hand", "flashlight"]
	for kind in ["player", "monster"]:
		var folder: String = "res://assets/characters/%s/rig/" % kind
		var texture: Texture2D = load(folder + "parts.png")
		var source: Image = texture.get_image()
		if source.is_compressed():
			source.decompress()
		var cell: Vector2i = source.get_size() / Vector2i(4, 2)
		for index in range(8):
			var start: Vector2i = Vector2i(index % 4, index / 4) * cell
			var used: Rect2i = opaque_bounds(source.get_region(Rect2i(start, cell)))
			assert(used.has_area(), "Empty rig component: %s/%s" % [kind, names[index]])
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(start + used.position, used.size)
			atlas.filter_clip = true
			assert(ResourceSaver.save(atlas, folder + names[index] + ".tres") == OK)
			if names[index] == "shin":
				var full_region: Rect2 = atlas.region
				var split: float = 0.64 if kind == "player" else 0.72
				var foot: AtlasTexture = AtlasTexture.new()
				foot.atlas = texture
				foot.filter_clip = true
				foot.region = Rect2(full_region.position + Vector2(0, full_region.size.y * split), Vector2(full_region.size.x, full_region.size.y * (1.0 - split)))
				assert(ResourceSaver.save(foot, folder + "foot.tres") == OK)
				atlas.region.size.y *= split
				assert(ResourceSaver.save(atlas, folder + "shin.tres") == OK)
	print("Built eight isolated textured rig parts per actor")
	quit()
