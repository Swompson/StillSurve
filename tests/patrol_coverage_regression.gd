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
	print("PATROL COVERAGE: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
