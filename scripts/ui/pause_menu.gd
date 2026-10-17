extends ColorRect

const INK: Color = Color("c5c1b2")
const MUTED: Color = Color("827f72")
var hud: CanvasLayer
var settings_panel: PanelContainer
var pages: Dictionary = {}
var tabs: Dictionary = {}
var title_font: Font = preload("res://assets/fonts/sjz/Sjz.otf")
var blank_icon: GradientTexture2D

func _ready() -> void:
	hud = get_parent().get_parent() as CanvasLayer
	settings_panel = $SettingsPanel
	$Navigation/Settings.toggled.connect(show_settings)
	$SettingsPanel/Frame/Footer/SettingsBack.pressed.connect(func() -> void: show_settings(false))
	$SettingsPanel/Frame/Footer/ApplySettings.pressed.connect(func() -> void: show_settings(false))
	for category in ["Graphics", "Sound", "Game", "Controls"]:
		pages[category] = find_child(category + "Page", true, false)
		tabs[category] = find_child(category + "Tab", true, false)
		tabs[category].pressed.connect(select_category.bind(category))
	for spec in [["Fps", "FpsChoice"], ["Resolution", "ResolutionChoice"]]:
		var selector: OptionButton = find_child(spec[1], true, false)
		find_child(spec[0] + "Previous", true, false).pressed.connect(cycle_option.bind(selector, -1))
		find_child(spec[0] + "Next", true, false).pressed.connect(cycle_option.bind(selector, 1))
	for button_name in ["FullscreenPrevious", "FullscreenNext"]:
		find_child(button_name, true, false).pressed.connect(func() -> void: hud.set_fullscreen(not hud.is_fullscreen()))
	var resolution: OptionButton = find_child("ResolutionChoice", true, false)
	var size_preference: Vector2i = RuntimeBudget.window_size
	for index in range(resolution.item_count):
		if resolution.get_item_metadata(index) == size_preference: resolution.select(index)
	resolution.item_selected.connect(func(index: int) -> void: RuntimeBudget.set_window_size(resolution.get_item_metadata(index)))
	var vsync: CheckButton = find_child("VsyncToggle", true, false)
	vsync.set_pressed_no_signal(RuntimeBudget.vsync_enabled)
	vsync.toggled.connect(func(value: bool) -> void:
		RuntimeBudget.set_vsync(value)
		sync_video())
	for button_name in ["VsyncPrevious", "VsyncNext"]:
		find_child(button_name, true, false).pressed.connect(func() -> void:
			vsync.button_pressed = not vsync.button_pressed)
	var volume: HSlider = find_child("MasterVolume", true, false)
	volume.set_value_no_signal(RuntimeBudget.master_volume * 100.0)
	volume.value_changed.connect(func(value: float) -> void:
		RuntimeBudget.set_master_volume(value / 100.0)
		find_child("VolumeValue", true, false).text = "%d%%" % value)
	find_child("VolumeValue", true, false).text = "%d%%" % volume.value
	var counter: CheckButton = find_child("FpsCounterToggle", true, false)
	counter.set_pressed_no_signal(RuntimeBudget.show_fps)
	counter.toggled.connect(func(value: bool) -> void:
		RuntimeBudget.set_show_fps(value)
		counter.text = "Вкл." if value else "Выкл.")
	for button_name in ["CounterPrevious", "CounterNext"]:
		find_child(button_name, true, false).pressed.connect(func() -> void: counter.button_pressed = not counter.button_pressed)
	counter.text = "Вкл." if counter.button_pressed else "Выкл."
	var vignette: CheckButton = find_child("VignetteToggle", true, false)
	vignette.set_pressed_no_signal(RuntimeBudget.vignette_enabled)
	vignette.text = "Вкл." if vignette.button_pressed else "Выкл."
	vignette.toggled.connect(func(value: bool) -> void:
		RuntimeBudget.set_vignette(value)
		vignette.text = "Вкл." if value else "Выкл.")
	for button_name in ["VignettePrevious", "VignetteNext"]:
		find_child(button_name, true, false).pressed.connect(func() -> void: vignette.button_pressed = not vignette.button_pressed)
	select_category("Graphics")
	var controls_page: Node = pages["Controls"]
	if not controls_page.has_node("MobileSettings"):
		controls_page.add_child(preload("res://scenes/ui/mobile_settings.tscn").instantiate())
	var mobile_settings: Node = controls_page.get_node("MobileSettings")
	mobile_settings.get_node("Customize").pressed.connect(func() -> void: mobile_controls().call("begin_edit"))
	mobile_settings.get_node("SprintMode").item_selected.connect(func(index: int) -> void:
		var mobile: Node = mobile_controls()
		mobile.set("button_sprint", index == 1)
		mobile.call("clear_controls")
		mobile.call("save_preferences"))
	mobile_settings.get_node("HudSize").value_changed.connect(func(value: float) -> void:
		var mobile: Node = mobile_controls()
		mobile.set("hud_scale", value / 100.0)
		mobile.call("save_preferences")
		hud.call("set_mobile_layout", true))
	reset_menu()

