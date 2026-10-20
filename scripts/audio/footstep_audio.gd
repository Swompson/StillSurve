extends AudioStreamPlayer2D

signal stepped
const SOUNDS: Array[AudioStream] = [
	preload("res://assets/audio/footsteps/boot_concrete_01.wav"),
	preload("res://assets/audio/footsteps/boot_concrete_02.wav"),
	preload("res://assets/audio/footsteps/boot_concrete_03.wav"),
	preload("res://assets/audio/footsteps/boot_concrete_04.wav"),
	preload("res://assets/audio/footsteps/boot_concrete_05.wav"),
	preload("res://assets/audio/footsteps/boot_concrete_06.wav")]
var running: bool = false
var travel: float = 0.0
var last_variant: int = -1
var steps_played: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	max_distance = 1600.0
	bus = &"StepsRoom"

func add_travel(distance: float) -> void:
	if distance < 0.05:
		return
	travel += distance
	var stride: float = 77.5 if running else 72.0
	if travel < stride:
		return
	travel = fmod(travel, stride)
	var variant: int = rng.randi_range(0, SOUNDS.size() - 1)
	if variant == last_variant:
		variant = (variant + 1) % SOUNDS.size()
	last_variant = variant
	stream = SOUNDS[variant]
	pitch_scale = rng.randf_range(0.98, 1.02)
	volume_db = rng.randf_range(-12.0, -10.0) if running else rng.randf_range(-16.0, -14.0)
	play()
	steps_played += 1
	stepped.emit()
