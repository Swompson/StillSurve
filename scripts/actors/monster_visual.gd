extends Node2D

const RIG = preload("res://scripts/actors/articulated_actor.gd")
var rig: Node2D

func _ready() -> void:
	rig = get_node_or_null("ArticulatedBody") as Node2D
	if rig == null:
		rig = RIG.new()
		rig.name = "ArticulatedBody"
		add_child(rig)
	rig.setup(get_parent() as CharacterBody2D, true)

func _process(delta: float) -> void:
	var actor: CharacterBody2D = get_parent() as CharacterBody2D
	rotation = lerp_angle(rotation, float(actor.get("facing_angle")) - PI * 0.5, 1.0 - exp(-14.0 * delta))
	rig.advance(delta)
