extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	set_meta("hard_mode", false)
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(5): await process_frame
	var game: Node = current_scene
	game.set_process(false)
	for sound in ["Ambience", "Heartbeat", "Danger", "StartGame", "OpeningHowl"]:
		game.get_node(sound).set_process(false)
		game.get_node(sound).stop()
	for drip in game.get_node("Maze/Overhead").find_children("*", "AudioStreamPlayer2D", true, false):
		drip.set_process(false)
		drip.stop()
	var player: CharacterBody2D = game.get_node("Player")
	player.set_physics_process(false)
	player.get_node("Breathing").set_process(false)
	player.get_node("Breathing").stop()
	player.get_node("FlashlightSwitch").stop()
	player.global_position = game.get_node("Maze").cell_position(60)
	var growl: AudioStreamPlayer2D = game.get_node("Monster/Growl")
	for hunter in game.get("monsters"):
		hunter.set_physics_process(false)
		hunter.get_node("Growl").set_process(false)
		hunter.get_node("Growl").stop()
		hunter.get_node("Growl/Howl").stop()
	game.get_node("Monster").global_position = player.global_position + Vector2(70, 0)
	for frame in range(3): await physics_frame
	growl.volume_db = -1.0
	growl.play()
	var peak: float = -200.0
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 1800:
		await process_frame
		peak = maxf(peak, maxf(AudioServer.get_bus_peak_volume_left_db(0, 0), AudioServer.get_bus_peak_volume_right_db(0, 0)))
	print("Audio outputs: ", AudioServer.get_output_device_list(), "; selected: ", AudioServer.output_device)
	print("Close growl Master peak: %.2f dBFS" % peak)
	var success: bool = peak > -30.0
	if not success: push_error("Close growl did not reach an audible mix level")
	quit(0 if success else 1)
