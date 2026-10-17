extends SceneTree
var failures: Array[String] = []
func expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	change_scene_to_file("res://scenes/game.tscn")
	await process_frame
	await physics_frame
	var game: Node = current_scene
	for name in ["Player", "Monster", "SecondMonster"]: game.get_node(name).set_physics_process(false)
	var mobile: Control = game.get_node("MobileControls/Controls")
	mobile.set("settings_path", "res://.godot/mobile_layout_test.cfg")
	mobile.call("reset_layout")
	mobile.call("set_enabled", true)
	var hud: Node = game.get_node("HUD")
	hud.call("set_paused", true)
	var menu: Node = hud.get("pause_overlay")
	menu.call("show_settings", true)
	menu.call("select_category", "Controls")
	var options: Node = menu.find_child("MobileSettings", true, false)
	expect(options.visible, "Mobile controls settings must replace desktop bindings")
	options.get_node("SprintMode").select(1)
	options.get_node("SprintMode").item_selected.emit(1)
	expect(mobile.get("button_sprint"), "Settings must enable the sprint button")
	options.get_node("HudSize").value = 160
	expect(is_equal_approx(hud.get("status_panel").scale.x, 1.6), "HUD scale must apply immediately")
	options.get_node("Customize").pressed.emit()
	expect(paused and mobile.get("editing") and not menu.visible, "Layout editing must freeze gameplay and hide the pause menu")
	var origin: Vector2 = mobile.call("center", "move")
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.index = 6
	touch.pressed = true
	touch.position = origin
	mobile.call("_input", touch)
	var drag: InputEventScreenDrag = InputEventScreenDrag.new()
	drag.index = 6
	drag.position = origin + Vector2(70, -35)
	mobile.call("_input", drag)
	mobile.get_node("Editor/Box/Size").value = 130
	var saved_point: Vector2 = mobile.get("positions")["move"]
	expect(Vector2(mobile.call("center", "move")).distance_to(origin) > 40, "Dragging must move the selected joystick")
	mobile.call("finish_edit", true)
	expect(not mobile.get("editing") and menu.visible and paused, "Saving must return to settings while keeping gameplay paused")
	var loaded: Control = preload("res://scripts/ui/mobile_controls.gd").new()
	loaded.set("settings_path", "res://.godot/mobile_layout_test.cfg")
	loaded.call("load_preferences")
	expect(loaded.get("positions")["move"].is_equal_approx(saved_point), "Position must survive reloading preferences")
	expect(is_equal_approx(loaded.get("control_scales")["move"], 1.3) and loaded.get("button_sprint") and is_equal_approx(loaded.get("hud_scale"), 1.6), "Size, HUD scale and sprint mode must survive reload")
	loaded.free()
	mobile.call("begin_edit")
	mobile.call("reset_layout")
	mobile.call("finish_edit", false)
	expect(mobile.get("positions")["move"].is_equal_approx(saved_point), "Cancel must restore the original layout")
	hud.call("set_paused", false)
	mobile.call("_process", 0.016)
	origin = mobile.call("center", "move")
	touch.index = 1
	touch.position = origin
	mobile.call("_input", touch)
	drag.index = 1
	drag.position = origin + Vector2(30, 0)
	mobile.call("_input", drag)
	expect(is_equal_approx(Vector2(mobile.get("move_vector")).length(), 1.0), "Small stick deflection must use constant walking speed")
	drag.position = origin + Vector2(140, 0)
	mobile.call("_input", drag)
	expect(not mobile.get("sprint_requested"), "Button mode must never sprint from stick distance")
	touch.index = 2
	touch.position = mobile.call("center", "sprint")
	mobile.call("_input", touch)
	expect(mobile.get("sprint_requested"), "Sprint button must work alongside a held movement finger")
	touch.pressed = false
	mobile.call("_input", touch)
	expect(not mobile.get("sprint_requested"), "Releasing sprint must resume walking")
	mobile.call("clear_controls")
	mobile.set("button_sprint", false)
	touch.index = 1
	touch.pressed = true
	touch.position = origin
	mobile.call("_input", touch)
	drag.position = origin + Vector2(140, 0)
	mobile.call("_input", drag)
	expect(mobile.get("sprint_requested"), "Ring mode must still sprint beyond the boundary")
	mobile.call("_notification", Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	expect(not mobile.get("sprint_requested"), "Losing focus must clear held controls")
	print("MOBILE LAYOUT SETTINGS: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
