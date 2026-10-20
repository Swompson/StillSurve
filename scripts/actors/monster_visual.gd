extends Node2D

var rig: Node2D

func _ready() -> void:
	rig = get_node_or_null("ArticulatedBody") as Node2D
	if rig == null:
		push_error("Hunter visual requires its authored ArticulatedBody scene.")
		set_process(false)
		return
	rig.setup(get_parent() as CharacterBody2D, true)

func _process(delta: float) -> void:
	var actor: CharacterBody2D = get_parent() as CharacterBody2D
	rotation = lerp_angle(rotation, float(actor.get("facing_angle")) - PI * 0.5, 1.0 - exp(-14.0 * delta))
	rig.advance(delta)
