extends SceneTree

var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run_checks")

func clear_notices(hud: Node) -> void:
	hud.get("notices").clear()
	hud.get("pending_notices").clear()
	for label in hud.get("notice_labels"): label.text = ""

func run_checks() -> void:
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(5): await process_frame
	var game: Node = current_scene
	var hud: Node = game.get_node("HUD")
	var player: Node2D = game.get_node("Player")
	var monster: Node2D = game.get_node("Monster")
	var visibility: Node = game.get_node("Visibility")
	hud.set_process(false)
	player.set_physics_process(false)
	monster.set_physics_process(false)
	clear_notices(hud)
	hud.call("notify", "first", 0.5)
	hud.call("notify", "second", 0.1)
	hud.call("notify", "third", 0.1)
	var entries: Array = hud.get("notices")
	expect(entries.size() == 3 and entries[0].text == "first" and entries[2].text == "third", "Messages must coexist and preserve arrival order")
	expect(entries[0].expires < entries[1].expires and entries[1].expires < entries[2].expires, "Expiry must stay FIFO despite different message durations")
	hud.call("update_notices", 0.3)
	var previous_y: float = entries[1].y
	hud.call("update_notices", 0.25)
	entries = hud.get("notices")
	expect(entries.size() == 2 and entries[0].text == "second", "Only the oldest message should disappear first")
	expect(float(entries[0].y) < previous_y, "Newer messages must rise smoothly into the vacated upper slot")
	hud.call("notify", "fourth", 2.0)
	hud.call("notify", "fifth", 2.0)
	expect(hud.get("pending_notices").size() == 1, "A full list must queue the next message instead of overwriting one")
	hud.call("update_notices", 0.26)
	entries = hud.get("notices")
	expect(entries.size() == 3 and entries[-1].text == "fifth", "A queued message must promptly occupy the freed slot")
	clear_notices(hud)
	hud.call("notify", "anchor", 3.0)
	# Simulate the pose pair used to draw a sprinting player between physics ticks.
	visibility.set("pose_initialized", true)
	visibility.set("previous_observer", player.global_position - Vector2(5.1667, 0))
	visibility.set("current_observer", player.global_position)
	var expected: Vector2 = root.get_canvas_transform() * Vector2(visibility.get("previous_observer")).lerp(player.global_position, Engine.get_physics_interpolation_fraction())
	expect(Vector2(hud.call("get_notice_anchor")).distance_to(expected) < 0.001, "Notification anchor must match interpolated sprint position exactly")
	clear_notices(hud)
	player.set("stamina", 0.01)
	player.set("exhausted", false)
	player.call("update_resources", 0.1, true)
	player.call("update_resources", 0.1, true)
	entries = hud.get("notices")
	expect(entries.size() == 1 and entries[0].text == "выдохся", "Exhaustion must emit exactly one notice per exhaustion episode")
	hud.call("_process", 0.01)
	expect("выдохся" in String(hud.get("stamina_label").text), "HUD must use the requested exhaustion wording")
	expect(is_equal_approx(80.0 / float(monster.get("stamina_regen")), 4.95), "Twenty percent slower recovery rate must take 4.95 seconds")
	clear_notices(hud)
	var maze: Node = game.get_node("Maze")
	var origin: Vector2 = maze.cell_position(60)
	var neighbor: Vector2 = maze.cell_position(maze.get("graph").get_point_connections(60)[0])
	monster.global_position = origin
	player.global_position = origin.lerp(neighbor, 0.5)
	monster.set("facing_angle", origin.angle_to_point(player.global_position))
	monster.set("state", "patrol")
	monster.set("disengage_timer", 0.0)
	game.set("spotted_notice_cooldown", 0.0)
	monster.call("perceive")
	monster.call("perceive")
	entries = hud.get("notices")
	expect(monster.get("state") == "alert" and entries.size() == 1 and entries[0].text == "вас увидели", "Visual acquisition must emit one notice, without repeating each sensing tick")
	for item in maze.get_node("Pickups").get_children():
		if item.get("kind") != "figurine": continue
		clear_notices(hud)
		game.call("collect_pickup", item)
		entries = hud.get("notices")
		expect(entries.size() == 1 and entries[0].text == "+25% выносливости", "Figurine popup must contain only its bonus")
		break
	var panel: PanelContainer = hud.get("status_panel")
	var panel_style: StyleBoxFlat = panel.get_theme_stylebox("panel")
	expect(panel.anchor_top == 1.0 and panel_style.bg_color.a == 0.0 and panel_style.border_width_left == 0, "HUD must sit at bottom left with no box or border")
	for button in hud.get("pause_overlay").find_children("*", "BaseButton", true, false):
		var normal: StyleBox = button.get_theme_stylebox("normal")
		var hover: StyleBox = button.get_theme_stylebox("hover")
		if normal is StyleBoxEmpty:
			expect(hover is StyleBoxEmpty and button.get_theme_stylebox("hover_pressed") is StyleBoxEmpty, "Textured menu controls must keep transparent backgrounds in hover states")
			expect(button.get_theme_color("font_hover_color").get_luminance() > button.get_theme_color("font_color").get_luminance(), "Menu text must become readable on hover")
		else:
			expect(normal is StyleBoxFlat and hover is StyleBoxFlat and hover.bg_color.get_luminance() < normal.bg_color.get_luminance(), "Boxed pause controls must darken on hover")
			var selected: StyleBoxFlat = button.get_theme_stylebox("pressed")
			var selected_hover: StyleBoxFlat = button.get_theme_stylebox("hover_pressed")
			expect(selected_hover.bg_color.get_luminance() < selected.bg_color.get_luminance(), "Boxed toggles must also darken on hover")
	hud.call("set_paused", true)
	var resume: BaseButton = hud.find_child("Resume", true, false)
	expect(resume.has_node("Highlight"), "Main pause actions must retain the textured menu highlight")
	resume.mouse_entered.emit()
	expect(root.get_node("MenuAudio/Hover").playing, "Hover audio must play while the game is paused")
	hud.call("_button_accepted")
	expect(root.get_node("MenuAudio/Accept").playing, "Accept audio must play while paused")
	print("RESULT FIFO notices, rising slots, interpolated anchor, exhaustion/spotted events, HUD and pause sounds: %d failure(s)" % failures.size())
	quit(0 if failures.is_empty() else 1)
