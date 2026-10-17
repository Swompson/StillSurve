@tool
extends Node2D

@export var lit: bool = true

func _draw() -> void:
	draw_circle(Vector2.ZERO, 3.3, Color("f6df9b") if lit else Color("55564d"))
