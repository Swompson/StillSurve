@tool
extends Control

const MOUSE_FINGER: int = 1000
const MOVE_RADIUS: float = 120.0
const WALK_RADIUS: float = 80.0
const SPRINT_RELEASE_RADIUS: float = 72.0
const MOVE_DEAD_ZONE: float = 12.0
const KEYS: Array[String] = ["move", "aim", "light", "pause", "sprint"]
const CAPTIONS: Array[String] = ["ХОД", "ВЗГЛЯД", "СВЕТ", "ПАУЗА", "БЕГ"]
const DEFAULT_POSITIONS: Array[Vector2] = [Vector2(0.13, 0.74), Vector2(0.85, 0.74), Vector2(0.89, 0.40), Vector2(0.93, 0.12), Vector2(0.68, 0.73)]
const RADII: Array[float] = [120.0, 96.0, 72.0, 60.0, 72.0]
var settings_path: String = "user://mobile_controls.cfg"
var positions: Dictionary = {}
var control_scales: Dictionary = {}
var button_sprint: bool = false
var hud_scale: float = 1.4
var enabled: bool = false
var editing: bool = false
var selected: String = "move"
var edit_finger: int = -1
var edit_offset: Vector2
var saved_positions: Dictionary
var saved_scales: Dictionary
var move_finger: int = -1
var aim_finger: int = -1
var sprint_finger: int = -1
var sprint_requested: bool = false
var move_offset: Vector2
var move_origin: Vector2
var aim_origin: Vector2
var move_vector: Vector2
var aim_vector: Vector2

func reset_layout() -> void:
	for index in range(KEYS.size()):
		positions[KEYS[index]] = DEFAULT_POSITIONS[index]
		control_scales[KEYS[index]] = 1.0
	queue_redraw()

func load_preferences() -> void:
	reset_layout()
	var config: ConfigFile = ConfigFile.new()
	if config.load(settings_path) != OK: return
	button_sprint = bool(config.get_value("controls", "button_sprint", false))
	hud_scale = clampf(float(config.get_value("controls", "hud_scale", 1.4)), 1.0, 1.8)
	for key in KEYS:
		var point: Variant = config.get_value("positions", key, positions[key])
		if point is Vector2 and point.is_finite(): positions[key] = point.clamp(Vector2.ZERO, Vector2.ONE)
		control_scales[key] = clampf(float(config.get_value("sizes", key, 1.0)), 0.65, 1.8)

func save_preferences() -> Error:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("controls", "button_sprint", button_sprint)
	config.set_value("controls", "hud_scale", hud_scale)
	for key in KEYS:
		config.set_value("positions", key, positions[key])
		config.set_value("sizes", key, control_scales[key])
	return config.save(settings_path)

func radius(key: String) -> float:
	return RADII[KEYS.find(key)] * float(control_scales.get(key, 1.0))

func center(key: String) -> Vector2:
	var point: Vector2 = positions.get(key, DEFAULT_POSITIONS[KEYS.find(key)])
	var padding: Vector2 = Vector2.ONE * (radius(key) + 12.0)
	return (point * size).clamp(padding, (size - padding).max(padding))

func set_enabled(value: bool) -> void:
	enabled = value
	clear_controls()
	visible = enabled and not get_tree().paused
	var game: Node = get_tree().current_scene
	if is_instance_valid(game): game.get_node("HUD").call("set_mobile_layout", enabled)
	queue_redraw()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Engine.is_editor_hint(): reset_layout()
	else: load_preferences()
	enabled = OS.has_feature("android") or "--touch-controls" in OS.get_cmdline_user_args()
	visible = Engine.is_editor_hint() or enabled
	$Editor.hide()
	$Editor/Box/Element.item_selected.connect(func(index: int) -> void: select_control(KEYS[index]))
	$Editor/Box/Size.value_changed.connect(func(value: float) -> void:
		control_scales[selected] = value / 100.0
		queue_redraw())
	$Editor/Box/Actions/Save.pressed.connect(func() -> void: finish_edit(true))
	$Editor/Box/Actions/Cancel.pressed.connect(func() -> void: finish_edit(false))
	$Editor/Box/Actions/Reset.pressed.connect(func() -> void:
		reset_layout()
		select_control(selected))
	if not Engine.is_editor_hint(): set_enabled.call_deferred(enabled)

func select_control(key: String) -> void:
	selected = key
	$Editor/Box/Element.select(KEYS.find(key))
	$Editor/Box/Size.set_value_no_signal(float(control_scales[key]) * 100.0)
	queue_redraw()

func begin_edit() -> void:
	clear_controls()
	saved_positions = positions.duplicate(true)
	saved_scales = control_scales.duplicate(true)
	editing = true
	visible = true
	var hud: Node = get_tree().current_scene.get_node("HUD")
	hud.call("set_paused", true)
	hud.get("pause_overlay").hide()
	$Editor.show()
	select_control("move")

