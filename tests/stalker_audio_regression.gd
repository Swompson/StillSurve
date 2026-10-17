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
	for hunter in game.monsters: hunter.set_physics_process(false)
	game.player.set_physics_process(false)
	var stalker: Node = game.get_node("Stalker")
	var laugh: AudioStreamPlayer2D = stalker.get_node("Laugh")
	var played: Array[int] = []
	laugh.laugh_started.connect(func(index: int) -> void: played.append(index))
	for index in range(90):
		laugh.stop()
		laugh.cooldown = 0.0
		laugh.play_laugh()
	var uninterrupted: int = played.size()
	var current_stream: AudioStream = laugh.stream
	laugh.play_laugh()
	assert(played.size() == uninterrupted and laugh.stream == current_stream)
	for index in range(1, played.size()): assert(played[index] != played[index - 1])
	for index in range(0, played.size(), 3):
		var cycle: Array[int] = played.slice(index, index + 3)
		cycle.sort()
		assert(cycle == [0, 1, 2])
	played.clear()
	laugh.stop()
	laugh.cooldown = 0.0
	stalker.begin_grab()
	assert(played.size() == 1 and game.player.grabbed and laugh.playing)
	var laugh_origin: Vector2 = laugh.global_position
	stalker.global_position += Vector2(20, 0)
	assert(laugh.global_position == laugh_origin)
	stalker.begin_flee(3.0)
	assert(played.size() == 1)
	laugh.stop()
	laugh.cooldown = 0.0
	stalker.state = "stalk"
	stalker.global_position = game.get_node("Maze/Overhead/Fixtures/CeilingLamp1").global_position
	stalker.sense_timer = 0.0
	stalker._physics_process(0.02)
	assert(stalker.state == "flee" and played.size() == 1)
	for tick in range(10): stalker._physics_process(0.02)
	assert(played.size() == 1)
	var tested_flashlight: bool = false
	for cell in range(121):
		var point: Vector2 = game.maze.cell_position(cell)
		if stalker.navigation.lamp_exposure(point + Vector2(80, 0)) > 0.01 or not game.maze.can_walk_line(point, point + Vector2(80, 0)): continue
		game.player.global_position = point
		game.player.flashlight_on = true
		game.player.flashlight_strength = 1.0
		game.player.facing_angle = 0.0
		stalker.global_position = point + Vector2(80, 0)
		stalker.state = "stalk"
		stalker.sense_timer = 0.0
		stalker.light_contact = 0.0
		stalker._physics_process(0.02)
		assert(played.size() == 1)
		stalker._physics_process(0.24)
		assert(stalker.state == "flee" and played.size() == 2)
		tested_flashlight = true
		break
	assert(tested_flashlight)
	assert(laugh.bus == &"Master" and AudioServer.get_bus_effect(0, 0) is AudioEffectDelay and AudioServer.get_bus_effect(0, 1) is AudioEffectReverb)
	var intro: Node = load("res://scenes/ui/studio_intro.tscn").instantiate()
	var sound: AudioStreamPlayer = intro.get_node("Sound")
	assert(sound.autoplay and sound.bus == &"Master")
	assert(sound.stream.resource_path.ends_with("swompson_intro_sound.wav") and absf(sound.stream.get_length() - 4.516667) < 0.01)
	intro.free()
	print("RESULT 30 shuffle cycles, no repeats, attack/light-only laughter and intro sound: passed")
	quit()
