extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func measure(label: String, operation: Callable, count: int) -> void:
	var durations: Array[float] = []
	for sample in range(count):
		var started: int = Time.get_ticks_usec()
		operation.call()
		durations.append(float(Time.get_ticks_usec() - started) / 1000.0)
	durations.sort()
	print("CLOSE MONSTER CPU %s median=%.3f ms p95=%.3f ms max=%.3f ms samples=%d" % [label, durations[count / 2], durations[mini(count - 1, int(count * 0.95))], durations[-1], count])

func run() -> void:
	seed(31018)
	set_meta("hard_mode", true)
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(8): await physics_frame
	var game: Node = current_scene
	game.immortal = true
	var player: CharacterBody2D = game.get_node("Player")
	var stalker: CharacterBody2D = game.get_node("Stalker")
	var maze: Node2D = game.get_node("Maze")
	var visibility: Node2D = game.get_node("Visibility")
	player.set_physics_process(false)
	for hunter in game.monsters: hunter.set_physics_process(false)
	visibility.set_process(false)
	visibility.set_physics_process(false)
	player.flashlight_on = false
	player.flashlight_strength = 0.0
	player.global_position = maze.cell_position(60)
	stalker.global_position = player.global_position + Vector2(120, 0)
	measure("retreat planning", stalker.choose_flee_target, 40)
	measure("weighted route", func(): stalker.navigation.route(stalker.global_position, maze.cell_position(0)), 120)
	stalker.begin_flee(20.0)
	measure("nearby retreat tick", func(): stalker._physics_process(1.0 / 60.0), 600)
	stalker.state = "stalk"
	stalker.strategy = "sneak"
	stalker.attack_cooldown = 0.0
	stalker.stalking.reset()
	stalker.global_position = player.global_position + Vector2(280, 0)
	player.facing_angle = 0.0
	measure("nearby approach target", func(): stalker.stalking.target(stalker), 120)
	var hunter: CharacterBody2D = game.get_node("Monster")
	hunter.global_position = player.global_position + Vector2(170, 0)
	hunter.state = "hunt"
	hunter.memory = 100.0
	hunter.last_known = player.global_position
	measure("nearby hunter tick", func(): hunter._physics_process(1.0 / 60.0), 600)
	print("CLOSE MONSTER CPU benchmark complete")
	quit()
