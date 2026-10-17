extends SceneTree
var failures: int = 0
func expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run_checks")
func settle() -> void:
	for frame in range(5):
		await process_frame
		await RenderingServer.frame_post_draw
func luminance_at(point: Vector2) -> float:
	var screen: Vector2 = root.get_canvas_transform() * point
	var image: Image = root.get_texture().get_image()
	var color: Color = image.get_pixelv(Vector2i(screen))
	return color.r * 0.299 + color.g * 0.587 + color.b * 0.114
func run_checks() -> void:
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(8): await process_frame
	var game: Node = current_scene
	var player: Node2D = game.get_node("Player")
	player.set_physics_process(false)
	for hunter in game.get("monsters"):
		hunter.set_physics_process(false)
		hunter.set("state", "patrol")
		hunter.set("disengage_timer", 0.0)
	game.call("step_on_glass", player.global_position, false)
	for hunter in game.get("monsters"):
		expect(hunter.get("state") == "investigate", "Monster glass crunch is heard by other hunters")
	game.call("step_on_glass", player.global_position)
	for hunter in game.get("monsters"):
		expect(hunter.get("state") == "investigate", "Player glass crunch still alerts hunters")
		hunter.set("active", false)
		hunter.hide()
	var cover_count: int = 0
	for pile in game.get_node("Maze/CorridorDetails").get_children():
		if String(pile.name).begins_with("CornerCover"):
			cover_count += 1
			expect(pile.has_node("Collision") and pile.is_in_group("vision_blockers"), "Corner cover blocks bodies and sight")
	expect(cover_count == 12, "Twelve extra authored corner hiding piles")
	expect(player.get_node("Sprite").z_index + 4 < game.get_node("Maze/Overhead").z_index, "Ceiling stays above player head")
	game.get_node("HUD").hide()
	game.get_node("Haze").hide()
	player.hide()
	var origin: Vector2 = Vector2(12000, 12000)
	var fixture: Node2D = game.get_node("Maze/Overhead/Fixtures/CeilingLamp1")
	fixture.global_position = origin
	fixture.set("blink_timer", 100.0)
	fixture.set("dark_remaining", 0.0)
	player.global_position = origin + Vector2(0, 350)
	player.set("flashlight_on", false)
	player.set("flashlight_strength", 0.0)
	player.set("flashlight_reveal", 0.0)
	var camera: Camera2D = player.get_node("Camera")
	camera.position_smoothing_enabled = false
	camera.zoom = Vector2.ONE
	camera.position = Vector2(0, -170)
	camera.force_update_scroll()
	player.reset_physics_interpolation()
	var floor_patch: Polygon2D = Polygon2D.new()
	floor_patch.polygon = PackedVector2Array([Vector2(-600, -600), Vector2(600, -600), Vector2(600, 600), Vector2(-600, 600)])
	floor_patch.position = origin
	floor_patch.color = Color(0.7, 0.7, 0.7)
	floor_patch.z_index = -25
	game.add_child(floor_patch)
	await settle()
	var lit: float = luminance_at(origin + Vector2(0, 70))
	expect(lit > 0.30, "Lamp reveals its floor pool without a flashlight beyond player ambient radius")
	root.get_texture().get_image().save_png("res://docs/visuals/lamp_without_flashlight.png")
	var wall: Node2D = load("res://scenes/world/wall.tscn").instantiate()
	wall.set("wall_size", Vector2(24, 180))
	wall.position = origin + Vector2(80, -50)
	game.add_child(wall)
	await settle()
	var shadow: float = luminance_at(origin + Vector2(150, 0))
	expect(shadow < 0.06, "Lamp glow and pool stop behind a wall even in observer line of sight")
	root.get_texture().get_image().save_png("res://docs/visuals/lamp_wall_shadow.png")
	wall.position = origin + Vector2(0, 175)
	wall.set("wall_size", Vector2(500, 24))
	await settle()
	var hidden: float = luminance_at(origin + Vector2(0, 20))
	expect(hidden < 0.03, "Lamp body and halo disappear together behind observer occlusion")
	print("RESULT lamp visibility, shadows, ceiling order, glass ownership and cover: %d failure(s); lit=%.3f shadow=%.3f hidden=%.3f" % [failures, lit, shadow, hidden])
	quit(0 if failures == 0 else 1)
