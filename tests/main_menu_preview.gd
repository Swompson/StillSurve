extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	for frame in range(10): await process_frame
	var menu: Node = current_scene.get_node("Layout/pause_overlay")
	root.get_node("RuntimeBudget").settings_path = "res://.godot/menu_music_test.cfg"
	var audio: Node = root.get_node("MenuAudio")
	assert(audio.get_node("Music").playing)
	var initial_track: int = audio.selected_track
	var music: OptionButton = menu.find_child("MusicChoice", true, false)
	music.select(2)
	music.item_selected.emit(2)
	assert(audio.selected_track == 2)
	assert(audio.get_node("Music").playing)
	assert(audio.get_node("Music").stream.resource_path.ends_with("main_menu_music2.mp3"))
	audio.select_track(initial_track)
	var title_position: Vector2 = menu.get_node("PauseTitle").position
	assert(menu.get_node("Version").text == "0.0.3  preAlpha")
	assert(current_scene.get_node("MenuWind").playing)
	assert(current_scene.get_node("MenuWind").stream.loop)
	assert(current_scene.get_node("MenuWind").bus == &"Environment")
	assert(current_scene.get_node("Layout/OutsideWind").playing)
	assert(current_scene.get_node("Layout/OutsideWind").stream.loop)
	var background: Control = current_scene.get_node("Layout/Background")
	var initial_position: Vector2 = background.position
	for frame in range(15): await process_frame
	assert(background.position != initial_position)
	assert(menu.get_node("PauseTitle").position == title_position)
	assert(current_scene.has_node("Layout/Dust"))
	assert(current_scene.get_node("Layout/Dust").get_child_count() == 3)
	var near_dust: Node2D = current_scene.get_node("Layout/Dust/Near")
	var far_dust: Node2D = current_scene.get_node("Layout/Dust/Far")
	var mote_position: Vector2 = near_dust.positions[0]
	var wave: InputEventMouseMotion = InputEventMouseMotion.new()
	wave.position = mote_position + near_dust.camera_offset
	wave.relative = Vector2(35, 12)
	near_dust._input(wave)
	near_dust._process(0.1)
	var disturbed_velocity: Vector2 = near_dust.velocities[0]
	assert(disturbed_velocity.length() > 0.1 and disturbed_velocity.length() < 8.0)
	assert(near_dust.positions[0].distance_to(mote_position) < 2.0)
	near_dust._process(0.1)
	assert(near_dust.velocities[0].length() < disturbed_velocity.length())
	assert(near_dust.camera_offset != far_dust.camera_offset)
	var title_rect: Rect2 = menu.get_node("PauseTitle").get_global_rect()
	var navigation_rect: Rect2 = menu.get_node("Navigation").get_global_rect()
	assert(absf(title_rect.get_center().x - navigation_rect.get_center().x) < 4.0)
	var version_rect: Rect2 = menu.get_node("Version").get_global_rect()
	assert(version_rect.position.x <= 10.0)
	assert(root.get_visible_rect().size.y - version_rect.end.y <= 10.0)
	for window_size in [Vector2i(1600, 900), Vector2i(960, 540), Vector2i(1280, 720)]:
		root.size = window_size
		for frame in range(3): await process_frame
		title_rect = menu.get_node("PauseTitle").get_global_rect()
		navigation_rect = menu.get_node("Navigation").get_global_rect()
		assert(absf(title_rect.get_center().x - navigation_rect.get_center().x) < 4.0)
		version_rect = menu.get_node("Version").get_global_rect()
		assert(root.get_visible_rect().size.y - version_rect.end.y <= 10.0)
	assert(current_scene.get_node("Layout").position == Vector2.ZERO)
	menu.get_node("Navigation/Resume").grab_focus()
	for frame in range(20): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/main_menu_preview.png")
	menu.show_settings(true)
	assert(menu.get_node("SettingsPanel").visible)
	for frame in range(15): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/main_menu_settings_preview.png")
	assert(menu.get_node("PauseTitle").get_global_rect().end.y < menu.get_node("SettingsPanel").get_global_rect().position.y)
	menu.select_category("Sound")
	for frame in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/main_menu_sound_preview.png")
	assert(menu.close_settings())
	var settings_button: Button = menu.get_node("Navigation/Settings")
	settings_button.button_pressed = true
	settings_button.button_pressed = false
	for frame in range(30): await process_frame
	assert(not menu.get_node("SettingsPanel").visible)
	assert(settings_button.get_node("Highlight").modulate.a < 0.05)
	menu.get_node("Navigation/Resume").pressed.emit()
	assert(current_scene.get_node("Layout/ModePanel").visible)
	var choices: Control = current_scene.get_node("Layout/ModePanel/Choices")
	for frame in range(4): await process_frame
	for choice in choices.get_children():
		assert(absf(choice.get_global_rect().get_center().x - choices.get_global_rect().get_center().x) < 1.0)
		if choice is Button: assert(choice.alignment == HORIZONTAL_ALIGNMENT_LEFT)
		if choice is Label: assert(choice.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT)
	choices.get_node("Normal").grab_focus()
	for frame in range(20): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/mode_selection_preview.png")
	current_scene.get_node("Layout/ModePanel/Choices/Normal").pressed.emit()
	await process_frame
	await process_frame
	assert(current_scene.scene_file_path == "res://scenes/ui/loading_screen.tscn")
	var loading: Control = current_scene
	loading.set_process(false)
	var hud_position: Vector2 = loading.get_node("HUD/Progress").position
	var background_position: Vector2 = loading.get_node("Background").position
	loading._process(0.25)
	assert(loading.get_node("HUD/Progress").position == hud_position)
	assert(loading.get_node("Background").position != background_position)
	var animation: AnimatedTexture = loading.get_node("Background").texture
	var animation_frame: int = animation.current_frame
	var animation_deadline: int = Time.get_ticks_msec() + 2000
	while animation.current_frame == animation_frame and Time.get_ticks_msec() < animation_deadline:
		await process_frame
	assert(animation.current_frame != animation_frame, "Loading GIF must keep animating during loading")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/loading_screen_preview.png")
	loading.set_process(true)
	var deadline: int = Time.get_ticks_msec() + 30000
	while current_scene == null or current_scene.scene_file_path != "res://scenes/game.tscn":
		assert(Time.get_ticks_msec() < deadline, "Threaded game loading timed out")
		await process_frame
	for frame in range(8): await process_frame
	assert(current_scene.scene_file_path == "res://scenes/game.tscn")
	var hud: Node = current_scene.get_node("HUD")
	hud.set_paused(true)
	hud.find_child("MainMenu", true, false).pressed.emit()
	for frame in range(8): await process_frame
	assert(current_scene.scene_file_path == "res://scenes/ui/main_menu.tscn")
	assert(not paused)
	print("RESULT main menu settings and start transition: OK")
	quit()
