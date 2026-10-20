extends SceneTree

func _initialize() -> void:
	var keys: Dictionary = {"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN], "move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "sprint": [KEY_SHIFT], "flashlight": [KEY_F], "restart": [KEY_R]}
	for action in keys:
		var events: Array[InputEventKey] = []
		for key in keys[action]:
			var event: InputEventKey = InputEventKey.new()
			event.device = -1
			event.physical_keycode = key
			events.append(event)
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.2, "events": events})
	ProjectSettings.save()
	print("Input actions saved.")
	quit()
