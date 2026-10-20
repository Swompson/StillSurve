extends SceneTree

func own_children(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		child.owner = scene_root
		# Keep instantiated scenes intact; owning their descendants duplicates
		# internal nodes when the packed parent is opened again.
		if child.scene_file_path.is_empty():
			own_children(child, scene_root)

func _initialize() -> void:
	var menu_root: CanvasLayer = CanvasLayer.new()
	menu_root.name = "MainMenu"
	menu_root.set_script(load("res://scripts/ui/main_menu.gd"))
	var layout: Control = Control.new()
	layout.name = "Layout"
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(layout)
	var background: TextureRect = TextureRect.new()
	background.name = "Background"
	background.texture = load("res://assets/ui/menu/mainmenu.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.offset_left = -40
	background.offset_top = -40
	background.offset_right = 40
	background.offset_bottom = 40
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(background)
	var dust: Node2D = load("res://scenes/ui/menu_dust.tscn").instantiate()
	layout.add_child(dust)
	var outside: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	outside.name = "OutsideWind"
	outside.stream = load("res://assets/ui/menu/outsidemenu.mp3")
	outside.position = Vector2(922, 324)
	outside.volume_db = -16.0
	outside.max_distance = 2200.0
	outside.attenuation = 0.5
	outside.panning_strength = 1.5
	outside.bus = &"Environment"
	outside.autoplay = true
	layout.add_child(outside)
	var wind: AudioStreamPlayer = AudioStreamPlayer.new()
	wind.name = "MenuWind"
	var wind_stream: AudioStreamMP3 = load("res://assets/ui/menu/podzemele-zvuk-vetra.mp3")
	wind_stream.loop = true
	wind.stream = wind_stream
	wind.bus = &"Environment"
	wind.volume_db = -19.0
	wind.autoplay = true
	menu_root.add_child(wind)
	var menu: ColorRect = load("res://scripts/ui/pause_menu.gd").new()
	menu.build_layout()
	layout.add_child(menu)
	menu.show()
	menu.get_node("Backdrop").free()
	menu.get_node("NavigationDivider").free()
	var settings: Control = menu.get_node("SettingsPanel")
	settings.anchor_left = 0.34
	settings.anchor_right = 0.95
	settings.anchor_top = 0.27
	settings.anchor_bottom = 0.98
	var navigation: VBoxContainer = menu.get_node("Navigation")
	navigation.anchor_left = 0.085
	navigation.anchor_right = 0.085
	navigation.offset_right = 400
	navigation.anchor_top = 0.52
	navigation.theme.default_font_size = 44
	navigation.add_theme_constant_override("separation", 42)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var centered_style: StyleBoxEmpty = StyleBoxEmpty.new()
		centered_style.content_margin_left = 22
		centered_style.content_margin_right = 22
		navigation.theme.set_stylebox(state, "Button", centered_style)
	var title: Label = navigation.get_node("PauseTitle")
	title.text = "STILLSURVE"
	navigation.remove_child(title)
	menu.add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	title.anchor_left = 0.085
	title.anchor_top = 0.075
	title.anchor_right = 0.085
	title.offset_right = 400
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 110)
	navigation.get_child(0).free()
	navigation.get_node("Resume").text = "НАЧАТЬ ИГРУ"
	navigation.get_node("RestartPause").free()
	navigation.get_node("MainMenu").free()
	navigation.get_node("QuitPause").text = "ВЫХОД"
	for entry in navigation.get_children():
		entry.alignment = HORIZONTAL_ALIGNMENT_CENTER
		entry.get_node("Highlight").fit_to_text()
	var mode_panel: PanelContainer = preload("res://scenes/ui/mode_selection.tscn").instantiate()
	layout.add_child(mode_panel)
	mode_panel.hide()
	var version: Label = Label.new()
	version.name = "Version"
	version.text = str(ProjectSettings.get_setting("application/config/version")).get_slice("-", 0) + "  preAlpha"
	var version_font: SystemFont = SystemFont.new()
	version_font.font_names = PackedStringArray(["Georgia", "Times New Roman"])
	version.add_theme_font_override("font", version_font)
	version.add_theme_font_size_override("font_size", 20)
	version.modulate = Color("85847d")
	version.anchor_top = 1.0
	version.anchor_bottom = 1.0
	version.offset_left = 8
	version.offset_top = -34
	version.offset_right = 200
	version.offset_bottom = -8
	menu.add_child(version)
	own_children(menu_root, menu_root)
	var scene: PackedScene = PackedScene.new()
	assert(scene.pack(menu_root) == OK)
	var output_path: String = "res://scenes/ui/main_menu.tscn" if OS.get_cmdline_user_args().is_empty() else OS.get_cmdline_user_args()[0]
	assert(ResourceSaver.save(scene, output_path) == OK)
	menu_root.free()
	quit()
