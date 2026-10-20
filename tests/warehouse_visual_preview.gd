extends SceneTree

var game: Node2D
var player: CharacterBody2D
var maze: Node2D
var camera: Camera2D

func _initialize() -> void:
	call_deferred("capture")

func settle() -> void:
	for frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw

func pose_player(point: Vector2, angle: float) -> void:
	player.set_physics_process(false)
	player.global_position = maze.to_global(point)
	player.velocity = Vector2.ZERO
	player.set("facing_angle", angle)
	player.set("flashlight_on", true)
	player.set("flashlight_reveal", 1.0)
	player.set("flashlight_strength", 1.0)
	player.set("flicker_multiplier", 1.0)
	player.set("flicker_remaining", 0.0)
	var sprite: AnimatedSprite2D = player.get_node("Sprite")
	sprite.global_position = player.global_position
	sprite.rotation = angle - PI * 0.5
	sprite.set_process(false)
	var rig: Node2D = sprite.get_node("ArticulatedBody")
	rig.set("phase", 0.65)
	rig.set("movement", 0.4)
	rig.call("pose")
	player.call("update_flashlight")
	player.reset_physics_interpolation()
	player.set_process(false)
	# Refresh both observer samples after a teleport, preserving the normal mask.
	game.get_node("Visibility").set("pose_initialized", false)
	game.get_node("Visibility").call("capture_pose")
	camera.reset_smoothing()
	camera.force_update_scroll()

func pose_hunter(hunter: CharacterBody2D, point: Vector2, angle: float) -> void:
	hunter.show()
	hunter.set_physics_process(false)
	hunter.set_process(false)
	hunter.set("active", true)
	hunter.global_position = maze.to_global(point)
	hunter.velocity = Vector2.ZERO
	hunter.set("facing_angle", angle)
	var visual: Node2D = hunter.get_node("Visual")
	visual.set_process(false)
	visual.rotation = angle - PI * 0.5
	var rig: Node2D = visual.get_node("ArticulatedBody")
	rig.set("phase", 1.1)
	rig.set("movement", 0.6)
	rig.call("pose")
	hunter.reset_physics_interpolation()

func capture() -> void:
	set_meta("hard_mode", true)
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(10):
		await process_frame
	game = current_scene
	maze = game.get_node("Maze")
	player = game.get_node("Player")
	camera = player.get_node("Camera")
	for hunter in game.get("monsters"):
		hunter.set_physics_process(false)
		hunter.hide()
	game.get_node("HUD").hide()
	root.get_node("RuntimeBudget").mark_focused()
	root.get_node("RuntimeBudget").set_process(false)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.position = Vector2i(-1600, -1200)
	camera.position_smoothing_enabled = false
	# Keep the authored gameplay zoom and the actual player/monster scales.
	camera.position = Vector2(160, 175)
	pose_player(Vector2(-320, 305), 1.20)
	await settle()
	root.get_texture().get_image().save_png("res://.godot/warehouse_gameplay.png")

	# The encounter uses the same warehouse, flashlight and visibility geometry.
	pose_hunter(game.get_node("Monster"), Vector2(-185, 455), -2.05)
	pose_hunter(game.get_node("Stalker"), Vector2(-318, 570), -1.55)
	await settle()
	root.get_texture().get_image().save_png("res://docs/visuals/warehouse_encounter.png")

	# An additional native-scale frame shows all three models beneath a real lamp.
	camera.position = Vector2(0, -80)
	pose_player(Vector2(20, 185), -1.70)
	pose_hunter(game.get_node("Monster"), Vector2(55, 70), 1.9)
	pose_hunter(game.get_node("Stalker"), Vector2(-100, -70), 1.1)
	await settle()
	root.get_texture().get_image().save_png("res://.godot/warehouse_lamp_encounter.png")

	# Retain the uncloaked authoring overview for checking the saved storage layout.
	for hunter in game.get("monsters"):
		hunter.hide()
	camera.position = Vector2(320, 175)
	pose_player(Vector2(-320, 305), 1.20)
	game.get_node("Visibility").hide()
	game.get_node("Visibility").set_process(false)
	game.get_node("Maze/Overhead").hide()
	game.get_node("Haze").hide()
	game.get_node("Vignette").hide()
	player.hide()
	for prop in get_nodes_in_group("warehouse_props"):
		prop.set_process(false)
		var top: Sprite2D = prop.get_node("Surface")
		top.material = null
		top.modulate = Color.WHITE
		top.show()
	var floor_material: ShaderMaterial = game.get_node("Maze/Floor").material
	floor_material.set_shader_parameter("normal_strength", 0.0)
	floor_material.set_shader_parameter("light_origin", Vector2(0, 480))
	floor_material.set_shader_parameter("light_range", 1800.0)
	floor_material.set_shader_parameter("half_fov", PI)
	await settle()
	root.get_texture().get_image().save_png("res://.godot/warehouse_editor_layout.png")
	print("Saved warehouse gameplay, warehouse encounter, lamp encounter and editor layout")
	quit()
