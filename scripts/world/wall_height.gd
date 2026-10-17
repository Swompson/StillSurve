@tool
extends Node2D

@export var height_pixels: float = 12.0
var update_clock: float = 0.0
var shift: Vector2 = Vector2(5, -7)

func _ready() -> void:
	set_process(not Engine.is_editor_hint())

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	update_clock -= delta
	if update_clock > 0.0:
		return
	update_clock = 0.033
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera:
		var extent: Vector2 = get_viewport_rect().size / camera.zoom * 0.5 + Vector2(350, 350)
		if not Rect2(camera.get_screen_center_position() - extent, extent * 2.0).has_point(global_position):
			return
		var next: Vector2 = ((global_position - camera.get_screen_center_position()) * 0.018 + Vector2(0, -height_pixels * 0.5)).limit_length(height_pixels)
		if next.distance_squared_to(shift) > 0.04:
			shift = next
			queue_redraw()

func _draw() -> void:
	var wall: Node = get_parent()
	if not wall.has_method("get_wall_rectangles"):
		return
	for bounds in wall.get_wall_rectangles():
		var points: PackedVector2Array = PackedVector2Array([bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)])
		for index in range(4):
			var a: Vector2 = points[index]
			var b: Vector2 = points[(index + 1) % 4]
			draw_colored_polygon(PackedVector2Array([a, b, b + shift, a + shift]), Color("262b2a") if index % 2 == 0 else Color("353a36"))
		draw_colored_polygon(PackedVector2Array([points[0]+shift, points[1]+shift, points[2]+shift, points[3]+shift]), Color("484c43"))
