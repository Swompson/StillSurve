extends SceneTree
func _initialize() -> void:
	var source := AudioStreamMP3.load_from_file("res://assets/audio/user_originals/voy2.mp3")
	var playback := source.instantiate_playback()
	playback.start()
	var data := PackedByteArray()
	var count := int(ceil(source.get_length() * 44100.0))
	while count > 0:
		var amount := mini(count, 4096)
		var samples := playback.mix_audio(1.0, amount)
		for sample in samples:
			var offset := data.size()
			data.resize(offset + 4)
			data.encode_s16(offset, int(clampf(sample.x, -1.0, 1.0) * 32767.0))
			data.encode_s16(offset + 2, int(clampf(sample.y, -1.0, 1.0) * 32767.0))
		count -= amount
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.stereo = true
	wav.data = data
	wav.save_to_wav("res://.godot/voy2_decoded.wav")
	print("Decoded ", source.get_length())
	quit()
