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

func _ready() -> void:
	set_physics_process(not Engine.is_editor_hint())
