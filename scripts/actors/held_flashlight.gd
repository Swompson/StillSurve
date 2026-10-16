@tool
extends Node2D

@export var lit: bool = true

func _draw() -> void:
	draw_rect(Rect2(-6, -4, 22, 8), Color("343a35"))
	draw_line(Vector2(0, -4), Vector2(0, 4), Color("848874"), 2)
	draw_circle(Vector2(16, 0), 4, Color("f6df9b") if lit else Color("55564d"))
