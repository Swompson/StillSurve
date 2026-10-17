extends SceneTree

var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(5): await process_frame
	var game: Node = current_scene
	var player: CharacterBody2D = game.get_node("Player")
	var monster: CharacterBody2D = game.get_node("Monster")
	var hud: CanvasLayer = game.get_node("HUD")
	var visibility: Node2D = game.get_node("Visibility")
	player.set_physics_process(false)
	monster.set_physics_process(false)
	visibility.set_process(false)
	visibility.set_physics_process(false)
	expect(player.get_node("AudioListener").is_current(), "Player must be the spatial audio listener")
	expect(monster.get_node("Growl").panning_strength == 2.5, "Monster sound must use stronger stereo separation")
	expect(hud.find_children("Quit*", "Button", true, false).size() == 2, "Pause and result menus need exit buttons")
	expect(hud.get_node("Layout").theme.default_font.resource_path.ends_with("Sjz.otf"), "Native HUD must use the user's font")
	expect(player.get("battery_max") == 70.0 and player.get("battery") <= 70.0, "Capacity must be reduced to seventy")
	hud.call("notify_pickup", "+20 заряда", 2.0)
	hud.call("_process", 0.1)
	var notice: Label = hud.get("pickup_notice")
	var center: Vector2 = player.get_global_transform_with_canvas().origin
	expect(absf(notice.position.x + notice.size.x * 0.5 - center.x) < 1.0 and notice.position.y > center.y, "Pickup notice must center below the player")
	var origin: Vector2 = Vector2(12000, 12000)
	var walls: Array[Node] = []
	for horizontal in [true, false]:
		var wall: Node2D = load("res://scenes/world/wall.tscn").instantiate()
		wall.set("wall_size", Vector2(240, 24) if horizontal else Vector2(24, 240))
		wall.position = origin + (Vector2(108, 0) if horizontal else Vector2(0, 108))
		game.add_child(wall)
		walls.append(wall)
	await physics_frame
	await physics_frame
	var observer: Vector2 = origin + Vector2(36, 36)
	var lens: CircleShape2D = CircleShape2D.new()
	lens.radius = 3.5
	var previous: Vector2
	var max_step: float = 0.0
	for step in range(721):
		var desired: Vector2 = observer + Vector2.from_angle(float(step) * TAU / 720.0) * 68.0
		var resolved: Vector2 = player.call("resolve_view_origin", observer, desired)
		var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
		query.shape = lens
		query.transform = Transform2D(0.0, resolved)
		query.collision_mask = 2
		query.margin = 0.0
		expect(player.get_world_2d().direct_space_state.intersect_shape(query).is_empty(), "Lens volume must stay outside both inner-corner walls")
		if step > 0: max_step = maxf(max_step, resolved.distance_to(previous))
		previous = resolved
	expect(max_step < 2.0, "Sweeping past the inner corner must keep the origin continuous")
	var before: PackedVector2Array = visibility.call("get_blocker_corners")
	expect(before.has(origin + Vector2(12, 12)), "Overlapping walls must contribute their inner-junction vertex to shadow rays")
	walls[0].position += Vector2(10, 0)
	walls[0].force_update_transform()
	var after: PackedVector2Array = visibility.call("get_blocker_corners")
	expect(before != after, "Geometry cache must invalidate after a wall moves")
	# Two colliders on one plane must not split a lit strip at their seam.
	var contacts: Array[Dictionary] = [{"point": Vector2(0, 0), "normal": Vector2.UP, "body": 1, "shape": 0}, {"point": Vector2(20, 0), "normal": Vector2.UP, "body": 2, "shape": 0}]
	visibility.call("build_wall_contacts", contacts)
	expect(visibility.get("contact_mesh").get_surface_count() == 1, "Coplanar wall sections must form continuous light")
	# Use an actual blocked pair inside the maze for acoustic investigation.
	var maze: Node2D = game.get_node("Maze")
	var heard: bool = false
	for wall in maze.get_node("Walls").get_children():
		if wall.get("damaged"): continue
		var offset: Vector2 = Vector2(0, 70) if wall.get("wall_size").x > wall.get("wall_size").y else Vector2(70, 0)
		var source: Vector2 = wall.global_position + offset
		monster.global_position = wall.global_position - offset
		if maze.call("clear_line", monster.global_position, source): continue
		player.global_position = source
		monster.set("active", true)
		monster.set("state", "hunt")
		monster.set("disengage_timer", 0.0)
		monster.call("hear_noise", source, 1000.0)
		expect(monster.get("state") == "investigate", "Hearing through a wall must investigate rather than chase")
		expect(monster.get("last_heard") == source, "Hearing must record the exact sound position")
		var target: Vector2 = monster.get("target")
		player.global_position += Vector2(80, 0)
		monster.call("perceive")
		expect(monster.get("target") == target, "Investigation target must not follow an unseen player")
		heard = true
		break
	expect(heard, "Test must exercise hearing behind a wall")
	print("CORNER sweep max step %.3f" % max_step)
	print("RESULT HUD, inner corner, cache invalidation, directional sound and hearing: %d failure(s)" % failures.size())
	quit(0 if failures.is_empty() else 1)
