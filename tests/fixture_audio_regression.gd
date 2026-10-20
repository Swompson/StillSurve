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
	game.player.set_physics_process(false)
	for hunter in game.monsters:
		hunter.set_physics_process(false)
		hunter.active = true
		hunter.global_position = Vector2(10000, 10000)
	var overhead: Node2D = game.get_node("Maze/Overhead")
	var fixtures: Array[Node] = overhead.get_node("Fixtures").get_children()
	expect(fixtures.size() == 6, "Six authored ceiling and wall fixtures remain in the editor scene")
	for fixture in fixtures:
		fixture.set_process(false)
		for sound_name in ["Hum", "Flicker", "Arc"]:
			var sound: AudioStreamPlayer2D = fixture.get_node(sound_name)
			expect(sound.owner == game.get_node("Maze/Overhead") and sound.bus == (&"Environment" if sound_name == "Hum" else &"Effects"), "Fixture audio is authored and uses shared building reflections")
			expect(sound.max_polyphony == 1 and sound.max_distance <= 650.0, "Nearby lamps have bounded spatial voices")
		var loop: AudioStreamWAV = fixture.get_node("Hum").stream
		expect(loop.loop_mode == AudioStreamWAV.LOOP_FORWARD and loop.get_length() >= 3.9, "Every ballast uses the shared seamless loop")
		expect(fixture.get_node("Housing/Sparks").amount <= 14, "Spark particle work stays bounded near multiple monsters")
	var fixture: Node2D = fixtures[0]
	for hunter in game.monsters:
		hunter.global_position = fixture.global_position + Vector2(300, 0)
		fixture.update_danger()
		expect(fixture.light_state == 1, "Each active hunter causes contact flicker")
		hunter.global_position = fixture.global_position + Vector2(80, 0)
		fixture.update_danger()
		fixture.spark_cooldown = 0.0
		fixture.get_node("Arc").stop()
		fixture.get_node("Flicker").stop()
		fixture.flicker_cooldown = 0.0
		fixture.begin_blink()
		expect(fixture.light_state == 2 and fixture.get_node("Arc").playing and fixture.get_node("Housing/Sparks").emitting, "Close hunter synchronizes visible sparks with one arc sound")
		expect(fixture.get_node("Flicker").playing and fixture.dark_remaining > 0.0, "Contact sound starts with the dark interval")
		var cooldown: float = fixture.spark_cooldown
		fixture.begin_blink()
		expect(fixture.spark_cooldown == cooldown, "Repeated flickers cannot stack or restart an active arc")
		hunter.active = false
		fixture.update_danger()
		expect(fixture.light_state == 0, "Inactive hunters do not disturb lamps")
		hunter.global_position = Vector2(10000, 10000)
		hunter.active = true
	fixture.light_power = 0.9
	fixture.dark_remaining = 0.1
	fixture.blink_timer = 1.0
	fixture.danger_probe = 0.0
	game.get_node("SecondMonster").global_position = fixture.global_position
	fixture._process(1.0 / 120.0)
	expect(absf(fixture.light_power - 0.9) <= 0.084, "Close-range flicker brightness approaches its target without a frame discontinuity")
	for index in range(1, 6):
		var drip: AudioStreamPlayer2D = overhead.get_node("PipeDrip%d" % index)
		expect(drip.stream.resource_path.ends_with("user_originals/waterdrop.mp3"), "Original water-drop recording is preserved")
		expect(is_equal_approx(drip.volume_db, -9.0) and drip.max_distance == 760.0, "Authored pipe drips are six decibels louder with useful reach")
		expect(drip.playing and drip.bus == &"Effects", "Pipe drips play on the map through the shared room")
	expect(AudioServer.get_bus_effect(0, 0) is AudioEffectDelay and AudioServer.get_bus_effect(0, 1) is AudioEffectReverb, "All new sounds retain building reflections and reverb")
	print("RESULT shared fixture audio, all nearby hunters, bounded sparks and louder authored drips: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
