extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	set_meta("hard_mode", false)
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(3): await physics_frame
	var game: Node = current_scene
	var maze: Node2D = game.get_node("Maze")
	for hunter in game.get("monsters"): hunter.set_physics_process(false)
	game.get_node("Player").set_physics_process(false)
	var overhead: Node2D = load("res://scenes/world/overhead.tscn").instantiate()
	var preferred: Array[Vector2] = [Vector2(-1015, -585), Vector2(1015, -1230), Vector2(690, 1015), Vector2(-1230, 585), Vector2(70, -90)]
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 66.0
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.collision_mask = 2
	var index: int = 0
	for fixture in overhead.get_node("Fixtures").get_children():
		var chosen: Vector2 = Vector2.INF
		for ring in range(6):
			for angle in range(16):
				var point: Vector2 = preferred[index] + Vector2.from_angle(angle * TAU / 16.0) * ring * 20.0
				query.transform = Transform2D(0.0, maze.to_global(point))
				if maze.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
					chosen = point
					break
			if chosen != Vector2.INF: break
		assert(chosen != Vector2.INF, "Fixture requires a clear corridor")
		fixture.position = chosen
		print(fixture.name, " -> ", chosen)
		index += 1
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(overhead) == OK)
	assert(ResourceSaver.save(packed, "res://scenes/world/overhead.tscn") == OK)
	overhead.free()
	quit()
