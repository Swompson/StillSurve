extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene: PackedScene = load("res://scenes/ui/menu_dust.tscn")
	var results: Array[Vector2] = []
	for fps in [60, 144]:
		var dust: Node2D = scene.instantiate()
		root.add_child(dust)
		for layer in dust.get_children(): layer.set_process(false)
		var near_layer: MultiMeshInstance2D = dust.get_node("Near")
		near_layer.positions[0] = Vector2(890, 360)
		near_layer.velocities[0] = Vector2.ZERO
		for frame in range(fps):
			# Same physical mouse speed at different render rates and polling rates.
			var polls: int = 8 if fps == 144 else 1
			for sample in range(polls):
				var wave: InputEventMouseMotion = InputEventMouseMotion.new()
				wave.relative = Vector2(300.0 / fps / polls, 0)
				wave.position = near_layer.positions[0]
				near_layer._input(wave)
			near_layer._process(1.0 / fps)
		assert(near_layer.velocities[0].length() > 0.1 and near_layer.velocities[0].length() < 2.0)
		results.append(near_layer.positions[0])
		var before: float = near_layer.velocities[0].length()
		for frame in range(fps): near_layer._process(1.0 / fps)
		assert(near_layer.velocities[0].length() < before * 0.21)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var actual: Vector2 = near_layer.multimesh.get_instance_transform_2d(0).origin
			var expected: Vector2 = near_layer.positions[0] + near_layer.camera_offset
			assert(actual.is_equal_approx(expected), "Rendered dust %s differs from simulation %s" % [actual, expected])
		dust.free()
	assert(results[0].distance_to(results[1]) < 0.12, "Dust response should stay consistent across frame and polling rates")
	print("RESULT gentle dust airflow at 60/144 FPS, polling rates and smooth decay: OK")
	quit()
