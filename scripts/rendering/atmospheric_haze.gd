extends CanvasLayer

var drift_time: float = 0.0
var haze_material: ShaderMaterial

func _ready() -> void:
	layer = 2
	var haze: ColorRect = ColorRect.new()
	haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	haze_material = ShaderMaterial.new()
	haze_material.shader = preload("res://shaders/atmospheric_haze.gdshader")
	haze.material = haze_material
	add_child(haze)
	haze.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	drift_time += delta
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera:
		haze_material.set_shader_parameter("camera_position", camera.get_screen_center_position())
		haze_material.set_shader_parameter("view_size", get_viewport().get_visible_rect().size / camera.zoom)
	haze_material.set_shader_parameter("drift_time", drift_time)
