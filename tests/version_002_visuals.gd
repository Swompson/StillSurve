extends SceneTree

var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run_checks")

func settle() -> void:
	for index in range(8):
		await process_frame
		await physics_frame

func capture(path: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(path)

func run_checks() -> void:
	change_scene_to_file("res://scenes/game.tscn")
	await settle()
	var game: Node2D = current_scene
	var player: CharacterBody2D = game.get_node("Player")
	var monster: CharacterBody2D = game.get_node("Monster")
	var visibility: Node2D = game.get_node("Visibility")
	var haze: CanvasLayer = game.get_node("Haze")
	player.set_physics_process(false)
	monster.set("active", false)
	monster.set_physics_process(false)
	var wall: Node2D
	for candidate in game.get_node("Maze/Walls").get_children():
		if not candidate.get("damaged") and candidate.get("wall_size").x > 100.0:
			wall = candidate
			break
	player.global_position = wall.global_position - Vector2(0, 140)
	player.reset_physics_interpolation()
	player.set("facing_angle", PI * 0.5)
	player.set("flashlight_on", true)
	player.set("flashlight_reveal", 1.0)
	player.set("flashlight_strength", 1.0)
	player.get_node("Sprite").rotation = 0.0
	player.call("update_flashlight")
	var camera: Camera2D = player.get_node("Camera")
	camera.reset_smoothing()
	camera.force_update_scroll()
	monster.global_position = player.global_position + Vector2(100, -50)
	monster.reset_physics_interpolation()
	monster.set("facing_angle", PI * 0.5)
	await settle()
	visibility.call("refresh_visibility", false)
	var surface: Array = visibility.get("fog_mesh").surface_get_arrays(0)
	var vertices: PackedVector2Array = surface[Mesh.ARRAY_VERTEX]
	var origin: Vector2 = visibility.global_position
	var space: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
	var blocked_rays: int = 0
	for index in range(1, vertices.size() - 1, 3):
		var endpoint: Vector2 = origin + vertices[index]
		var direction: Vector2 = origin.direction_to(endpoint)
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(origin, endpoint + direction * 4.0, 2)
		var hit: Dictionary = space.intersect_ray(query)
		if not hit.is_empty():
			blocked_rays += 1
			expect(origin.distance_to(endpoint) <= origin.distance_to(hit.position) + 0.05, "Cone must stop before the first wall face")
	expect(blocked_rays > 10, "Wall occlusion checks must exercise multiple blocked rays")
	expect(wall.z_index < visibility.z_index, "Unseen concrete must be covered by the darkness mask")
	var before: PackedVector2Array = vertices.duplicate()
	haze.hide()
	visibility.call("refresh_visibility", false)
	var after: Array = visibility.get("fog_mesh").surface_get_arrays(0)
	expect(before == after[Mesh.ARRAY_VERTEX], "Atmospheric haze must not change light occlusion")
	haze.show()
	expect(player.get_node("FlashlightSwitch").max_polyphony > 1, "Rapid switching must retain click tails")
	var visual: Node2D = monster.get_node("Visual")
	var monster_rig: Node2D = visual.get("rig")
	expect(monster_rig.has_node("LeftFoot") and not monster_rig.has_node("LeftShin"), "Overhead monster must show feet without intermediate leg parts")
	await capture("res://.godot/v002_light.png")
	player.set("flashlight_on", false)
	player.set("flashlight_reveal", 0.0)
	player.set("flashlight_strength", 0.0)
	player.call("update_flashlight")
	await settle()
	await capture("res://.godot/v002_dark.png")
	player.set("flashlight_reveal", 0.25)
	player.call("update_flashlight")
	var tucked: Vector2 = player.get_node("Flashlight").global_position
	player.set("flashlight_reveal", 0.75)
	player.call("update_flashlight")
	var raised: Vector2 = player.get_node("Flashlight").global_position
	expect(tucked.distance_to(raised) > 10.0, "Drawing the flashlight must animate its position")
	var sprite: AnimatedSprite2D = player.get_node("Sprite")
	player.velocity = Vector2(180, 0)
	player.set("sprinting", false)
	sprite.call("_process", 1.0 / 60.0)
	var cycle_before: float = float(sprite.get("cycle"))
	player.set("sprinting", true)
	sprite.call("_process", 1.0 / 60.0)
	expect(float(sprite.get("cycle")) > cycle_before, "Walk/run transition must retain gait phase")
	expect(float(sprite.get("run_blend")) > 0.0 and float(sprite.get("run_blend")) < 1.0, "Walk/run poses must blend instead of switching instantly")
	var reveal_before: float = float(player.get("flashlight_reveal"))
	player.call("toggle_flashlight")
	player.call("toggle_flashlight")
	expect(is_equal_approx(float(player.get("flashlight_reveal")), reveal_before), "Rapid toggling must not snap the hand pose")
	player.velocity = Vector2.ZERO
	game.get_node("HUD").hide()
	visibility.hide()
	camera.zoom = Vector2(2.8, 2.8)
	camera.position_smoothing_enabled = false
	camera.global_position = monster.global_position
	camera.force_update_scroll()
	await settle()
	await capture("res://.godot/v002_monster.png")
	print("RESULT v0.0.2 light, walls, haze, flashlight and monster: %d failure(s)" % failures.size())
	quit(0 if failures.is_empty() else 1)
