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
	await process_frame
	await physics_frame
	await physics_frame
	var game: Node2D = current_scene
	var maze: Node2D = game.get_node("Maze")
	var player: CharacterBody2D = game.get_node("Player")
	var monster: CharacterBody2D = game.get_node("Monster")
	var hud: CanvasLayer = game.get_node("HUD")
	player.set_physics_process(false)
	monster.set_physics_process(false)
	monster.set("active", false)
	var escape_event: InputEventKey = InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_event.pressed = true
	hud.call("_input", escape_event)
	expect(paused and bool(hud.get("pause_overlay").visible), "Esc must open pause menu and pause the scene tree")
	var paused_time: float = float(game.get("survived_seconds"))
	var paused_battery: float = float(player.get("battery"))
	player.set_physics_process(true)
	await process_frame
	await process_frame
	expect(is_equal_approx(float(game.get("survived_seconds")), paused_time), "Survival timer must freeze during pause")
	expect(is_equal_approx(float(player.get("battery")), paused_battery), "Battery must not drain during pause")
	player.set_physics_process(false)
	hud.call("_input", escape_event)
	expect(not paused and not bool(hud.get("pause_overlay").visible), "Esc must resume gameplay")
	expect(is_equal_approx(80.0 / float(monster.get("stamina_regen")), 4.95), "Monster recovery speed must decrease by twenty percent")
	var key_event: InputEventKey = InputEventKey.new()
	key_event.physical_keycode = KEY_D
	key_event.keycode = KEY_D
	key_event.device = 0
	key_event.pressed = true
	Input.parse_input_event(key_event)
	Input.flush_buffered_events()
	expect(Input.is_action_pressed("move_right"), "Physical D key binding does not work")
	key_event = InputEventKey.new()
	key_event.physical_keycode = KEY_D
	key_event.keycode = KEY_D
	key_event.pressed = false
	Input.parse_input_event(key_event)
	Input.flush_buffered_events()
	var graph: AStar2D = maze.get("graph")
	var damaged_walls: int = 0
	for wall in maze.get_node("Walls").get_children():
		if not bool(wall.get("damaged")):
			continue
		damaged_walls += 1
		var wall_size: Vector2 = wall.get("wall_size")
		var normal: Vector2 = Vector2.DOWN if wall_size.x > wall_size.y else Vector2.RIGHT
		var from: Vector2 = wall.global_position - normal * 100.0
		var to: Vector2 = wall.global_position + normal * 100.0
		expect(bool(maze.call("clear_line", from, to)), "Damaged wall slit must allow line of sight")
		expect(not bool(maze.call("can_walk_line", from, to)), "Path shortcut must not pass through slit")
		var player_transform: Transform2D = player.global_transform
		player_transform.origin = from
		expect(player.test_move(player_transform, normal * 200.0), "Player collision must prevent passing through slit")
		var monster_transform: Transform2D = monster.global_transform
		monster_transform.origin = from
		expect(monster.test_move(monster_transform, normal * 200.0), "Monster collision must prevent passing through slit")
	expect(damaged_walls == 10, "Maze must contain ten damaged walls")
	print("PASS pause/resume, frozen timer, 4.95-second monster recovery and see-through impassable slits")
	expect(graph.get_point_count() == 121, "Maze must have 121 cells")
	for cell in range(121):
		expect(graph.get_id_path(60, cell).size() > 0, "Unreachable cell %d" % cell)
		for neighbor in graph.get_point_connections(cell):
			expect(bool(maze.call("clear_line", maze.call("cell_position", cell), maze.call("cell_position", neighbor))), "Graph passage blocked by wall")
	expect(player.global_position.length() > 1300.0, "Spawn is too close to central monster")
	expect(monster.global_position.x < 0.0 and game.get_node("SecondMonster").global_position.x > 0.0, "Hunters must spawn on opposite halves")
	var items: Array[Node] = maze.get_node("Pickups").get_children()
	var dolls: Array[Node] = []
	var batteries: Array[Node] = []
	for item in items:
		if item.get("kind") == "figurine": dolls.append(item)
		else: batteries.append(item)
	expect(dolls.size() == 12 and batteries.size() == (4 if game.get("hard_mode") else 5), "Pickup counts incorrect")
	var sprite: AnimatedSprite2D = player.get_node("Sprite")
	var room_bus: int = AudioServer.get_bus_index("StepsRoom")
	expect(room_bus >= 0, "Room footsteps bus missing")
	if room_bus >= 0:
		expect(AudioServer.get_bus_effect(room_bus, 0) is AudioEffectLowPassFilter, "Footstep highs are not filtered")
		expect(AudioServer.get_bus_effect(room_bus, 1) is AudioEffectReverb, "Room echo missing")
	var ambience: AudioStreamPlayer = game.get_node("Ambience")
	expect(ambience.playing, "Ambient loop did not start")
	expect(ambience.stream is AudioStreamWAV and ambience.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Ambient must loop")
	expect(ambience.stream.get_length() >= 30.0, "Ambient loop is too short")
	expect(sprite.sprite_frames.has_animation("run") and sprite.sprite_frames.has_animation("walk"), "Walk and run states remain available to the continuous rig")
	var authored_torso: Sprite2D = sprite.get_node("ArticulatedBody/Torso")
	expect(authored_torso.texture.atlas.resource_path.ends_with("player/rig_v3/overhead_parts.png"), "Editor and gameplay share the newly generated 2D survivor")
	var visibility: Node2D = game.get_node("Visibility")
	var benchmark_start: int = Time.get_ticks_usec()
	for sample in range(90):
		player.set("facing_angle", float(sample) * TAU / 90.0)
		visibility.call("refresh_visibility", false)
	print("BENCH visibility 52-wall maze: %.3f ms/update" % (float(Time.get_ticks_usec() - benchmark_start) / 90000.0))
	print("PASS maze: 121 reachable cells, clear passages, 12 dolls, mode-dependent 4/5 batteries; saved player animations")

	player.set("stamina", 100.0)
	player.call("update_resources", 4.1, true)
	expect(float(player.get("stamina")) == 0.0 and bool(player.get("exhausted")), "Sprint must exhaust stamina")
	player.call("update_resources", 0.5, false)
	expect(float(player.get("stamina")) == 0.0, "Stamina regeneration delay missing")
	player.call("update_resources", 2.0, false)
	expect(float(player.get("stamina")) >= 28 and not bool(player.get("exhausted")), "Exhaustion recovery failed")
	player.set("battery", 70.0)
	player.set("flashlight_on", true)
	player.call("update_resources", 10.0, false)
	expect(is_equal_approx(float(player.get("battery")), 65.0), "Flashlight must drain 0.5 charge per second")
	player.set("battery", 0.01)
	player.set("flashlight_on", true)
	player.call("update_resources", 1.0, false)
	expect(not bool(player.get("flashlight_on")), "Empty battery must switch flashlight off")
	expect(is_equal_approx(float(player.call("get_view_distance")), float(player.get("ambient_view_distance"))) and float(player.call("get_effective_fov")) == 360.0, "Flashlight off must retain configured ambient vision")
	visibility.call("refresh_visibility", false)
	expect(visibility.global_position.is_equal_approx(player.global_position), "Ambient-only vision must be centered on player")
	expect(float(player.call("get_mask_extent")) > 1600.0, "Darkness must cover screen even with flashlight off")
	player.call("toggle_flashlight")
	expect(not bool(player.get("flashlight_on")), "Empty flashlight switched on")
	player.set("battery", 10.0)
	game.call("collect_pickup", batteries[0])
	expect(is_equal_approx(float(player.get("battery")), 30.0), "Battery pickup must add 20 charge")
	player.call("toggle_flashlight")
	expect(bool(player.get("flashlight_on")), "Charged flashlight cannot toggle on")
	player.set("facing_angle", 0.0)
	player.call("update_flashlight")
	var torch: Node2D = player.get_node("Flashlight")
	var view_origin: Vector2 = player.call("get_view_origin")
	visibility.call("refresh_visibility", false)
	var fog_material: ShaderMaterial = visibility.get("fog_material")
	var ambient_center: Vector2 = fog_material.get_shader_parameter("ambient_center")
	expect((visibility.global_position + ambient_center).is_equal_approx(player.global_position), "Ambient center must remain on player with flashlight enabled")
	expect(torch.global_position.distance_to(view_origin) < 0.01, "Light origin must match held torch")
	expect(bool(player.call("is_point_visible", view_origin + Vector2(-50, 0))), "Ambient vision behind player must remain with flashlight on")
	expect(is_equal_approx(float(monster.get("escape_distance")), 892.5), "Escape distance must decrease by 15 percent")
	expect(is_equal_approx(float(player.get("field_of_view")), 83.16), "Flashlight cone must be narrowed by another ten percent")
	player.set("sprinting", false)
	expect(is_equal_approx(float(player.call("get_movement_speed", Vector2.LEFT)), 108.0), "Backward speed regression")
	var steps: Node = player.get_node("Footsteps")
	steps.call("add_travel", 0.0)
	var initial_steps: int = int(steps.get("steps_played"))
	steps.call("add_travel", 73.0)
	expect(int(steps.get("steps_played")) == initial_steps + 1, "Footstep on travel missing")
	steps.call("add_travel", 0.0)
	expect(int(steps.get("steps_played")) == initial_steps + 1, "Footstep emitted while stationary")
	print("PASS stamina exhaustion/recovery, charge drain/toggle/refill, torch origin and dry footsteps")

	var open_from: int = -1
	var open_to: int = -1
	var closed_from: int = -1
	var closed_to: int = -1
	for cell in range(120):
		if cell % 11 == 10: continue
		if graph.are_points_connected(cell, cell + 1):
			open_from = cell
			open_to = cell + 1
		elif not bool(maze.call("clear_line", maze.call("cell_position", cell), maze.call("cell_position", cell + 1))):
			closed_from = cell
			closed_to = cell + 1
	monster.global_position = maze.call("cell_position", closed_from)
	player.global_position = maze.call("cell_position", open_from)
	player.set("facing_angle", 0.0)
	player.set("stamina", 100.0)
	player.set("exhausted", false)
	var mouse_event: InputEventMouseMotion = InputEventMouseMotion.new()
	mouse_event.position = root.get_canvas_transform() * (player.global_position + Vector2(600, 0))
	root.push_input(mouse_event)
	Input.action_press("move_right")
	Input.action_press("sprint")
	player.call("_physics_process", 1.0 / 60.0)
	expect(bool(player.get("sprinting")) and sprite.animation == "run", "Shift movement must use running animation")
	expect(float(player.get("stamina")) < 100.0 and player.velocity.length() > 300.0, "Sprinting must use stamina and increase speed")
	Input.action_release("move_right")
	Input.action_release("sprint")
	player.set("sprinting", false)
	player.global_position = maze.call("cell_position", closed_to)
	monster.set("active", true)
	monster.set("state", "patrol")
	monster.set("facing_angle", 0.0)
	monster.call("perceive")
	expect(monster.get("state") == "patrol", "Monster saw through wall")
	monster.call("hear_noise", player.global_position, 400.0)
	expect(monster.get("state") == "patrol", "Wall did not attenuate walking noise")
	monster.call("hear_noise", player.global_position, 1050.0)
	expect(monster.get("state") == "investigate", "Monster did not hear nearby sprint through wall")
	monster.global_position = maze.call("cell_position", open_from)
	player.global_position = maze.call("cell_position", open_to)
	monster.set("state", "patrol")
	monster.set("facing_angle", 0.0)
	monster.call("perceive")
	expect(monster.get("state") == "alert", "Monster did not begin detection through open passage")
	monster.call("_physics_process", 0.5)
	expect(monster.get("state") == "hunt", "Monster did not chase after detection delay")
	monster.call("_physics_process", 0.1)
	expect(bool(monster.get("sprinting")), "Monster sprint missing")
	monster.set("stamina", 1.0)
	monster.call("_physics_process", 0.1)
	expect(bool(monster.get("recovering")), "Monster sprint must have cooldown")
	monster.call("_physics_process", 0.1)
	expect(is_equal_approx(float(monster.get("stamina")), 20.0 / 1.1 / 0.9 * 0.8 * 0.1), "Monster must regenerate at the updated recovery rate")
	monster.global_position = player.global_position + Vector2(20, 0)
	monster.call("_physics_process", 0.016)
	expect(bool(game.get("finished")) and not bool(game.get("won")), "One-hit kill did not finish game")
	expect(not bool(player.get("alive")), "Dead player still alive")
	print("PASS monster LOS/hearing attenuation, hunt/sprint/recovery and one-hit death")

	var spawn_ids: Dictionary = {}
	for attempt in range(4):
		game.get_node("HUD").call("set_paused", true)
		game.call("restart")
		await process_frame
		await process_frame
		game = current_scene
		expect(not paused, "Restart from pause menu must resume the new run")
		game.get_node("Monster").set("active", false)
		game.get_node("Player").set_physics_process(false)
		spawn_ids[int(game.get("spawn_cell"))] = true
		expect(not bool(game.get("finished")) and int(game.get("collected")) == 0, "Restart did not reset game")
	expect(spawn_ids.size() > 1, "Spawn does not randomize")
	player = game.get_node("Player")
	maze = game.get_node("Maze")
	var test_dolls: Array[Node] = []
	for item in maze.get_node("Pickups").get_children():
		if item.get("kind") == "figurine": test_dolls.append(item)
	player.set("stamina", 35.0)
	game.call("collect_pickup", test_dolls[0])
	expect(is_equal_approx(float(player.get("stamina")), 60.0), "Doll must restore 25 percent of maximum stamina")
	game.call("collect_pickup", test_dolls[0])
	expect(is_equal_approx(float(player.get("stamina")), 60.0), "Collected doll restored stamina twice")
	player.set("stamina", 95.0)
	game.call("collect_pickup", test_dolls[1])
	expect(is_equal_approx(float(player.get("stamina")), 100.0), "Doll stamina restore must cap at maximum")
	player.set("stamina", 15.0)
	player.set("exhausted", true)
	game.call("collect_pickup", test_dolls[2])
	expect(is_equal_approx(float(player.get("stamina")), 40.0) and not bool(player.get("exhausted")), "Doll must clear exhaustion when restore exceeds recovery threshold")
	print("PASS soft room audio/ambient loop and single-use 25 percent doll stamina restore")
	for item in maze.get_node("Pickups").get_children():
		if item.get("kind") == "figurine":
			game.call("collect_pickup", item)
	expect(int(game.get("collected")) == 12 and bool(game.get("won")), "Collecting 12 dolls must win")
	game.call("collect_pickup", maze.get_node("Pickups").get_child(0))
	expect(int(game.get("collected")) == 12, "Duplicate collection increased counter")
	print("PASS restart/random spawns and exactly 12 figurines for victory")

	game.call("restart")
	await process_frame
	await process_frame
	game = current_scene
	player = game.get_node("Player")
	monster = game.get_node("Monster")
	maze = game.get_node("Maze")
	player.set_physics_process(false)
	monster.set("active", false)
	var spawn: int = int(game.get("spawn_cell"))
	graph = maze.get("graph")
	var next: int = graph.get_point_connections(spawn)[0]
	var direction: Vector2 = Vector2(maze.call("cell_position", next)) - player.global_position
	player.set("facing_angle", direction.angle())
	player.get_node("Sprite").rotation = direction.angle() - PI * 0.5
	player.call("update_flashlight")
	player.get_node("Camera").reset_smoothing()
	for frame in range(10): await process_frame
	if DisplayServer.get_name() != "headless":
		# Use the current HUD after scene restarts.
		hud = game.get_node("HUD")
		var was_fullscreen: bool = bool(hud.call("is_fullscreen"))
		hud.call("set_fullscreen", not was_fullscreen)
		await process_frame
		expect(bool(hud.call("is_fullscreen")) != was_fullscreen, "Fullscreen toggle must change window mode")
		hud.call("set_fullscreen", was_fullscreen)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/gameplay_preview.png")
		hud.call("set_paused", true)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/pause_preview.png")
		hud.call("set_paused", false)
		var slit_wall: Node2D = maze.get_node("Walls/Wall002")
		player.global_position = slit_wall.global_position - Vector2(17, 110)
		player.set("facing_angle", PI * 0.5)
		player.call("update_flashlight")
		player.get_node("Camera").reset_smoothing()
		for frame in range(5): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/slit_preview.png")
		game.get_node("Visibility").hide()
		game.get_node("HUD").hide()
		var camera: Camera2D = player.get_node("Camera")
		camera.position_smoothing_enabled = false
		camera.zoom = Vector2(0.18, 0.18)
		camera.global_position = Vector2.ZERO
		for frame in range(5): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/maze_overview.png")
	print("RESULT: %d failure(s)" % failures.size())
	quit(0 if failures.is_empty() else 1)
