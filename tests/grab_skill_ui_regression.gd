extends SceneTree

var failures: int = 0

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	set_meta("hard_mode", true)
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(6): await physics_frame
	var game: Node = current_scene
	for actor in game.monsters: actor.set_physics_process(false)
	game.player.set_physics_process(false)
	var stalker: Node = game.get_node("Stalker")
	var hud: Node = game.get_node("HUD")
	var skill: Control = hud.find_child("GrabSkillCheck", true, false)
	skill.set_process(false)
	expect(skill.scene_file_path == "res://scenes/ui/grab_skill_check.tscn", "The editor and runtime use the same saved skill scene")
	expect(skill.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF, "Render-frame needle animation cannot receive a second physics interpolation")
	expect(skill.get_node("Dial/Plate").texture != null and skill.get_node("Dial/Needle/Arrow").texture != null, "Both dial and needle have authored textures")
	game.player.battery = 70.0
	stalker.begin_grab()
	skill._process(0.01)
	expect(skill.visible and skill.opening < 1.0, "Grab opens the dial with an entrance animation")
	skill._process(0.2)
	expect(is_equal_approx(skill.get_node("Dial/Needle").rotation, skill.displayed_phase * TAU), "Drawn needle and judged angle match at high refresh rates")
	var points: PackedVector2Array = skill.get_node("Dial/Target").points
	var first_angle: float = points[0].angle()
	expect(absf(wrapf(first_angle - ((stalker.green_center - stalker.green_half_width) * TAU - PI * 0.5), -PI, PI)) < 0.0001, "The target arc exactly matches the gameplay success window")
	var keyboard: InputEventKey = InputEventKey.new()
	keyboard.keycode = KEY_SPACE
	keyboard.pressed = true
	keyboard.echo = true
	skill._input(keyboard)
	expect(stalker.results.is_empty(), "Held space cannot submit repeated checks")
	keyboard.echo = false
	stalker.green_center = fposmod(stalker.needle_phase() + 0.4, 1.0)
	skill.displayed_phase = stalker.green_center
	skill.displayed_round = 0
	skill._input(keyboard)
	expect(stalker.results.size() == 1 and stalker.results[0] and game.player.battery == 66.0, "Space judges the displayed angle even if the simulation angle differs")
	skill._process(0.01)
	expect(skill.get_node("Dial/Result1").color == skill.SUCCESS and skill.feedback_time > 0.0, "A successful round updates its marker and animates feedback")
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	skill.displayed_phase = fposmod(stalker.green_center + 0.4, 1.0)
	skill.displayed_round = 1
	skill._input(click)
	skill._process(0.01)
	expect(stalker.results.size() == 2 and not stalker.results[1] and skill.get_node("Dial/Result2").color == skill.FAILURE, "Mouse misses have distinct feedback and count once")
	hud.set_paused(true)
	skill._input(keyboard)
	expect(stalker.results.size() == 2, "Pause blocks skill-check input")
	var hover: AudioStreamPlayer = root.get_node("MenuAudio/Hover")
	hud.find_child("Resume", true, false).mouse_entered.emit()
	expect(hover.playing and hover.volume_db == -25.0 and hover.bus == &"Effects", "Quiet hover still works while paused through the shared acoustics bus")
	hud.set_paused(false)
	skill.displayed_phase = stalker.green_center
	skill.displayed_round = 2
	skill._input(click)
	skill._process(0.01)
	expect(stalker.results.size() == 3 and stalker.state == "flee" and not game.player.grabbed and not skill.visible, "The last click immediately releases the player and closes the dial")
	skill._input(click)
	expect(stalker.results.size() == 3, "Extra input cannot submit a fourth result")
	stalker.update_grab(3.0)
	skill._process(0.01)
	expect(not skill.visible and not game.player.grabbed, "Release closes the dial and frees the player")
	stalker.begin_grab()
	skill._process(0.01)
	expect(skill.visible and skill.shown_results == 0 and skill.get_node("Dial/Result1").color == skill.PENDING, "A new grab clears old results and restarts the entrance")
	for round_index in range(3):
		skill.displayed_phase = stalker.green_center
		skill.displayed_round = round_index
		skill._input(click)
		expect(stalker.state == ("flee" if round_index == 2 else "grab"), "Only the final successful click ends the grab")
	skill._process(0.01)
	expect(stalker.successful_checks == 3 and not game.player.grabbed and not skill.visible, "Three successful clicks complete immediately without advancing the attack timer")
	print("RESULT authored skill art, timing, animation, input, pause, quiet hover and reset: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
