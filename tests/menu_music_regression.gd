extends SceneTree

var failures: int = 0

func expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var budget: Node = root.get_node("RuntimeBudget")
	budget.settings_path = "res://.godot/menu_music_regression.cfg"
	var audio: Node = root.get_node("MenuAudio")
	var original_track: int = audio.selected_track
	for cycle in range(2):
		change_scene_to_file("res://scenes/ui/main_menu.tscn")
		for frame in range(4): await process_frame
		expect(audio.track_changed.get_connections().size() == 1, "Only the current menu receives music changes")
		expect(audio.get_node("Music").playing, "Menu music resumes on returning to the main menu")
		audio.select_track((original_track + cycle + 1) % audio.TRACKS.size())
		set_meta("hard_mode", false)
		change_scene_to_file("res://scenes/game.tscn")
		for frame in range(5): await process_frame
		var hud: Node = current_scene.get_node("HUD")
		hud.set_paused(true)
		var menu: Control = hud.pause_overlay
		menu.show_settings(true)
		menu.select_category("Sound")
		var choice: OptionButton = menu.find_child("MusicChoice", true, false)
		expect(menu.pages.Sound.is_ancestor_of(choice), "Menu music selection is in Sound settings")
		expect(audio.track_changed.get_connections().size() == 1, "Scene changes remove the previous music selector connection")
		menu.find_child("MusicNext", true, false).pressed.emit()
		expect(choice.selected == audio.selected_track, "Music arrows update the current paused menu")
		choice.item_selected.emit(0)
		expect(choice.selected == 0 and audio.selected_track == 0, "Dropdown and music selector stay synchronized")
		expect(not audio.get_node("Music").playing, "Selecting menu music during gameplay keeps it stopped")
		var config: ConfigFile = ConfigFile.new()
		config.load(budget.settings_path)
		expect(config.get_value("audio", "menu_music", -1) == 0, "Paused music selection is saved")
		hud.set_paused(false)
		await process_frame
	audio.select_track(original_track)
	print("RESULT music selection across menu, gameplay, pause and return: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
