extends AnimatedSprite2D

const RIG = preload("res://scripts/actors/articulated_actor.gd")
var rig: Node2D
var cycle: float = 0.0
var run_blend: float = 0.0

func _ready() -> void:
	self_modulate.a = 0.0
	rig = get_node_or_null("ArticulatedBody") as Node2D
	if rig == null:
		rig = RIG.new()
		rig.name = "ArticulatedBody"
		add_child(rig)
	rig.setup(get_parent() as CharacterBody2D, false)

func _process(delta: float) -> void:
	rig.advance(delta)
	cycle = rig.phase
	run_blend = rig.running

func get_flashlight_grip() -> Vector2:
	return rig.flashlight_grip()
