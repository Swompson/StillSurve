extends AudioStreamPlayer2D

@export var start_offset: float = 0.0
var restart_delay: float = 0.0

func _ready() -> void:
	bus = &"Master"
	finished.connect(_on_finished)
	play(start_offset)

func _process(delta: float) -> void:
	if playing:
		return
	restart_delay -= delta
	if restart_delay <= 0.0:
		play()

func _on_finished() -> void:
	restart_delay = randf_range(0.8, 2.8)
