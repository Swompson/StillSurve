extends SceneTree

var failures: int = 0

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	set_meta("hard_mode", true)
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(8):
		await physics_frame
		await process_frame
	var game: Node = current_scene
	var maze: Node2D = game.get_node("Maze")
	var stalker: Node2D = game.get_node("Stalker")
	var player: Node2D = game.get_node("Player")
	for hunter in game.get("monsters"): hunter.set_physics_process(false)
	player.set_physics_process(false)
	player.flashlight_on = false
	var strategies: Dictionary = {}
	for index in range(100):
		stalker.choose_strategy()
		strategies[stalker.strategy] = true
	expect(strategies.has("sneak") and strategies.has("ambush"), "Both strategies are selected randomly")
	var ambushes: int = 0
	for cell in [60, 49, 71, 48, 72, 38, 82]:
		player.global_position = maze.cell_position(cell)
		stalker.global_position = maze.cell_position(0)
		stalker.strategy = "ambush"
		stalker.plan_ambush()
		if stalker.strategy != "ambush": continue
		ambushes += 1
		expect(is_instance_valid(stalker.ambush_objective) and not stalker.ambush_objective.collected, "Ambush predicts an uncollected objective")
		expect(not maze.clear_line(player.global_position, stalker.ambush_target), "Ambush waits behind cover")
		expect(stalker.navigation.lamp_exposure(stalker.ambush_target) <= 0.08, "Ambush waits in shadow")
		expect(not stalker.navigation.route(stalker.global_position, stalker.ambush_target).is_empty(), "Ambush is reachable without crossing walls")
	expect(ambushes > 0, "Actual maze offers usable objective ambushes")
	stalker.state = "leap"
	stalker.begin_flee(3.0)
	expect(stalker.attack_cooldown == 15.0 and stalker.strategy_pending, "Aborted attack starts a full fifteen-second cooldown")
	stalker._physics_process(14.9)
	expect(stalker.attack_cooldown > 0.0 and stalker.strategy_pending, "Strategy is not rerolled before cooldown ends")
	stalker._physics_process(0.11)
	expect(stalker.attack_cooldown == 0.0 and not stalker.strategy_pending, "Cooldown completion chooses the next strategy")
	var overhead: Node2D = maze.get_node("Overhead")
	for layer in ["Pipes", "Beams", "Wires"]:
		expect(overhead.get_node(layer).material.get_shader_parameter("projection_enabled") == true, "Ceiling depth projection is enabled only for the running game")
	for fixture in overhead.get_node("Fixtures").get_children():
		if fixture.fixture_kind == "bunker":
			var wall: Node2D = maze.get_node(fixture.get_meta("mount_wall"))
			var foot: Vector2 = fixture.to_global(Vector2(0, 22))
			var closest: float = INF
			for bounds in wall.get_wall_rectangles():
				var local: Vector2 = wall.to_local(foot)
				closest = minf(closest, local.distance_to(local.clamp(bounds.position, bounds.end)))
			expect(closest < 0.1, "Bunker fixture mounting plate touches its authored wall")
		else:
			var support: Line2D = overhead.get_node(fixture.get_meta("mount_support"))
			var distance: float = INF
			var anchor: Vector2 = fixture.global_position
			for index in range(support.points.size() - 1):
				var point: Vector2 = Geometry2D.get_closest_point_to_segment(anchor, support.to_global(support.points[index]), support.to_global(support.points[index + 1]))
				distance = minf(distance, point.distance_to(anchor))
			expect(distance < 0.1 and fixture.z_index < support.z_index and not fixture.has_node("MountClamp") and not fixture.has_node("Suspension"), "Ceiling fixture is directly below an existing support with no holders")
			var camera: Camera2D = player.get_node("Camera")
			camera.position_smoothing_enabled = false
			camera.force_update_scroll()
			fixture._process(0.01)
			var offset: Vector2 = ((fixture.global_position - camera.get_screen_center_position()) * fixture.mount_elevation).clamp(Vector2(-20, -20), Vector2(20, 20))
			var swing_margin: float = 9.0 if fixture.fixture_kind == "shade" else 0.1
			expect(fixture.get_node("Housing").global_position.distance_to(fixture.global_position + offset) < swing_margin, "Housing stays below its support with matching projection and visible shade sway")
	print("RESULT mounted fixtures, random strategies, shaded objective ambushes and cooldown: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
