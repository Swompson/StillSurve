extends SceneTree

var failures: int = 0

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	set_meta("hard_mode", true)
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(8):
		await physics_frame
		await process_frame
	var game: Node = current_scene
	for hunter in game.monsters: hunter.set_physics_process(false)
	game.player.set_physics_process(false)
	var overhead: Node = game.get_node("Maze/Overhead")
	var fixture: Node2D = overhead.get_node("Fixtures/CeilingLamp1")
	var first: Node2D = game.get_node("Monster")
	first.active = false
	game.get_node("SecondMonster").global_position = fixture.global_position
	game.get_node("Stalker").global_position = fixture.global_position
	fixture.danger_probe = 0.0
	fixture._process(0.1)
	expect(fixture.light_state == 0 and not fixture.danger, "Other monsters never trigger lamp disturbance")
	first.active = true
	first.global_position = fixture.global_position + Vector2(300, 0)
	fixture.danger_probe = 0.0
	fixture.blink_timer = 0.0
	fixture._process(0.1)
	expect(fixture.light_state == 1 and fixture.danger and not fixture.get_node("Housing/Sparks").emitting, "First hunter within 430 triggers strong flicker without sparks")
	first.global_position = fixture.global_position + Vector2(80, 0)
	fixture.danger_probe = 0.0
	fixture.blink_timer = 0.0
	fixture.spark_cooldown = 0.0
	fixture._process(0.1)
	expect(fixture.light_state == 2 and fixture.get_node("Housing/Sparks").emitting, "First hunter within 150 adds sparks")
	first.global_position = fixture.global_position + Vector2(800, 0)
	fixture.danger_probe = 0.0
	fixture._process(0.1)
	expect(fixture.light_state == 0 and not fixture.get_node("Housing/Sparks").emitting, "Leaving restores ordinary flicker and stops new sparks")
	expect(overhead.fixtures.size() == 6 and overhead.shadow_texture.get_height() == 6, "All six fixtures have shadow-map rows")
	var bunker: Node2D = overhead.get_node("Fixtures/WallLampUpperLeft")
	expect(bunker.position.x < -1000 and bunker.position.y < -1000 and bunker.fixture_kind == "bunker", "Sixth lamp is a wall bunker fixture in the upper-left zone")
	var variants: Dictionary = {}
	for pile in game.get_node("Maze/CorridorDetails").get_children():
		if not pile.has_method("build_surface"): continue
		var surface: Node = pile.get_node("Surface")
		expect(surface is Sprite2D and pile.has_node("Collision"), "Authored rubble sprites preserve their physical cover")
		variants[pile.visual_variant] = true
	expect(variants.size() == 4, "All four rubble textures are used")
	var stalker: Node = game.get_node("Stalker")
	for cell in [0, 30, 60, 90, 120]:
		game.player.global_position = game.get_node("Maze").cell_position(cell)
		stalker.plan_ambush()
		var distances: Array[float] = []
		for pickup in game.get_node("Maze/Pickups").get_children():
			if not pickup.collected: distances.append(game.player.global_position.distance_squared_to(pickup.global_position))
		distances.sort()
		expect(is_equal_approx(distances[1], game.player.global_position.distance_squared_to(stalker.ambush_objective.global_position)), "Ambush chooses the second-closest uncollected pickup to the player")
	for lamp in overhead.fixtures:
		if lamp.fixture_kind == "bunker": continue
		expect(lamp.z_index < 0 and not lamp.has_node("Suspension") and not lamp.has_node("MountClamp"), "Lamp is below pipes and beams with no holders")
		if lamp.fixture_kind == "fluorescent": expect("fluorescent_top" in lamp.get_node("Housing/Lens").texture.resource_path, "Fluorescent lamp shows its upper metal case")
	var vignette: CanvasLayer = game.get_node("Vignette")
	expect(vignette.layer < game.get_node("HUD").layer and vignette.get_node("Edges").mouse_filter == Control.MOUSE_FILTER_IGNORE, "Vignette darkens the world without dimming HUD or blocking input")
	print("RESULT first-monster lamp states, six lights, rubble variants, nearest ambush and vignette: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
