extends SceneTree

func _initialize() -> void:
	call_deferred("run_benchmark")

func run_benchmark() -> void:
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(4): await process_frame
	var player: Node2D = current_scene.get_node("Player")
	var visibility: Node2D = current_scene.get_node("Visibility")
	current_scene.get_node("Monster").set("active", false)
	player.set_physics_process(false)
	player.get_node("Sprite").set_process(false)
	visibility.set_process(false)
	visibility.set_physics_process(false)
	player.global_position = current_scene.get_node("Maze").cell_position(60)
	player.set("flashlight_reveal", 1.0)
	player.set("flashlight_strength", 1.0)
	var blockers: Array[Node] = get_nodes_in_group("vision_blockers")
	var cold_times: Array[float] = []
	var warm_times: Array[float] = []
	var identical: bool = true
	# Same fixed position and rotation samples for both paths in the same process.
	# Force the former per-frame geometry work, then compare with cached geometry.
	for round_index in range(5):
		var cold: int = 0
		var warm: int = 0
		for sample in range(120):
			player.set("facing_angle", float(sample) * TAU / 120.0)
			for wall in blockers:
				if wall.get("cached_size") != null: wall.set("cached_size", Vector2.INF)
				if wall.get("cached_outline") != null: wall.set("cached_outline", PackedVector2Array())
			visibility.set("geometry_dirty", true)
			visibility.set("previous_origin", Vector2.INF)
			var start: int = Time.get_ticks_usec()
			visibility.call("refresh_visibility", false)
			cold += Time.get_ticks_usec() - start
			var mesh: ArrayMesh = visibility.get("fog_mesh")
			var reference: Array = mesh.surface_get_arrays(0)
			visibility.set("previous_origin", Vector2.INF)
			start = Time.get_ticks_usec()
			visibility.call("refresh_visibility", false)
			warm += Time.get_ticks_usec() - start
			var actual: Array = mesh.surface_get_arrays(0)
			identical = identical and reference[Mesh.ARRAY_VERTEX] == actual[Mesh.ARRAY_VERTEX] and reference[Mesh.ARRAY_COLOR] == actual[Mesh.ARRAY_COLOR] and reference[Mesh.ARRAY_INDEX] == actual[Mesh.ARRAY_INDEX]
		cold_times.append(float(cold) / 120000.0)
		warm_times.append(float(warm) / 120000.0)
	cold_times.sort()
	warm_times.sort()
	print("BENCH identical visibility geometry=%s; median uncached %.3f ms, cached %.3f ms; gain %.1f%%" % [identical, cold_times[2], warm_times[2], (1.0 - warm_times[2] / cold_times[2]) * 100.0])
	quit(0 if identical else 1)
