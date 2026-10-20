extends AStar2D

var maze: Node2D
var fixtures: Array[Node] = []
var exposure: Dictionary = {}
var connected_components: Dictionary = {}
var concealment_key: Array = []
var concealed_blocked: Array[int] = []
const RELOCATION_CLEARANCE: float = 250.0

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
	build_connected_components()

func build_connected_components() -> void:
	# The authored navigation graph is static during play. Reachability checks do
	# not need a complete weighted A* search for every possible retreat target.
	connected_components.clear()
	var component: int = 0
	for start in get_point_ids():
		if connected_components.has(start): continue
		var pending: Array[int] = [start]
		connected_components[start] = component
		var cursor: int = 0
		while cursor < pending.size():
			var current: int = pending[cursor]
			cursor += 1
			for neighbor in get_point_connections(current):
				if connected_components.has(neighbor): continue
				connected_components[neighbor] = component
				pending.append(neighbor)
		component += 1

func has_route(from_id: int, to_id: int) -> bool:
	return connected_components.has(from_id) and connected_components.has(to_id) and connected_components[from_id] == connected_components[to_id]

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
	var points: PackedVector2Array = get_point_path(get_closest_point(from), get_closest_point(target))
	if maze.has_method("refine_warehouse_path"):
		return maze.call("refine_warehouse_path", from, target, points)
	return points

func relocation_point_safe(point: Vector2, hero: CharacterBody2D) -> bool:
	if point.distance_squared_to(hero.global_position) < RELOCATION_CLEARANCE * RELOCATION_CLEARANCE and maze.call("clear_line", hero.global_position, point):
		return false
	return not hero.call("is_point_visible", point)

func concealed_segment(from: Vector2, to: Vector2, hero: CharacterBody2D) -> bool:
	var samples: int = maxi(1, ceili(from.distance_to(to) / 24.0))
	for index in range(samples + 1):
		if not relocation_point_safe(from.lerp(to, float(index) / samples), hero): return false
	return true

func concealed_route(from: Vector2, target: Vector2, hero: CharacterBody2D) -> PackedVector2Array:
	if get_point_count() == 0: return PackedVector2Array()
	if not relocation_point_safe(from, hero) or not relocation_point_safe(target, hero): return PackedVector2Array()
	# Reuse visibility queries for all candidate corners evaluated in this plan.
	var key: Array = [hero.global_position, hero.get("facing_angle"), hero.get("flashlight_on"), hero.get("flashlight_strength")]
	if key != concealment_key:
		concealment_key = key
		concealed_blocked.clear()
		for id in get_point_ids():
			if not relocation_point_safe(get_point_position(id), hero): concealed_blocked.append(id)
	var changed: Array[int] = []
	for id in concealed_blocked:
		if not is_point_disabled(id):
			set_point_disabled(id, true)
			changed.append(id)
	var result: PackedVector2Array = get_point_path(get_closest_point(from), get_closest_point(target))
	for id in changed: set_point_disabled(id, false)
	var previous: Vector2 = from
	for point in result:
		if not concealed_segment(previous, point, hero): return PackedVector2Array()
		previous = point
	if not concealed_segment(previous, target, hero): return PackedVector2Array()
	return result
