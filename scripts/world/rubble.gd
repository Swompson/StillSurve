@tool
extends StaticBody2D

@export_range(0, 3) var visual_variant: int = 0

signal vision_geometry_changed

var cached_transform: Transform2D
var cached_outline: PackedVector2Array = PackedVector2Array()
var cached_corners: PackedVector2Array = PackedVector2Array()

var outline: PackedVector2Array = PackedVector2Array([
	Vector2(-37, -10), Vector2(-24, -22), Vector2(-3, -16), Vector2(16, -21),
	Vector2(36, -4), Vector2(26, 16), Vector2(5, 20), Vector2(-28, 15)])

func _ready() -> void:
	set_notify_transform(true)
	collision_layer = 2
	collision_mask = 0
	z_index = 90
	add_to_group("vision_blockers")
	add_to_group("rubble")
	if not has_node("Collision"):
		var collision: CollisionPolygon2D = CollisionPolygon2D.new()
		collision.name = "Collision"
		collision.polygon = outline
		add_child(collision)
	material = null
	if not has_node("Surface"):
		build_surface()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		vision_geometry_changed.emit()

func get_vision_corners() -> PackedVector2Array:
	if cached_transform == global_transform and cached_outline == outline:
		return cached_corners
	var points: PackedVector2Array = PackedVector2Array()
	for point in outline:
		points.append(to_global(point))
	cached_transform = global_transform
	cached_outline = outline
	cached_corners = points
	return cached_corners

func build_surface() -> void:
	if has_node("Surface"): get_node("Surface").free()
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "Surface"
	sprite.texture = load("res://assets/textures/rubble/broken_concrete_%d.svg" % visual_variant)
	sprite.scale = Vector2(0.82, 0.82)
	add_child(sprite)

