extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.mode = Window.MODE_WINDOWED
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	for frame in range(5): await process_frame
	var layout: Control = current_scene.get_node("Layout")
	var panel: Control = layout.get_node("ModePanel")
	for window_size in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1280, 1024)]:
		root.size = window_size
		for frame in range(5): await process_frame
		for opening in range(2):
			panel.show()
			for frame in range(3): await process_frame
			var expected: Vector2 = layout.size * Vector2(0.68, 0.59) + Vector2(-350, -270)
			if not panel.position.is_equal_approx(expected) or not panel.size.is_equal_approx(Vector2(700, 520)):
				push_error("Difficulty panel moved after scene export: %s, expected position %s" % [panel.get_rect(), expected])
				quit(1)
				return
			print("Difficulty layout OK: ", window_size, " ", panel.get_rect())
			panel.hide()
	quit()
