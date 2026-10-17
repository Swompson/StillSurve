@tool
extends Control

var stalker: Node
var displayed_phase: float = 0.0
var displayed_round: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(_delta: float) -> void:
	if Engine.is_editor_hint(): return
	var game: Node = get_tree().current_scene
	stalker = game.get_node_or_null("Stalker") if is_instance_valid(game) else null
	visible = is_instance_valid(stalker) and stalker.get("state") == "grab" and not game.get("finished")
	if visible: queue_redraw()

func _draw() -> void:
	if not Engine.is_editor_hint() and (not is_instance_valid(stalker) or stalker.get("state") != "grab"): return
	var center: Vector2 = Vector2(size.x * 0.5, minf(size.y * 0.66, size.y - 200.0))
	var phase: float = 0.12 if Engine.is_editor_hint() else float(stalker.call("needle_phase"))
	var target: float = 0.72 if Engine.is_editor_hint() else float(stalker.get("green_center"))
	var half_width: float = 0.10 if Engine.is_editor_hint() else float(stalker.get("green_half_width"))
	var results: Array = [] if Engine.is_editor_hint() else stalker.get("results")
	var complete: bool = results.size() >= 3
	if not Engine.is_editor_hint():
		phase = fposmod(phase + Engine.get_physics_interpolation_fraction() / float(Engine.physics_ticks_per_second), 1.0)
		displayed_phase = phase
		displayed_round = results.size()
	draw_circle(center, 96.0, Color(0.015, 0.018, 0.02, 0.94))
	draw_arc(center, 82.0, 0.0, TAU, 96, Color(0.35, 0.32, 0.30), 10.0, true)
	if not complete:
		draw_arc(center, 82.0, (target - half_width) * TAU - PI * 0.5, (target + half_width) * TAU - PI * 0.5, 40, Color("71cd89"), 14.0, true)
	var needle: Vector2 = Vector2.from_angle(phase * TAU - PI * 0.5)
	if not complete: draw_line(center - needle * 10.0, center + needle * 92.0, Color("f1e9d6"), 4.0, true)
	draw_circle(center, 5.0, Color("f1e9d6"))

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not visible or get_tree().paused: return
	var keyboard: bool = event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_SPACE or event.keycode == KEY_SPACE)
	var mouse: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if keyboard or mouse:
		# Judge the angle that was actually drawn, including high refresh interpolation.
		var phase: float = displayed_phase if displayed_round == stalker.get("results").size() else -1.0
		stalker.call("submit_check", phase)
		get_viewport().set_input_as_handled()
