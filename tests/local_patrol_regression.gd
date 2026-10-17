extends SceneTree

var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	set_meta("hard_mode", false)
	change_scene_to_file("res://scenes/game.tscn")
	await process_frame
	await physics_frame
	var game: Node = current_scene
	var maze: Node = game.get_node("Maze")
	var graph: AStar2D = maze.get("graph")
	var hunter: CharacterBody2D = game.get_node("Monster")
	for actor in [hunter, game.get_node("SecondMonster"), game.get_node("Player")]:
		actor.set_physics_process(false)
	var max_edges: int = 0
	for cell in range(121):
		hunter.global_position = maze.call("cell_position", cell)
		hunter.set("has_saved_patrol", false)
		hunter.call("choose_patrol_target")
		var goal: int = maze.call("cell_at", hunter.get("target"))
		var route: PackedInt64Array = graph.get_id_path(cell, goal)
		expect(goal != cell and route.size() >= 2 and route.size() <= 5, "Every patrol leg must be reachable within four corridors")
		max_edges = maxi(max_edges, route.size() - 1)
		expect(hunter.get("recent_patrol_cells").size() <= 6, "Patrol history must remain bounded")
	# A nearby figurine should attract patrol to its area without requiring its cell.
	graph.clear()
	for cell in range(5):
		graph.add_point(cell, maze.call("cell_position", cell))
		if cell > 0:
			graph.connect_points(cell - 1, cell)
	for pickup in maze.get_node("Pickups").get_children():
		pickup.set("collected", true)
	var doll: Node2D = maze.get_node("Pickups/Figurine01")
	doll.set("collected", false)
	doll.global_position = maze.call("cell_position", 3)
	hunter.set("previous_patrol_cell", -1)
	game.get_node("SecondMonster").set("target", maze.call("cell_position", 0))
	hunter.get("recent_patrol_cells").clear()
	for sample in range(20):
		expect(hunter.call("local_patrol_cell", 0) == 2, "Patrol should choose the shorter nearby approach instead of visiting every doll")
	graph.disconnect_points(1, 2)
	expect(hunter.call("local_patrol_cell", 0) == 1, "Dead ends must allow the only reachable exit")
	graph.disconnect_points(0, 1)
	expect(hunter.call("local_patrol_cell", 0) == 0, "Isolated cells must not create unreachable goals")
	print("LOCAL PATROL: ", "PASS" if failures.is_empty() else failures, "; max corridors=", max_edges)
	quit(0 if failures.is_empty() else 1)
