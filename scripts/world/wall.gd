@tool
extends StaticBody2D

signal vision_geometry_changed

var cached_transform: Transform2D
var cached_size: Vector2 = Vector2.INF
var cached_damaged: bool = false
var cached_gap: float = -1.0
var cached_corners: PackedVector2Array = PackedVector2Array()

@export var wall_size: Vector2 = Vector2(320, 24):
	set(value):
		wall_size = value
		queue_redraw()
		if is_node_ready():
			update_shape()
@export var damaged: bool = false:
	set(value):
		damaged = value
		queue_redraw()
		if is_node_ready():
			update_shape()
@export_range(12.0, 36.0) var gap_width: float = 28.0:
	set(value):
		gap_width = value
		queue_redraw()
		if is_node_ready():
			update_shape()

func _ready() -> void:
	set_notify_transform(true)
	z_index = 90
	var concrete: ShaderMaterial = ShaderMaterial.new()
	concrete.shader = preload("res://shaders/concrete_wall.gdshader")
	concrete.set_shader_parameter("exposure", 0.18)
	material = concrete
	collision_layer = 2
	collision_mask = 0
	add_to_group("vision_blockers")
	update_shape()

func update_shape() -> void:
	var rectangles: Array[Rect2] = get_wall_rectangles()
	var first: CollisionShape2D = $Collision
	var second: CollisionShape2D = get_node_or_null("BrokenCollision") as CollisionShape2D
	if rectangles.size() == 2 and second == null:
		second = CollisionShape2D.new()
		second.name = "BrokenCollision"
		add_child(second)
	if second != null:
		second.disabled = rectangles.size() == 1
	for index in range(rectangles.size()):
		var collision: CollisionShape2D = first if index == 0 else second
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = rectangles[index].size
		collision.position = rectangles[index].get_center()
		collision.shape = shape
	if has_node("Height"):
		$Height.queue_redraw()
	vision_geometry_changed.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		vision_geometry_changed.emit()

func get_wall_rectangles() -> Array[Rect2]:
	var bounds: Rect2 = Rect2(-wall_size * 0.5, wall_size)
	if not damaged:
		return [bounds]
	var half_gap: float = minf(gap_width, maxf(wall_size.x, wall_size.y) * 0.5) * 0.5
	if wall_size.x > wall_size.y:
		return [Rect2(bounds.position, Vector2(wall_size.x * 0.5 - half_gap, wall_size.y)), Rect2(Vector2(half_gap, bounds.position.y), Vector2(wall_size.x * 0.5 - half_gap, wall_size.y))]
	return [Rect2(bounds.position, Vector2(wall_size.x, wall_size.y * 0.5 - half_gap)), Rect2(Vector2(bounds.position.x, half_gap), Vector2(wall_size.x, wall_size.y * 0.5 - half_gap))]

func get_vision_corners() -> PackedVector2Array:
	if global_transform == cached_transform and wall_size == cached_size and damaged == cached_damaged and gap_width == cached_gap:
		return cached_corners
	var corners: PackedVector2Array = PackedVector2Array()
	for bounds in get_wall_rectangles():
		corners.append_array(PackedVector2Array([to_global(bounds.position), to_global(Vector2(bounds.end.x, bounds.position.y)), to_global(bounds.end), to_global(Vector2(bounds.position.x, bounds.end.y))]))
	cached_transform = global_transform
	cached_size = wall_size
	cached_damaged = damaged
	cached_gap = gap_width
	cached_corners = corners
	return cached_corners

func _draw() -> void:
	for bounds in get_wall_rectangles():
		draw_wall_section(bounds)
	if damaged:
		draw_damage()

func draw_wall_section(bounds: Rect2) -> void:
	draw_rect(bounds, Color.WHITE)

func draw_damage() -> void:
	var horizontal: bool = wall_size.x > wall_size.y
	var half_gap: float = gap_width * 0.5
	var thickness: float = minf(wall_size.x, wall_size.y) * 0.5
	# Jagged chips stay on the solid sides so the slit remains visibly open.
	for sign_value in [-1.0, 1.0]:
		var edge: float = sign_value * half_gap
		for index in range(4):
			var along: float = -thickness + 3.0 + index * 6.0
			var points: PackedVector2Array = PackedVector2Array([Vector2(edge, along - 3), Vector2(edge + sign_value * (5 + index % 2 * 3), along), Vector2(edge, along + 3)])
			if not horizontal:
				for point_index in range(points.size()):
					points[point_index] = Vector2(points[point_index].y, points[point_index].x)
			draw_colored_polygon(points, Color("1b1e19"))
		var start: Vector2 = Vector2(edge + sign_value * 4, -3)
		var end: Vector2 = Vector2(edge + sign_value * 38, 6)
		if not horizontal:
			start = Vector2(start.y, start.x)
			end = Vector2(end.y, end.x)
		draw_line(start, end, Color("1b1e19"), 2, true)
