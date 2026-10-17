extends SceneTree

var failures: Array[String] = []

func expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	seed(74)
	set_meta("hard_mode", false)
	change_scene_to_file("res://scenes/game.tscn")
	await process_frame
	await physics_frame
	var game: Node = current_scene
	var maze: Node = game.get_node("Maze")
	var hunters: Array[Node2D] = [game.get_node("Monster"), game.get_node("SecondMonster")]
	game.get_node("Player").set_physics_process(false)
	for hunter in hunters:
		hunter.set_physics_process(false)
	expect(hunters[0].position.x < 0 and hunters[1].position.x > 0, "Hunters must start on opposite halves")
	for hunter in hunters:
		expect(hunter.position.distance_to(game.get_node("Player").position) > 1000.0, "Hunters must give the player a safe start")
	var visited: Array[Dictionary] = [{}, {}]
	var own_half: Array[int] = [0, 0]
	for step in range(240):
		for index in range(2):
			var hunter: Node2D = hunters[index]
			var start: int = maze.call("cell_at", hunter.position)
			hunter.call("choose_patrol_target")
			var goal: int = maze.call("cell_at", hunter.get("target"))
			var route: PackedInt64Array = maze.get("graph").get_id_path(start, goal)
			expect(route.size() >= 2 and route.size() <= 5, "Coverage must retain short reachable patrol legs")
			for cell in route: visited[index][cell] = true
			hunter.position = hunter.get("target")
			if hunter.position.x * int(hunter.get("patrol_side")) >= 0: own_half[index] += 1
	for index in range(2):
		expect(visited[index].size() >= 45, "Each hunter must cover many corridors instead of looping near dolls")
		expect(own_half[index] > 140, "Hunters should prefer their assigned halves")
	print("PATROL COVERAGE cells=", [visited[0].size(), visited[1].size()], "; own half=", own_half)
	var mobile: Control = game.get_node("MobileControls/Controls")
	mobile.set("enabled", true)
	mobile.visible = true
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.index = 3
	touch.pressed = true
	touch.position = mobile.call("center", "move")
	mobile.call("_input", touch)
	var drag: InputEventScreenDrag = InputEventScreenDrag.new()
	drag.index = 3
	drag.position = Vector2(mobile.call("center", "move")) + Vector2(65, 0)
	mobile.call("_input", drag)
	expect(Vector2(mobile.get("move_vector")).x > 0.9, "Left touch must move the player")
	touch.index = 4
	touch.position = mobile.call("center", "aim")
	mobile.call("_input", touch)
	drag.index = 4
	drag.position = Vector2(mobile.call("center", "aim")) + Vector2(0, -100)
	mobile.call("_input", drag)
	expect(Vector2(mobile.get("aim_vector")).y < -0.9 and int(mobile.get("move_finger")) == 3, "Aim and movement must support independent fingers")
	var player: CharacterBody2D = game.get_node("Player")
	player.set("facing_angle", 0.0)
	drag.index = 3
	drag.position = Vector2(mobile.call("center", "move")) + Vector2(40, 0)
	mobile.call("_input", drag)
	player.call("_physics_process", 0.016)
	expect(not mobile.get("sprint_requested") and not player.get("sprinting"), "Short stick drags must walk")
	drag.position = Vector2(mobile.call("center", "move")) + Vector2(100, 0)
	mobile.call("_input", drag)
	player.call("_physics_process", 0.016)
	expect(mobile.get("sprint_requested") and player.get("sprinting"), "Dragging past the ring must start sprinting without another finger")
	drag.position = Vector2(mobile.call("center", "move")) + Vector2(76, 0)
	mobile.call("_input", drag)
	expect(mobile.get("sprint_requested"), "Small movement near the boundary must not flicker sprint")
	drag.position = Vector2(mobile.call("center", "move")) + Vector2(65, 0)
	mobile.call("_input", drag)
	expect(not mobile.get("sprint_requested"), "Returning inside the ring must resume walking")
	drag.position = Vector2(mobile.call("center", "move")) + Vector2(100, 0)
	mobile.call("_input", drag)
	touch.index = 3
	touch.pressed = false
	mobile.call("_input", touch)
	expect(not mobile.get("sprint_requested") and Vector2(mobile.get("move_vector")).is_zero_approx(), "Releasing the move finger must stop movement and sprint")
	get_tree_pause(mobile)
	var toggle: InputEventKey = InputEventKey.new()
	toggle.physical_keycode = KEY_M
	toggle.pressed = true
	mobile.call("_input", toggle)
	expect(not mobile.get("enabled") and not game.get_node("HUD").get("mobile_layout"), "M must restore desktop controls and HUD")
	mobile.call("_input", toggle)
	expect(mobile.get("enabled") and game.get_node("HUD").get("mobile_layout"), "Physical M must enable mobile preview in any keyboard layout")
	var editor_stop: InputEventKey = InputEventKey.new()
	editor_stop.keycode = KEY_F8
	editor_stop.pressed = true
	mobile.call("_input", editor_stop)
	expect(mobile.get("enabled"), "The preview must not bind the editor Stop shortcut")
	Input.action_press("move_right")
	player.call("_physics_process", 0.016)
	Input.action_release("move_right")
	expect(player.velocity.x > 0.0, "Keyboard movement must remain available in desktop mobile preview")
	var flashlight_before: bool = player.get("flashlight_on")
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = mobile.call("center", "light")
	mobile.call("_input", click)
	expect(bool(player.get("flashlight_on")) != flashlight_before, "Mouse must activate the mobile flashlight button")
	mobile.call("_input", toggle)
	expect(int(mobile.get("move_finger")) == -1 and not mobile.get("sprint_requested"), "Leaving preview must release held controls")
	print("PATROL AND MOBILE: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)

func get_tree_pause(mobile: Control) -> void:
	paused = true
	mobile.call("_process", 0.016)
	expect(Vector2(mobile.get("move_vector")) == Vector2.ZERO and int(mobile.get("aim_finger")) == -1, "Pausing must release all fingers")
	paused = false
