extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	set_meta("hard_mode", true)
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(6): await process_frame
	var game: Node2D = current_scene
	var player: CharacterBody2D = game.get_node("Player")
	var stalker: CharacterBody2D = game.get_node("Stalker")
	var hud: Node = game.get_node("HUD")
	for hunter in game.get("monsters"): hunter.set_physics_process(false)
	player.set_physics_process(false)
	player.global_position = game.get_node("Maze").cell_position(60)
	player.facing_angle = 0.0
	player.flashlight_reveal = 1.0
	player.flashlight_strength = 1.0
	player.update_mouse_aim(0.0)
	player.update_flashlight()
	player.reset_physics_interpolation()
	stalker.global_position = player.global_position - Vector2(42, 0)
	stalker.grab_offset = Vector2(-42, 0)
	stalker.facing_angle = 0.0
	stalker.get_node("Visual").rotation = -PI * 0.5
	stalker.begin_grab()
	stalker.attack_elapsed = 0.6
	stalker.check_phase = 0.12
	stalker.green_center = 0.72
	stalker.get_node("Visual/ArticulatedBody").pose()
	player.grab_clock = 0.6
	player.get_node("Sprite/ArticulatedBody").pose()
	stalker.reset_physics_interpolation()
	var camera: Camera2D = player.get_node("Camera")
	camera.position_smoothing_enabled = false
	camera.zoom = Vector2(1.25, 1.25)
	camera.reset_smoothing()
	camera.force_update_scroll()
	for frame in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/hardcore_grab.png")
	hud.set_paused(true)
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/hardcore_pause.png")
	hud.set_paused(false)
	hud.hide()
	game.get_node("Visibility").hide()
	game.get_node("Haze").hide()
	player.hide()
	for hunter in game.get("monsters"):
		if hunter != stalker: hunter.hide()
	stalker.state = "stalk"
	stalker.global_position = player.global_position
	stalker.get_node("Visual").rotation = 0.0
	var rig: Node2D = stalker.get_node("Visual/ArticulatedBody")
	rig.preview_mode = true
	rig.pose()
	camera.zoom = Vector2(3.6, 3.6)
	camera.force_update_scroll()
	for frame in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/stalker_body_preview.png")
	print("Saved hardcore grab, pause and authored body previews")
	quit()
