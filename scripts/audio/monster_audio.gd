extends AudioStreamPlayer2D

const GROWL = preload("res://assets/audio/monster/nearby_growl.wav")
@export var audible_radius: float = 1150.0
var cooldown: float = 0.6

func _ready() -> void:
	stream = GROWL
	max_distance = audible_radius
	attenuation = 0.75
	volume_db = -8.0
	bus = &"Master"

func _process(delta: float) -> void:
	var monster: CharacterBody2D = get_parent() as CharacterBody2D
	var player: CharacterBody2D = monster.get("player") as CharacterBody2D
	if not monster.get("active") or not is_instance_valid(player):
		stop()
		return
	if monster.global_position.distance_to(player.global_position) > audible_radius:
		stop()
		cooldown = minf(cooldown, 0.6)
		return
	cooldown -= delta
	var maze: Node = monster.get("maze") as Node
	var blocked: bool = is_instance_valid(maze) and not maze.call("clear_line", monster.global_position, player.global_position)
	volume_db = move_toward(volume_db, -12.0 if blocked else -8.0, delta * 12.0)
	if cooldown <= 0.0 and not playing:
		pitch_scale = randf_range(0.96, 1.03)
		play()
		cooldown = randf_range(3.5, 5.5) if monster.get("state") == "hunt" else randf_range(5.0, 8.0)
