extends SceneTree

const CONTACT = preload("res://scripts/world/glass_contact.gd")
var failures: int = 0
var crunches: Array[Dictionary] = []

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")

func prepare_hunters(game: Node, point: Vector2) -> void:
	for index in range(2):
		var hunter: CharacterBody2D = game.monsters[index]
		hunter.active = true
		hunter.state = "patrol"
		hunter.disengage_timer = 0.0
		hunter.last_heard = Vector2.INF
		hunter.investigation_route.clear()
		hunter.sense_timer = 1000.0
		for cell in game.maze.graph.get_point_ids():
			var candidate: Vector2 = game.maze.cell_position(cell)
			if candidate.distance_to(point) > 900.0 + index * 500.0 and candidate.distance_to(point) < 1200.0 + index * 500.0:
				hunter.global_position = candidate
				break
		hunter.velocity = Vector2.ZERO

func run() -> void:
	set_meta("hard_mode", true)
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(8): await physics_frame
	var game: Node = current_scene
	root.get_node("RuntimeBudget").mark_focused()
	root.get_node("RuntimeBudget").set_process(false)
	game.player.set_physics_process(false)
	for actor in game.monsters: actor.set_physics_process(false)
	var patches: Array[Node] = get_nodes_in_group("glass_patches")
	for patch in patches:
		expect(patch.has_method("can_crunch") and patch.retrigger_delay == 1.25, "Every saved glass patch has the shared 1.25-second delay")
		patch._physics_process(patch.retrigger_delay)
	var patch: Node2D = patches[0]
	var point: Vector2 = patch.global_position
	prepare_hunters(game, point)
	game.glass_crunched.connect(func(position: Vector2, source: Node) -> void: crunches.append({"point": position, "source": source}))
	game.player.global_position = point - Vector2(40, 0)
	game.player.flashlight_on = false
	game.player.flashlight_strength = 0.0
	game.player.glass_contact = CONTACT.new()
	Input.action_press("move_right")
	for frame in range(27): game.player._physics_process(1.0 / 60.0)
	Input.action_release("move_right")
	expect(crunches.size() == 1, "Holding ordinary walk across one patch produces one crunch instead of two")
	expect(crunches[0].source == game.player, "The real player movement preserves glass noise ownership")
	var heard: Vector2 = crunches[0].point
	var behind_walls: int = 0
	for index in range(2):
		var hunter: CharacterBody2D = game.monsters[index]
		if not game.maze.clear_line(hunter.global_position, heard): behind_walls += 1
		expect(hunter.state == "investigate" and hunter.last_heard.is_equal_approx(heard), "Both hunters hear the actual contact, including through walls")
		expect(game.maze.cell_at(hunter.target) == game.maze.cell_at(heard), "Hunters investigate the source cell rather than the player's current position")
		hunter.rebuild_path(game.maze.cell_at(hunter.target))
		expect(not hunter.path.is_empty(), "Glass investigation produces a traversable route")
	expect(behind_walls > 0, "The hearing integration includes a hunter separated from the glass by walls")
	# Resetting an actor tracker or switching actors must not bypass a patch lockout.
	for actor in [game.player, game.monsters[0], game.monsters[1], game.get_node("Stalker")]:
		var contact: RefCounted = CONTACT.new()
		contact.update(actor, point - Vector2(40, 0), point + Vector2(40, 0), game, actor == game.player, 0.4)
	expect(crunches.size() == 1, "Player, both hunters and stalker share the same patch lockout")
	var flank: PackedVector2Array = game.monsters[1].investigation_route.duplicate()
	patch._physics_process(1.24)
	game.player.glass_contact.update(game.player, point - Vector2(40, 0), point + Vector2(40, 0), game, true, 0.4)
	expect(crunches.size() == 1 and game.monsters[1].investigation_route == flank, "A suppressed repeat cannot replay audio or reset the hunters' flank")
	patch._physics_process(0.02)
	game.player.glass_contact.update(game.player, point, point, game, true, 0.1)
	expect(crunches.size() == 1, "Timer expiry never makes stationary glass crunch by itself")
	game.player.glass_contact.update(game.player, point, point + Vector2(4, 0), game, true, 0.1)
	expect(crunches.size() == 2, "Moving again can retrigger after the delay")
	# Different patches stay independent even while the first is cooling down.
	var other: Vector2 = patches[1].global_position
	var independent: RefCounted = CONTACT.new()
	independent.update(game.player, other - Vector2(4, 0), other, game, true, 0.02)
	expect(crunches.size() == 3 and crunches.back().point.distance_to(other) < 10.0, "Cooling one patch never silences a different patch")
	patch._physics_process(1.26)
	prepare_hunters(game, point)
	var source: CharacterBody2D = game.monsters[0]
	source.global_position = point + Vector2(4, 0)
	source.glass_contact = CONTACT.new()
	source.update_glass_steps(4.0, point, 0.02)
	expect(crunches.size() == 4 and crunches.back().source == source, "A real hunter's glass-step code uses the same patch delay")
	expect(source.state == "patrol" and source.last_heard == Vector2.INF, "A hunter does not investigate its own glass crunch")
	expect(game.monsters[1].state == "investigate" and game.monsters[1].last_heard.is_equal_approx(crunches.back().point), "The other hunter investigates a monster's glass crunch")
	for frame in range(10): source.update_glass_steps(80.0, point - Vector2(76, 0), 0.4)
	expect(crunches.size() == 4, "Repeated monster strides cannot bypass the same patch cooldown")
	# Let both hunters physically begin following a newly heard source.
	patch._physics_process(1.26)
	prepare_hunters(game, point)
	game.player.global_position = Vector2(20000, 20000)
	independent = CONTACT.new()
	independent.update(game.player, point - Vector2(4, 0), point, game, true, 0.02)
	for index in range(2):
		var hunter: CharacterBody2D = game.monsters[index]
		var start: Vector2 = hunter.global_position
		hunter.rebuild_path(game.maze.cell_at(hunter.target))
		var waypoint: Vector2 = hunter.navigation_destination()
		var before: float = start.distance_to(waypoint)
		for frame in range(30): hunter._physics_process(1.0 / 60.0)
		var after: float = hunter.global_position.distance_to(waypoint)
		expect(hunter.global_position.distance_to(start) > 10.0 and after < before, "Hunters physically move along the route toward the glass")
	var overlap: Node2D = patch.duplicate()
	patch.get_parent().add_child(overlap)
	patch._physics_process(1.26)
	overlap._physics_process(1.26)
	var previous_count: int = crunches.size()
	independent = CONTACT.new()
	independent.update(game.player, point - Vector2(4, 0), point, game, true, 0.02)
	expect(crunches.size() == previous_count + 1 and not patch.can_crunch() and not overlap.can_crunch(), "One footfall locks every overlapping real footprint")
	independent = CONTACT.new()
	independent.update(source, point, point + Vector2(4, 0), game, false, 0.4)
	expect(crunches.size() == previous_count + 1, "A different actor cannot retrigger through the overlapping footprint")
	overlap.free()
	patch.start_cooldown()
	var remaining: float = patch.cooldown_remaining
	paused = true
	for frame in range(3): await physics_frame
	expect(is_equal_approx(patch.cooldown_remaining, remaining), "Pause freezes the shared patch delay")
	paused = false
	print("RESULT per-patch delay, actual walking, all actors, independent patches, pause and hunter hearing/navigation: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
