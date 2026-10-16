extends AudioStreamPlayer

const AMBIENCE = preload("res://assets/audio/ambience/abandoned_building.wav")
var reduced_for_result: bool = false
var fade: Tween

func _ready() -> void:
	bus = &"Ambience"
	var loop: AudioStreamWAV = AMBIENCE.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = int(loop.get_length() * loop.mix_rate)
	stream = loop
	volume_db = -28.0
	play()
	fade = create_tween()
	fade.tween_property(self, "volume_db", 0.0, 4.0)

func _process(_delta: float) -> void:
	if not reduced_for_result and get_parent().get("finished"):
		reduced_for_result = true
		if is_instance_valid(fade):
			fade.kill()
		fade = create_tween()
		fade.tween_property(self, "volume_db", -7.0, 2.0)
