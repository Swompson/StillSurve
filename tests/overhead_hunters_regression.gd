extends SceneTree
var failures: int = 0
func expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run_checks")
func run_checks() -> void:
	for hard in [false, true]:
		set_meta("hard_mode", hard)
		change_scene_to_file("res://scenes/game.tscn")
		for frame in range(5): await process_frame
		var game: Node = current_scene
		var player: Node2D = game.get_node("Player")
		player.set_physics_process(false)
		var hunters: Array = game.get("monsters")
		expect(hunters.size() == 2, "Both modes start with exactly two authored hunters")
		for hunter in hunters:
			hunter.set_physics_process(false)
			expect(is_equal_approx(hunter.get("hearing_multiplier"), 1.22 if hard else 1.0), "Balanced hard hearing multiplier")
			expect(is_equal_approx(hunter.get("field_of_view"), 125.0 if hard else 105.0), "Mode-specific sight width")
		var battery_points: Array[Vector2] = []
		for pickup in game.get_node("Maze/Pickups").get_children():
			if pickup.get("kind") == "battery": battery_points.append(pickup.position)
		expect(battery_points.size() == (4 if hard else 5), "Correct battery count for mode")
		for a in range(battery_points.size()):
			for b in range(a): expect(battery_points[a].distance_to(battery_points[b]) > 1300.0, "Batteries spread throughout map")
		var voice: Node = hunters[0].get_node("Growl")
		voice.set("last_howl_interval", -1.0)
		var previous: float = -1.0
		for sample in range(1000):
			var interval: float = voice.call("choose_howl_interval")
			expect(interval >= 26.0 and interval <= 40.0, "Howl interval bounds")
			expect(previous < 0.0 or absf(interval - previous) >= 4.99999, "Successive howl intervals differ by at least five seconds")
			previous = interval
		var fixtures: Array[Node] = get_nodes_in_group("ceiling_fixtures")
		expect(fixtures.size() == 5, "Five authored mixed ceiling and wall fixtures")
		expect(float(voice.call("distance_gain_db", 90.0, 1150.0)) > float(voice.call("distance_gain_db", 1000.0, 1150.0)) + 25.0, "Near monsters sound substantially louder than distant monsters")
		for drip_index in range(1, 4):
			var drip: AudioStreamPlayer2D = game.get_node("Maze/Overhead/PipeDrip%d" % drip_index)
			expect(drip.stream.resource_path.ends_with("waterdrop.mp3") and drip.bus == &"Master", "Original waterdrop uses the shared building acoustics")
		var fixture: Node2D = fixtures[0]
		for hunter in hunters: hunter.global_position = fixture.global_position + Vector2(1000, 0)
		fixture.set("blink_timer", 0.0)
		fixture.set("danger_probe", 0.0)
		fixture.call("_process", 0.01)
		expect(not fixture.get("danger") and fixture.get("blink_timer") >= 1.8, "Ordinary lamp blinking is slow")
		hunters[1].global_position = fixture.global_position + Vector2(100, 0)
		fixture.set("blink_timer", 0.0)
		fixture.set("danger_probe", 0.0)
		fixture.call("_process", 0.01)
		expect(fixture.get("danger") and fixture.get("blink_timer") <= 0.38, "Either hunter accelerates lamp blinking")
		expect(fixture.get_node("Housing/Sparks").emitting, "Close hunter triggers authored sparks")
		var maze: Node2D = game.get_node("Maze")
		var walls: Array[Node] = maze.get_node("Walls").get_children()
		var count: int = 0
		for span in get_nodes_in_group("anchored_overhead"):
			count += 1
			for end in [span.points[0], span.points[-1]]:
				var attached: bool = false
				var world: Vector2 = span.to_global(end)
				for wall in walls:
					for rect in wall.call("get_wall_rectangles"):
						if rect.has_point(wall.to_local(world)): attached = true
				expect(attached, "Every overhead span terminates inside a solid wall")
		expect(count == 60, "Full-map authored pipe, beam and cable coverage")
	print("RESULT overhead, batteries, two hunters, mode balance, howl intervals, fixtures and sparks: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
