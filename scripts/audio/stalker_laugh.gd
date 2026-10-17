extends AudioStreamPlayer2D

const CLIPS: Array[AudioStream] = [
	preload("res://assets/audio/user_originals/laugh.mp3"),
	preload("res://assets/audio/user_originals/laugh1.mp3"),
	preload("res://assets/audio/user_originals/laugh2.mp3")]
var pending: Array[int] = []
var last_index: int = -1
var cooldown: float = 0.0
signal laugh_started(index: int)

func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)

func play_laugh() -> void:
	# New reactions must never restart a recording that is still playing.
	if playing or cooldown > 0.0:
		return
	cooldown = 6.0
	if pending.is_empty():
		pending.assign([0, 1, 2])
		pending.shuffle()
		# Also avoid repeating the previous sound across shuffle-cycle boundaries.
		if pending.back() == last_index:
			var first: int = pending[0]
			pending[0] = pending[-1]
			pending[-1] = first
	last_index = pending.pop_back()
	# Leave the sound at the reaction point while the hunter runs away.
	var source_position: Vector2 = get_parent().global_position
	set_as_top_level(true)
	global_position = source_position
	stream = CLIPS[last_index]
	play()
	laugh_started.emit(last_index)
