extends SceneTree

class Hero extends CharacterBody2D:
	var facing_angle: float = 0.0
	var flashlight_on: bool = false
	var flashlight_strength: float = 0.0
	var visible_points: bool = false
	func is_point_visible(_point: Vector2) -> bool: return visible_points

class World extends Node2D:
	var open: bool = true
	func clear_line(_from: Vector2, _to: Vector2) -> bool: return open
	func can_walk_line(_from: Vector2, _to: Vector2) -> bool: return open

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var hero: Hero = Hero.new()
	var world: World = World.new()
	root.add_child(hero)
	root.add_child(world)
	var nav: AStar2D = load("res://scripts/actors/stalker_navigation.gd").new()
	nav.maze = world
	var points: Array[Vector2] = [Vector2(-400, 0), Vector2.ZERO, Vector2(400, 0), Vector2(-400, 400), Vector2(0, 400), Vector2(400, 400)]
	for index in range(points.size()):
		nav.add_point(index, points[index])
		nav.exposure[index] = 0.0
	for edge in [[0, 1], [1, 2], [0, 3], [3, 4], [4, 5], [5, 2]]: nav.connect_points(edge[0], edge[1])
	assert(nav.route(points[0], points[2]).has(Vector2.ZERO), "Ordinary shortest route reproduces the pass-by bug")
	var route: PackedVector2Array = nav.concealed_route(points[0], points[2], hero)
	assert(not route.is_empty() and not route.has(Vector2.ZERO), "Ambush takes the safe outer detour")
	var previous: Vector2 = points[0]
	for point in route:
		assert(nav.concealed_segment(previous, point, hero))
		previous = point
	assert(not nav.is_point_disabled(1), "Temporary exclusions never damage shared navigation")
	assert(not nav.concealed_segment(Vector2(-400, 100), Vector2(400, 100), hero), "A long shortcut cannot cut through the player exclusion zone")
	var hunter: CharacterBody2D = load("res://scripts/actors/stalker_controller.gd").new()
	hunter.maze = world
	hunter.player = hero
	hunter.navigation = nav
	hunter.position = points[0]
	hunter.strategy = "ambush"
	hunter.path = route
	hunter.path_index = 1
	assert(hunter.next_destination(points[2]) == points[3], "Controller preserves the detour even when a direct dark shortcut exists")
	hero.position = Vector2(-400, 380)
	assert(not nav.concealed_segment(points[0], points[3], hero), "Moving the player into the detour invalidates it immediately")
	hero.position = Vector2.ZERO
	nav.disconnect_points(3, 4)
	assert(nav.concealed_route(points[0], points[2], hero).is_empty(), "A route that only passes beside the player is rejected")
	hunter.velocity = Vector2(700, 0)
	hunter.abandon_ambush()
	assert(hunter.strategy == "sneak" and hunter.velocity == Vector2.ZERO and hunter.path.is_empty(), "Unsafe transit stops and becomes cautious stalking")
	hero.visible_points = true
	hero.facing_angle = 0.2
	assert(nav.concealed_route(points[0], points[2], hero).is_empty(), "A visible relocation cannot use the unseen sprint")
	hunter.free()
	hero.free()
	world.free()
	set_meta("hard_mode", true)
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(8): await physics_frame
	var game: Node = current_scene
	game.player.set_physics_process(false)
	for actor in game.monsters: actor.set_physics_process(false)
	var stalker: CharacterBody2D = game.get_node("Stalker")
	var checked: bool = false
	for cell in range(121):
		var center: Vector2 = game.maze.cell_position(cell)
		var start: Vector2 = center + Vector2(80, 0)
		var target: Vector2 = center - Vector2(80, 0)
		if not game.maze.can_walk_line(start, target): continue
		game.player.global_position = center
		game.player.flashlight_on = false
		game.player.flashlight_strength = 0.0
		stalker.global_position = start
		stalker.state = "stalk"
		stalker.strategy = "ambush"
		stalker.ambush_planned = true
		stalker.ambush_ready = false
		stalker.ambush_objective = game.maze.get_node("Pickups").get_child(0)
		stalker.ambush_target = target
		stalker.attack_cooldown = 0.0
		stalker.strategy_pending = false
		stalker.path_timer = 0.0
		stalker.sense_timer = 10.0
		stalker.flashlight_contact = false
		stalker.lamp_contact = false
		stalker.light_contact = 0.0
		stalker._physics_process(1.0 / 60.0)
		assert(stalker.global_position == start and stalker.strategy == "sneak", "Actual physics cancels a pass-by ambush before moving beside the player")
		checked = true
		break
	assert(checked, "A real open corridor was used for the pass-by reproduction")
	print("RESULT concealed ambush detours, no close pass, safe shortcuts, moving player, blocked routes and cautious fallback: passed")
	quit()
