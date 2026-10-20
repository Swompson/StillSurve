extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	set_meta("hard_mode", true)
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(8):
		await physics_frame
		await process_frame
	var game: Node = current_scene
	var hero: CharacterBody2D = game.player
	var stalker: CharacterBody2D = game.get_node("Stalker")
	var maze: Node2D = game.get_node("Maze")
	hero.set_physics_process(false)
	hero.flashlight_on = false
	hero.flashlight_strength = 0.0
	for hunter in game.monsters: hunter.set_physics_process(false)
	var found: bool = false
	for cell in [60, 49, 71, 48, 72, 38, 82]:
		hero.global_position = maze.cell_position(cell)
		stalker.global_position = maze.cell_position(0)
		stalker.strategy = "ambush"
		stalker.plan_ambush()
		if not stalker.ambush_planned: continue
		found = true
		assert(stalker.ambush_target.distance_to(stalker.ambush_objective.global_position) >= 220.0)
		assert(not maze.clear_line(stalker.ambush_entry, stalker.ambush_target))
		assert(maze.can_walk_line(stalker.ambush_target, stalker.ambush_trigger))
		assert(stalker.ambush_target.distance_to(stalker.ambush_trigger) <= 150.0)
		stalker.global_position = stalker.ambush_target
		stalker.state = "stalk"
		stalker.attack_cooldown = 0.0
		stalker.strategy_pending = false
		hero.global_position = stalker.ambush_entry
		hero.facing_angle = hero.global_position.angle_to_point(stalker.ambush_trigger)
		var target: Vector2 = stalker.ambush_target
		stalker.plan_timer = -10.0
		assert(stalker.choose_approach_target() == target and stalker.ambush_ready)
		stalker.sense_timer = 0.0
		stalker._physics_process(1.0 / 60.0)
		assert(stalker.state == "stalk", "Hunter waits while the player is still behind the corner")
		hero.global_position = stalker.ambush_trigger
		stalker._physics_process(1.0 / 60.0)
		assert(stalker.state == "leap", "Emerging around the corner triggers the short side attack")
		stalker.state = "stalk"
		stalker.global_position = target
		hero.facing_angle = hero.global_position.angle_to_point(target)
		hero.flashlight_on = true
		hero.flashlight_strength = 1.0
		hero.flashlight_reveal = 1.0
		stalker.sense_timer = 0.0
		stalker._physics_process(1.0 / 60.0)
		# Flashlight fear needs the authored 0.24-second exposure, unlike a lamp.
		for tick in range(16):
			if stalker.state == "flee": break
			await physics_frame
			stalker._physics_process(1.0 / 60.0)
		assert(stalker.state == "flee", "A flashlight aimed into the ambush corner repels the hunter")
		break
	assert(found, "Maze contains a viable concealed corner on an objective route")
	print("RESULT corner concealment, distance from pickup, stable waiting, emergence trigger and flashlight counterplay: passed")
	quit()
