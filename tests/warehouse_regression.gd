extends SceneTree

var failures: int = 0

func expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var maze: Node2D = load("res://scenes/world/maze.tscn").instantiate()
	root.add_child(maze)
	current_scene = maze
	for frame in range(3):
		await physics_frame
	var warehouse: Node2D = maze.get_node("Warehouse")
	var props: Array[Node] = warehouse.get_node("Props").get_children()
	expect(props.size() == 11, "Warehouse contains eleven saved physical props")
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 29.0
	var space: PhysicsDirectSpaceState2D = maze.get_world_2d().direct_space_state
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.collision_mask = 2
	var routes: int = 0
	for cell in range(121):
		var from: Vector2 = maze.call("cell_position", cell)
		for neighbor in maze.get("graph").get_point_connections(cell):
			if neighbor <= cell:
				continue
			var to: Vector2 = maze.call("cell_position", neighbor)
			query.transform = Transform2D(0.0, from)
			query.motion = to - from
			var sweep: PackedFloat32Array = space.cast_motion(query)
			expect(sweep[0] > 0.999, "Player/hunter width stays clear on graph edge %d-%d" % [cell, neighbor])
			routes += 1
	var figurines: int = 0
	var batteries: int = 0
	for pickup in maze.get_node("Pickups").get_children():
		if pickup.get("kind") == "figurine":
			figurines += 1
		else:
			batteries += 1
		for prop in props:
			var shape: Shape2D = prop.get_node("Collision").shape
			var size: Vector2 = Vector2.ONE * shape.radius * 2.0 if shape is CircleShape2D else shape.size
			var bounds: Rect2 = Rect2(prop.global_position - size * 0.5, size).grow(48.0)
			expect(not bounds.has_point(pickup.global_position), "Warehouse keeps collectible reach free: " + pickup.name)
	expect(figurines == 12 and batteries == 5, "All twelve figurines and five batteries remain authored")
	for prop in props:
		expect(prop.is_in_group("vision_blockers"), "Solid storage props participate in visibility: " + prop.name)
		var expected_points: int = 16 if prop.get_node("Collision").shape is CircleShape2D else 4
		expect(prop.call("get_vision_corners").size() == expected_points, "Storage outline follows its round or rectangular collision: " + prop.name)
		var shape_node: CollisionShape2D = prop.get_node("Collision")
		query.shape = shape_node.shape
		query.transform = shape_node.global_transform
		query.motion = Vector2.ZERO
		query.exclude = [prop.get_rid()]
		var hits: Array[Dictionary] = space.intersect_shape(query)
		expect(hits.is_empty(), "Warehouse prop stays clear of existing walls and rubble: " + prop.name)
	print("RESULT warehouse: %d graph edges at radius 29, 17 collectibles, 11 saved props: %d failure(s)" % [routes, failures])
	quit(0 if failures == 0 else 1)
