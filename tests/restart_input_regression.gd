extends SceneTree

var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run_checks")

func send_key(code: Key, pressed: bool, repeated: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = repeated
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run_checks() -> void:
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(4): await process_frame
	for attempt in range(4):
		current_scene.get_node("Monster").set("active", false)
		var active_id: int = current_scene.get_instance_id()
		send_key(KEY_R, true)
		send_key(KEY_R, false)
		for frame in range(3): await process_frame
		expect(current_scene.get_instance_id() == active_id, "R during gameplay must not restart")
		send_key(KEY_ESCAPE, true)
		send_key(KEY_ESCAPE, false)
		expect(paused, "Esc must pause before keyboard restart")
		var old_id: int = current_scene.get_instance_id()
		send_key(KEY_R, true)
		for frame in range(6): await process_frame
		expect(is_instance_valid(current_scene), "Holding R must leave a current scene")
		if not is_instance_valid(current_scene):
			quit(1)
			return
		var new_id: int = current_scene.get_instance_id()
		expect(new_id != old_id, "R must restart the run")
		send_key(KEY_R, true, true)
		for frame in range(3): await process_frame
		expect(current_scene.get_instance_id() == new_id, "Held R and key repeat must not restart twice")
		send_key(KEY_R, false)
		expect(not paused, "Restart must leave gameplay unpaused")
		var hud: CanvasLayer = current_scene.get_node("HUD")
		expect(not bool(hud.get("pause_overlay").visible), "Restart must hide pause menu")
		expect(bool(hud.get("status_panel").visible), "Restart must show HUD")
		var player: CharacterBody2D = current_scene.get_node("Player")
		expect(player.get_node("Camera").is_current(), "Restart must activate the new player camera")
		expect(player.is_visible_in_tree(), "Restart must show the new player")
		expect(current_scene.get_node("Visibility").get("fog_mesh").get_surface_count() > 0, "Restart must rebuild visibility mesh")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var image: Image = root.get_texture().get_image()
			var center: Vector2i = image.get_size() / 2
			expect(image.get_pixelv(center).get_luminance() > 0.01, "Restart must render the player at screen center")
			image.save_png("res://.godot/restart_preview.png")
	print("RESULT restart input: %d failure(s)" % failures.size())
	quit(0 if failures.is_empty() else 1)
