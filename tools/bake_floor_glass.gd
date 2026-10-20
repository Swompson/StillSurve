extends SceneTree

## Bake subtle glass and its matching contact footprints as editable scene nodes.
func _initialize() -> void:
	var path: String = "res://scenes/world/floor_glass.tscn"
	var previous: Node2D = load(path).instantiate()
	var positions: Array[Vector2] = []
	for patch in previous.get_children(): positions.append(patch.position)
	previous.free()
	var floor_glass: Node2D = Node2D.new()
	floor_glass.name = "FloorGlass"
	var glass_material: ShaderMaterial = ShaderMaterial.new()
	glass_material.resource_local_to_scene = true
	glass_material.shader = load("res://shaders/glass_reflections.gdshader")
	glass_material.set_shader_parameter("light_power", 0.0)
	glass_material.set_shader_parameter("reflection_strength", 1.2)
	floor_glass.material = glass_material
	var variants: Array[Texture2D] = []
	var outlines: Array[PackedVector2Array] = []
	for index in range(4):
		var texture: Texture2D = load("res://assets/textures/decals/glass_%02d.png" % (index + 1))
		variants.append(texture)
		var mask: BitMap = BitMap.new()
		mask.create_from_image_alpha(texture.get_image(), 0.25)
		var points: PackedVector2Array = PackedVector2Array()
		for polygon in mask.opaque_to_polygons(Rect2i(Vector2i.ZERO, mask.get_size()), 3.0):
			for point in polygon: points.append(point - texture.get_size() * 0.5)
		outlines.append(Geometry2D.convex_hull(points))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261019
	var bag: Array[int] = []
	floor_glass.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for patch_index in range(positions.size()):
		if bag.is_empty():
			bag.assign([0, 1, 2, 3])
			for index in range(3, 0, -1):
				var other: int = rng.randi_range(0, index)
				var previous_index: int = bag[index]
				bag[index] = bag[other]
				bag[other] = previous_index
		var patch: Area2D = Area2D.new()
		patch.set_script(preload("res://scripts/world/glass_patch.gd"))
		patch.name = "Patch%02d" % patch_index
		patch.use_parent_material = true
		patch.position = positions[patch_index]
		patch.collision_layer = 0
		patch.collision_mask = 0
		patch.monitoring = false
		patch.monitorable = false
		patch.add_to_group("glass_patches", true)
		floor_glass.add_child(patch)
		patch.owner = floor_glass
		var shards: Sprite2D = Sprite2D.new()
		shards.name = "Shards"
		shards.use_parent_material = true
		var variant: int = bag.pop_back()
		shards.texture = variants[variant]
		shards.rotation = rng.randf_range(-PI, PI)
		var width: float = rng.randf_range(110.0, 125.0)
		shards.scale = Vector2.ONE * width / shards.texture.get_width()
		shards.flip_h = rng.randf() < 0.5
		shards.self_modulate = Color(0.65, 0.67, 0.64, 0.36)
		patch.add_child(shards)
		shards.owner = floor_glass
		var footprint: CollisionPolygon2D = CollisionPolygon2D.new()
		footprint.name = "Footprint"
		footprint.polygon = outlines[variant]
		footprint.rotation = shards.rotation
		footprint.scale = shards.scale * Vector2(-1.0 if shards.flip_h else 1.0, 1.0)
		patch.add_child(footprint)
		footprint.owner = floor_glass
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(floor_glass) == OK)
	assert(ResourceSaver.save(packed, path) == OK)
	floor_glass.free()
	print("Saved all four subtle glass variants and contact footprints")
	quit()
