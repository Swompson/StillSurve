extends Node

const FPS_OPTIONS: Array[int] = [60, 144, 180, 0]
const BACKGROUND_FPS: int = 15
var active_fps: int = 60
var focused: bool = true
var paused: bool = false
var focus_loss_pending: bool = false
var focus_loss_elapsed: float = 0.0
var vsync_enabled: bool = false
var master_volume: float = 0.794328
var show_fps: bool = false
var vignette_enabled: bool = true
signal vignette_changed(enabled: bool)
var window_size: Vector2i = Vector2i(1280, 720)
var settings_path: String = "user://settings.cfg"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var settings: ConfigFile = ConfigFile.new()
	settings.load(settings_path)
	var saved: int = int(settings.get_value("video", "max_fps", 60))
	active_fps = saved if saved in FPS_OPTIONS else 60
	vsync_enabled = bool(settings.get_value("video", "vsync", false))
	master_volume = clampf(float(settings.get_value("audio", "master_volume", 0.794328)), 0.0, 1.0)
	show_fps = bool(settings.get_value("video", "show_fps", false))
	vignette_enabled = bool(settings.get_value("video", "vignette", true))
	window_size = settings.get_value("video", "window_size", Vector2i(1280, 720))
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	# The editor can embed the game before its first native focus event arrives.
	# Application focus notifications are unreliable for that child window.
	focused = true
	get_window().focus_entered.connect(mark_focused)
	get_window().focus_exited.connect(request_background)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)
	apply_budget()

func mark_focused() -> void:
	focus_loss_pending = false
	focus_loss_elapsed = 0.0
	if not focused:
		focused = true
		apply_budget()

func request_background() -> void:
	# A native FPS popup temporarily takes focus from the main game window.
	focus_loss_pending = true
	focus_loss_elapsed = 0.0

func has_focused_game_window() -> bool:
	for window_id in DisplayServer.get_window_list():
		if DisplayServer.window_is_focused(window_id):
			return true
	return false

func _process(delta: float) -> void:
	if DisplayServer.get_name() == "headless": return
	if focus_loss_pending or not focused:
		update_window_focus(has_focused_game_window(), delta)

func update_window_focus(window_focused: bool, delta: float) -> void:
	if window_focused:
		mark_focused()
	elif focus_loss_pending:
		focus_loss_elapsed += delta
		if focus_loss_elapsed >= 0.3:
			focus_loss_pending = false
			focused = false
			apply_budget()

func _input(event: InputEvent) -> void:
	# Input delivered to an embedded game proves it is active, even if Windows
	# failed to send its initial focus-in event. Menu input follows this path too.
	if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		mark_focused()
	elif event is InputEventMouseMotion and has_focused_game_window():
		mark_focused()

func set_paused(value: bool) -> void:
	paused = value
	apply_budget()

func apply_budget() -> void:
	Engine.max_fps = BACKGROUND_FPS if not focused else active_fps
	OS.low_processor_usage_mode = not focused

func set_fps(value: int, persist: bool = true) -> void:
	if value not in FPS_OPTIONS:
		return
	active_fps = value
	apply_budget()
	if not persist: return
	var settings: ConfigFile = ConfigFile.new()
	settings.load(settings_path)
	settings.set_value("video", "max_fps", active_fps)
	settings.save(settings_path)

func save_preference(section: String, key: String, value: Variant) -> void:
	var settings: ConfigFile = ConfigFile.new()
	settings.load(settings_path)
	settings.set_value(section, key, value)
	settings.save(settings_path)

func set_vsync(enabled: bool) -> void:
	vsync_enabled = enabled
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED)
	save_preference("video", "vsync", enabled)

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	save_preference("audio", "master_volume", master_volume)

func set_show_fps(enabled: bool) -> void:
	show_fps = enabled
	save_preference("video", "show_fps", enabled)

func set_vignette(enabled: bool) -> void:
	vignette_enabled = enabled
	vignette_changed.emit(enabled)
	save_preference("video", "vignette", enabled)

func set_window_size(value: Vector2i) -> void:
	window_size = value
	if get_window().mode == Window.MODE_WINDOWED:
		get_window().size = window_size
	save_preference("video", "window_size", value)
