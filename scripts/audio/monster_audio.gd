extends AudioStreamPlayer2D

const HOWLS: Array[AudioStream] = [preload("res://assets/audio/user_originals/voy.mp3"), preload("res://assets/audio/monster/howls/howl_2.wav"), preload("res://assets/audio/monster/howls/howl_3.wav"), preload("res://assets/audio/monster/howls/howl_4.wav"), preload("res://assets/audio/monster/howls/howl_5.wav")]
var howl_timer: float = 0.0
var last_howl: int = -1
var last_howl_interval: float = -1.0
var howl_player: AudioStreamPlayer2D
const GROWL = preload("res://assets/audio/monster/nearby_growl.wav")
@export var audible_radius: float = 1150.0
var occlusion_timer: float = 0.0
var blocked: bool = false
var cooldown: float = 0.6

func _ready() -> void:
	howl_player = get_node("Howl") as AudioStreamPlayer2D
	stream = GROWL
	max_distance = audible_radius
	# Distance is controlled here once; built-in attenuation previously muted it again.
	attenuation = 0.0
	volume_db = -1.0
	panning_strength = 1.0
	howl_player.attenuation = 0.0
	bus = &"Master"

func _process(delta: float) -> void:
	var monster: CharacterBody2D = get_parent() as CharacterBody2D
	var player: CharacterBody2D = monster.get("player") as CharacterBody2D
	if not monster.get("active") or not is_instance_valid(player):
		stop()
		howl_player.stop()
		return
	# One shared schedule prevents two hunters from producing overlapping howl timers.
	if monster.get("game").get("monster") == monster:
		howl_timer -= delta
		if howl_timer <= 0.0:
			play_scheduled_howl()
	var distance: float = monster.global_position.distance_to(player.global_position)
	# Both near growls and distant howls carry a strong distance cue.
	var maze: Node = monster.get("maze") as Node
	occlusion_timer -= delta
	if occlusion_timer <= 0.0:
		blocked = is_instance_valid(maze) and not maze.call("clear_line", monster.global_position, player.global_position)
		occlusion_timer = 0.12
	howl_player.volume_db = distance_gain_db(distance, 2800.0) - (5.0 if blocked else 0.0)
	if distance > audible_radius:
		stop()
		cooldown = minf(cooldown, 0.6)
		return
	if distance < 240.0:
		cooldown = minf(cooldown, 0.18)
	cooldown -= delta
	volume_db = move_toward(volume_db, distance_gain_db(distance, audible_radius) - (6.0 if blocked else 0.0), delta * 32.0)
	if cooldown <= 0.0 and not playing:
		pitch_scale = randf_range(0.96, 1.03)
		play()
		cooldown = randf_range(0.35, 0.65) if distance < 240.0 else randf_range(1.2, 2.4)

func choose_howl_interval() -> float:
	# Draw uniformly from the valid parts of [26, 40], without rejection loops.
	if last_howl_interval < 0.0:
		last_howl_interval = randf_range(26.0, 40.0)
	else:
		var lower_length: float = maxf(0.0, last_howl_interval - 5.0 - 26.0)
		var upper_start: float = maxf(26.0, last_howl_interval + 5.0)
		var upper_length: float = maxf(0.0, 40.0 - upper_start)
		var sample: float = randf() * (lower_length + upper_length)
		last_howl_interval = 26.0 + sample if sample < lower_length else upper_start + sample - lower_length
	return last_howl_interval

func distance_gain_db(distance: float, radius: float) -> float:
	return lerpf(-1.0, -38.0, clampf((distance - 140.0) / (radius - 140.0), 0.0, 1.0))

func play_scheduled_howl(opening: bool = false) -> void:
	var monster: Node2D = get_parent() as Node2D
	var game: Node = monster.get("game")
	var variant: int = randi_range(0, HOWLS.size() - (2 if last_howl >= 0 else 1))
	if last_howl >= 0 and variant >= last_howl:
		variant += 1
	last_howl = variant
	if opening:
		# Establish the monster's presence reliably even when both spawn far away.
		var introduction: AudioStreamPlayer = game.get_node("OpeningHowl")
		introduction.stream = HOWLS[variant]
		introduction.play()
	else:
		var hunters: Array = []
		for candidate in game.get("monsters"):
			if candidate.has_node("Growl/Howl"):
				hunters.append(candidate)
		var hunter: Node = hunters[randi_range(0, hunters.size() - 1)]
		var source: AudioStreamPlayer2D = hunter.get_node("Growl/Howl")
		source.stream = HOWLS[variant]
		source.play()
	howl_timer = choose_howl_interval()
