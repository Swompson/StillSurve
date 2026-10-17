extends SceneTree

var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	set_meta("hard_mode", true)
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(6):
		await physics_frame
	var game: Node = current_scene
	var stalker: CharacterBody2D = game.get_node("Stalker")
	var player: CharacterBody2D = game.get_node("Player")
	var hud: Node = game.get_node("HUD")
	var maze: Node = game.get_node("Maze")
	for actor in game.get("monsters"):
		actor.set_physics_process(false)
	player.set_physics_process(false)
	player.set("battery", 0.0)
	player.set("flashlight_on", false)
	player.set("stamina_max", 100.0)
	player.set("stamina", 100.0)
	stalker.call("begin_grab")
	stalker.call("resolve_check", true)
	expect(player.get("stamina_max") == 96.0 and player.get("stamina") == 96.0, "Success with empty battery must reduce maximum stamina by four")
	stalker.call("resolve_check", false)
	expect(player.get("stamina_max") == 86.0, "Miss with empty battery must reduce maximum stamina by ten")
	var entries: Array = hud.get("notices") + hud.get("pending_notices")
	var found: bool = false
	for entry in entries:
		if String(entry.text).begins_with("ПРОМАХ"):
			found = entry.get("color") == Color("f17a70") and String(entry.text).contains("МАКС. ВЫНОСЛИВОСТИ")
	expect(found, "Results must enter the bonus notification queue in red")
	player.set("stamina_max", 3.0)
	stalker.call("resolve_check", false)
	expect(player.get("stamina_max") == 1.0 and player.get("stamina") <= 1.0, "Maximum stamina must remain positive and current stamina must be clamped")
	player.set("exhausted", true)
	player.call("restore_stamina", 1.0)
	expect(not player.get("exhausted"), "Reduced stamina capacity must not permanently lock exhaustion")
	stalker.call("begin_flee", 6.0)
	var origin: Vector2 = maze.call("cell_position", 60)
	stalker.global_position = origin
	player.global_position = origin + Vector2(55, 0)
	stalker.set("flee_target", origin)
	stalker.set("attack_cooldown", 10.0)
	stalker.set("retreat_refresh", 0.0)
	stalker.set("sense_timer", 0.0)
	player.set("flashlight_on", true)
	player.set("flashlight_strength", 1.0)
	player.set("facing_angle", PI)
	expect(stalker.call("is_illuminated"), "Close flashlight must repel the hunter even behind its offset light origin")
	stalker.call("_physics_process", 1.0 / 60.0)
	expect(Vector2(stalker.get("flee_target")).distance_to(origin) > 100.0, "Hunter at its retreat goal must select a new destination when followed")
	expect(stalker.get("state") == "flee", "Light must remain effective during the post-attack cooldown")
	print("GRAB FEEDBACK AND RETREAT: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
