extends SceneTree

var failures: int = 0

func expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var budget: Node = root.get_node("RuntimeBudget")
	var saved: int = budget.active_fps
	# A false application focus-out is what used to trap the embedded game at 15.
	budget.mark_focused()
	budget.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	expect(budget.focused, "Application focus notifications cannot background an active embedded game")
	for limit in [60, 144, 180, 0]:
		budget.focused = false
		budget.apply_budget()
		expect(Engine.max_fps == 15 and OS.low_processor_usage_mode, "An actual background game retains the 15 FPS budget")
		budget.set_fps(limit, false)
		expect(Engine.max_fps == 15, "Changing the foreground preference preserves background throttling")
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		budget.request_background()
		budget._input(click)
		expect(Engine.max_fps == limit and not OS.low_processor_usage_mode and not budget.focus_loss_pending, "Clicking an embedded game restores its chosen FPS immediately")
		budget.set_paused(true)
		expect(Engine.max_fps == limit, "Pause retains every selected FPS limit")
		budget.set_paused(false)
		budget.request_background()
		budget.update_window_focus(true, 0.5)
		expect(budget.focused and Engine.max_fps == limit, "A focused native popup keeps the selected foreground limit")
		budget.request_background()
		budget.update_window_focus(false, 0.15)
		expect(budget.focused, "A brief focus transition cannot enable the background limit")
		budget.update_window_focus(false, 0.16)
		expect(not budget.focused and Engine.max_fps == 15, "A confirmed focus loss enables 15 FPS after the grace period")
		budget.update_window_focus(true, 0.01)
		expect(budget.focused and Engine.max_fps == limit, "Window focus recovery restores every selected limit")
		budget.request_background()
		budget.mark_focused()
		expect(not budget.focus_loss_pending and Engine.max_fps == limit, "Returning from an FPS popup cancels pending background throttling")
	budget.focused = false
	budget.apply_budget()
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	budget._input(key)
	expect(budget.focused and Engine.max_fps == 0, "Keyboard movement also recovers a missing native focus-in event")
	budget.set_fps(saved, false)
	print("RESULT embedded focus, FPS selection, popup focus, pause and background: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
