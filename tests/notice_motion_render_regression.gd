extends SceneTree

var moving_player: Node2D
var moving: bool = false

func _initialize() -> void:
	call_deferred("run_checks")

func move_player() -> void:
	if moving:
		moving_player.position += Vector2(310.0, 120.0) / 60.0

func run_checks() -> void:
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(5): await process_frame
	var game: Node = current_scene
	moving_player = game.get_node("Player")
	moving_player.set_physics_process(false)
	game.get_node("Monster").set("active", false)
	game.get_node("Haze").hide()
	moving_player.get_node("Sprite").hide()
	moving_player.get_node("Flashlight").hide()
	var marker: Polygon2D = Polygon2D.new()
	marker.polygon = PackedVector2Array([Vector2(-6, -6), Vector2(6, -6), Vector2(6, 6), Vector2(-6, 6)])
	marker.color = Color.RED
	marker.z_index = 300
	moving_player.add_child(marker)
	moving_player.position = Vector2(12000, 12000)
	moving_player.reset_physics_interpolation()
	moving_player.get_node("Camera").reset_smoothing()
	moving_player.get_node("Camera").force_update_scroll()
	var hud: Node = game.get_node("HUD")
	hud.get("notices").clear()
	hud.get("pending_notices").clear()
	for label in hud.get("notice_labels"): label.text = ""
	hud.call("notify", "motion check", 10.0)
	physics_frame.connect(move_player)
	Engine.max_fps = 240
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	moving = true
	var maximum: float = 0.0
	var samples: int = 0
	for frame in range(130):
		await process_frame
		await RenderingServer.frame_post_draw
		if frame < 20: continue
		var image: Image = root.get_texture().get_image()
		var anchor: Vector2 = hud.get_notice_anchor()
		var sum: Vector2 = Vector2.ZERO
		var count: int = 0
		for y in range(maxi(0, int(anchor.y) - 20), mini(image.get_height(), int(anchor.y) + 20)):
			for x in range(maxi(0, int(anchor.x) - 20), mini(image.get_width(), int(anchor.x) + 20)):
				var color: Color = image.get_pixel(x, y)
				if color.r > 0.8 and color.g < 0.1 and color.b < 0.1:
					sum += Vector2(x + 0.5, y + 0.5)
					count += 1
		if count == 0: continue
		var center: Vector2 = sum / float(count)
		maximum = maxf(maximum, anchor.distance_to(center))
		samples += 1
	moving = false
	print("NOTICE MOTION render samples=%d maximum anchor error=%.3f pixels" % [samples, maximum])
	var passed: bool = samples > 80 and maximum < 1.2
	print("RESULT interpolated moving notification versus rendered marker: %s" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
