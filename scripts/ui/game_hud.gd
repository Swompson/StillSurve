extends CanvasLayer

var game: Node
var objective: Label
var stamina_label: Label
var charge_label: Label
var stamina_bar: ProgressBar
var charge_bar: ProgressBar
var fps_choice: OptionButton
var fps_counter: Label
var overlay: ColorRect
var result_title: Label
var result_text: Label
var difficulty_checks: Array[CheckButton] = []
var pause_overlay: ColorRect
var fullscreen_toggle: CheckButton
var aim_cursor: ImageTexture
var pickup_notice: Label
var status_panel: PanelContainer
var notice_labels: Array[Label] = []
var notices: Array[Dictionary] = []
var pending_notices: Array[Dictionary] = []
var notice_clock: float = 0.0
var mobile_layout: bool = false
const NOTICE_LIMIT: int = 3
const NOTICE_ROW_HEIGHT: float = 38.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	create_aim_cursor()
	if not has_node("Layout"):
		build_layout()
	for key in ["objective", "stamina_label", "charge_label", "stamina_bar", "charge_bar", "overlay", "result_title", "result_text", "pause_overlay", "fullscreen_toggle", "status_panel", "pickup_notice"]:
		set(key, find_child(key, true, false))
	difficulty_checks.clear()
	for node in find_children("difficulty_*", "CheckButton", true, false):
		difficulty_checks.append(node)
		node.toggled.connect(_set_difficulty)
	for node in find_children("Restart*", "Button", true, false):
		node.pressed.connect(_restart)
	for node in find_children("Quit*", "Button", true, false):
		node.pressed.connect(_quit)
	find_child("Resume", true, false).pressed.connect(func() -> void: set_paused(false))
	fullscreen_toggle.toggled.connect(set_fullscreen)
	fullscreen_toggle.set_pressed_no_signal(is_fullscreen())
	fps_choice = find_child("FpsChoice", true, false) as OptionButton
	fps_counter = find_child("FpsCounter", true, false) as Label
	fps_choice.select(RuntimeBudget.FPS_OPTIONS.find(RuntimeBudget.active_fps))
	fps_choice.item_selected.connect(func(index: int) -> void: RuntimeBudget.set_fps(fps_choice.get_item_id(index)))
	notice_labels.append(pickup_notice)
	for index in range(1, NOTICE_LIMIT):
		notice_labels.append(find_child("Notice%d" % index, true, false))
	for button in find_children("*", "BaseButton", true, false):
		button.mouse_entered.connect(_button_hovered.bind(button))
		button.pressed.connect(_button_accepted)
	update_cursor()
	set_mobile_layout(OS.has_feature("android") or "--touch-controls" in OS.get_cmdline_user_args())

func set_mobile_layout(value: bool) -> void:
	mobile_layout = value
	var mobile: Node = get_tree().current_scene.get_node_or_null("MobileControls/Controls") if is_instance_valid(get_tree().current_scene) else null
	var ui_scale: float = float(mobile.get("hud_scale")) if value and mobile else (1.4 if value else 1.0)
	status_panel.scale = Vector2.ONE * ui_scale
	for label in [objective, stamina_label, charge_label]:
		label.add_theme_font_size_override("font_size", 26 if value else (24 if label == objective else 20))
	status_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT if value else Control.PRESET_BOTTOM_LEFT)
	status_panel.offset_left = 30.0 if value else 26.0
	status_panel.offset_top = 24.0 if value else -180.0
	status_panel.offset_right = status_panel.offset_left + status_panel.size.x
	status_panel.offset_bottom = status_panel.offset_top + status_panel.size.y

func _button_hovered(button: BaseButton) -> void:
	if button.is_visible_in_tree():
		get_node("/root/MenuAudio/Hover").play()

func _button_accepted() -> void:
	get_node("/root/MenuAudio/Accept").play()

