extends SceneTree

var failures: int = 0

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func step(cues: Node, delta: float) -> void:
	cues.transition.pause()
	cues.transition.custom_step(delta)

func peak(samples: PackedVector2Array) -> float:
	var maximum: float = 0.0
	for sample in samples: maximum = maxf(maximum, maxf(absf(sample.x), absf(sample.y)))
	return maximum

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var menu_audio: Node = root.get_node("MenuAudio")
	var button: AudioStreamPlayer = menu_audio.get_node("StartGameButton")
	var rate: int = int(AudioServer.get_mix_rate())
	var recording: AudioStreamPlayback = button.stream.instantiate_playback()
	recording.start()
	expect(peak(recording.mix_audio(1.0, int(rate * 0.45))) < 0.001, "The original recording really contains the measured silent lead-in")
	recording.stop()
	recording.start(menu_audio.START_BUTTON_OFFSET_SECONDS)
	expect(peak(recording.mix_audio(1.0, int(rate * 0.035))) > 0.05, "The trimmed playback reaches the attack within 35 milliseconds")
	recording.stop()
	menu_audio.play_start_confirmation()
	expect(button.playing and button.get_playback_position() >= 0.49 and button.volume_db == -24.0, "Mode confirmation immediately seeks to the attack and plays 8 dB quieter")
	button.stop()
	var loading: Node = load("res://scenes/ui/loading_screen.tscn").instantiate()
	expect(loading.get_node("LoadingAudio").volume_db == -26.0, "Loading music is 8 dB quieter")
	loading.free()
	var cues: Node = load("res://scenes/audio/game_cues.tscn").instantiate()
	root.add_child(cues)
	var final: AudioStreamPlayer = cues.get_node("PreEnd")
	var dark: AudioStreamPlayer = cues.get_node("PreLateNoLight")
	expect(final.volume_db == -28.0 and dark.volume_db == -28.0, "Both final-phase tracks are 10 dB quieter")
	expect(cues.get_node("NoBattery").volume_db == -26.0 and cues.get_node("AllCollected").volume_db == -20.0, "The remaining new music is 8 dB quieter")
	var events: Array[StringName] = []
	cues.cue_changed.connect(func(cue: StringName) -> void: events.append(cue))
	cues.update_context(8, 12, 70.0)
	expect(cues.current_cue == &"" and not final.playing, "Four remaining dolls keep the previous silence")
	cues.update_context(9, 12, 70.0)
	var target: float = cues.target_levels[&"PreEnd"]
	expect(final.playing and is_zero_approx(final.volume_linear), "The last-three track starts at true silence")
	step(cues, 0.1)
	expect(final.volume_linear > 0.0 and final.volume_linear < target * 0.005, "The first 100 ms stay below half a percent of final amplitude")
	step(cues, 0.4)
	expect(final.volume_linear > target * 0.03 and final.volume_linear < target * 0.05, "The first half-second is a gentle, curved fade rather than an abrupt onset")
	step(cues, 1.5)
	expect(is_equal_approx(final.volume_linear, target * 0.5), "The four-second entrance reaches half amplitude after two seconds")
	var active_tween: Tween = cues.transition
	for frame in range(120): cues.update_context(9, 12, 70.0)
	expect(cues.transition == active_tween and events.size() == 1, "Stable conditions never restart the entrance")
	step(cues, 2.01)
	expect(is_equal_approx(final.volume_linear, target), "The entrance settles at the quieter saved level")
	cues.update_context(9, 12, 0.0)
	step(cues, 1.0)
	expect(is_equal_approx(final.volume_linear, target * 0.5) and is_equal_approx(dark.volume_linear, target * 0.5), "Context changes use a two-second crossfade at the lower volume")
	step(cues, 1.01)
	expect(not final.playing and dark.playing and is_equal_approx(dark.volume_linear, target), "The previous recording stops after the crossfade")
	cues.update_context(9, 12, 20.0)
	step(cues, 0.2)
	cues.update_context(9, 12, 0.0)
	step(cues, 2.01)
	expect(dark.playing and not final.playing and is_equal_approx(dark.volume_linear, target), "Quick battery changes cancel stale stop callbacks without muting the selected track")
	cues.finish(true)
	step(cues, 0.36)
	expect(not dark.playing and cues.get_node("AllCollected").playing, "Victory retains its short exit fade and quieter completion recording")
	cues.free()
	print("RESULT measured immediate button attack, all six quieter recordings, four-second curved entrance and interrupted crossfades: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
