@tool
extends CanvasLayer

func _ready() -> void:
	if Engine.is_editor_hint(): return
	visible = RuntimeBudget.vignette_enabled
	RuntimeBudget.vignette_changed.connect(func(enabled: bool) -> void: visible = enabled)
