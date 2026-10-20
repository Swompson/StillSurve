@tool
extends "res://scripts/world/warehouse_prop.gd"

@export_range(0, 3) var visual_variant: int = 0:
	set(value):
		visual_variant = value
		if is_node_ready(): build_surface()

func _ready() -> void:
	build_surface()
	add_to_group("rubble", true)
	add_to_group("warehouse_props", true)
	super._ready()

func build_surface() -> void:
	# Saved nodes share one silhouette between physics, lighting and the texture.
	var sprite: Sprite2D = get_node("Surface")
	var collision: CollisionShape2D = get_node("Collision")
	sprite.texture = load("res://assets/textures/rubble/stone_mask_%d.svg" % visual_variant)
	sprite.material = load("res://assets/textures/rubble/broken_concrete_%d_material.tres" % visual_variant)
	sprite.scale = Vector2(88, 56) / sprite.texture.get_size()
	sprite.z_index = 101
	sprite.z_as_relative = false
	collision.shape = load("res://assets/textures/rubble/broken_concrete_%d_shape.tres" % visual_variant)
	cached_polygon = PackedVector2Array()
	vision_geometry_changed.emit()
