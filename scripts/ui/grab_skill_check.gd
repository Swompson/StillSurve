@tool
extends Control

const PAPER: Color = Color("d9cba9")
const SUCCESS: Color = Color("a4b47c")
const FAILURE: Color = Color("b8614b")
const PENDING: Color = Color("49473c")
var stalker: Node
var displayed_phase: float = 0.0
var displayed_round: int = -1
var shown_results: int = 0
var opening: float = 1.0
var feedback_time: float = 0.0
var feedback_color: Color = PAPER
var was_active: bool = false
var arc_target: Vector2 = Vector2.INF

@onready var dial: Node2D = $Dial
@onready var target_arc: Line2D = $Dial/Target
@onready var needle: Node2D = $Dial/Needle
@onready var feedback_ring: Line2D = $Dial/Feedback
@onready var hint: Label = $Dial/Hint

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(delta: float) -> void:
	var preview: bool = Engine.is_editor_hint()
	if not preview:
		var game: Node = get_tree().current_scene
		stalker = game.get_node_or_null("Stalker") if is_instance_valid(game) else null
		visible = is_instance_valid(stalker) and stalker.get("state") == "grab" and not game.get("finished")
		if not visible:
			was_active = false
			return
		if not was_active:
			opening = 0.0
			shown_results = 0
			feedback_time = 0.0
		was_active = true
	var phase: float = 0.12 if preview else float(stalker.call("needle_phase"))
	var target: float = 0.72 if preview else float(stalker.get("green_center"))
	var half_width: float = 0.10 if preview else float(stalker.get("green_half_width"))
	var results: Array = [] if preview else stalker.get("results")
	var complete: bool = results.size() >= 3
	if not preview:
		# Keep visual rotation and input judgement on the same interpolated angle.
		phase = fposmod(phase + Engine.get_physics_interpolation_fraction() / float(Engine.physics_ticks_per_second), 1.0)
		displayed_phase = phase
		displayed_round = results.size()
		if results.size() > shown_results:
			feedback_color = SUCCESS if results.back() else FAILURE
			feedback_time = 0.36
		shown_results = results.size()
	opening = minf(1.0, opening + delta / 0.16)
	feedback_time = maxf(0.0, feedback_time - delta)
	var ease: float = 1.0 - pow(1.0 - opening, 3.0)
	dial.position = Vector2(size.x * 0.5, minf(size.y * 0.66, size.y - 200.0))
	dial.scale = Vector2.ONE * lerpf(0.94, 1.0, ease)
	dial.modulate.a = ease
	needle.rotation = phase * TAU
	needle.visible = not complete
	target_arc.visible = not complete
	if arc_target != Vector2(target, half_width):
		arc_target = Vector2(target, half_width)
		var points: PackedVector2Array = []
		for index in range(49):
			points.append(Vector2.from_angle((target - half_width + 2.0 * half_width * float(index) / 48.0) * TAU - PI * 0.5) * 82.0)
		target_arc.points = points
	var flash: float = feedback_time / 0.36
	feedback_ring.default_color = Color(feedback_color, flash * 0.8)
	feedback_ring.scale = Vector2.ONE * (1.0 + (1.0 - flash) * 0.035)
	hint.text = "ДЕРЖИСЬ..." if complete else "ПРОБЕЛ / ЛКМ"
	hint.modulate = PAPER.lerp(feedback_color, flash * 0.65)
	for index in range(3):
		var marker: Polygon2D = dial.get_node("Result%d" % (index + 1))
		marker.color = (SUCCESS if results[index] else FAILURE) if index < results.size() else PENDING
		marker.scale = Vector2.ONE * (1.0 + flash * 0.3 if index == results.size() - 1 else 1.0)

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not visible or get_tree().paused or not is_instance_valid(stalker): return
	var keyboard: bool = event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_SPACE or event.keycode == KEY_SPACE)
	var mouse: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if keyboard or mouse:
		# Judge the angle that was actually drawn, including high refresh interpolation.
		var phase: float = displayed_phase if displayed_round == stalker.get("results").size() else -1.0
		stalker.call("submit_check", phase)
		get_viewport().set_input_as_handled()