func build_layout() -> void:
	var root: Control = Control.new()
	root.name = "Layout"
	var theme: Theme = Theme.new()
	theme.default_font = load("res://assets/fonts/sjz/Sjz.otf")
	theme.default_font_size = 24
	for state in ["normal", "hover", "pressed", "focus"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color.TRANSPARENT if state == "focus" else (Color("292525") if state == "normal" else (Color("211e1e") if state == "pressed" else Color("100e0e")))
		style.content_margin_left = 18
		style.content_margin_right = 18
		style.content_margin_top = 9
		style.content_margin_bottom = 9
		for button_type in ["Button", "CheckButton", "OptionButton"]:
			theme.set_stylebox(state, button_type, style)
	for button_type in ["Button", "CheckButton", "OptionButton"]:
		var selected_hover: StyleBoxFlat = theme.get_stylebox("pressed", button_type).duplicate() as StyleBoxFlat
		selected_hover.bg_color = Color("080707")
		theme.set_stylebox("hover_pressed", button_type, selected_hover)
	theme.set_color("font_color", "Button", Color("dfd4bc"))
	root.theme = theme
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var panel: PanelContainer = PanelContainer.new()
	status_panel = panel
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.position = Vector2(26, -180)
	panel.custom_minimum_size = Vector2(365, 156)
	var box_style: StyleBoxFlat = StyleBoxFlat.new()
	box_style.bg_color = Color.TRANSPARENT
	box_style.border_color = Color("81705f")
	box_style.content_margin_left = 18
	box_style.content_margin_right = 18
	box_style.content_margin_top = 13
	box_style.content_margin_bottom = 13
	panel.add_theme_stylebox_override("panel", box_style)
	root.add_child(panel)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	panel.add_child(stack)
	objective = make_label("ФИГУРКИ  0 / 12", 28)
	stack.add_child(objective)
	stamina_label = make_label("ВЫНОСЛИВОСТЬ", 21)
	stack.add_child(stamina_label)
	stamina_bar = make_bar(Color("a39b87"))
	stack.add_child(stamina_bar)
	charge_label = make_label("ФОНАРИК · F", 21)
	stack.add_child(charge_label)
	charge_bar = make_bar(Color("c5a672"))
	stack.add_child(charge_bar)
	pickup_notice = make_label("", 20)
	pickup_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pickup_notice.size = Vector2(900, 32)
	pickup_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pickup_notice.add_theme_color_override("font_shadow_color", Color.BLACK)
	pickup_notice.add_theme_constant_override("shadow_offset_x", 2)
	pickup_notice.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(pickup_notice)
	for index in range(1, NOTICE_LIMIT):
		var notice: Label = pickup_notice.duplicate() as Label
		notice.name = "Notice%d" % index
		root.add_child(notice)
	overlay = ColorRect.new()
	overlay.color = Color(0.02, 0.025, 0.021, 0.9)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var result_box: VBoxContainer = VBoxContainer.new()
	result_box.add_theme_constant_override("separation", 20)
	center.add_child(result_box)
	result_title = make_label("", 38)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_box.add_child(result_title)
	result_text = make_label("", 18)
	result_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_box.add_child(result_text)
	var retry: Button = Button.new()
	retry.text = "Начать заново [R]"
	retry.custom_minimum_size = Vector2(300, 48)
	retry.name = "RestartResult"
	result_box.add_child(retry)
	add_quit_button(result_box, "QuitResult")
	overlay.hide()
	build_pause_menu(root, box_style)
	fps_counter = make_label("", 16)
	fps_counter.name = "FpsCounter"
	root.add_child(fps_counter)
	fps_counter.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	fps_counter.offset_left = -150
	fps_counter.offset_top = 14
	fps_counter.offset_right = -20
	fps_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_counter.hide()
	var skill_check: Control = Control.new()
	skill_check.name = "GrabSkillCheck"
	skill_check.set_script(load("res://scripts/ui/grab_skill_check.gd"))
	skill_check.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skill_check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_check.hide()
	root.add_child(skill_check)
	for key in ["objective", "stamina_label", "charge_label", "stamina_bar", "charge_bar", "overlay", "result_title", "result_text", "pause_overlay", "fullscreen_toggle", "status_panel", "pickup_notice"]:
		get(key).name = key

func add_quit_button(parent: Node, node_name: String) -> void:
	var button: Button = Button.new()
	button.name = node_name
	button.text = "Выйти из игры"
	button.custom_minimum_size.y = 44
	parent.add_child(button)

func _quit() -> void:
	# Let the button transient be heard before closing the audio device.
	await get_tree().create_timer(0.15, true).timeout
	get_tree().quit()

func build_pause_menu(root: Control, _style: StyleBoxFlat) -> void:
	pause_overlay = load("res://scripts/ui/pause_menu.gd").new()
	pause_overlay.call("build_layout")
	root.add_child(pause_overlay)
	fullscreen_toggle = pause_overlay.find_child("fullscreen_toggle", true, false)
	fps_choice = pause_overlay.find_child("FpsChoice", true, false)

func _notification(what: int) -> void:
	if not OS.has_feature("android") or not is_instance_valid(game): return
	var mobile: Node = game.get_node_or_null("MobileControls/Controls")
	if mobile and mobile.get("editing"):
		if what == NOTIFICATION_WM_GO_BACK_REQUEST: mobile.call("finish_edit", false)
		return
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not game.get("finished"):
		set_paused(not get_tree().paused)
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and not game.get("finished"):
		set_paused(true)

func _input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F11:
		set_fullscreen(not is_fullscreen())
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and is_instance_valid(game) and not game.get("finished"):
		if not get_tree().paused or not pause_overlay.call("close_settings"):
			set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ENTER and get_tree().paused and pause_overlay.get_node("SettingsPanel").visible:
		pause_overlay.call("close_settings")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart") and (get_tree().paused or overlay.visible):
		get_viewport().set_input_as_handled()
		_restart()

func set_paused(enabled: bool) -> void:
	RuntimeBudget.set_paused(enabled)
	get_tree().paused = enabled
	pause_overlay.visible = enabled
	if enabled: pause_overlay.call("reset_menu")
	status_panel.visible = not enabled
	pickup_notice.visible = not enabled
	for label in notice_labels:
		label.visible = not enabled
	var skill_check: Control = find_child("GrabSkillCheck", true, false)
	skill_check.visible = not enabled and is_instance_valid(game) and game.get_node("Stalker").get("state") == "grab" and not game.get("finished")
	update_cursor()

func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]

