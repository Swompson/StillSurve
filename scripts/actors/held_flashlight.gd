@tool
extends Node2D

@export var lit: bool = true

func _draw() -> void:
	# The lens faces forward: overhead only its narrow front edge is visible.
	if lit:
		draw_line(Vector2(-0.2, -1.8), Vector2(-0.2, 1.8), Color(0.92, 0.91, 0.80, 0.65), 0.65, true)
