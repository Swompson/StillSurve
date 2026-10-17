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
	for frame in range(4):
		await process_frame
		await physics_frame
	var game: Node2D = current_scene
	var player: CharacterBody2D = game.get_node("Player")
	var monster: CharacterBody2D = game.get_node("Monster")
	var maze: Node2D = game.get_node("Maze")
	player.set_physics_process(false)
	monster.set_physics_process(false)
	player.get_node("Sprite").set_process(false)
	monster.get_node("Visual").set_process(false)
	var player_rig: Node2D = player.get_node("Sprite").get("rig")
	var monster_rig: Node2D = monster.get_node("Visual").get("rig")
	var parts: Dictionary = monster_rig.get("parts")
	var torso_before: Transform2D = parts.torso.transform
	var head_before: Transform2D = parts.head.transform
	monster.set("active", true)
	monster.set("sprinting", false)
	monster.velocity = Vector2(0, 180)
	player.velocity = Vector2(0, 180)
	player.set("sprinting", false)
	var foot_start: Vector2 = monster_rig.get("joints").left_foot
	var hand_start: Vector2 = monster_rig.get("joints").right_hand
	var previous_foot: Vector2 = foot_start
	var foot_travel: float = 0.0
	var hand_travel: float = 0.0
	for frame in range(120):
		monster_rig.call("advance", 1.0 / 120.0)
		var foot: Vector2 = monster_rig.get("joints").left_foot
		foot_travel = maxf(foot_travel, foot.distance_to(foot_start))
		hand_travel = maxf(hand_travel, Vector2(monster_rig.get("joints").right_hand).distance_to(hand_start))
		expect(foot.distance_to(previous_foot) < 5.0, "Feet must move continuously between 120 Hz samples")
		expect(parts.torso.transform == torso_before and parts.head.transform == head_before, "Torso and skull must remain rigid throughout gait")
		previous_foot = foot
	expect(foot_travel > 8.0 and hand_travel > 18.0, "Monster must visibly articulate both feet and hands")
	expect(is_equal_approx(float(player.call("get_beam_distance")), 700.0), "Beam range must be fixed at 700 world units")
	expect(float(monster.get("sight_radius")) >= float(player.call("get_beam_distance")) and float(monster.get("sight_radius")) < 900.0, "Reduced monster vision must remain at least player range")
	expect(get_nodes_in_group("door_jambs").size() == 28, "Fourteen door openings must each have two jambs")
	# Corner cover shares the rubble group, but is additional to the sixteen piles.
	var rubble_piles: Array[Node] = get_nodes_in_group("rubble").filter(func(pile: Node) -> bool: return String(pile.name).begins_with("Rubble"))
	expect(rubble_piles.size() == 16, "Sixteen corridor rubble piles must exist")
	for debris in get_nodes_in_group("rubble"):
		var from: Vector2 = debris.global_position - Vector2(0, 70)
		var to: Vector2 = debris.global_position + Vector2(0, 70)
		expect(not bool(maze.call("clear_line", from, to)), "Rubble must block vision and light")
		var body_transform: Transform2D = player.global_transform
		body_transform.origin = from
		expect(player.test_move(body_transform, to - from), "Rubble must also block movement")
	var camera: Camera2D = player.get_node("Camera")
	var beam_before: float = float(player.call("get_beam_distance"))
	camera.zoom = Vector2(0.3, 0.3)
	expect(is_equal_approx(float(player.call("get_beam_distance")), beam_before), "Zoom must not stretch beam range")
	game.get_node("Visibility").hide()
	game.get_node("Haze").hide()
	game.get_node("HUD").hide()
	var center: Vector2 = maze.call("cell_position", 60)
	player.global_position = center + Vector2(-65, 0)
	monster.global_position = center + Vector2(65, 0)
	player.reset_physics_interpolation()
	monster.reset_physics_interpolation()
	player.get_node("Sprite").rotation = 0.0
	monster.get_node("Visual").rotation = 0.0
	player.set("facing_angle", PI * 0.5)
	monster.set("facing_angle", PI * 0.5)
	player.set("flashlight_reveal", 1.0)
	player.set("flashlight_strength", 1.0)
	player.call("update_flashlight")
	camera.position_smoothing_enabled = false
	camera.zoom = Vector2(2.5, 2.5)
	camera.global_position = center
	camera.force_update_scroll()
	camera.reset_physics_interpolation()
	for frame in range(6):
		await process_frame
		await physics_frame
	for rig in [player_rig, monster_rig]:
		rig.set("phase", 0.0)
		rig.set("movement", 1.0)
		rig.set("travel_direction", Vector2.DOWN)
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute("res://.godot/rig_frames")
		for frame in range(48):
			player_rig.call("advance", 1.0 / 60.0)
			monster_rig.call("advance", 1.0 / 60.0)
			player.call("update_flashlight")
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/rig_frames/%03d.png" % frame)
	game.get_node("Visibility").show()
	game.get_node("Haze").show()
	game.get_node("HUD").show()
	for cell in range(maze.get("width") * maze.get("height") - 2):
		if cell % 11 > 8:
			continue
		var graph: AStar2D = maze.get("graph")
		if graph.are_points_connected(cell, cell + 1) and graph.are_points_connected(cell + 1, cell + 2):
			player.global_position = maze.call("cell_position", cell)
			player.set("facing_angle", 0.0)
			player.get_node("Sprite").rotation = -PI * 0.5
			player.reset_physics_interpolation()
			player.velocity = Vector2.ZERO
			player.set("flashlight_on", true)
			player.call("update_flashlight")
			camera.zoom = Vector2(0.7, 0.7)
			camera.position = Vector2.ZERO
			camera.reset_physics_interpolation()
			camera.force_update_scroll()
			for frame in range(5):
				await process_frame
				await physics_frame
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.godot/rig_beam.png")
			break
	print("RESULT articulated gait, rigid torso/head, balanced range, doors and rubble: %d failure(s)" % failures.size())
	quit(0 if failures.is_empty() else 1)
