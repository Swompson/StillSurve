extends SceneTree
var failures: int = 0
func expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run_checks")
func run_checks() -> void:
	set_meta("hard_mode", false)
	change_scene_to_file("res://world.tscn")
	for frame in range(5): await process_frame
	var game: Node = current_scene
	var player: Node2D = game.get_node("Player")
	var hunters: Array = game.get("monsters")
	player.set_physics_process(false)
	for hunter in hunters: hunter.set_physics_process(false)
	expect(hunters.size() == 2 and game.has_node("Heartbeat"), "Legacy editor scene uses the complete current game")
	var maze: Node2D = game.get_node("Maze")
	var fixtures: Node = maze.get_node("Overhead/Fixtures")
	expect(fixtures.get_child_count() == 6, "All six authored fixtures are present")
	for fixture in fixtures.get_children():
		expect(fixture.scene_file_path.is_empty(), "Fixtures are actual native nodes, not hidden nested instances")
		expect(fixture.get_node("Housing/Lens").owner == maze.get_node("Overhead"), "Complete fixture mesh is stored in editable overhead scene")
		if fixture.fixture_kind == "shade":
			expect(not fixture.has_node("Cable") and not fixture.has_node("CeilingMount"), "Shade uses its central suspension cap")
	for pickup in maze.get_node("Pickups").get_children():
		if pickup.kind == "battery": expect(pickup.has_node("BatteryBody"), "Real battery image is visible as a saved scene node")
	var source: CharacterBody2D = hunters[0]
	var listener: CharacterBody2D = hunters[1]
	var patch: Node2D = get_nodes_in_group("glass_patches")[0]
	source.global_position = patch.global_position
	listener.global_position = source.global_position + Vector2(0, 1400)
	for hunter in hunters:
		hunter.set("state", "patrol")
		hunter.set("active", true)
		hunter.set("disengage_timer", 0.0)
	game.call("step_on_glass", source.global_position, false, source)
	expect(source.state == "patrol", "Hunter does not investigate its own footsteps")
	expect(listener.state == "investigate" and listener.last_heard == source.global_position, "Other hunter hears distant monster glass crunch")
	var crunch: AudioStreamPlayer2D = game.get_node("GlassCrunch")
	expect(crunch.playing and crunch.max_distance == 700 and crunch.attenuation >= 1.5, "Player hears crunch over a much smaller spatial range")
	expect(crunch.bus == &"Effects", "Glass audio retains shared building reflections")
	listener.state = "patrol"
	source.call("update_glass_steps", 60.0)
	expect(listener.state == "investigate", "Actual movement across glass alerts the other hunter")
	var budget: Node = root.get_node("RuntimeBudget")
	budget.set("focused", true)
	budget.call("set_paused", false)
	expect(Engine.max_fps == budget.active_fps and not OS.low_processor_usage_mode, "Active play uses the selected FPS budget")
	budget.call("set_paused", true)
	expect(Engine.max_fps == budget.active_fps and not OS.low_processor_usage_mode, "Pause uses the same FPS budget as gameplay")
	budget.set("focused", false)
	budget.call("apply_budget")
	expect(Engine.max_fps == 15 and OS.low_processor_usage_mode, "Background rendering is limited to 15 FPS")
	budget.set("focused", true)
	budget.call("set_paused", false)
	expect(Engine.physics_ticks_per_second == 60, "Frame budgets preserve simulation tick rate")
	print("RESULT editor fixtures, canonical scene, battery, glass hearing and thermal budgets: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
