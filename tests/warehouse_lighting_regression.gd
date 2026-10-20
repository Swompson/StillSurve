extends SceneTree

var failures: int = 0
var game: Node2D
var maze: Node2D
var player: CharacterBody2D

func expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("check")

func place_player(point: Vector2, angle: float, power: float) -> void:
	player.global_position = maze.to_global(point)
	player.set("facing_angle", angle)
	player.set("flashlight_reveal", 1.0)
	player.set("flashlight_strength", power)
	player.get_node("Sprite").rotation = angle - PI * 0.5
	player.call("update_flashlight")
	player.reset_physics_interpolation()

func check() -> void:
	set_meta("hard_mode", false)
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(8):
		await process_frame
	game = current_scene
	maze = game.get_node("Maze")
	player = game.get_node("Player")
	player.set_physics_process(false)
	player.set_process(false)
	player.get_node("Sprite").set_process(false)
	for hunter in game.get("monsters"):
		hunter.set_physics_process(false)
	for fixture in get_nodes_in_group("ceiling_fixtures"):
		fixture.set_process(false)
		fixture.set("light_power", 0.9)
	var props: Array[Node] = get_nodes_in_group("warehouse_props")
	for prop in props:
		prop.set_process(false)
	var pallet: Node = maze.get_node("Warehouse/Props/LoadedPalletB")
	place_player(Vector2(-100, 218), 0.0, 1.0)
	pallet.call("update_top_lighting")
	expect(Color(pallet.get("top_target")).a > 0.9, "A real flashlight exposes a visible storage top beyond ambient range")
	expect(pallet.get_node("Surface").z_index == 101 and not pallet.get_node("Surface").z_as_relative, "Top renders above fog while its physical shadow remains below it")
	var live_material: ShaderMaterial = pallet.get_node("Surface").material
	var surface: Sprite2D = pallet.get_node("Surface")
	var texture_size: Vector2 = surface.texture.get_size()
	var mask_origin: Vector2 = live_material.get_shader_parameter("surface_origin")
	var mask_x: Vector2 = live_material.get_shader_parameter("surface_axis_x")
	var mask_y: Vector2 = live_material.get_shader_parameter("surface_axis_y")
	expect(mask_origin.is_equal_approx(surface.to_global(surface.offset - texture_size * 0.5)), "The light mask starts at the actual texture corner")
	expect((mask_origin + mask_x + mask_y).is_equal_approx(surface.to_global(surface.offset + texture_size * 0.5)), "Opposite texture pixels receive distinct world positions across the entire scaled prop")
	var probes_before: int = int(pallet.get("top_probe_count"))
	pallet.set("probe_timer", 0.1)
	player.set("facing_angle", 0.37)
	player.set("flashlight_strength", 0.63)
	pallet.call("_process", 0.001)
	expect(is_equal_approx(float(live_material.get_shader_parameter("facing_angle")), 0.37), "Top shader receives the current aim on a render frame between exposure probes")
	expect(is_equal_approx(float(live_material.get_shader_parameter("beam_strength")), 0.63), "Top shader receives current flashlight power between exposure probes")
	expect(Vector2(live_material.get_shader_parameter("light_origin")).is_equal_approx(player.call("get_view_origin_at", player.call("get_render_observer"))), "Top shader receives the current interpolated lens position")
	expect(int(pallet.get("top_probe_count")) == probes_before + 1, "A render-frame exposure check removes corner reveal latency")
	expect(int(live_material.get_shader_parameter("box_count")) > 0, "Visible top pixels receive cached wall occluders instead of revealing the whole texture")
	place_player(Vector2(-100, 218), PI, 1.0)
	pallet.call("update_top_lighting")
	expect(Color(pallet.get("top_target")).a == 0.0, "Turning the real beam away hides storage outside ambient")
	place_player(Vector2(-100, 218), 0.0, 0.0)
	pallet.call("update_top_lighting")
	expect(Color(pallet.get("top_target")).a == 0.0, "An extinguished beam does not expose a distant top")
	var rack: Node = maze.get_node("Warehouse/Props/WestRackB")
	place_player(Vector2(-535, 640), 0.0, 1.0)
	rack.call("update_top_lighting")
	expect(Color(rack.get("top_target")).a == 0.0, "Nearby storage remains hidden across the closed warehouse wall")
	place_player(Vector2(-340, 640), PI, 0.0)
	rack.call("update_top_lighting")
	expect(Color(rack.get("top_target")).a > 0.9, "Nearby storage receives the player's unobstructed ambient light")

	# Exercise a real ceiling lamp independently of flashlight and ambient.
	# Placement is tested separately; isolate exposure from the authored layout.
	maze.get_node("Overhead/Fixtures/CeilingLamp5").position = Vector2(-59, 10)
	pallet.position = Vector2(-30, 80)
	for frame in range(3):
		await physics_frame
	place_player(Vector2(-30, 340), -PI * 0.5, 0.0)
	pallet.call("update_top_lighting")
	expect(Color(pallet.get("top_target")).a == 0.0, "A ceiling lamp cannot reveal an entire top outside the player's visibility mask")
	player.set("flashlight_strength", 1.0)
	pallet.call("update_top_lighting")
	var top_material: ShaderMaterial = pallet.get_node("Surface").material
	expect(float(top_material.get_shader_parameter("lamp_power")) > 0.8, "Top shader uses actual ceiling-lamp power with per-pixel radial falloff")
	for fixture in get_nodes_in_group("ceiling_fixtures"):
		fixture.set("light_power", 0.0)
	player.set("flashlight_strength", 0.0)
	pallet.call("update_top_lighting")
	expect(Color(pallet.get("top_target")).a == 0.0, "Storage cannot glow after all real light sources go dark")
	print("RESULT warehouse lighting: real beam, turned/off beam, wall occlusion, ambient and ceiling lamp: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
