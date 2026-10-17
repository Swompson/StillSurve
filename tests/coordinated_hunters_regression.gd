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
	var hunters: Array[CharacterBody2D] = [game.get_node("Monster"), game.get_node("SecondMonster")]
	game.get_node("Player").set_physics_process(false)
	for hunter in hunters:
		hunter.set_physics_process(false)
	# A square has two genuine approaches to the noise; Euclidean distance ties.
	var graph: AStar2D = maze.get("graph")
	graph.clear()
	for cell in [0, 1, 11, 12]:
		graph.add_point(cell, maze.call("cell_position", cell))
	for edge in [Vector2i(0, 1), Vector2i(1, 12), Vector2i(12, 11), Vector2i(11, 0)]:
		graph.connect_points(edge.x, edge.y)
	var noise: Vector2 = maze.call("cell_position", 0)
	hunters[0].global_position = maze.call("cell_position", 1)
	hunters[1].global_position = maze.call("cell_position", 12)
	var previous: Array[Vector2] = []
	for hunter in hunters:
		hunter.set("state", "patrol")
		hunter.set("has_saved_patrol", false)
		hunter.set("disengage_timer", 0.0)
		hunter.set("target", maze.call("cell_position", 11))
		previous.append(hunter.get("target"))
	game.call("step_on_glass", noise)
	expect(hunters[0].get("state") == "investigate" and hunters[1].get("state") == "investigate", "Both hunters must investigate glass")
	var alternate: PackedVector2Array = hunters[1].get("investigation_route")
	expect(not alternate.is_empty(), "Farther hunter must receive an alternate route")
	expect(PackedVector2Array(hunters[0].get("investigation_route")).is_empty(), "Nearer hunter must keep the direct route")
	expect(alternate.size() == 3 and alternate[1] == maze.call("cell_position", 11), "Farther hunter must approach from the other corridor")
	expect(graph.are_points_connected(0, 1), "Shared navigation graph must be restored")
	hunters[1].call("rebuild_path", 0)
	expect(hunters[1].call("navigation_destination") == maze.call("cell_position", 11), "Navigation must preserve the alternate waypoint")
	hunters[1].call("hear_noise", noise, 12000.0)
	expect(hunters[1].get("investigation_route") == alternate, "Repeated noise must preserve the flank")
	for index in range(2):
		hunters[index].call("choose_patrol_target")
		expect(hunters[index].get("target") == previous[index], "Unsuccessful search must resume the previous patrol")
		hunters[index].call("remember_patrol")
		hunters[index].set("state", "hunt")
		hunters[index].call("begin_investigation", noise)
		hunters[index].call("choose_patrol_target")
		expect(hunters[index].get("target") == previous[index], "Lost chase must resume the previous patrol")
	# Roles depend on current route distance, never on the monster's scene name.
	hunters[0].global_position = maze.call("cell_position", 12)
	hunters[1].global_position = maze.call("cell_position", 1)
	game.call("step_on_glass", noise)
	expect(not PackedVector2Array(hunters[0].get("investigation_route")).is_empty(), "First hunter must flank when it is farther away")
	expect(PackedVector2Array(hunters[1].get("investigation_route")).is_empty(), "Second hunter must go directly when it is nearer")
	# A dead end cannot offer a second approach and must not damage navigation.
	graph.disconnect_points(0, 11)
	var direct: PackedVector2Array = maze.call("find_path", hunters[1].global_position, noise)
	var unavailable: PackedVector2Array = maze.call("find_alternate_path", hunters[1].global_position, noise, direct)
	expect(unavailable.is_empty() and graph.are_points_connected(0, 1), "Dead end must fall back safely and restore its edge")
	print("COORDINATED HUNTERS: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
