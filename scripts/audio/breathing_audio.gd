extends AudioStreamPlayer

## The two authored players crossfade through the shared room acoustic bus.
var player: CharacterBody2D
var recovery_latched: bool = false
var noise_cooldown: float = 0.0
var run_tail: float = 0.0
var run_gain: float = 0.0
var recovery_gain: float = 0.0
var was_exhausted: bool = false
const RUN_VOLUME_DB: float = -8.0
const RECOVERY_VOLUME_DB: float = -9.0
@onready var recovery_voice: AudioStreamPlayer = $Recovery

func _ready() -> void:
	player = get_parent() as CharacterBody2D
	bus = &"Breathing"
	recovery_voice.bus = &"Breathing"
	stream = stream.duplicate()
	(stream as AudioStreamMP3).loop = true
	pitch_scale = 1.0
	recovery_voice.pitch_scale = 1.0
	volume_db = -60.0
	recovery_voice.volume_db = -60.0

func _process(delta: float) -> void:
	if not player.get("alive"):
		stop()
		recovery_voice.stop()
		return
	var running: bool = bool(player.get("sprinting"))
	var exhausted: bool = bool(player.get("exhausted"))
	if exhausted and not was_exhausted:
		recovery_latched = true
		recovery_voice.play()
	was_exhausted = exhausted
	if running or float(player.get("stamina")) >= float(player.get("stamina_max")) - 0.1:
		recovery_latched = false
	run_tail = 0.8 if running else maxf(0.0, run_tail - delta)
	var run_target: float = 1.0 if running and not recovery_latched else 0.0
	if not running and run_tail > 0.0 and not recovery_latched:
		run_target = 0.5 * run_tail / 0.8
	var recovery_target: float = 1.0 if recovery_latched else 0.0
	run_gain = move_toward(run_gain, run_target, delta * 1.3)
	recovery_gain = move_toward(recovery_gain, recovery_target, delta * 1.3)
	if run_target > 0.0 and not playing:
		play()
	volume_db = RUN_VOLUME_DB + linear_to_db(maxf(run_gain, 0.0001))
	recovery_voice.volume_db = RECOVERY_VOLUME_DB + linear_to_db(maxf(recovery_gain, 0.0001))
	if run_gain <= 0.001 and run_target == 0.0:
		stop()
	if recovery_gain <= 0.001 and not recovery_latched:
		recovery_voice.stop()
	noise_cooldown -= delta
	if exhausted and noise_cooldown <= 0.0:
		var game: Node = player.get("game")
		if is_instance_valid(game):
			game.call("emit_player_noise", player.global_position, 430.0)
		noise_cooldown = 1.2
