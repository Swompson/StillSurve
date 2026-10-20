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
	var space: PhysicsDirectSpaceState2D = pile.get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.new()
	query.collision_mask = 2
	var valid: bool = true
	var checked: int = 0
	var worst_front: float = 0.0
	for sample in range(41):
		var origin: Vector2 = pile.global_position + Vector2(-180, sample * 0.5 - 10.0)
		visibility.call("update_visibility", origin, 560.0, pile.call("get_vision_corners"), 1000.0)
		var arrays: Array = visibility.get("fog_mesh").surface_get_arrays(0)
		var vertices: Variant = arrays[Mesh.ARRAY_VERTEX]
		for index in range((vertices.size() - 1) / 3):
			var start: Vector2 = Vector2(vertices[index * 3].x, vertices[index * 3].y)
			query.from = origin
			query.to = origin + start.normalized() * 560.0
			var hit: Dictionary = space.intersect_ray(query)
			if hit.is_empty() or hit.collider != pile: continue
			checked += 1
			var front: float = origin.distance_to(hit.position) - start.length()
			worst_front = maxf(worst_front, front)
			valid = valid and front < 0.02
	# Verify that the lamp's three-pixel fade also begins on the true outline.
	var overhead: Node = game.get_node("Maze/Overhead")
	var lamp_origin: Vector2 = pile.global_position - Vector2(180, 0)
	var origins: PackedVector2Array = PackedVector2Array()
	for index in range(6): origins.append(lamp_origin)
	overhead.call("build_fixture_shadows", origins)
	var map: Image = overhead.get("shadow_texture").get_image()
	for index in range(1024):
		query.from = lamp_origin
		query.to = lamp_origin + Vector2.from_angle(TAU * (index + 0.5) / 1024.0) * 245.0
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty() or hit.collider != pile: continue
		var fade_start: float = map.get_pixel(index, 0).r * 245.0 - 3.0
		valid = valid and fade_start >= lamp_origin.distance_to(hit.position) - 0.02
	valid = valid and checked > 100
	print("RESULT moving stone shadow contact: ", "PASS" if valid else "FAIL", " rays=", checked, " maximum front overlap=", worst_front)
	quit(0 if valid else 1)
