extends SceneTree

var failures: int = 0

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")

func load_game() -> Node:
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(6): await process_frame
	var game: Node = current_scene
	game.set_process(false)
	game.player.set_physics_process(false)
	for hunter in game.monsters: hunter.set_physics_process(false)
	return game

func run() -> void:
	var menu_audio: Node = root.get_node("MenuAudio")
	var start: AudioStreamPlayer = menu_audio.get_node("StartGameButton")
	for hard in [false, true]:
		change_scene_to_file("res://scenes/ui/main_menu.tscn")
		for frame in range(3): await process_frame
		var menu: Node = current_scene
		expect(not start.playing, "Opening the menu never plays the final mode confirmation")
		menu.get_node("Layout/pause_overlay/Navigation/Resume").pressed.emit()
		expect(not start.playing, "Opening the mode selector does not confirm a mode")
		menu_audio.get_node("Accept").stop()
		menu.get_node("Layout/ModePanel/Choices/Hard" if hard else "Layout/ModePanel/Choices/Normal").pressed.emit()
		menu.start_game()
		for frame in range(3): await process_frame
		expect(bool(get_meta("hard_mode")) == hard and start.playing, "Both final mode choices play the dedicated confirmation once")
		expect(not menu_audio.get_node("Accept").playing, "Final confirmation replaces the generic accept click")
		expect(start.stream.resource_path.ends_with("startgame_button.mp3") and start.bus == &"Effects", "Confirmation survives scene changes through the shared acoustic bus")
		var loading: Node = current_scene
		var loading_audio: AudioStreamPlayer = loading.get_node("LoadingAudio")
		expect(loading_audio.playing and loading_audio.stream.loop and loading_audio.bus == &"Effects", "Loading plays its scene-local looping recording")
		expect(not load("res://assets/audio/user_originals/loading_screen.mp3").loop, "Looping never changes the original loading stream")
		loading.show_error()
		expect(not loading_audio.playing, "A loading error stops the loading soundtrack")
	var game: Node = await load_game()
	var player: Node = game.player
	var cues: Node = game.get_node("GameCues")
	var changed: Array[StringName] = []
	cues.cue_changed.connect(func(cue: StringName) -> void: changed.append(cue))
	var laugh: AudioStreamPlayer2D = game.get_node("Stalker/Laugh")
	expect(laugh.volume_db == -14.0 and laugh.bus == &"Effects", "The shared player makes all three stalker laughs 10 dB quieter")
	for name in ["NoBattery", "PreEnd", "PreLateNoLight", "AllCollected"]:
		expect(cues.get_node(name).bus == &"Effects", "All situational recordings use the shared reflections/reverb path")
	expect(AudioServer.get_bus_effect(0, 0) is AudioEffectDelay and AudioServer.get_bus_effect(0, 1) is AudioEffectReverb, "The common building acoustics remain enabled")
	game._process(0.01)
	expect(cues.current_cue == &"", "A charged early run starts without a warning recording")
	player.flashlight_on = false
	game._process(0.01)
	expect(cues.current_cue == &"", "Manually stowing a charged flashlight is not a depleted battery")
	player.battery = 0.001
	player.flashlight_on = true
	player.update_resources(0.1, false)
	game._process(0.01)
	expect(player.battery == 0.0 and cues.current_cue == &"NoBattery" and cues.get_node("NoBattery").playing, "Natural battery exhaustion starts no_battarey")
	for frame in range(120): game._process(1.0 / 60.0)
	expect(changed.count(&"NoBattery") == 1, "An unchanged condition does not restart its recording every frame")
	player.add_battery()
	game._process(0.01)
	await create_timer(cues.FADE_OUT_SECONDS + 0.1).timeout
	expect(cues.current_cue == &"" and not cues.get_node("NoBattery").playing, "Battery recovery fades the empty-battery recording out")
	var dolls: Array[Node] = []
	var battery: Node2D
	for pickup in game.maze.get_node("Pickups").get_children():
		if pickup.kind == "figurine": dolls.append(pickup)
		elif not is_instance_valid(battery): battery = pickup
	for index in range(8): game.collect_pickup(dolls[index])
	expect(game.collected == 8 and cues.current_cue == &"", "Four remaining dolls do not start the last-three cue")
	game.collect_pickup(dolls[8])
	expect(game.collected == 9 and cues.current_cue == &"PreEnd" and cues.get_node("PreEnd").playing, "Collecting the ninth doll starts pre_end with exactly three remaining")
	player.drain_flashlight(100.0)
	game._process(0.01)
	await create_timer(cues.CROSSFADE_SECONDS + 0.1).timeout
	expect(cues.current_cue == &"PreLateNoLight" and cues.get_node("PreLateNoLight").playing and not cues.get_node("PreEnd").playing and not cues.get_node("NoBattery").playing, "Late darkness replaces the other two recordings instead of stacking them")
	game.collect_pickup(battery)
	await create_timer(cues.CROSSFADE_SECONDS + 0.1).timeout
	expect(cues.current_cue == &"PreEnd" and not cues.get_node("PreLateNoLight").playing, "Picking up a real battery restores the lit final phase")
	player.battery = 2.0
	var stalker: Node = game.get_node("Stalker")
	stalker.begin_grab()
	stalker.resolve_check(false)
	game._process(0.01)
	expect(player.battery == 0.0 and cues.current_cue == &"PreLateNoLight", "Stalker charge theft also triggers the late empty-battery cue")
	stalker.begin_flee(3.0)
	var transitions: int = changed.size()
	game.collect_pickup(dolls[9])
	game.collect_pickup(dolls[10])
	expect(changed.size() == transitions, "The last-two and last-one pickups keep the final-phase recording running")
	game.collect_pickup(dolls[11])
	await create_timer(0.45).timeout
	expect(game.finished and game.won and cues.ended and cues.get_node("AllCollected").playing and not cues.get_node("AllCollected").stream.loop, "The final doll plays all_collected once on victory")
	for name in cues.CONTEXTS: expect(not cues.get_node(NodePath(name)).playing, "Victory fades every tension recording out")
	expect(not game.get_node("ToyPickup").playing and not start.playing, "Routine pickup and start cues cannot mask the victory recording")
	game.finish(true)
	game.collect_pickup(dolls[11])
	expect(cues.current_cue == &"" and cues.ended, "Repeated finish and pickup calls cannot re-enter warning states")
	game = await load_game()
	cues = game.get_node("GameCues")
	expect(not cues.ended and cues.current_cue == &"" and not cues.get_node("AllCollected").playing, "A new run clears the previous run's audio state")
	game.player.battery = 0.0
	game._process(0.01)
	game.finish(false)
	await create_timer(0.45).timeout
	expect(not cues.get_node("AllCollected").playing and not cues.get_node("NoBattery").playing, "Death stops tension without playing the collection victory cue")
	print("RESULT mode confirmation, loading/error, quieter laughter, empty charge, last three, compound state, recovery, victory and death: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
