extends SceneTree

var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run_checks")

func check_authored_body(kind: String) -> void:
	# Inspect before entering the tree: none of these sprites can come from _ready.
	var body: Node2D = load("res://scenes/actors/%s_body.tscn" % kind).instantiate()
	expect(body.has_node("Torso") and body.has_node("Head"), "Editor must have saved torso/head sprites")
	expect(body.has_node("LeftFoot") and body.has_node("RightFoot"), "Editor must have saved foot sprites")
	expect(not body.has_node("LeftThigh") and not body.has_node("LeftShin") and not body.has_node("LeftKnee"), "Overhead bodies must not contain intermediate leg parts")
	for child in body.get_children():
		expect(child is Sprite2D and child.texture != null, "All body parts must be actual textured scene nodes")
	body.free()

func run_chase(recovery: bool) -> void:
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(4):
		await process_frame
		await physics_frame
	var game: Node2D = current_scene
	var maze: Node2D = game.get_node("Maze")
	var player: CharacterBody2D = game.get_node("Player")
	var monster: CharacterBody2D = game.get_node("Monster")
	player.set_physics_process(false)
	monster.set_physics_process(false)
	var graph: AStar2D = maze.get("graph")
	var start: int = -1
	for cell in range(120):
		if cell % 11 < 10 and graph.are_points_connected(cell, cell + 1):
			start = cell
			break
	expect(start >= 0, "Chase test requires an open corridor")
	var origin: Vector2 = maze.call("cell_position", start)
	monster.global_position = origin
	player.global_position = origin + Vector2(85, 0)
	monster.velocity = Vector2.ZERO
	monster.set("active", true)
	monster.set("state", "hunt")
	monster.set("facing_angle", 0.0)
	monster.set("last_known", player.global_position)
	monster.set("memory", 3.0)
	monster.set("disengage_timer", 0.0)
	monster.set("sense_timer", 0.0)
	monster.set("stamina", 0.0 if recovery else 100.0)
	monster.set("recovering", recovery)
	monster.set("path_goal", -1)
	monster.set_physics_process(true)
	Engine.physics_ticks_per_second = 240
	Engine.time_scale = 4.0
	var ticks: int = 0
	for tick in range(150):
		await physics_frame
		if game.get("finished"):
			break
		player.global_position += Vector2(3, 0)
		ticks += 1
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	expect(bool(game.get("finished")) and not bool(game.get("won")), "Monster must catch and attack a walking player, including during stamina recovery")
	print("CHASE recovery=%s ticks=%d distance=%.2f attacked=%s" % [recovery, ticks, monster.global_position.distance_to(player.global_position), game.get("finished")])
	monster.set_physics_process(false)
	var player_sprite: Node2D = player.get_node("Sprite")
	expect(player_sprite.has_node("ArticulatedBody"), "Player must use its saved body scene")
	expect(monster.has_node("Visual/ArticulatedBody"), "Monster must use the same saved model in editor and game")
	expect(maze.has_node("CorridorDetails/Rubble00/Surface/Concrete"), "Rubble geometry must be saved and visible in the editor")
	expect(AudioServer.get_bus_effect(0, 0) is AudioEffectDelay, "Every sound must pass through hall early reflections")
	expect(AudioServer.get_bus_effect(0, 1) is AudioEffectReverb, "Every sound must pass through the hall reverb")
	expect(not AudioServer.is_bus_bypassing_effects(0), "Hall effects must be enabled")
	for bus in range(1, AudioServer.bus_count):
		expect(AudioServer.get_bus_send(bus) == &"Master", "All sound buses must reach shared hall acoustics")
	var sound: AudioStream = player.get("SWITCH_ON")
	expect(sound.resource_path.ends_with("user_switch_on.wav"), "Flashlight must use the user-provided recording")
	expect(int(maze.call("cell_at", maze.call("cell_position", 60))) == 60, "Navigation must account for the maze transform")

func run_checks() -> void:
	check_authored_body("player")
	check_authored_body("monster")
	await run_chase(false)
	await run_chase(true)
	print("RESULT chase attack, authored editor visuals and shared hall audio: %d failure(s)" % failures.size())
	quit(0 if failures.is_empty() else 1)
