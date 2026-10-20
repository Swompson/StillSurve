extends Control

const TARGET: String = "res://scenes/game.tscn"
const MINIMUM_DISPLAY_TIME: float = 3.0
var elapsed: float = 0.0
var requested: bool = false
var switching: bool = false
var failed: bool = false
var camera_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	MenuAudio.set_menu_active(false)
	$LoadingAudio.stream = $LoadingAudio.stream.duplicate()
	$LoadingAudio.stream.loop = true
	$LoadingAudio.play()
	$HUD/Error.hide()
	$HUD/Back.hide()
	$HUD/Back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	# Present the actual loading screen before starting work, including cached loads.
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	var result: Error = ResourceLoader.load_threaded_request(TARGET, "PackedScene")
	if result != OK:
		show_error()
		return
	requested = true

func _process(delta: float) -> void:
	elapsed += delta
	var pointer: Vector2 = (get_viewport().get_mouse_position() / get_viewport_rect().size - Vector2(0.5, 0.5)).clamp(Vector2(-0.5, -0.5), Vector2(0.5, 0.5))
	var target_offset: Vector2 = Vector2(sin(elapsed * 0.19) * 10.0, sin(elapsed * 0.27) * 6.0) - pointer * 9.0
	camera_offset = camera_offset.lerp(target_offset, 1.0 - exp(-delta * 2.0))
	$Background.position = Vector2(-32, -32) + camera_offset
	$Background.rotation = sin(elapsed * 0.13) * 0.0015
	if not requested or switching or failed: return
	var progress: Array = []
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(TARGET, progress)
	if not progress.is_empty(): $HUD/Progress.value = maxf($HUD/Progress.value, float(progress[0]) * 100.0)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		$HUD/Progress.value = 100.0
		if elapsed < MINIMUM_DISPLAY_TIME: return
		switching = true
		enter_game.call_deferred()
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		show_error()

func enter_game() -> void:
	var fade: Tween = create_tween()
	fade.tween_property($LoadingAudio, "volume_db", -60.0, 0.2)
	await fade.finished
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	var packed: PackedScene = ResourceLoader.load_threaded_get(TARGET) as PackedScene
	if packed == null or get_tree().change_scene_to_packed(packed) != OK:
		show_error()

func show_error() -> void:
	failed = true
	$LoadingAudio.stop()
	$HUD/Error.show()
	$HUD/Back.show()
