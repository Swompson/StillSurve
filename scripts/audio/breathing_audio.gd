extends AudioStreamPlayer

const RUN_BREATH = preload("res://assets/audio/breathing/running_breath.wav")
const TIRED_BREATH = preload("res://assets/audio/breathing/exhausted_breath.wav")
var player: CharacterBody2D
var cooldown: float = 0.0
var recovery: float = 0.0
var noise_cooldown: float = 0.0

func _ready() -> void:
	player = get_parent() as CharacterBody2D
	bus = &"Breathing"

func _process(delta: float) -> void:
	if not player.get("alive"):
		stop()
		return
	cooldown -= delta
	noise_cooldown -= delta
	var running: bool = bool(player.get("sprinting"))
	var exhausted: bool = bool(player.get("exhausted"))
	if running:
		recovery = 3.0
	else:
		recovery = maxf(0.0, recovery - delta)
	if cooldown <= 0.0 and (running or exhausted or recovery > 0.0):
		stream = TIRED_BREATH if exhausted else RUN_BREATH
		volume_db = -16.0 if exhausted else -21.0
		pitch_scale = randf_range(0.98, 1.02)
		play()
		cooldown = 1.6 if exhausted else 1.8
	if exhausted and noise_cooldown <= 0.0:
		var game: Node = player.get("game")
		if is_instance_valid(game):
			game.call("emit_player_noise", player.global_position, 430.0)
		noise_cooldown = 1.2
