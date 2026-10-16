extends CanvasLayer

var game: Node
var objective: Label
var stamina_label: Label
var charge_label: Label
var stamina_bar: ProgressBar
var charge_bar: ProgressBar
var notification: Label
var notice_time: float = 0.0
var overlay: ColorRect
var result_title: Label
var result_text: Label
var difficulty_checks: Array[CheckButton] = []
var pause_overlay: ColorRect
var fullscreen_toggle: CheckButton
var aim_cursor: ImageTexture
var status_panel: PanelContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	create_aim_cursor()
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var panel: PanelContainer = PanelContainer.new()
	status_panel = panel
	panel.position = Vector2(22, 20)
	panel.custom_minimum_size = Vector2(355, 155)
	var box_style: StyleBoxFlat = StyleBoxFlat.new()
	box_style.bg_color = Color(0.035, 0.047, 0.043, 0.92)
	box_style.border_color = Color("776949")
	box_style.set_border_width_all(1)
	box_style.content_margin_left = 18
	box_style.content_margin_right = 18
	box_style.content_margin_top = 13
	box_style.content_margin_bottom = 13
	panel.add_theme_stylebox_override("panel", box_style)
	root.add_child(panel)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	panel.add_child(stack)
	objective = make_label("СОЛОМЕННЫЕ ФИГУРКИ   0 / 12", 19)
	stack.add_child(objective)
	stamina_label = make_label("ВЫНОСЛИВОСТЬ", 12)
	stack.add_child(stamina_label)
	stamina_bar = make_bar(Color("a7b79c"))
	stack.add_child(stamina_bar)
	charge_label = make_label("ФОНАРИК · F", 12)
	stack.add_child(charge_label)
	charge_bar = make_bar(Color("dbc484"))
	stack.add_child(charge_bar)
	notification = make_label("", 17)
	notification.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	notification.position = Vector2(24, -72)
	notification.add_theme_color_override("font_color", Color("ead5a2"))
	root.add_child(notification)
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
	result_box.add_child(make_difficulty_toggle())
	var retry: Button = Button.new()
	retry.text = "Начать заново [R]"
	retry.custom_minimum_size = Vector2(300, 48)
	retry.pressed.connect(_restart)
	result_box.add_child(retry)
	overlay.hide()
	build_pause_menu(root, box_style)
	update_cursor()

func build_pause_menu(root: Control, style: StyleBoxFlat) -> void:
	pause_overlay = ColorRect.new()
	pause_overlay.color = Color(0.015, 0.02, 0.018, 0.88)
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(pause_overlay)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size.x = 430
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var title: Label = make_label("ПАУЗА", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var resume: Button = Button.new()
	resume.text = "Продолжить [Esc]"
	resume.custom_minimum_size.y = 44
	resume.pressed.connect(func() -> void: set_paused(false))
	box.add_child(resume)
	fullscreen_toggle = CheckButton.new()
	fullscreen_toggle.text = "Полный экран [F11]"
	fullscreen_toggle.set_pressed_no_signal(is_fullscreen())
	fullscreen_toggle.toggled.connect(set_fullscreen)
	box.add_child(fullscreen_toggle)
	box.add_child(make_difficulty_toggle())
	var restart: Button = Button.new()
	restart.text = "Начать заново [R]"
	restart.custom_minimum_size.y = 44
	restart.pressed.connect(_restart)
	box.add_child(restart)
	box.add_child(make_label("WASD / стрелки — движение\nМышь — взгляд · Shift — спринт\nF — фонарь · Esc — пауза · F11 — полный экран", 16))
	pause_overlay.hide()

func _input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F11:
		set_fullscreen(not is_fullscreen())
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and is_instance_valid(game) and not game.get("finished"):
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()
		_restart()

func set_paused(enabled: bool) -> void:
	get_tree().paused = enabled
	pause_overlay.visible = enabled
	status_panel.visible = not enabled
	notification.visible = not enabled
	update_cursor()

func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]

func set_fullscreen(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	fullscreen_toggle.set_pressed_no_signal(enabled)

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
	var menu_open: bool = get_tree().paused or (is_instance_valid(overlay) and overlay.visible)
	Input.set_custom_mouse_cursor(null if menu_open else aim_cursor, Input.CURSOR_ARROW, Vector2.ZERO if menu_open else Vector2(16, 16))

func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null)

func make_label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e0dfd1"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func make_bar(color: Color) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(300, 10)
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

func make_difficulty_toggle() -> CheckButton:
	var toggle: CheckButton = CheckButton.new()
	toggle.text = "Хард — со следующего забега"
	toggle.tooltip_text = "После сбора 6 из 12 фигурок появляется второй монстр. Выберите и нажмите «Заново»."
	toggle.toggled.connect(_set_difficulty)
	difficulty_checks.append(toggle)
	return toggle

func _set_difficulty(enabled: bool) -> void:
	for toggle in difficulty_checks:
		toggle.set_pressed_no_signal(enabled)
	if is_instance_valid(game):
		game.call("set_next_hard_mode", enabled)

func _process(delta: float) -> void:
	if not is_instance_valid(game):
		return
	if get_tree().paused:
		return
	var player: CharacterBody2D = game.get("player")
	var count: int = int(game.get("collected"))
	objective.text = "ФИГУРКИ: %d / 12   ·   ОСТАЛОСЬ: %d" % [count, 12 - count]
	stamina_bar.max_value = float(player.get("stamina_max"))
	stamina_bar.value = float(player.get("stamina"))
	charge_bar.value = float(player.get("battery"))
	stamina_label.text = "ВЫНОСЛИВОСТЬ: %d / %d %s" % [int(stamina_bar.value), int(stamina_bar.max_value), "— ВЫДОХЛИСЬ" if player.get("exhausted") else ""]
	charge_label.text = "ФОНАРИК [F]: %s   ·   ЗАРЯД: %d%%" % ["ВКЛ" if player.get("flashlight_on") else "ВЫКЛ", int(charge_bar.value)]
	notice_time -= delta
	if notice_time <= 0.0:
		notification.text = ""

func notify(text: String, duration: float = 2.0) -> void:
	notification.text = text
	notice_time = duration

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