func mobile_controls() -> Node:
	return get_tree().current_scene.get_node("MobileControls/Controls")

func sync_mobile_settings() -> void:
	var mobile: Node = mobile_controls()
	var use_mobile: bool = mobile.get("enabled")
	for child in pages["Controls"].get_children():
		child.visible = use_mobile if child.name == "MobileSettings" else not use_mobile
	var panel: Node = pages["Controls"].get_node("MobileSettings")
	panel.get_node("SprintMode").select(1 if mobile.get("button_sprint") else 0)
	panel.get_node("HudSize").set_value_no_signal(float(mobile.get("hud_scale")) * 100.0)

func reset_menu() -> void:
	show_settings(false)

func show_settings(enabled: bool) -> void:
	settings_panel.visible = enabled
	$Navigation/Settings.set_pressed_no_signal(enabled)
	$Navigation/Settings/SelectionArrow.visible = enabled
	if enabled:
		sync_video()
		sync_mobile_settings()
	refresh_menu.call_deferred()

func close_settings() -> bool:
	if settings_panel.visible:
		show_settings(false)
		return true
	return false

func select_category(category: String) -> void:
	for key in pages:
		pages[key].visible = key == category
		tabs[key].set_pressed_no_signal(key == category)
	refresh_menu.call_deferred()

func refresh_menu() -> void:
	# Invalidate static controls with the changed page, including while paused.
	for item in find_children("*", "CanvasItem", true, false):
		item.queue_redraw()

func sync_video() -> void:
	find_child("fullscreen_toggle", true, false).text = "Вкл." if hud.is_fullscreen() else "Выкл."
	find_child("VsyncToggle", true, false).text = "Вкл." if RuntimeBudget.vsync_enabled else "Выкл."
	var resolution: OptionButton = find_child("ResolutionChoice", true, false)
	var current_size: Vector2i = DisplayServer.window_get_size() if hud.is_fullscreen() else RuntimeBudget.window_size
	for index in range(resolution.item_count):
		if resolution.get_item_metadata(index) == current_size: resolution.select(index)
	resolution.disabled = hud.is_fullscreen()
	for arrow in ["ResolutionPrevious", "ResolutionNext"]:
		find_child(arrow, true, false).disabled = hud.is_fullscreen()
	var refresh: float = DisplayServer.screen_get_refresh_rate()
	find_child("RefreshRate", true, false).text = "%d Гц" % roundi(refresh) if refresh > 0 else "—"

func cycle_option(selector: OptionButton, direction: int) -> void:
	var index: int = posmod(selector.selected + direction, selector.item_count)
	selector.select(index)
	selector.item_selected.emit(index)

func label(text: String, font_size: int = 26, tint: Color = INK) -> Label:
	var node: Label = Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", tint)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func button(text: String, node_name: String) -> Button:
	var node: Button = Button.new()
	node.name = node_name
	node.text = text
	node.custom_minimum_size.y = 44
	node.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return node

func line() -> ColorRect:
	var node: ColorRect = ColorRect.new()
	node.color = Color(0.32, 0.31, 0.27, 0.32)
	node.custom_minimum_size = Vector2(1, 1)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func spacer(height: float) -> Control:
	var node: Control = Control.new()
	node.custom_minimum_size.y = height
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func row(parent: Node, caption: String) -> HBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.13, 0.32)
	style.content_margin_left = 12
	style.content_margin_right = 4
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var box: HBoxContainer = HBoxContainer.new()
	box.custom_minimum_size.y = 42
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	var caption_label: Label = label(caption, 24)
	caption_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(caption_label)
	return box

func selector_row(parent: Node, caption: String, prefix: String, selector: Control) -> void:
	var box: HBoxContainer = row(parent, caption)
	var previous: Button = button("‹", prefix + "Previous")
	previous.alignment = HORIZONTAL_ALIGNMENT_CENTER
	previous.custom_minimum_size = Vector2(30, 42)
	box.add_child(previous)
	selector.custom_minimum_size = Vector2(140, 42)
	box.add_child(selector)
	var next: Button = button("›", prefix + "Next")
	next.alignment = HORIZONTAL_ALIGNMENT_CENTER
	next.custom_minimum_size = Vector2(30, 42)
	box.add_child(next)

