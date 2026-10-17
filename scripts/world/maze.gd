extends Node2D

@export var width: int = 11
@export var height: int = 11
@export var cell_size: float = 320.0
@export var connections: PackedInt32Array
var graph: AStar2D = AStar2D.new()
const WALL_SCENE = preload("res://scenes/world/wall.tscn")
const RUBBLE = preload("res://scripts/world/rubble.gd")
const OFFSETS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const BITS: Array[int] = [1, 2, 4, 8]

func _ready() -> void:
	for cell in range(width * height):
		graph.add_point(cell, cell_position(cell))
	for cell in range(width * height):
		for direction in range(4):
			if connections[cell] & BITS[direction]:
				var next: Vector2i = Vector2i(cell % width, cell / width) + OFFSETS[direction]
				var neighbor: int = next.y * width + next.x
				if not graph.are_points_connected(cell, neighbor):
					graph.connect_points(cell, neighbor)
	if not has_node("CorridorDetails"):
		build_corridor_details()

func build_corridor_details() -> void:
	var details: Node2D = Node2D.new()
	details.name = "CorridorDetails"
	add_child(details)
	var door_count: int = 0
	for cell in range(width * height):
		for neighbor in graph.get_point_connections(cell):
			if neighbor <= cell or (cell * 7 + neighbor * 3) % 11 != 0 or door_count >= 14:
				continue
			var normal: Vector2 = cell_local_position(cell).direction_to(cell_local_position(neighbor))
			var tangent: Vector2 = normal.orthogonal()
			var center: Vector2 = (cell_local_position(cell) + cell_local_position(neighbor)) * 0.5
			for side in [-1.0, 1.0]:
				var jamb: StaticBody2D = WALL_SCENE.instantiate() as StaticBody2D
				jamb.name = "Door%02dJamb%s" % [door_count, "A" if side < 0.0 else "B"]
				jamb.position = center + tangent * side * 116.0
				jamb.set("wall_size", Vector2(88, 28) if absf(normal.y) > 0.5 else Vector2(28, 88))
				jamb.add_to_group("door_jambs", true)
				details.add_child(jamb)
			door_count += 1
	for index in range(16):
		var cell: int = (index * 17 + 19) % (width * height)
		var debris: StaticBody2D = RUBBLE.new()
		debris.name = "Rubble%02d" % index
		debris.position = cell_local_position(cell) + Vector2(100.0 if index % 2 == 0 else -100.0, 105.0)
		debris.rotation = -0.22 if index % 2 == 0 else 0.18
		details.add_child(debris)

	build_corner_cover(details)

func build_corner_cover(details: Node2D) -> void:
	var count: int = 0
	# Pick closed inside corners, leaving cell centers and doorways navigable.
	for cell in range(width * height):
		if (cell * 7) % 5 > 1:
			continue
		for corner in range(4):
			var next: int = (corner + 1) % 4
			if connections[cell] & BITS[corner] or connections[cell] & BITS[next]:
				continue
			var debris: StaticBody2D = RUBBLE.new()
			debris.name = "CornerCover%02d" % count
			var offset: Vector2 = Vector2(OFFSETS[corner] + OFFSETS[next]) * 94.0
			debris.position = cell_local_position(cell) + offset
			debris.scale = Vector2(1.5, 1.25)
			debris.rotation = float(corner) * PI * 0.5 + 0.12
			details.add_child(debris)
			count += 1
			break
		if count >= 12:
			break

func cell_position(cell: int) -> Vector2:
	return to_global(cell_local_position(cell))

func cell_local_position(cell: int) -> Vector2:
	return Vector2((float(cell % width) + 0.5 - width * 0.5) * cell_size, (floorf(float(cell) / width) + 0.5 - height * 0.5) * cell_size)

func cell_at(point: Vector2) -> int:
	point = to_local(point)
	var x: int = clampi(int(floor(point.x / cell_size + width * 0.5)), 0, width - 1)
	var y: int = clampi(int(floor(point.y / cell_size + height * 0.5)), 0, height - 1)
	return y * width + x

func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	return graph.get_point_path(cell_at(from), cell_at(to))

func find_alternate_path(from: Vector2, to: Vector2, direct_route: PackedVector2Array) -> PackedVector2Array:
	# Reserve the direct hunter's final corridor; restore the shared graph immediately.
	if direct_route.size() < 2:
		return PackedVector2Array()
	var entry: int = cell_at(direct_route[direct_route.size() - 2])
	var goal: int = cell_at(to)
	if not graph.are_points_connected(entry, goal):
		return PackedVector2Array()
	graph.disconnect_points(entry, goal)
	var alternate: PackedVector2Array = find_path(from, to)
	graph.connect_points(entry, goal)
	return alternate

func clear_line(from: Vector2, to: Vector2) -> bool:
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to, 2)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func can_walk_line(from: Vector2, to: Vector2) -> bool:
	var side: Vector2 = from.direction_to(to).orthogonal() * 29.0
	return clear_line(from, to) and clear_line(from + side, to + side) and clear_line(from - side, to - side)

func spawn_candidates() -> Array[int]:
	var cells: Array[int] = []
	for cell in range(width * height):
		var x: int = cell % width
		var y: int = cell / width
		if (x == 0 or y == 0 or x == width - 1 or y == height - 1) and cell_local_position(cell).length() > 1300.0:
			cells.append(cell)
	return cells
