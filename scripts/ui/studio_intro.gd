extends Control

const DURATION: float = 4.5
var elapsed: float = 0.0
var leaving: bool = false
var capture: bool = false

func _ready() -> void:
	capture = "--intro-capture" in OS.get_cmdline_user_args()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	$Title.modulate.a = 0.0
	$Subtitle.modulate.a = 0.0
	ResourceLoader.load_threaded_request("res://scenes/ui/main_menu.tscn")

func _process(delta: float) -> void:
	elapsed += delta
	$Backdrop.material.set_shader_parameter("clock", elapsed)
	var fade: float = smoothstep(0.35, 1.2, elapsed) * (1.0 - smoothstep(3.6, DURATION, elapsed))
	var flicker: float = 0.72 if (elapsed > 0.85 and elapsed < 0.94) or (elapsed > 1.08 and elapsed < 1.12) else 1.0
	$Title.modulate.a = fade * flicker
	$Subtitle.modulate.a = smoothstep(1.35, 2.0, elapsed) * fade * 0.65
	$Rule.modulate.a = fade * 0.4
	$Rule.scale.x = lerpf(0.05, 1.0, smoothstep(0.5, 2.0, elapsed))
	if elapsed >= DURATION:
		if capture: get_tree().quit()
		else: finish()

func finish() -> void:
	if leaving or elapsed < DURATION: return
	if ResourceLoader.load_threaded_get_status("res://scenes/ui/main_menu.tscn") != ResourceLoader.THREAD_LOAD_LOADED: return
	leaving = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get("res://scenes/ui/main_menu.tscn"))
