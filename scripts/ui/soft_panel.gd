@tool
extends PanelContainer

func _ready() -> void:
	material = material.duplicate()
	resized.connect(update_mask)
	update_mask()

func update_mask() -> void:
	material.set_shader_parameter("panel_size", size)
