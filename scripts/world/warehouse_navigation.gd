extends AStar2D

## A shared, cached body-clearance graph for the warehouse's small storage aisles.
const SPACING: float = 24.0
const MARGIN: float = 192.0
var maze: Node2D
var bounds: Rect2
var query: PhysicsShapeQueryParameters2D

func build(world: Node2D) -> void:
	maze = world
	var warehouse: Node2D = maze.get_node("Warehouse")
	var local_bounds: Rect2 = warehouse.get_meta("bounds")
	bounds = Rect2(warehouse.to_global(local_bounds.position), local_bounds.size).grow(MARGIN)
	query = PhysicsShapeQueryParameters2D.new()
	var body: CircleShape2D = CircleShape2D.new()
	body.radius = 29.0
	query.shape = body
	query.collision_mask = 2
	var columns: int = ceili(bounds.size.x / SPACING) + 1
	var rows: int = ceili(bounds.size.y / SPACING) + 1
	var space: PhysicsDirectSpaceState2D = maze.get_world_2d().direct_space_state
	for row in range(rows):
		for column in range(columns):
			var point: Vector2 = bounds.position + Vector2(column, row) * SPACING
			query.transform = Transform2D(0.0, point)
			if space.intersect_shape(query, 1).is_empty():
				add_point(row * columns + column, point)
	for row in range(rows):
		for column in range(columns):
			var id: int = row * columns + column
			if not has_point(id): continue
			for offset in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1)]:
				var neighbor_column: int = column + offset.x
				if neighbor_column < 0 or neighbor_column >= columns: continue
				var neighbor: int = (row + offset.y) * columns + neighbor_column
				if has_point(neighbor) and clear_segment(get_point_position(id), get_point_position(neighbor)):
					connect_points(id, neighbor)

func clear_segment(from: Vector2, to: Vector2) -> bool:
	query.transform = Transform2D(0.0, from)
	query.motion = Vector2.ZERO
	var space: PhysicsDirectSpaceState2D = maze.get_world_2d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty(): return false
	query.motion = to - from
	return space.cast_motion(query)[0] > 0.9999

func route(from: Vector2, to: Vector2) -> PackedVector2Array:
	if not bounds.has_point(from) or not bounds.has_point(to): return PackedVector2Array()
	# Attach the actual endpoints by swept-body checks, never through a crate.
	var ids: PackedInt64Array = get_point_ids()
	var start: int = get_available_point_id()
	add_point(start, from)
	var finish: int = get_available_point_id()
	add_point(finish, to)
	for id in ids:
		var point: Vector2 = get_point_position(id)
		if point.distance_squared_to(from) < SPACING * SPACING * 6.25 and clear_segment(from, point):
			connect_points(start, id)
		if point.distance_squared_to(to) < SPACING * SPACING * 6.25 and clear_segment(point, to):
			connect_points(id, finish)
	var result: PackedVector2Array = get_point_path(start, finish)
	remove_point(start)
	remove_point(finish)
	return result
