extends SceneTree

var failures: int = 0

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func load_game(hard: bool) -> Node:
	paused = false
	set_meta("hard_mode", hard)
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(5):
		await physics_frame
		await process_frame
	var game: Node = current_scene
	game.get_node("Player").set_physics_process(false)
	for hunter in game.get("monsters"): hunter.set_physics_process(false)
	return game

func run() -> void:
	var body: Node2D = load("res://scenes/actors/stalker_body.tscn").instantiate()
	expect(body.has_node("Torso") and body.has_node("Head") and body.has_node("LeftFoot") and body.has_node("RightFoot"), "Stalker is an authored textured biped in the editor")
	expect(not body.has_node("LeftThigh") and not body.has_node("RightShin"), "Overhead model has feet without exposed leg segments")
	body.free()
	var game: Node = await load_game(false)
	expect(game.get("monsters").size() == 2 and not game.get_node("Stalker").visible, "Normal mode retains two existing hunters")
	var budget: Node = root.get_node("RuntimeBudget")
	var saved_fps: int = budget.active_fps
	budget.focused = true
	for fps in [60, 144, 180, 0]:
		budget.active_fps = fps
		budget.set_paused(false)
		expect(Engine.max_fps == fps and not OS.low_processor_usage_mode, "Selected FPS applies during play")
		budget.set_paused(true)
		expect(Engine.max_fps == fps and not OS.low_processor_usage_mode, "Pause retains selected FPS without idle throttling")
		budget.focused = false
		budget.apply_budget()
		expect(Engine.max_fps == 15, "Background overrides every FPS setting with 15")
		budget.focused = true
	budget.active_fps = saved_fps
	budget.set_paused(false)
	var hud: Node = game.get_node("HUD")
	var choice: OptionButton = hud.find_child("FpsChoice", true, false)
	expect(choice != null and choice.item_count == 4 and choice.get_item_id(3) == 0, "FPS dropdown offers 60, 144, 180 and uncapped")
	expect(ProjectSettings.get_setting("display/window/size/mode") == 3, "Game starts fullscreen")
	var growl: AudioStreamPlayer2D = game.get_node("Monster/Growl")
	var player: CharacterBody2D = game.get_node("Player")
	var maze: Node2D = game.get_node("Maze")
	player.global_position = maze.cell_position(60)
	game.get_node("Monster").global_position = player.global_position + Vector2(70, 0)
	growl.cooldown = 0.0
	growl._process(1.0)
	expect(growl.playing and growl.volume_db > -2.0 and growl.attenuation == 0.0, "Close hunter is audible without double distance attenuation")
	expect(growl.bus == &"Master" and AudioServer.get_bus_effect(0, 1) is AudioEffectReverb, "Monster audio retains the shared hall acoustics")
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 20.0
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.collision_mask = 2
	for fixture in maze.get_node("Overhead/Fixtures").get_children():
		query.transform = Transform2D(0.0, fixture.global_position)
		if fixture.fixture_kind != "bunker":
			expect(maze.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty(), "Ceiling lamps retain clear floor space below their supports")
		if fixture.name != "WallLampUpperLeft":
			expect(fixture.position.distance_to(fixture.get_meta("previous_position")) < 500.0, "Lamps stay near their previous locations when attached to supports")
	game = await load_game(true)
	expect(game.get("monsters").size() == 3, "Hardcore starts with exactly three monsters")
	var stalker: CharacterBody2D = game.get_node("Stalker")
	stalker.strategy = "sneak"
	stalker.attack_cooldown = 0.0
	player = game.get_node("Player")
	maze = game.get_node("Maze")
	expect(stalker.active and stalker.visible and not stalker.has_node("Growl"), "Third monster is a silent active biped")
	expect(maze.get_node_or_null("Pickups/Battery05") == null, "Hardcore retains the four-battery rule")
	expect(stalker.navigation.get_point_count() > 650, "Stalker navigation includes lateral routes around lamp pools")
	for cell in range(121):
		expect(not stalker.navigation.route(maze.cell_position(60), maze.cell_position(cell)).is_empty(), "Light-aware routes preserve access to every maze cell")
	for id in stalker.navigation.get_point_ids():
		for neighbor in stalker.navigation.get_point_connections(id):
			expect(maze.can_walk_line(stalker.navigation.get_point_position(id), stalker.navigation.get_point_position(neighbor)), "Stalker navigation never crosses walls or rubble")
	# Find a dark, unobstructed corridor long enough for a real leap.
	var origin: Vector2 = Vector2.ZERO
	for cell in range(121):
		var candidate: Vector2 = maze.cell_position(cell)
		if stalker.navigation.lamp_exposure(candidate) > 0.01: continue
		if maze.can_walk_line(candidate - Vector2(145, 0), candidate + Vector2(85, 0)):
			origin = candidate
			break
	expect(origin != Vector2.ZERO, "Test found a dark open ambush corridor")
	player.global_position = origin
	player.flashlight_on = false
	player.flashlight_strength = 0.0
	player.facing_angle = 0.0
	var approach_start: Vector2 = Vector2.INF
	for cell in range(121):
		var candidate: Vector2 = maze.cell_position(cell)
		if candidate.distance_to(origin) < 450.0: continue
		var route: PackedVector2Array = stalker.navigation.route(candidate, origin - Vector2(115, 0))
		if route.is_empty(): continue
		var route_length: float = 0.0
		var dark_route: bool = true
		for index in range(route.size()):
			if stalker.navigation.lamp_exposure(route[index]) > 0.05: dark_route = false
			if index > 0: route_length += route[index].distance_to(route[index - 1])
		if dark_route and route_length < 1600.0:
			approach_start = candidate
			break
	expect(approach_start != Vector2.INF, "Test found a dark multi-cell stalking route")
	if approach_start != Vector2.INF:
		stalker.global_position = approach_start
		stalker.state = "stalk"
		stalker.path_timer = 0.0
		for tick in range(1800):
			stalker._physics_process(1.0 / 60.0)
			if stalker.state == "grab": break
		if stalker.state != "grab": print("STALK DIAGNOSTIC ", stalker.global_position, " player=", player.global_position, " phase=", stalker.stalking.phase, " target=", stalker.approach_target, " watched=", stalker.stalking.watched)
		expect(stalker.state == "grab", "Hunter follows corridors and reaches the player's back without teleporting")
		stalker.cancel_grab()
	var tested_short_leap: bool = false
	for cell in range(121):
		if tested_short_leap: break
		var target: Vector2 = maze.cell_position(cell)
		for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			var start: Vector2 = target + direction * 150.0
			if not maze.can_walk_line(start, target) or not stalker.dark_segment(start, target): continue
			player.global_position = target
			stalker.global_position = start
			stalker.state = "stalk"
			stalker.path_timer = 0.0
			stalker.sense_timer = 0.0
			player.facing_angle = direction.angle() + PI
			stalker._physics_process(1.0 / 60.0)
			expect(stalker.state == "leap", "Hunter initiates a short leap from the side or back")
			for tick in range(32):
				if stalker.state == "grab": break
				stalker._physics_process(1.0 / 60.0)
			expect(stalker.state == "grab", "Short leap reaches the player through a clear corridor")
			stalker.cancel_grab()
			tested_short_leap = true
			break
	expect(tested_short_leap, "Test exercised an actual short leap")
	player.global_position = origin
	player.facing_angle = 0.0
	stalker.global_position = origin + Vector2(80, 0)
	stalker.state = "stalk"
	stalker.path_timer = 0.0
	stalker._physics_process(1.0 / 60.0)
	expect(stalker.state == "stalk" and stalker.stalking.phase == "flank", "Close frontal encounter switches to a flank rather than jumping into the player's gaze")
	stalker.global_position = origin - Vector2(140, 0)
	stalker.state = "stalk"
	stalker.path_timer = 0.0
	stalker._physics_process(1.0 / 60.0)
	expect(stalker.state == "leap", "Silent hunter jumps at the player's back")
	for frame in range(24):
		if stalker.state == "grab": break
		stalker._physics_process(1.0 / 60.0)
	expect(stalker.state == "grab" and player.grabbed, "Leap attaches to the player")
	expect(stalker.grab_offset.x < 0.0, "Grab stays on the side from which the monster jumped")
	expect(is_equal_approx(player.get_movement_speed(Vector2.RIGHT), player.speed * 0.3), "Grab reduces player walking speed by 70 percent")
	player.sprinting = true
	expect(is_equal_approx(player.get_movement_speed(Vector2.RIGHT), player.speed * 0.3), "Sprinting cannot bypass the grab slowdown")
	player.sprinting = false
	player.battery = 70.0
	stalker.green_center = stalker.needle_phase()
	stalker.submit_check()
	expect(player.battery == 66.0, "Successful check steals four charge")
	expect(is_equal_approx(stalker.green_half_width, 0.075), "First success immediately shrinks the green zone")
	var skill: Control = game.get_node("HUD").find_child("GrabSkillCheck", true, false)
	skill.visible = true
	skill.stalker = stalker
	skill.displayed_phase = stalker.green_center
	skill.displayed_round = 1
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	skill._input(click)
	expect(player.battery == 62.0 and stalker.results.size() == 2, "Mouse input resolves the next round immediately using the displayed angle")
	expect(is_equal_approx(stalker.green_half_width, 0.05), "Second success shrinks the zone again")
	stalker.green_center = fposmod(stalker.needle_phase() + 0.5, 1.0)
	stalker.submit_check()
	expect(player.battery == 52.0 and stalker.feedback.begins_with("ПРОМАХ"), "Failed check steals ten charge and immediately displays failure")
	expect(is_equal_approx(stalker.green_half_width, 0.05), "Miss does not shrink the green zone")
	stalker.submit_check()
	expect(player.battery == 52.0 and stalker.results.size() == 3, "Additional input cannot exceed three checks")
	stalker.update_grab(2.9)
	expect(stalker.state == "grab", "Quick answers retain the full three-second struggle")
	stalker.update_grab(0.1)
	expect(stalker.state == "flee" and not player.grabbed, "Monster releases and flees after exactly three seconds")
	expect(player.get_node("Camera").offset == Vector2.ZERO, "Release resets camera shake")
	stalker.begin_grab()
	stalker.update_grab(3.0)
	expect(stalker.results.size() == 3 and player.battery == 22.0 and stalker.state == "flee", "Three unanswered rounds resolve exactly once even in one large time step")
	expect(is_equal_approx(stalker.green_half_width, 0.10), "Misses leave the initial green zone unchanged; each grab resets its size")
	stalker.state = "stalk"
	stalker.attack_cooldown = 0.0
	stalker.strategy = "sneak"
	stalker.stalking.phase = "close"
	stalker.stalking.watched = true
	stalker.observed = true
	var seen_pace: float = stalker.movement_pace()
	stalker.observed = false
	stalker.stalking.watched = false
	expect(stalker.movement_pace() > seen_pace and stalker.movement_pace() <= 140.0, "Stalking remains slow even outside visibility")
	stalker.strategy = "ambush"
	expect(stalker.movement_pace() == 700.0, "Only the ambush strategy uses a fast unseen detour")
	stalker.strategy = "sneak"
	stalker.attack_cooldown = 15.0
	stalker.strategy_pending = false
	stalker.global_position = player.global_position - Vector2(120, 0)
	stalker._physics_process(14.9)
	expect(stalker.state != "leap" and stalker.attack_cooldown > 0.0, "Cooldown prevents another nearby attack for fifteen seconds")
	stalker.attack_cooldown = 0.0
	stalker.begin_flee(6.0)
	for tick in range(120): stalker._physics_process(1.0 / 60.0)
	expect(stalker.global_position.distance_to(player.global_position) > 220.0, "Released hunter actually runs away through the maze")
	# Light fear is independent of the ambient visibility circle.
	stalker.state = "stalk"
	stalker.global_position = origin + Vector2(100, 0)
	player.global_position = origin
	player.facing_angle = 0.0
	player.flashlight_on = true
	player.flashlight_strength = 1.0
	player.flashlight_reveal = 1.0
	expect(stalker.is_illuminated(), "Player flashlight reveals and repels the stalker")
	stalker.sense_timer = 0.0
	stalker._physics_process(0.02)
	expect(stalker.state != "flee", "Brief beam contact must not trigger fear")
	stalker._physics_process(0.24)
	expect(stalker.state == "flee", "Sustained flashlight exposure makes the stalker flee")
	player.flashlight_on = false
	player.flashlight_strength = 0.0
	var fixture: Node2D = maze.get_node("Overhead/Fixtures").get_child(0)
	stalker.global_position = fixture.global_position
	expect(stalker.is_illuminated(), "Ceiling lamp pools also repel the stalker")
	stalker.grab_offset = Vector2(-42, 0)
	stalker.begin_grab()
	stalker.sense_timer = 0.0
	stalker._physics_process(0.02)
	expect(stalker.state == "grab" and player.grabbed, "Light must not cancel an active skill-check grab")
	var dark: Vector2 = origin
	expect(stalker.navigation.lamp_exposure(dark) < stalker.navigation.lamp_exposure(fixture.global_position), "Route costs distinguish dark paths and lit lamp centers")
	player.global_position = origin
	stalker.global_position = origin - Vector2(42, 0)
	stalker.grab_offset = Vector2(-42, 0)
	player.battery = 3.0
	player.flashlight_on = true
	stalker.begin_grab()
	stalker.resolve_check(false)
	expect(player.battery == 0.0 and not player.flashlight_on, "Charge theft clamps at zero and switches an empty flashlight off")
	var before: float = stalker.attack_elapsed
	hud = game.get_node("HUD")
	hud.set_paused(true)
	for frame in range(3): await process_frame
	stalker.submit_check()
	expect(stalker.attack_elapsed == before, "Pause freezes grab time and ignores skill input")
	hud.set_paused(false)
	player.set_grabbed(true)
	player._physics_process(0.016)
	expect(not player.sprinting and player.get_node("Camera").offset.length() > 0.0, "Grab disables sprint and shakes the screen")
	game.finish(true)
	expect(not player.grabbed and player.get_node("Camera").offset == Vector2.ZERO, "Result screen clears the grab and shake")
	game.restart()
	for frame in range(6):
		await process_frame
		await physics_frame
	expect(not paused and not current_scene.get_node("Player").grabbed and current_scene.get("monsters").size() == 3, "Restart restores a fresh hardcore run without a stale grab")
	print("RESULT hardcore, FPS, audio, lamps, ambush, light fear and three charge checks: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
