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
	var music: OptionButton = find_child("MusicChoice", true, false)
	music.select(MenuAudio.selected_track)
	music.item_selected.connect(MenuAudio.select_track)
	# The selector owns this callable, so freeing its scene disconnects it.
	MenuAudio.track_changed.connect(music.select)
	$Navigation/Settings.toggled.connect(show_settings)
	$SettingsPanel/Frame/Footer/SettingsBack.pressed.connect(func() -> void: show_settings(false))
	$SettingsPanel/Frame/Footer/ApplySettings.pressed.connect(func() -> void: show_settings(false))
	for category in ["Graphics", "Sound", "Game", "Controls"]:
		pages[category] = find_child(category + "Page", true, false)
		tabs[category] = find_child(category + "Tab", true, false)
		tabs[category].pressed.connect(select_category.bind(category))
	for spec in [["Fps", "FpsChoice"], ["Resolution", "ResolutionChoice"], ["Music", "MusicChoice"]]:
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
	for category in RuntimeBudget.category_volumes:
		var slider: HSlider = find_child(category + "Volume", true, false)
		var readout: Label = find_child(category + "VolumeValue", true, false)
		slider.set_value_no_signal(float(RuntimeBudget.category_volumes[category]) * 100.0)
		readout.text = "%d%%" % slider.value
		slider.value_changed.connect(func(value: float) -> void:
			RuntimeBudget.set_category_volume(category, value / 100.0)
			readout.text = "%d%%" % value)
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
	reset_menu()

func reset_menu() -> void:
	show_settings(false)

func show_settings(enabled: bool) -> void:
	settings_panel.visible = enabled
	$Navigation/Settings.set_pressed_no_signal(enabled)
	$Navigation/Settings/SelectionArrow.visible = enabled
	if enabled: sync_video()
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
	node.color = Color.TRANSPARENT
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
	style.bg_color = Color.TRANSPARENT
	style.set_corner_radius_all(5)
	style.anti_aliasing = true
	style.content_margin_left = 12
	style.content_margin_right = 4
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var box: HBoxContainer = HBoxContainer.new()
	box.custom_minimum_size.y = 30
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	var caption_label: Label = label(caption, 22)
	caption_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(caption_label)
	return box

