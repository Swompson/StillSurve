extends SceneTree

func _initialize() -> void:
	AudioServer.set_bus_count(4)
	AudioServer.set_bus_name(0, "Master")
	AudioServer.set_bus_volume_db(0, -2.0)
	for bus in range(4):
		while AudioServer.get_bus_effect_count(bus) > 0:
			AudioServer.remove_bus_effect(bus, 0)
	var reflections: AudioEffectDelay = AudioEffectDelay.new()
	reflections.dry = 1.0
	reflections.tap1_delay_ms = 72.0
	reflections.tap1_level_db = -18.0
	reflections.tap1_pan = -0.45
	reflections.tap2_delay_ms = 127.0
	reflections.tap2_level_db = -23.0
	reflections.tap2_pan = 0.45
	reflections.feedback_active = false
	AudioServer.add_bus_effect(0, reflections)
	var hall: AudioEffectReverb = AudioEffectReverb.new()
	hall.room_size = 0.90
	hall.damping = 0.72
	hall.spread = 0.90
	hall.dry = 1.0
	hall.wet = 0.18
	hall.predelay_msec = 55.0
	hall.predelay_feedback = 0.06
	AudioServer.add_bus_effect(0, hall)
	AudioServer.set_bus_name(1, "StepsRoom")
	AudioServer.set_bus_send(1, "Master")
	var step_filter: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
	step_filter.cutoff_hz = 1600.0
	step_filter.resonance = 0.1
	AudioServer.add_bus_effect(1, step_filter)
	var room: AudioEffectReverb = AudioEffectReverb.new()
	room.room_size = 0.85
	room.damping = 0.8
	room.spread = 0.85
	room.dry = 0.85
	room.wet = 0.075
	room.predelay_msec = 50.0
	room.predelay_feedback = 0.08
	AudioServer.add_bus_effect(1, room)
	AudioServer.set_bus_name(2, "Breathing")
	AudioServer.set_bus_send(2, "Master")
	var breath_filter: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
	breath_filter.cutoff_hz = 2200.0
	breath_filter.resonance = 0.1
	AudioServer.add_bus_effect(2, breath_filter)
	var breath_room: AudioEffectReverb = AudioEffectReverb.new()
	breath_room.room_size = 0.7
	breath_room.damping = 0.85
	breath_room.dry = 1.0
	breath_room.wet = 0.025
	AudioServer.add_bus_effect(2, breath_room)
	AudioServer.set_bus_name(3, "Ambience")
	AudioServer.set_bus_send(3, "Master")
	AudioServer.set_bus_volume_db(3, -24.0)
	var layout: AudioBusLayout = AudioServer.generate_bus_layout()
	var error: Error = ResourceSaver.save(layout, "res://assets/audio/mixer.tres")
	if error != OK:
		push_error("Could not save audio mixer")
		quit(1)
		return
	print("Built shared hall reflections/reverb for all sounds, with filtered steps and breathing")
	quit()