func set_fullscreen(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	if not enabled: get_window().size = RuntimeBudget.window_size
	fullscreen_toggle.set_pressed_no_signal(enabled)
	pause_overlay.call("sync_video")

func create_aim_cursor() -> void:
	var image: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in range(32):
		for x in range(32):
			var point: Vector2 = Vector2(x, y) - Vector2(15.5, 15.5)
			var ring: float = 1.0 - smoothstep(0.5, 1.4, absf(point.length() - 9.0))
			var dot: float = 1.0 - smoothstep(0.6, 1.3, point.length())
			image.set_pixel(x, y, Color(0.86, 0.82, 0.67, maxf(ring * 0.58, dot * 0.7)))
	aim_cursor = ImageTexture.create_from_image(image)

func update_cursor() -> void:
	if OS.has_feature("android"): return
	var menu_open: bool = get_tree().paused or (is_instance_valid(overlay) and overlay.visible)
	Input.set_custom_mouse_cursor(null if menu_open else aim_cursor, Input.CURSOR_ARROW, Vector2.ZERO if menu_open else Vector2(16, 16))

func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null)

func make_label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("dfd4bc"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func make_bar(color: Color) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(310, 5)
	bar.show_percentage = false
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = color
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = Color("242b27")
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", background)
	return bar

func bind_game(value: Node) -> void:
	game = value
	for toggle in difficulty_checks:
		toggle.set_pressed_no_signal(bool(game.get("hard_mode")))

func _set_difficulty(enabled: bool) -> void:
	for toggle in difficulty_checks:
		toggle.set_pressed_no_signal(enabled)
	if is_instance_valid(game):
		game.call("set_next_hard_mode", enabled)

func _process(delta: float) -> void:
	if not is_instance_valid(game):
		return
	fps_counter.visible = RuntimeBudget.show_fps and not get_tree().paused and not overlay.visible
	fps_counter.text = "%d FPS" % Engine.get_frames_per_second()
	if get_tree().paused:
		return
	var player: CharacterBody2D = game.get("player")
	var count: int = int(game.get("collected"))
	objective.text = "ФИГУРКИ  %02d / 12" % count
	stamina_bar.max_value = float(player.get("stamina_max"))
	stamina_bar.value = float(player.get("stamina"))
	charge_bar.max_value = float(player.get("battery_max"))
	charge_bar.value = float(player.get("battery"))
	stamina_label.text = "ВЫНОСЛИВОСТЬ  %d / %d %s" % [int(stamina_bar.value), int(stamina_bar.max_value), "— выдохся" if player.get("exhausted") else ""]
	charge_label.text = ("ФОНАРЬ  %s   %d / 70" if mobile_layout else "ФОНАРЬ [F]  %s   %d / 70") % ["ВКЛ" if player.get("flashlight_on") else "ВЫКЛ", int(charge_bar.value)]
	update_notices(delta)
	for label in notice_labels:
		label.visible = true

func get_notice_anchor() -> Vector2:
	if is_instance_valid(game) and game.get_node("Player").get("grabbed"):
		return Vector2(get_viewport().get_visible_rect().size.x * 0.5, 24.0)
	var player: Node2D = game.get("player")
	var world: Vector2 = player.global_position
	var visibility: Node = game.get_node("Visibility")
	# Match the rendered player, rather than its next fixed-step physics position.
	if visibility.get("pose_initialized") and world.distance_to(visibility.get("current_observer")) < 128.0:
		world = Vector2(visibility.get("previous_observer")).lerp(visibility.get("current_observer"), Engine.get_physics_interpolation_fraction())
	return get_viewport().get_canvas_transform() * world

func update_notices(delta: float) -> void:
	notice_clock += delta
	while not notices.is_empty() and float(notices[0].expires) <= notice_clock:
		var label: Label = notices.pop_front().label
		label.text = ""
	fill_notice_slots()
	var anchor: Vector2 = get_notice_anchor()
	for index in range(notices.size()):
		var entry: Dictionary = notices[index]
		var label: Label = entry.label
		var target: float = 42.0 + index * NOTICE_ROW_HEIGHT
		entry.y = lerpf(float(entry.y), target, 1.0 - exp(-14.0 * delta))
		label.position = anchor + Vector2(-label.size.x * 0.5, float(entry.y))
		label.modulate.a = minf(1.0, maxf(0.0, float(entry.expires) - notice_clock) / 0.4)

func fill_notice_slots() -> void:
	while notices.size() < NOTICE_LIMIT and not pending_notices.is_empty():
		var entry: Dictionary = pending_notices.pop_front()
		for label in notice_labels:
			var occupied: bool = false
			for active in notices:
				if active.label == label: occupied = true
			if occupied: continue
			entry.label = label
			label.text = entry.text
			label.add_theme_color_override("font_color", entry.get("color", Color("dfd4bc")))
			var previous_expiry: float = float(notices[-1].expires) if not notices.is_empty() else notice_clock - 0.75
			entry.expires = maxf(notice_clock + float(entry.duration), previous_expiry + 0.75)
			entry.y = 42.0 + notices.size() * NOTICE_ROW_HEIGHT + 28.0
			notices.append(entry)
			break

func notify_pickup(text: String, duration: float = 2.0, color: Color = Color("dfd4bc")) -> void:
	notify(text, duration, color)

func notify(text: String, duration: float = 2.0, color: Color = Color("dfd4bc")) -> void:
	pending_notices.append({"text": text, "duration": duration, "color": color})
	if notices.size() == NOTICE_LIMIT:
		# Make space promptly without overwriting a message or reversing FIFO order.
		notices[0].expires = minf(float(notices[0].expires), notice_clock + 0.25)
	fill_notice_slots()

func show_result(victory: bool) -> void:
	result_title.text = "ВСЕ ФИГУРКИ СОБРАНЫ" if victory else "ОН ВАС НАШЁЛ"
	result_text.text = "Вы разорвали круг. Можно начать новый забег." if victory else "Одного удара было достаточно. Собрано: %d / 12" % int(game.get("collected"))
	var elapsed: int = int(game.get("survived_seconds"))
	result_text.text += "\nПрожито: %02d:%02d · %s" % [elapsed / 60, elapsed % 60, "Хард" if game.get("hard_mode") else "Обычный режим"]
	overlay.show()
	update_cursor()

func _restart() -> void:
	if is_instance_valid(game):
		game.call("restart")
