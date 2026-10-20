extends SceneTree

## Decode the preserved MP3 recordings offline; gameplay uses normalized PCM.
func _initialize() -> void:
	prepare("dihanie_beg2", "running_user", 0.25, 11.5)
	prepare("vinoslivosti_net", "recovery_user", 1.9, 7.2)
	quit()

func prepare(source: String, destination: String, start: float, duration: float) -> void:
	var recording: AudioStreamMP3 = AudioStreamMP3.new()
	recording.data = FileAccess.get_file_as_bytes("res://assets/audio/user_originals/" + source + ".mp3")
	var rate: int = int(AudioServer.get_mix_rate())
	if duration < 0.0:
		duration = recording.get_length()
	assert(recording.get_length() >= start + duration - 0.05)
	var playback: AudioStreamPlayback = recording.instantiate_playback()
	playback.start(start)
	var frames: PackedVector2Array = playback.mix_audio(1.0, int(duration * rate))
	var square_sum: float = 0.0
	var peak: float = 0.001
	for frame in frames:
		square_sum += frame.length_squared()
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	var rms: float = sqrt(square_sum / float(frames.size() * 2))
	var gain: float = minf(db_to_linear(-23.0) / maxf(rms, 0.0001), db_to_linear(-1.0) / peak)
	var pcm: PackedByteArray = PackedByteArray()
	pcm.resize(frames.size() * 4)
	for index in range(frames.size()):
		var fade: float = minf(1.0, minf(float(index), float(frames.size() - 1 - index)) / (rate * 0.08))
		pcm.encode_s16(index * 4, int(clampf(frames[index].x * gain * fade, -1.0, 1.0) * 32767.0))
		pcm.encode_s16(index * 4 + 2, int(clampf(frames[index].y * gain * fade, -1.0, 1.0) * 32767.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = true
	wav.data = pcm
	assert(wav.save_to_wav("res://assets/audio/breathing/" + destination + ".wav") == OK)
	print(destination, ": ", duration, " seconds, gain ", linear_to_db(gain), " dB")
