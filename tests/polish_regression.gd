extends SceneTree

var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run_checks")

func check_bones(rig: Node2D, monstrous: bool) -> void:
	var worst_length_error: float = 0.0
	var worst_elbow_jump: float = 0.0
	var free_arm_projection_valid: bool = true
	for direction_index in range(8):
		rig.set("travel_direction", Vector2.from_angle(direction_index * TAU / 8.0))
		var previous: Dictionary = {}
		for sample in range(240):
			rig.set("phase", float(sample) * TAU / 240.0)
			rig.set("movement", 1.0)
			rig.set("running", 1.0)
			rig.get("actor").set("flashlight_reveal", 0.5 - cos(float(sample) * TAU / 240.0) * 0.5)
			rig.call("pose")
			var joints: Dictionary = rig.get("joints")
			for side in ["left", "right"]:
				var shoulder: Vector2 = joints[side + "_shoulder"]
				var elbow: Vector2 = joints[side + "_elbow"]
				var hand: Vector2 = joints[side + "_hand"]
				var upper_length: float = shoulder.distance_to(elbow)
				var lower_length: float = elbow.distance_to(hand)
				if monstrous or (side == "left" and is_equal_approx(float(rig.get("actor").get("flashlight_reveal")), 1.0)):
					worst_length_error = maxf(worst_length_error, absf(upper_length - 18.0))
					worst_length_error = maxf(worst_length_error, absf(lower_length - (24.0 if monstrous else 21.0)))
				else:
					free_arm_projection_valid = free_arm_projection_valid and upper_length > 0.1 and upper_length <= 18.001 and lower_length > 0.1 and lower_length <= 21.001
				if not monstrous:
					expect(elbow.x < shoulder.x if side == "left" else elbow.x > shoulder.x, "Player elbows must face outwards")
				if previous.has(side):
					worst_elbow_jump = maxf(worst_elbow_jump, elbow.distance_to(previous[side]))
				previous[side] = elbow
	expect(worst_length_error < 0.001, "Monster arms and the player's flashlight arm must keep their limb segment lengths constant")
	expect(free_arm_projection_valid, "The player's free arm must keep a nonzero overhead projection within its physical segment lengths")
	expect(worst_elbow_jump < 4.0, "Elbows must not flip sides during gait or flashlight draw")
	print("BONES %s max length error %.6f; max elbow movement %.3f" % ["monster" if monstrous else "player", worst_length_error, worst_elbow_jump])

func run_checks() -> void:
	seed(31018)
	set_meta("hard_mode", false)
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(4):
		await process_frame
		await physics_frame
	var game: Node2D = current_scene
	var player: CharacterBody2D = game.get_node("Player")
	var monster: CharacterBody2D = game.get_node("Monster")
	var maze: Node2D = game.get_node("Maze")
	player.set_physics_process(false)
	# This checks one stable investigation route. Other patrols can step on glass
	# and legitimately redirect it to a different sound before it reaches the goal.
	for hunter in game.get("monsters"):
		hunter.set_physics_process(false)
		if hunter != monster: hunter.set("active", false)
	player.get_node("Sprite").set_process(false)
	monster.get_node("Visual").set_process(false)
	check_bones(player.get_node("Sprite").get("rig"), false)
	check_bones(monster.get_node("Visual").get("rig"), true)
	player.global_position = Vector2(10000, 10000)
	var graph: AStar2D = maze.get("graph")
	var goal_cell: int = -1
	for cell in range(121):
		var route: PackedInt64Array = graph.get_id_path(60, cell)
		if route.size() >= 7 and route.size() <= 9:
			goal_cell = cell
			break
	expect(goal_cell >= 0, "Test must use a multi-corner investigation route")
	var goal: Vector2 = maze.call("cell_position", goal_cell)
	monster.global_position = maze.call("cell_position", 60)
	monster.velocity = Vector2.ZERO
	monster.set("active", true)
	monster.set("state", "hunt")
	monster.set("last_known", goal)
	monster.set("memory", 0.0)
	monster.set("sense_timer", 999.0)
	monster.set("disengage_timer", 999.0)
	monster.set("path_rebuilds", 0)
	monster.set_physics_process(true)
	# Four times faster wall-clock run, with the normal 1/60 simulation step.
	Engine.physics_ticks_per_second = 240
	Engine.time_scale = 4.0
	var visited: bool = false
	var departed: bool = false
	var minimum_distance: float = INF
	for tick in range(3000):
		await physics_frame
		minimum_distance = minf(minimum_distance, monster.global_position.distance_to(goal))
		if monster.global_position.distance_to(goal) < 40.0:
			visited = true
		if visited and monster.get("state") == "patrol" and monster.global_position.distance_to(goal) > 110.0:
			departed = true
			break
	monster.set_physics_process(false)
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	expect(visited, "After losing a chase the monster must reach the investigation area")
	expect(departed, "Monster must leave the investigation point instead of oscillating around it")
	expect(int(monster.get("path_rebuilds")) < 20, "Following a stable route must not restart its waypoint index every half second")
	print("NAV visited=%s departed=%s closest=%.2f path rebuilds=%d" % [visited, departed, minimum_distance, monster.get("path_rebuilds")])
	print("RESULT joint constraints and post-chase navigation: %d failure(s)" % failures.size())
	quit(0 if failures.is_empty() else 1)
