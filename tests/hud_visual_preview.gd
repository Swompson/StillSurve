extends SceneTree

func _initialize() -> void:
	call_deferred("run_preview")

func run_preview() -> void:
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(4): await process_frame
	var game: Node = current_scene
	var player: Node2D = game.get_node("Player")
	var hud: CanvasLayer = game.get_node("HUD")
	game.get_node("Monster").set("active", false)
	player.set_physics_process(false)
	player.global_position = game.get_node("Maze").cell_position(60)
	player.reset_physics_interpolation()
	player.set("facing_angle", PI * 0.5)
	player.set("flashlight_strength", 1.0)
	player.set("flashlight_reveal", 1.0)
	player.call("update_flashlight")
	player.get_node("Camera").position_smoothing_enabled = false
	player.get_node("Camera").reset_smoothing()
	player.get_node("Camera").force_update_scroll()
	game.get_node("Visibility").set("pose_initialized", false)
	game.get_node("Visibility").capture_pose()
	for label in hud.get("notice_labels"): label.text = ""
	hud.get("notices").clear()
	hud.get("pending_notices").clear()
	hud.call("notify_pickup", "+20 заряда · +10 максимальной выносливости", 3.0)
	hud.call("notify", "выдохся", 2.4)
	hud.call("notify", "вас увидели", 2.8)
	for frame in range(8):
		await physics_frame
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/hud_preview.png")
	hud.call("set_paused", true)
	for frame in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/pause_preview.png")
	var exit_button: Button = hud.find_child("QuitPause", true, false)
	assert(exit_button.pressed.is_connected(hud._quit))
	print("RESULT HUD and pause previews saved; exit button connected")
	quit()
