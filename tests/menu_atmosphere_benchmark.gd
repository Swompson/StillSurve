extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	for frame in range(12): await process_frame
	root.get_node("RuntimeBudget").set_process(false)
	Engine.max_fps = 0
	var layers: Array[Node] = current_scene.get_node("Layout/Dust").get_children()
	var wave: InputEventMouseMotion = InputEventMouseMotion.new()
	wave.relative = Vector2(4, 2)
	var started: int = Time.get_ticks_usec()
	for frame in range(600):
		for sample in range(8):
			wave.position = Vector2(890 + sin(frame * 0.03) * 80, 360 + cos(frame * 0.03) * 150)
			for layer in layers: layer._input(wave)
		for layer in layers: layer._process(1.0 / 144.0)
	print("DUST simulation and 8 mouse samples: %.3f ms/frame" % ((Time.get_ticks_usec() - started) / 600000.0))
	for frame in range(30): await process_frame
	var samples: PackedFloat64Array = []
	var previous: int = Time.get_ticks_usec()
	for frame in range(120):
		await process_frame
		var now: int = Time.get_ticks_usec()
		samples.append((now - previous) / 1000.0)
		previous = now
	samples.sort()
	print("MENU frame interval median %.3f ms, p95 %.3f ms; draw calls %d; primitives %d" % [samples[60], samples[114],
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	quit()
