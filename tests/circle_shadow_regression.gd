extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(6): await physics_frame
	var visibility: Node2D = current_scene.get_node("Visibility")
	visibility.set_process(false)
	visibility.set_physics_process(false)
	var center: Vector2 = Vector2(100000, 100000)
	var body: StaticBody2D = StaticBody2D.new()
	body.position = center
	body.collision_layer = 8
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 23.0
	collision.shape = shape
	body.add_child(collision)
	root.add_child(body)
	for frame in range(2): await physics_frame
	visibility.get("ray_query").collision_mask = 8
	var circles: Array[Vector3] = [Vector3(center.x, center.y, shape.radius)]
	visibility.set("geometry_circles", circles)
	var worst_error: float = 0.0
	var valid: bool = true
	for sample in range(121):
		var origin: Vector2 = center + Vector2(-250.0, float(sample) * 0.5 - 30.0)
		visibility.call("update_visibility", origin, 560.0, PackedVector2Array(), 1000.0)
		var arrays: Array = visibility.get("fog_mesh").surface_get_arrays(0)
		var vertices: Variant = arrays[Mesh.ARRAY_VERTEX]
		var count: int = (vertices.size() - 1) / 3
		var transitions: int = 0
		var offset: Vector2 = center - origin
		var half_angle: float = asin(shape.radius / offset.length())
		for index in range(count):
			var a: Vector2 = Vector2(vertices[index * 3 + 1].x, vertices[index * 3 + 1].y)
			var next: int = (index + 1) % count
			var b: Vector2 = Vector2(vertices[next * 3 + 1].x, vertices[next * 3 + 1].y)
			if (a.length() < 559.0) == (b.length() < 559.0): continue
			transitions += 1
			var edge: float = a.angle() if a.length() < 559.0 else b.angle()
			var error: float = minf(absf(angle_difference(edge, offset.angle() - half_angle)), absf(angle_difference(edge, offset.angle() + half_angle)))
			worst_error = maxf(worst_error, error)
		valid = valid and transitions == 2
	valid = valid and worst_error < 0.0003
	print("RESULT moving circle shadow silhouette: ", "PASS" if valid else "FAIL", " worst tangent error=", worst_error)
	quit(0 if valid else 1)
