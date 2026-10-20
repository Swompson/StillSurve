extends SceneTree

var failures: int = 0

func expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(5): await physics_frame
	var game: Node2D = current_scene
	for hunter in game.monsters:
		hunter.set_physics_process(false)
	game.player.set_physics_process(false)
	var maze: Node2D = game.maze
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 29.0
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 2
	var space: PhysicsDirectSpaceState2D = maze.get_world_2d().direct_space_state
	var cases: int = 0
	var first_from: Vector2
	var first_to: Vector2
	var stalker_navigation: AStar2D = load("res://scripts/actors/stalker_navigation.gd").new()
	stalker_navigation.build(maze)
	for prop in maze.get_node("Warehouse/Props").get_children():
		if not String(prop.name).begins_with("ShippingCrate"): continue
		for direction_index in range(8):
			var axis: Vector2 = Vector2.RIGHT.rotated(float(direction_index) * TAU / 8.0)
			var to: Vector2 = prop.global_position + axis * 74.0
			var from: Vector2 = maze.cell_position(maze.cell_at(to))
			query.motion = Vector2.ZERO
			query.transform = Transform2D(0.0, from)
			if not space.intersect_shape(query, 1).is_empty(): continue
			query.transform = Transform2D(0.0, to)
			if not space.intersect_shape(query, 1).is_empty(): continue
			if maze.can_walk_line(from, to): continue
			var route: PackedVector2Array = maze.find_path(from, to)
			expect(not route.is_empty(), "A hunter must find the open aisle around " + prop.name)
			if route.is_empty(): continue
			var stalker_route: PackedVector2Array = stalker_navigation.route(from, to)
			expect(not stalker_route.is_empty(), "The stalker must also route around " + prop.name)
			var stalker_previous: Vector2 = from
			for point in stalker_route:
				query.transform = Transform2D(0.0, stalker_previous)
				query.motion = point - stalker_previous
				expect(space.cast_motion(query)[0] > 0.999, "The stalker must not attach its local route through a crate")
				stalker_previous = point
			query.transform = Transform2D(0.0, stalker_previous)
			query.motion = to - stalker_previous
			expect(space.cast_motion(query)[0] > 0.999, "The stalker must reach the exact hiding point")
			var previous: Vector2 = from
			for point in route:
				query.transform = Transform2D(0.0, previous)
				query.motion = point - previous
				expect(space.cast_motion(query)[0] > 0.999, "The hunter's full body must clear each crate detour segment")
				previous = point
			query.transform = Transform2D(0.0, previous)
			query.motion = to - previous
			expect(space.cast_motion(query)[0] > 0.999, "Local detours must reach the actual hiding point")
			if cases == 0:
				first_from = from
				first_to = to
			cases += 1
	expect(cases >= 2, "Exercise multiple real warehouse hiding approaches")
	if cases > 0:
		var hunter: CharacterBody2D = game.get_node("Monster")
		hunter.global_position = first_from
		game.player.global_position = first_to
		hunter.active = true
		hunter.state = "hunt"
		hunter.last_known = first_to
		hunter.memory = 1000.0
		hunter.disengage_timer = 1000.0
		hunter.target = first_to
		hunter.velocity = Vector2.ZERO
		hunter.rebuild_path(maze.cell_at(first_to))
		for tick in range(600):
			hunter._physics_process(1.0 / 60.0)
			if hunter.global_position.distance_to(first_to) < hunter.attack_radius: break
		expect(hunter.global_position.distance_to(first_to) < hunter.attack_radius, "A physical hunter must catch the player around the crate without sticking")
	print("RESULT warehouse pursuit: %d hiding approaches, swept body clearance and physical catch; %d failure(s)" % [cases, failures])
	quit(0 if failures == 0 else 1)
