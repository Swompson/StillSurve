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
		if ResourceLoader.load_threaded_get_status("res://scenes/ui/main_menu.tscn") == ResourceLoader.THREAD_LOAD_LOADED: break
		await process_frame
	intro.finish()
	assert(not intro.leaving)
	intro.elapsed = 4.4
	intro._process(0.0)
	await RenderingServer.frame_post_draw
	var faded_image: Image = root.get_texture().get_image()
	assert(faded_image.get_pixel(20, 20).get_luminance() < 0.002)
	faded_image.save_png("res://.godot/intro_fade_preview.png")
	intro.elapsed = intro.DURATION
	intro.finish()
	for frame in range(8): await process_frame
	assert(current_scene.name == "MainMenu" and not paused)
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	print("RESULT custom intro fade, blocked skip and main menu transition: passed")
	quit()
