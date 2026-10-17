extends AStar2D

var maze: Node2D
var fixtures: Array[Node] = []
var exposure: Dictionary = {}

func build(world: Node2D) -> void:
	maze = world
	fixtures = maze.get_node("Overhead/Fixtures").get_children()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 28.0
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 2
	var space: PhysicsDirectSpaceState2D = maze.get_world_2d().direct_space_state
	var count: int = int(maze.get("width")) * int(maze.get("height"))
	# Nine samples per cell allow detours beside lamps instead of only cell centers.
	for cell in range(count):
		for row in range(3):
			for column in range(3):
				var point: Vector2 = Vector2(maze.call("cell_position", cell)) + Vector2(column - 1, row - 1) * 96.0
				query.transform = Transform2D(0.0, point)
				if space.intersect_shape(query, 1).is_empty():
					var id: int = cell * 9 + row * 3 + column
					add_point(id, point)
					exposure[id] = lamp_exposure(point)
	var grid: AStar2D = maze.get("graph")
	for cell in range(count):
		for row in range(3):
			for column in range(3):
				var id: int = cell * 9 + row * 3 + column
				if column < 2: link(id, id + 1)
				if row < 2: link(id, id + 3)
				if column == 2 and cell % int(maze.get("width")) < int(maze.get("width")) - 1 and grid.are_points_connected(cell, cell + 1):
					link(id, (cell + 1) * 9 + row * 3)
				var below: int = cell + int(maze.get("width"))
				if row == 2 and below < count and grid.are_points_connected(cell, below):
					link(id, below * 9 + column)

func link(first: int, second: int) -> void:
	if has_point(first) and has_point(second) and maze.call("can_walk_line", get_point_position(first), get_point_position(second)):
		connect_points(first, second)

func lamp_exposure(point: Vector2) -> float:
	var result: float = 0.0
	for fixture in fixtures:
		var radius: float = float(fixture.get("light_radius"))
		var distance: float = point.distance_to(fixture.global_position)
		if distance < radius and maze.call("clear_line", point, fixture.global_position):
			result = maxf(result, 1.0 - smoothstep(radius * 0.55, radius, distance))
	return result

func _compute_cost(from_id: int, to_id: int) -> float:
	return get_point_position(from_id).distance_to(get_point_position(to_id)) * (1.0 + maxf(float(exposure[from_id]), float(exposure[to_id])) * 45.0)

func _estimate_cost(from_id: int, to_id: int) -> float:
	return get_point_position(from_id).distance_to(get_point_position(to_id))

func route(from: Vector2, target: Vector2) -> PackedVector2Array:
	if get_point_count() == 0:
		return PackedVector2Array()
	return get_point_path(get_closest_point(from), get_closest_point(target))
