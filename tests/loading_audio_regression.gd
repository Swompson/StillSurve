extends SceneTree

var failures: int = 0

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.position = Vector2i(-1400, -1000)
	var budget: Node = root.get_node("RuntimeBudget")
	budget.mark_focused()
	budget.set_process(false)
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	for frame in range(4): await process_frame
	var menu: Node = current_scene
	menu.get_node("Layout/ModePanel").show()
	var started: int = Time.get_ticks_msec()
	menu.get_node("Layout/ModePanel/Choices/Normal").pressed.emit()
	for frame in range(2): await process_frame
	var loading: Node = current_scene
	expect(loading.scene_file_path == "res://scenes/ui/loading_screen.tscn", "Mode confirmation enters the real loading screen")
	var loading_sound: WeakRef = weakref(loading.get_node("LoadingAudio"))
	expect(loading.get_node("LoadingAudio").playing, "Loading audio starts before the threaded request completes")
	while is_instance_valid(current_scene) and current_scene.scene_file_path != "res://scenes/game.tscn" and Time.get_ticks_msec() - started < 15000:
		await process_frame
	expect(is_instance_valid(current_scene) and current_scene.scene_file_path == "res://scenes/game.tscn", "Threaded loading and the audio fade enter the actual game")
	for frame in range(2): await process_frame
	expect(Time.get_ticks_msec() - started >= 3000, "Loading retains the existing minimum display time")
	expect(not is_instance_valid(loading_sound.get_ref()), "The loading soundtrack ends with its scene")
	var audio: Node = root.get_node("MenuAudio")
	expect(audio.get_node("StartGameButton").playing and not audio.get_node("Music").playing, "The confirmation tail survives loading while menu music stays stopped")
	print("RESULT rendered final choice, loading playback/fade, threaded transition and persistent confirmation: %d failure(s) in %.2fs" % [failures, float(Time.get_ticks_msec() - started) / 1000.0])
	quit(0 if failures == 0 else 1)
