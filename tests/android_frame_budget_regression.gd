extends SceneTree
var failures: Array[String] = []
func expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var budget: Node = root.get_node("RuntimeBudget")
	budget.set("mobile_platform", true)
	budget.call("set_fps", 60, false)
	budget.call("_notification", Node.NOTIFICATION_APPLICATION_PAUSED)
	expect(Engine.max_fps == 15, "Android background must retain the low FPS budget")
	budget.call("_notification", Node.NOTIFICATION_APPLICATION_RESUMED)
	expect(Engine.max_fps == 60 and budget.get("focused"), "Android resume must restore gameplay FPS")
	budget.call("request_background")
	budget.call("update_window_focus", false, 1.0)
	expect(Engine.max_fps == 60, "Desktop window polling must not throttle Android")
	budget.call("_notification", Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	budget.call("_input", touch)
	expect(Engine.max_fps == 60 and not budget.get("focus_loss_pending"), "Touch must recover foreground FPS even after a missing focus event")
	budget.call("_notification", Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	budget.call("_notification", Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	expect(Engine.max_fps == 60, "Android focus-in must restore gameplay FPS")
	budget.set("mobile_platform", false)
	print("ANDROID FRAME BUDGET: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
