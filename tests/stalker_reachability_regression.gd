extends SceneTree

const NAVIGATION = preload("res://scripts/actors/stalker_navigation.gd")
var failures: int = 0

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func legacy_retreat_target(hunter: Node2D) -> Vector2:
	# Preserve the previous exhaustive A* checks as an independent behavior oracle.
	var maze: Node2D = hunter.maze
	var navigation: AStar2D = hunter.navigation
	var best: float = -INF
	var chosen: Vector2 = hunter.flee_target
	var start: int = navigation.get_closest_point(hunter.global_position)
	for cell in range(int(maze.width) * int(maze.height)):
		var point: Vector2 = maze.cell_position(cell)
		var distance: float = hunter.global_position.distance_to(point)
		if distance < 420.0 or distance > 1250.0 or navigation.lamp_exposure(point) > 0.1: continue
		if navigation.get_id_path(start, navigation.get_closest_point(point)).is_empty(): continue
		var score: float = point.distance_to(hunter.player.global_position) - distance * 0.32
		if score > best:
			best = score
			chosen = point
	if best == -INF:
		for id in navigation.get_point_ids():
			var point: Vector2 = navigation.get_point_position(id)
			if hunter.global_position.distance_to(point) < 100.0 or navigation.get_id_path(start, id).is_empty(): continue
			var score: float = point.distance_to(hunter.player.global_position) - navigation.lamp_exposure(point) * 1500.0
			if score > best:
				best = score
				chosen = point
	return chosen

func run() -> void:
	var disconnected: AStar2D = NAVIGATION.new()
	for id in range(4): disconnected.add_point(id, Vector2(id * 100, 0))
	disconnected.connect_points(0, 1)
	disconnected.connect_points(2, 3)
	disconnected.build_connected_components()
	expect(disconnected.has_route(0, 1) and disconnected.has_route(2, 3), "Connected samples remain reachable")
	expect(not disconnected.has_route(0, 2) and not disconnected.has_route(-1, 0), "Disconnected or missing samples stay unreachable")
	set_meta("hard_mode", true)
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(6): await physics_frame
	var game: Node = current_scene
	var stalker: CharacterBody2D = game.get_node("Stalker")
	var player: CharacterBody2D = game.get_node("Player")
	var maze: Node2D = game.get_node("Maze")
	player.set_physics_process(false)
	for hunter in game.monsters: hunter.set_physics_process(false)
	var samples: int = 0
	for cell in range(0, 121, 7):
		stalker.global_position = maze.cell_position(cell)
		player.global_position = maze.cell_position((cell + 11) % 121)
		stalker.choose_flee_target()
		expect(stalker.flee_target == legacy_retreat_target(stalker), "Retreat target keeps the original light and distance ranking in cell %d" % cell)
		var start: int = stalker.navigation.get_closest_point(stalker.global_position)
		for target_cell in range(0, 121, 11):
			var end: int = stalker.navigation.get_closest_point(maze.cell_position(target_cell))
			expect(stalker.navigation.has_route(start, end) == not stalker.navigation.get_id_path(start, end).is_empty(), "Cached connectivity matches the actual weighted navigation graph")
			samples += 1
	print("STALKER REACHABILITY: %d graph pairs, 18 retreat targets; %d failure(s)" % [samples, failures])
	quit(0 if failures == 0 else 1)
