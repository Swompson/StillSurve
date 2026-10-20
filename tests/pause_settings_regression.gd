extends SceneTree

var failures: int = 0

func expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	set_meta("hard_mode", false)
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(5): await process_frame
	var budget: Node = root.get_node("RuntimeBudget")
	budget.settings_path = "res://.godot/pause_settings_test.cfg"
	var hud: Node = current_scene.get_node("HUD")
	var menu: ColorRect = hud.pause_overlay
	var settings: Control = menu.get_node("SettingsPanel")
	hud.set_paused(true)
	var resume: Button = menu.get_node("Navigation/Resume")
	resume.grab_focus()
	for frame in range(20): await process_frame
	expect(resume.get_node("Highlight").modulate.a > 0.1, "Pause highlight animates while the tree is paused")
	expect(paused and menu.visible and not settings.visible, "Pause initially shows only the left navigation")
	expect(menu.get_node("Navigation").anchor_right < 0.31, "Title and every pause navigation action are on the left")
	expect(menu.get_node("Navigation").get_child_count() == 7, "Pause includes return to main menu")
	menu.get_node("Navigation/Settings").button_pressed = true
	var small_button: Button = menu.find_child("GraphicsTab", true, false)
	small_button.grab_focus()
	for frame in range(20): await process_frame
	expect(not small_button.has_node("Highlight"), "Settings use font highlighting without textured strips")
	expect(settings.visible and paused, "Settings opens on the right without resuming gameplay")
	expect(settings.is_ancestor_of(hud.fps_choice) and settings.is_ancestor_of(hud.fullscreen_toggle), "Video controls live inside settings")
	expect(hud.difficulty_checks.is_empty(), "Difficulty selection is moved to the main menu start page")
	budget.mark_focused()
	budget.set_fps(60, false)
	hud.fps_choice.select(0)
	menu.find_child("FpsNext", true, false).pressed.emit()
	expect(budget.active_fps == 144 and Engine.max_fps == 144, "Right FPS arrow applies 144 from the real UI")
	menu.find_child("FpsNext", true, false).pressed.emit()
	expect(budget.active_fps == 180, "Next FPS arrow selects 180")
	menu.find_child("FpsNext", true, false).pressed.emit()
	expect(budget.active_fps == 0 and Engine.max_fps == 0, "Final FPS option removes the cap")
	menu.find_child("FpsPrevious", true, false).pressed.emit()
	expect(budget.active_fps == 180, "Left FPS arrow selects the previous cap")
	var config: ConfigFile = ConfigFile.new()
	config.load(budget.settings_path)
	expect(config.get_value("video", "max_fps") == 180, "UI selection persists through the actual settings writer")
	var vignette: CheckButton = menu.find_child("VignetteToggle", true, false)
	vignette.button_pressed = false
	expect(not current_scene.get_node("Vignette").visible and not budget.vignette_enabled, "Graphics toggle disables vignette immediately during pause")
	config.load(budget.settings_path)
	expect(config.get_value("video", "vignette", true) == false, "Vignette preference is saved")
	menu.find_child("VignetteNext", true, false).pressed.emit()
	expect(current_scene.get_node("Vignette").visible and budget.vignette_enabled, "Vignette arrow restores the effect")
	menu.find_child("SoundTab", true, false).pressed.emit()
	expect(menu.find_child("SoundPage", true, false).visible and not menu.find_child("GraphicsPage", true, false).visible, "Sound tab replaces the graphics settings")
	menu.find_child("MasterVolume", true, false).value = 50.0
	expect(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(0)), 0.5), "Volume slider controls shared Master acoustics")
	for category in budget.category_volumes:
		var channel: HSlider = menu.find_child(category + "Volume", true, false)
		expect(channel != null, "Sound category has an authored slider: " + category)
		channel.value = 35.0
		var bus_index: int = AudioServer.get_bus_index(category)
		expect(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(bus_index)), 0.35), "Category slider updates its own real bus: " + category)
		config.load(budget.settings_path)
		expect(is_equal_approx(float(config.get_value("audio", "volume_" + category)), 0.35), "Category gain persists: " + category)
		channel.value = 0.0
		expect(AudioServer.is_bus_mute(bus_index), "Zero category volume fully mutes: " + category)
		channel.value = 100.0
		expect(not AudioServer.is_bus_mute(bus_index), "Raising volume restores the category: " + category)
	menu.find_child("GameTab", true, false).pressed.emit()
	expect(menu.find_child("GamePage", true, false).visible, "Game tab opens its settings page")
	menu.find_child("ControlsTab", true, false).pressed.emit()
	expect(menu.find_child("ControlsPage", true, false).visible, "Controls tab displays the bindings")
	menu.find_child("GraphicsTab", true, false).pressed.emit()
	menu.find_child("FpsCounterToggle", true, false).button_pressed = true
	expect(budget.show_fps, "FPS display toggle applies")
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	hud._input(escape)
	expect(paused and not settings.visible, "First Escape returns from settings to pause")
	hud._input(escape)
	expect(not paused and not menu.visible, "Second Escape resumes gameplay")
	hud._process(0.01)
	expect(hud.fps_counter.visible, "Enabled FPS counter is visible during gameplay")
	budget.set_master_volume(0.794328)
	print("RESULT left pause, settings tabs, real FPS arrows, persistence, audio and escape navigation: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
