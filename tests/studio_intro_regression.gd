extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(not ProjectSettings.get_setting("application/boot_splash/show_image"))
	assert(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/ui/studio_intro.tscn")
	change_scene_to_file("res://scenes/ui/studio_intro.tscn")
	for frame in range(8): await process_frame
	var intro: Control = current_scene
	intro.set_process(false)
	assert(intro.get_node("Title").text == "Swompson")
	intro.elapsed = 0.0
	intro._process(0.2)
	assert(intro.get_node("Title").modulate.a == 0.0)
	intro._process(2.0)
	assert(intro.get_node("Title").modulate.a > 0.9)
	for frame in range(120):
		if ResourceLoader.load_threaded_get_status("res://scenes/game.tscn") == ResourceLoader.THREAD_LOAD_LOADED: break
		await process_frame
	intro.finish()
	for frame in range(8): await process_frame
	assert(current_scene.name == "Game" and not paused)
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	print("RESULT custom intro fade, asynchronous preload, skip and game transition: passed")
	quit()
