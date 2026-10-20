extends AnimatedSprite2D

var rig: Node2D
var cycle: float = 0.0
var run_blend: float = 0.0

func _ready() -> void:
	self_modulate.a = 0.0
	rig = $ArticulatedBody
	rig.setup(get_parent() as CharacterBody2D, false)

func _process(delta: float) -> void:
	rig.advance(delta)
	cycle = rig.phase
	run_blend = rig.running

func get_flashlight_grip() -> Vector2:
	return rig.flashlight_grip()

func get_flashlight_angle() -> float:
	return rig.flashlight_angle()

func get_flashlight_alpha() -> float:
	return rig.flashlight_alpha()