func selector_row(parent: Node, caption: String, prefix: String, selector: Control) -> void:
	var box: HBoxContainer = row(parent, caption)
	var previous: Button = button("‹", prefix + "Previous")
	previous.alignment = HORIZONTAL_ALIGNMENT_CENTER
	previous.custom_minimum_size = Vector2(30, 30)
	box.add_child(previous)
	selector.custom_minimum_size = Vector2(140, 30)
	box.add_child(selector)
	var next: Button = button("›", prefix + "Next")
	next.alignment = HORIZONTAL_ALIGNMENT_CENTER
	next.custom_minimum_size = Vector2(30, 30)
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
	var game_frame: BackBufferCopy = BackBufferCopy.new()
	game_frame.name = "GameFrame"
	game_frame.z_index = -2
	game_frame.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(game_frame)
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
	apply_navigation_style()
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
	navigation.theme = get_meta("navigation_theme")
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
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	navigation.add_child(spacer(35))
	for spec in [["ПРОДОЛЖИТЬ", "Resume"], ["НАЧАТЬ ЗАНОВО [R]", "RestartPause"], ["НАСТРОЙКИ", "Settings"], ["В ГЛАВНОЕ МЕНЮ", "MainMenu"], ["ВЫЙТИ ИЗ ИГРЫ", "QuitPause"]]:
		var entry: Button = button(spec[0], spec[1])
		entry.custom_minimum_size.y = 50
		entry.alignment = HORIZONTAL_ALIGNMENT_CENTER
		navigation.add_child(entry)
		add_navigation_highlight(entry)
		if spec[1] == "Settings":
			entry.toggle_mode = true
			var arrow: Label = label("›", 32)
			arrow.name = "SelectionArrow"
			arrow.position = Vector2(-15, 3)
			entry.add_child(arrow)
			arrow.hide()
	settings_panel = PanelContainer.new()
	settings_panel.name = "SettingsPanel"
	settings_panel.set_script(load("res://scripts/ui/soft_panel.gd"))
	var soft_material: ShaderMaterial = ShaderMaterial.new()
	soft_material.shader = load("res://shaders/soft_panel.gdshader")
	settings_panel.material = soft_material
	settings_panel.z_index = 1
	add_child(settings_panel)
	settings_panel.anchor_left = 0.323
	settings_panel.anchor_top = 0.09
	settings_panel.anchor_right = 0.95
	settings_panel.anchor_bottom = 0.90
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.018, 0.019, 0.017, 0.94)
	panel_style.border_color = Color(0.30, 0.29, 0.25, 0.5)
	panel_style.set_border_width_all(0)
	panel_style.set_corner_radius_all(0)
	panel_style.anti_aliasing = true
	panel_style.shadow_color = Color(0, 0, 0, 0.6)
	panel_style.shadow_size = 0
	panel_style.content_margin_left = 22
	panel_style.content_margin_right = 22
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	settings_panel.add_theme_stylebox_override("panel", panel_style)
	var frame: VBoxContainer = VBoxContainer.new()
	frame.name = "Frame"
	frame.add_theme_constant_override("separation", 6)
	settings_panel.add_child(frame)
	frame.add_child(label("НАСТРОЙКИ", 32))
	frame.add_child(line())
	var body: VBoxContainer = VBoxContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	frame.add_child(body)
	var categories: HBoxContainer = HBoxContainer.new()
	categories.custom_minimum_size.x = 140
	categories.add_theme_constant_override("separation", 5)
	body.add_child(categories)
	var tab_group: ButtonGroup = ButtonGroup.new()
	for spec in [["ГРАФИКА", "Graphics"], ["ЗВУК", "Sound"], ["ИГРА", "Game"], ["УПРАВЛЕНИЕ", "Controls"]]:
		var tab: Button = button(spec[0], spec[1] + "Tab")
		tab.custom_minimum_size.y = 32
		tab.add_theme_font_size_override("font_size", 23)
		tab.toggle_mode = true
		tab.button_group = tab_group
		categories.add_child(tab)
	var category_divider: ColorRect = line()
	body.add_child(category_divider)
	var content: Control = Control.new()
	content.name = "Pages"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(content)
	for category in ["Graphics", "Sound", "Game", "Controls"]:
		var page: VBoxContainer = VBoxContainer.new()
		page.name = category + "Page"
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		page.add_theme_constant_override("separation", 3)
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
	for spec in [["Музыка", "Music"], ["Окружение", "Environment"], ["Шаги", "StepsRoom"], ["Дыхание", "Breathing"], ["Сердцебиение", "Heartbeat"], ["Звуковые эффекты", "Effects"]]:
		var channel_row: HBoxContainer = row(sound, spec[0])
		var channel: HSlider = HSlider.new()
		channel.name = spec[1] + "Volume"
		channel.max_value = 100
		channel.step = 1
		channel.value = 100
		channel.custom_minimum_size.x = 145
		channel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		channel_row.add_child(channel)
		var readout: Label = label("100%", 24)
		readout.name = spec[1] + "VolumeValue"
		readout.custom_minimum_size.x = 60
		channel_row.add_child(readout)
	sound.add_child(spacer(15))
	sound.add_child(label("МУЗЫКА ГЛАВНОГО МЕНЮ", 28))
	var music: OptionButton = option("MusicChoice")
	for caption in ["Основная", "Трек 1", "Трек 2", "Трек 3"]:
		music.add_item(caption)
	selector_row(sound, "Композиция", "Music", music)
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
	for control in settings_panel.find_children("*", "BaseButton", true, false):
		for font_state in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
			control.add_theme_color_override(font_state, Color("fff6de"))
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			var clear: StyleBoxEmpty = StyleBoxEmpty.new()
			clear.content_margin_left = 12
			clear.content_margin_right = 12
			control.add_theme_stylebox_override(state, clear)
	hide()

func apply_navigation_style() -> void:
	var navigation_theme: Theme = Theme.new()
	navigation_theme.default_font = title_font
	navigation_theme.default_font_size = 30
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	empty.content_margin_left = 22
	empty.content_margin_right = 22
	for state in ["normal", "disabled"]:
		navigation_theme.set_stylebox(state, "Button", empty)
	for state in ["hover", "pressed", "hover_pressed", "focus"]:
		navigation_theme.set_stylebox(state, "Button", empty)
	navigation_theme.set_color("font_color", "Button", Color("85847d"))
	for state in ["font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		navigation_theme.set_color(state, "Button", Color("f2eee0"))
	# The theme is assigned after navigation exists by the scene baker.
	set_meta("navigation_theme", navigation_theme)

func add_navigation_highlight(entry: BaseButton) -> void:
	var glow: TextureRect = TextureRect.new()
	glow.name = "Highlight"
	glow.set_script(load("res://scripts/ui/menu_highlight.gd"))
	var source: Texture2D = load("res://assets/ui/menu/lightbutton.png")
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(0, source.get_height() * 0.42, source.get_width() * 0.56, source.get_height() * 0.22)
	glow.texture = atlas
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.show_behind_parent = true
	var glow_material: ShaderMaterial = ShaderMaterial.new()
	glow_material.shader = load("res://shaders/menu_highlight.gdshader")
	glow.material = glow_material
	glow.modulate.a = 0.0
	glow.process_mode = Node.PROCESS_MODE_ALWAYS
	entry.add_child(glow)
	glow.fit_to_text()
