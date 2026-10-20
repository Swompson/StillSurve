extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(6): await physics_frame
	var game: Node = current_scene
	for actor in game.monsters: actor.set_physics_process(false)
	game.player.set_physics_process(false)
	var pile: Node2D = game.get_node("Maze/CorridorDetails/Rubble00")
	pile.global_position = Vector2(10000, 10000)
	var visibility: Node2D = game.get_node("Visibility")
	visibility.set_process(false)
	visibility.set_physics_process(false)
	for frame in range(2): await physics_frame
	visibility.call("get_blocker_corners")
	var corners: PackedVector2Array = pile.call("get_vision_corners")
	var worst_error: float = 0.0
	var worst_jump: float = 0.0
	var previous_error: float = 0.0
	var valid: bool = true
	for sample in range(481):
		var origin: Vector2 = pile.global_position + Vector2(-180, sample * 0.125 - 30.0)
		var center_angle: float = (pile.global_position - origin).angle()
		var low: float = INF
		var high: float = -INF
		for corner in corners:
			var angle: float = angle_difference(center_angle, (corner - origin).angle())
			low = minf(low, angle)
			high = maxf(high, angle)
		visibility.call("update_visibility", origin, 560.0, corners, 1000.0)
		var arrays: Array = visibility.get("fog_mesh").surface_get_arrays(0)
		var vertices: Variant = arrays[Mesh.ARRAY_VERTEX]
		var count: int = (vertices.size() - 1) / 3
		var transitions: int = 0
		var frame_error: float = 0.0
		for index in range(count):
			var next: int = (index + 1) % count
			var a: Vector2 = Vector2(vertices[index * 3 + 1].x, vertices[index * 3 + 1].y)
			var b: Vector2 = Vector2(vertices[next * 3 + 1].x, vertices[next * 3 + 1].y)
			if (a.length() < 559.0) == (b.length() < 559.0): continue
			transitions += 1
			var direction: Vector2 = a if a.length() < 559.0 else b
			var angle: float = angle_difference(center_angle, direction.angle())
			var error: float = minf(absf(angle - low), absf(angle - high)) * 1000.0
			frame_error = maxf(frame_error, error)
		worst_error = maxf(worst_error, frame_error)
		worst_jump = maxf(worst_jump, absf(frame_error - previous_error))
		previous_error = frame_error
		valid = valid and transitions == 2
	valid = valid and worst_error < 0.2 and worst_jump < 0.2
	print("RESULT polygon shadow moving silhouette: ", "PASS" if valid else "FAIL", " maximum edge error=", worst_error, " px; maximum error jump=", worst_jump, " px")
	quit(0 if valid else 1)
