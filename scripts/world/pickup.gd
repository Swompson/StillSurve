@tool
extends Node2D

@export_enum("figurine", "battery") var kind: String = "figurine":
	set(value):
		kind = value
		queue_redraw()
var game: Node
var collected: bool = false

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or collected or not is_instance_valid(game) or game.get("finished"):
		return
	var player: CharacterBody2D = game.get("player")
	if global_position.distance_to(player.global_position) < 48.0:
		game.call("collect_pickup", self)

func _draw() -> void:
	if collected:
		return
	if kind == "battery":
		draw_circle(Vector2.ZERO, 20, Color(0.6, 0.65, 0.38, 0.08))
		draw_rect(Rect2(-10, -16, 20, 32), Color("a3a572"))
		draw_rect(Rect2(-7, -10, 14, 23), Color("303e35"))
		draw_rect(Rect2(-4, -20, 8, 4), Color("d6d0ab"))
		draw_line(Vector2(-4, -2), Vector2(4, -2), Color("e8e1a3"), 2)
		draw_line(Vector2(0, -6), Vector2(0, 2), Color("e8e1a3"), 2)
		return
	# Ochre stain and scattered straw are visible clues close to each figurine.
	var mark: Vector2 = Vector2(-85, 48)
	draw_circle(mark, 33, Color(0.45, 0.28, 0.1, 0.24))
	draw_arc(mark, 27, 0.2, 5.4, 22, Color(0.7, 0.57, 0.32, 0.65), 3)
	for index in range(12):
		var offset: Vector2 = Vector2(sin(index * 7.1) * 42, cos(index * 3.2) * 30)
		draw_line(mark + offset, mark + offset + Vector2(11, -4), Color("9b814e"), 1.4)
	draw_line(mark + Vector2(16, -3), Vector2(-22, 8), Color(0.65, 0.49, 0.25, 0.4), 5)
	for strand in range(5):
		var dx: float = strand - 2
		draw_line(Vector2(dx, -17), Vector2(dx * 1.4, 12), Color("c3a765"), 1.5)
		draw_line(Vector2(-16, dx), Vector2(16, -dx), Color("aa8f50"), 1.1)
		draw_line(Vector2(dx, 8), Vector2(-9 + dx, 25), Color("c1a463"), 1.1)
		draw_line(Vector2(dx, 8), Vector2(9 + dx, 25), Color("c1a463"), 1.1)
	draw_circle(Vector2(0, -20), 8, Color("b29b63"))
	draw_line(Vector2(-7, 0), Vector2(7, 0), Color("6e3e2c"), 3)
	draw_line(Vector2(-4, -12), Vector2(4, -12), Color("6e3e2c"), 2)
