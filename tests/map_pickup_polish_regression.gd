extends SceneTree
var failures: int = 0
func expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("check")
func settle() -> void:
	for frame in range(4):
		await process_frame
		await RenderingServer.frame_post_draw
func check() -> void:
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(8): await process_frame
	var game: Node = current_scene
	var player: Node2D = game.get_node("Player")
	player.set_physics_process(false)
	for hunter in game.get("monsters"):
		hunter.set_physics_process(false)
		hunter.set("active", false)
	var maze: Node2D = game.get_node("Maze")
	var fixtures: Array[Node] = maze.get_node("Overhead/Fixtures").get_children()
	expect(fixtures.size() == 5, "Exactly five visible authored fixtures")
	var kinds: Dictionary = {"shade":0, "fluorescent":0, "bunker":0}
	for fixture in fixtures:
		kinds[fixture.fixture_kind] += 1
		var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
		query.position = fixture.global_position
		query.collision_mask = 2
		expect(player.get_world_2d().direct_space_state.intersect_point(query).is_empty(), "Lamp origins stay outside walls and cover")
		for other in fixtures:
			if fixture != other: expect(fixture.position.distance_to(other.position) > 1600.0, "Fixtures are widely separated")
	expect(kinds == {"shade":2,"fluorescent":2,"bunker":1}, "Mixed lamp split is two, two and one")
	for index in range(12):
		var name: String = "Figurine%02d" % (index + 1)
		var pickup: Node2D = maze.get_node("Pickups/" + name)
		expect(pickup.has_node("StrawDoll"), "Real straw sprite is an authored editor node")
		var trail: Node2D = maze.get_node("BloodClues/" + name)
		expect(trail.get_child_count() >= 7, "Nearby blood trail contains readable successive footprints")
		var previous: Vector2 = trail.get_child(0).global_position
		for step in trail.get_children():
			expect(maze.call("clear_line", previous, step.global_position), "Blood trail follows open passages")
			var direction: Vector2 = Vector2.UP.rotated(step.rotation)
			expect(direction.dot(step.global_position.direction_to(pickup.global_position)) > -0.1, "Footprint toes lead toward the collectible")
			previous = step.global_position
		var last: Vector2 = trail.get_child(-1).global_position
		expect(last.distance_to(pickup.global_position) < 105, "Trail ends next to the actual collectible")
	var doll: Node2D = maze.get_node("Pickups/Figurine01")
	game.call("collect_pickup", doll)
	expect(not maze.get_node("BloodClues/Figurine01").visible, "Collected figurine clears its directional clue")
	game.get_node("HUD").hide()
	game.get_node("Haze").hide()
	player.global_position = maze.to_global(Vector2(0, 100))
	player.reset_physics_interpolation()
	var camera: Camera2D = player.get_node("Camera")
	camera.position_smoothing_enabled = false
	camera.force_update_scroll()
	await settle()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var materials: Array[ShaderMaterial] = [game.get_node("Visibility").fog_material, game.get_node("Visibility").floor_material]
	for fixture in fixtures: materials.append(fixture.get_node("Housing/Glow").material)
	for surface in materials: surface.set_shader_parameter("optimize_fixture_samples", false)
	await settle()
	var reference: PackedByteArray = root.get_texture().get_image().get_data()
	for surface in materials: surface.set_shader_parameter("optimize_fixture_samples", true)
	await settle()
	var optimized: PackedByteArray = root.get_texture().get_image().get_data()
	expect(reference == optimized, "Optimized shadow shader is pixel-identical to full sampling")
	print("RESULT five fixtures, straw pickups, directional clues and pixel-identical optimization: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
