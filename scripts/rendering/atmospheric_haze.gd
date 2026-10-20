extends CanvasLayer

var drift_time: float = 0.0
var haze_material: ShaderMaterial
var previous_camera: Vector2 = Vector2.INF
var previous_view: Vector2 = Vector2.INF

func _ready() -> void:
	haze_material = $Overlay.material
	_process(0.0)

func _process(delta: float) -> void:
	drift_time += delta
	if not visible: return
	var size: Vector2 = get_viewport().get_visible_rect().size
	var camera: Camera2D = get_viewport().get_camera_2d()
	var center: Vector2 = camera.get_screen_center_position() if camera else Vector2.ZERO
	var view: Vector2 = size / camera.zoom if camera else size
	if center != previous_camera:
		haze_material.set_shader_parameter("camera_position", center)
		previous_camera = center
	if view != previous_view:
		haze_material.set_shader_parameter("view_size", view)
		previous_view = view
	haze_material.set_shader_parameter("drift_time", drift_time)
