extends SceneTree

func _initialize() -> void:
	var overhead: Node2D = load("res://scenes/world/overhead.tscn").instantiate()
	for fixture in overhead.get_node("Fixtures").get_children():
		if fixture.fixture_kind == "bunker": continue
		var support: Line2D = overhead.get_node(fixture.get_meta("mount_support"))
		var best: float = INF
		var anchor: Vector2
		for index in range(support.points.size() - 1):
			var point: Vector2 = Geometry2D.get_closest_point_to_segment(fixture.position, support.points[index], support.points[index + 1])
			if point.distance_squared_to(fixture.position) < best:
				best = point.distance_squared_to(fixture.position)
				anchor = point
		fixture.position = anchor
		fixture.z_index = -2
		fixture.get_node("Housing").position = Vector2.ZERO
		fixture.get_node("Housing").rotation = 0.0
		for obsolete in ["MountClamp", "Suspension", "Cable", "CeilingMount"]:
			var node: Node = fixture.get_node_or_null(obsolete)
			if node: node.free()
		print(fixture.name, " directly under ", support.get_parent().name, "/", support.name, " at ", anchor)
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(overhead) == OK)
	assert(ResourceSaver.save(packed, "res://scenes/world/overhead.tscn") == OK)
	overhead.free()
	quit()
