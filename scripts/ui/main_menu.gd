extends CanvasLayer

const LOADING_SCREEN: PackedScene = preload("res://scenes/ui/loading_screen.tscn")

var starting: bool = false
var atmosphere_clock: float = 0.0
var pointer_offset: Vector2 = Vector2.ZERO

func _process(delta: float) -> void:
	atmosphere_clock += delta
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var pointer: Vector2 = (get_viewport().get_mouse_position() / viewport_size - Vector2(0.5, 0.5)).clamp(Vector2(-0.5, -0.5), Vector2(0.5, 0.5))
	pointer_offset = pointer_offset.lerp(pointer * 12.0, 1.0 - exp(-delta * 2.5))
	var drift_sway: Vector2 = Vector2(sin(atmosphere_clock * 0.22) * 12.0, sin(atmosphere_clock * 0.29) * 7.0)
	var sway: Vector2 = drift_sway - pointer_offset
	$Layout/Background.position = Vector2(-40, -40) + sway
	$Layout/Background.rotation = sin(atmosphere_clock * 0.23) * 0.002
	for layer in $Layout/Dust.get_children():
		layer.camera_offset = drift_sway * (0.35 + layer.depth * 0.65) - pointer_offset * layer.depth * 0.20

func _ready() -> void:
	$Layout/pause_overlay/Version.text = str(ProjectSettings.get_setting("application/config/version")).get_slice("-", 0) + "  preAlpha"
	MenuAudio.set_menu_active(true)
	$MenuWind.stream.loop = true
	$Layout/OutsideWind.stream.loop = true
	get_viewport().size_changed.connect(update_atmosphere_size)
	update_atmosphere_size()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Input.set_custom_mouse_cursor(null)
	var menu: ColorRect = $Layout/pause_overlay
	menu.show()
	menu.get_node("Navigation/Resume").pressed.connect(func() -> void:
		menu.show_settings(false)
		$Layout/ModePanel.visible = not $Layout/ModePanel.visible)
	menu.get_node("Navigation/Settings").toggled.connect(func(enabled: bool) -> void:
		if enabled: $Layout/ModePanel.hide())
	$Layout/ModePanel/Choices/Normal.pressed.connect(func() -> void:
		if starting: return
		get_tree().set_meta("hard_mode", false)
		start_game())
	$Layout/ModePanel/Choices/Hard.pressed.connect(func() -> void:
		if starting: return
		get_tree().set_meta("hard_mode", true)
		start_game())
	$Layout/ModePanel/Choices/Back.pressed.connect(func() -> void: $Layout/ModePanel.hide())
	menu.get_node("Navigation/QuitPause").pressed.connect(func() -> void: get_tree().quit())
	var fps: OptionButton = menu.find_child("FpsChoice", true, false)
	fps.select(RuntimeBudget.FPS_OPTIONS.find(RuntimeBudget.active_fps))
	fps.item_selected.connect(func(index: int) -> void: RuntimeBudget.set_fps(fps.get_item_id(index)))
	menu.find_child("fullscreen_toggle", true, false).toggled.connect(set_fullscreen)
	var hover_sound: AudioStreamPlayer = MenuAudio.get_node("Hover")
	var accept_sound: AudioStreamPlayer = MenuAudio.get_node("Accept")
	for button in find_children("*", "BaseButton", true, false):
		button.mouse_entered.connect(func() -> void:
			if button.is_visible_in_tree(): hover_sound.play())
		if button not in [$Layout/ModePanel/Choices/Normal, $Layout/ModePanel/Choices/Hard]:
			button.pressed.connect(func() -> void: accept_sound.play())

func start_game() -> void:
	if starting: return
	starting = true
	MenuAudio.play_start_confirmation()
	get_tree().change_scene_to_packed(LOADING_SCREEN)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event.keycode == KEY_ESCAPE:
		$Layout/ModePanel.hide()
		$Layout/pause_overlay.close_settings()
	elif event.keycode == KEY_F11:
		set_fullscreen(not is_fullscreen())

func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]

func set_fullscreen(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	if not enabled: get_window().size = RuntimeBudget.window_size
	$Layout/pause_overlay.sync_video()

func update_atmosphere_size() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	$Layout/OutsideWind.position = viewport_size * Vector2(0.72, 0.45)

func _exit_tree() -> void:
	MenuAudio.set_menu_active(false)