func toggle(node_name: String) -> CheckButton:
	var node: CheckButton = CheckButton.new()
	node.name = node_name
	node.text = "Выкл."
	node.alignment = HORIZONTAL_ALIGNMENT_CENTER
	for icon_name in ["checked", "unchecked", "checked_disabled", "unchecked_disabled"]:
		node.add_theme_icon_override(icon_name, blank_icon)
	return node

func option(node_name: String) -> OptionButton:
	var node: OptionButton = OptionButton.new()
	node.name = node_name
	node.alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_theme_font_size_override("font_size", 24)
	node.add_theme_icon_override("arrow", blank_icon)
	return node

func build_layout() -> void:
	name = "pause_overlay"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color.TRANSPARENT
	var backdrop: ShaderMaterial = ShaderMaterial.new()
	backdrop.shader = preload("res://shaders/pause_backdrop.gdshader")
	var background: ColorRect = ColorRect.new()
	background.name = "Backdrop"
	background.material = backdrop
	background.z_index = -1
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var menu_theme: Theme = Theme.new()
	menu_theme.default_font = title_font
	menu_theme.default_font_size = 28
	for kind in ["Button", "CheckButton", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			var style: StyleBoxFlat = StyleBoxFlat.new()
			style.bg_color = Color(0.26, 0.26, 0.22, 0.28) if state in ["hover", "pressed", "hover_pressed"] else Color.TRANSPARENT
			style.content_margin_left = 12
			style.content_margin_right = 12
			menu_theme.set_stylebox(state, kind, style)
		menu_theme.set_color("font_color", kind, INK)
		menu_theme.set_color("font_hover_color", kind, Color("e3dfcf"))
		menu_theme.set_color("font_pressed_color", kind, Color("e3dfcf"))
	theme = menu_theme
	blank_icon = GradientTexture2D.new()
	blank_icon.width = 1
	blank_icon.height = 1
	blank_icon.gradient = Gradient.new()
	blank_icon.gradient.colors = PackedColorArray([Color.TRANSPARENT, Color.TRANSPARENT])
	var divider: ColorRect = line()
	divider.name = "NavigationDivider"
	divider.z_index = 1
	add_child(divider)
	divider.anchor_left = 0.307
	divider.anchor_right = 0.307
	divider.anchor_top = 0.09
	divider.anchor_bottom = 0.92
	divider.offset_right = 2
	var navigation: VBoxContainer = VBoxContainer.new()
	navigation.name = "Navigation"
	navigation.z_index = 1
	add_child(navigation)
	navigation.anchor_left = 0.065
	navigation.anchor_right = 0.277
	navigation.anchor_top = 0.17
	navigation.add_theme_constant_override("separation", 13)
	var title: Label = label("ПАУЗА", 60)
	title.name = "PauseTitle"
	title.add_theme_font_override("font", title_font)
	navigation.add_child(title)
	navigation.add_child(spacer(35))
	for spec in [["ПРОДОЛЖИТЬ", "Resume"], ["НАЧАТЬ ЗАНОВО [R]", "RestartPause"], ["НАСТРОЙКИ", "Settings"], ["ВЫЙТИ ИЗ ИГРЫ", "QuitPause"]]:
		var entry: Button = button(spec[0], spec[1])
		entry.custom_minimum_size.y = 50
		navigation.add_child(entry)
		if spec[1] == "Settings":
			entry.toggle_mode = true
			var arrow: Label = label("›", 32)
			arrow.name = "SelectionArrow"
			arrow.position = Vector2(-15, 3)
			entry.add_child(arrow)
			arrow.hide()
	settings_panel = PanelContainer.new()
	settings_panel.name = "SettingsPanel"
	settings_panel.z_index = 1
	add_child(settings_panel)
	settings_panel.anchor_left = 0.323
	settings_panel.anchor_top = 0.09
	settings_panel.anchor_right = 0.95
	settings_panel.anchor_bottom = 0.90
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.022, 0.024, 0.020, 0.78)
	panel_style.border_color = Color(0.30, 0.29, 0.25, 0.5)
	panel_style.set_border_width_all(1)
	panel_style.content_margin_left = 22
	panel_style.content_margin_right = 22
	panel_style.content_margin_top = 20
	panel_style.content_margin_bottom = 14
	settings_panel.add_theme_stylebox_override("panel", panel_style)
	var frame: VBoxContainer = VBoxContainer.new()
	frame.name = "Frame"
	frame.add_theme_constant_override("separation", 16)
	settings_panel.add_child(frame)
	frame.add_child(label("НАСТРОЙКИ", 32))
	frame.add_child(line())
	var body: HBoxContainer = HBoxContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	frame.add_child(body)
	var categories: VBoxContainer = VBoxContainer.new()
	categories.custom_minimum_size.x = 140
	categories.add_theme_constant_override("separation", 5)
	body.add_child(categories)
	var tab_group: ButtonGroup = ButtonGroup.new()
	for spec in [["ГРАФИКА", "Graphics"], ["ЗВУК", "Sound"], ["ИГРА", "Game"], ["УПРАВЛЕНИЕ", "Controls"]]:
		var tab: Button = button(spec[0], spec[1] + "Tab")
		tab.toggle_mode = true
		tab.button_group = tab_group
		categories.add_child(tab)
	var category_divider: ColorRect = line()
	body.add_child(category_divider)
	var content: Control = Control.new()
	content.name = "Pages"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(content)
	for category in ["Graphics", "Sound", "Game", "Controls"]:
		var page: VBoxContainer = VBoxContainer.new()
		page.name = category + "Page"
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		page.add_theme_constant_override("separation", 7)
		content.add_child(page)
		pages[category] = page
	var graphics: VBoxContainer = pages.Graphics
	graphics.add_child(label("ЭКРАН", 28))
	selector_row(graphics, "Полный экран", "Fullscreen", toggle("fullscreen_toggle"))
	var resolution: OptionButton = option("ResolutionChoice")
	for size in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		resolution.add_item("%d × %d" % [size.x, size.y])
		resolution.set_item_metadata(resolution.item_count - 1, size)
	resolution.tooltip_text = "Размер окна. В полном экране используется разрешение дисплея."
	selector_row(graphics, "Разрешение", "Resolution", resolution)
	var refresh_row: HBoxContainer = row(graphics, "Частота обновления")
	var refresh: Label = label("144 Гц", 24, MUTED)
	refresh.name = "RefreshRate"
	refresh.custom_minimum_size.x = 206
	refresh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	refresh.tooltip_text = "Текущая частота дисплея; изменяется в параметрах экрана Windows."
	refresh_row.add_child(refresh)
	selector_row(graphics, "Вертикальная синхронизация", "Vsync", toggle("VsyncToggle"))
	selector_row(graphics, "Виньетка", "Vignette", toggle("VignetteToggle"))
	graphics.add_child(spacer(15))
	graphics.add_child(label("ПРОИЗВОДИТЕЛЬНОСТЬ", 28))
	var fps: OptionButton = option("FpsChoice")
	for limit in [60, 144, 180, 0]: fps.add_item("Без лимита" if limit == 0 else str(limit), limit)
	selector_row(graphics, "Лимит FPS", "Fps", fps)
	selector_row(graphics, "Отображение FPS", "Counter", toggle("FpsCounterToggle"))
	var sound: VBoxContainer = pages.Sound
	sound.add_child(label("ГРОМКОСТЬ", 28))
	var volume_row: HBoxContainer = row(sound, "Общая громкость")
	var volume: HSlider = HSlider.new()
	volume.name = "MasterVolume"
	volume.min_value = 0
	volume.max_value = 100
	volume.step = 1
	volume.custom_minimum_size.x = 145
	volume.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	volume_row.add_child(volume)
	var volume_value: Label = label("80%", 24)
	volume_value.name = "VolumeValue"
	volume_value.custom_minimum_size.x = 60
	volume_row.add_child(volume_value)
	var game_page: VBoxContainer = pages.Game
	game_page.add_child(label("СЛОЖНОСТЬ", 28))
	var hard: CheckButton = CheckButton.new()
	hard.name = "difficulty_0"
	hard.text = "Хардкор · 3 монстра"
	game_page.add_child(hard)
	game_page.add_child(label("Применяется со следующего забега.\nДва охотника и бесшумный гуманоид.\nЧетыре батарейки вместо пяти.", 23, MUTED))
	var controls: VBoxContainer = pages.Controls
	controls.add_child(label("УПРАВЛЕНИЕ", 28))
	for spec in [["Движение", "WASD / стрелки"], ["Взгляд", "Мышь"], ["Спринт", "Shift"], ["Фонарик", "F"], ["Проверка захвата", "Пробел"], ["Пауза", "Esc"], ["Полный экран", "F11"]]:
		var key_row: HBoxContainer = row(controls, spec[0])
		key_row.add_child(label(spec[1], 24, MUTED))
	var footer: HBoxContainer = HBoxContainer.new()
	footer.name = "Footer"
	frame.add_child(footer)
	footer.add_child(button("[ESC]  НАЗАД", "SettingsBack"))
	var footer_gap: Control = spacer(0)
	footer_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_gap)
	footer.add_child(button("[ENTER]  ПРИМЕНИТЬ", "ApplySettings"))
	settings_panel.hide()
	hide()