func finish_edit(save: bool) -> void:
	if save:
		if save_preferences() != OK:
			$Editor/Box/Hint.text = "Не удалось сохранить. Попробуйте ещё раз."
			return
	else:
		positions = saved_positions.duplicate(true)
		control_scales = saved_scales.duplicate(true)
	editing = false
	edit_finger = -1
	clear_controls()
	$Editor.hide()
	get_tree().current_scene.get_node("HUD").get("pause_overlay").show()
	visible = false

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	if editing: draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.02, 0.025, 0.88))
	for index in range(KEYS.size()):
		var key: String = KEYS[index]
		if key == "sprint" and not button_sprint and not editing: continue
		var point: Vector2 = center(key)
		var extent: float = radius(key)
		var tint: Color = Color(0.75, 0.85, 0.85, 0.75)
		if (editing and selected == key) or (key == "move" and sprint_requested): tint = Color(1.0, 0.82, 0.4, 0.95)
		draw_circle(point, extent, Color(0.1, 0.15, 0.16, 0.52))
		draw_arc(point, extent, 0, TAU, 64, tint, 2.0, true)
		if key == "move" and not button_sprint:
			draw_arc(point, extent * WALK_RADIUS / MOVE_RADIUS, 0, TAU, 64, tint, 1.5, true)
		var text_size: int = roundi(24.0 * minf(float(control_scales.get(key, 1.0)), 1.4))
		var caption: String = CAPTIONS[index]
		draw_string(font, point + Vector2(-font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x * 0.5, 8), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size)
	if move_finger >= 0: draw_circle(move_origin + move_offset, 25.0, Color(0.8, 0.9, 0.9, 0.85))
	if aim_finger >= 0: draw_circle(aim_origin + aim_vector * radius("aim"), 25.0, Color(0.95, 0.85, 0.65, 0.85))

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	if editing:
		queue_redraw()
		return
	if not enabled: return
	var game: Node = get_tree().current_scene
	visible = is_instance_valid(game) and not game.get("finished") and not get_tree().paused
	if not visible: clear_controls()
	queue_redraw()

func clear_controls() -> void:
	move_finger = -1
	aim_finger = -1
	sprint_finger = -1
	sprint_requested = false
	move_offset = Vector2.ZERO
	move_vector = Vector2.ZERO
	aim_vector = Vector2.ZERO

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		clear_controls()
		edit_finger = -1

func update_move(point: Vector2) -> void:
	move_offset = (point - move_origin).limit_length(radius("move"))
	var distance: float = move_offset.length() / float(control_scales.get("move", 1.0))
	# Walking speed is constant outside the dead zone.
	move_vector = move_offset.normalized() if distance > MOVE_DEAD_ZONE else Vector2.ZERO
	if not button_sprint:
		sprint_requested = distance > (SPRINT_RELEASE_RADIUS if sprint_requested else WALK_RADIUS)

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint(): return
	if editing and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		finish_edit(false)
		get_viewport().set_input_as_handled()
		return
	if not editing and not OS.has_feature("android") and event is InputEventKey and event.pressed and not event.echo and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed and (event.physical_keycode == KEY_M or (event.physical_keycode == 0 and event.keycode == KEY_M)):
		set_enabled(not enabled)
		get_viewport().set_input_as_handled()
		return
	if (not enabled and not editing) or not visible: return
	if editing and (event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch) and $Editor.get_global_rect().has_point(event.position):
		if event is InputEventMouseMotion and edit_finger < 0: return
		if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed: return
	if not OS.has_feature("android") and event.device != -1:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			var touch: InputEventScreenTouch = InputEventScreenTouch.new()
			touch.index = MOUSE_FINGER
			touch.position = event.position
			touch.pressed = event.pressed
			_input(touch)
			return
		if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var drag: InputEventScreenDrag = InputEventScreenDrag.new()
			drag.index = MOUSE_FINGER
			drag.position = event.position
			_input(drag)
			return
	if event is InputEventScreenTouch:
		if not event.pressed or event.canceled:
			if event.index == edit_finger: edit_finger = -1
			if event.index == move_finger:
				move_finger = -1
				move_vector = Vector2.ZERO
				move_offset = Vector2.ZERO
				if not button_sprint: sprint_requested = false
			if event.index == aim_finger:
				aim_finger = -1
				aim_vector = Vector2.ZERO
			if event.index == sprint_finger:
				sprint_finger = -1
				sprint_requested = false
			return
		var point: Vector2 = event.position
		var game: Node = get_tree().current_scene
		if editing:
			for key in KEYS:
				if point.distance_to(center(key)) <= radius(key):
					select_control(key)
					edit_finger = event.index
					edit_offset = center(key) - point
					get_viewport().set_input_as_handled()
					return
			return
		if point.distance_to(center("pause")) < radius("pause"):
			game.get_node("HUD").call("set_paused", true)
		elif point.distance_to(center("light")) < radius("light"):
			game.get_node("Player").call("toggle_flashlight")
		elif button_sprint and point.distance_to(center("sprint")) < radius("sprint"):
			sprint_finger = event.index
			sprint_requested = true
		elif point.distance_to(center("move")) < radius("move") * 1.15 and move_finger < 0:
			move_finger = event.index
			move_origin = center("move")
			update_move(point)
		elif point.distance_to(center("aim")) < radius("aim") * 1.15 and aim_finger < 0:
			aim_finger = event.index
			aim_origin = center("aim")
		else: return
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if editing:
			if event.index != edit_finger: return
			var padding: Vector2 = Vector2.ONE * (radius(selected) + 12.0)
			positions[selected] = (event.position + edit_offset).clamp(padding, (size - padding).max(padding)) / size.max(Vector2.ONE)
		elif event.index == move_finger: update_move(event.position)
		elif event.index == aim_finger: aim_vector = ((event.position - aim_origin) / radius("aim")).limit_length()
		else: return
		get_viewport().set_input_as_handled()
