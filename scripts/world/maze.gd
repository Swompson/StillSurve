extends Node2D

@export var width: int = 11
@export var height: int = 11
@export var cell_size: float = 320.0
@export var connections: PackedInt32Array
var graph: AStar2D = AStar2D.new()
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

func cell_position(cell: int) -> Vector2:
	return Vector2((float(cell % width) + 0.5 - width * 0.5) * cell_size, (floorf(float(cell) / width) + 0.5 - height * 0.5) * cell_size)

func cell_at(point: Vector2) -> int:
	var x: int = clampi(int(floor(point.x / cell_size + width * 0.5)), 0, width - 1)
	var y: int = clampi(int(floor(point.y / cell_size + height * 0.5)), 0, height - 1)
	return y * width + x

func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	return graph.get_point_path(cell_at(from), cell_at(to))

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
		if (x == 0 or y == 0 or x == width - 1 or y == height - 1) and cell_position(cell).length() > 1300.0:
			cells.append(cell)
	return cells
