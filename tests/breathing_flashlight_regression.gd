extends SceneTree

var failures: int = 0

func expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var player: CharacterBody2D = load("res://scenes/actors/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	var breath: AudioStreamPlayer = player.get_node("Breathing")
	breath.set_process(false)
	var tired: AudioStreamPlayer = breath.get_node("Recovery")
	expect(breath.stream is AudioStreamMP3 and breath.stream.data == FileAccess.get_file_as_bytes("res://assets/audio/user_originals/dihanie_beg2.mp3"), "Run playback uses the complete untouched original MP3")
	expect(tired.stream.resource_path.ends_with("user_originals/vinoslivosti_net.mp3"), "Recovery playback uses its complete untouched original MP3")
	expect(breath.bus == &"Breathing" and tired.bus == &"Breathing", "Both voices retain shared building acoustics")
	for index in range(48):
		player.call("_physics_process", 0.01)
	expect(not player.get_node("FlashlightSwitch").playing and player.get("flashlight_strength") == 0.0, "Drawing the prop does not emit light or a premature switch click")
	player.call("_physics_process", 0.02)
	expect(player.get_node("FlashlightSwitch").playing and player.get("flashlight_strength") > 0.0, "Audible click and first light begin on the same update")
	player.call("toggle_flashlight")
	expect(player.get("flashlight_strength") == 0.0, "Off click extinguishes the beam immediately")
	player.set("stamina", 80.0)
	player.set("sprinting", true)
	breath.call("_process", 0.2)
	expect(breath.playing and breath.get("run_gain") > 0.0, "Sprint starts the new continuous recording")
	player.set("stamina", 0.0)
	player.set("sprinting", false)
	player.set("exhausted", true)
	breath.call("_process", 0.2)
	expect(tired.playing and breath.get("recovery_latched"), "Empty stamina starts the recovery recording")
	player.set("exhausted", false)
	player.set("stamina", 40.0)
	breath.call("_process", 0.3)
	expect(tired.playing and breath.get("recovery_latched"), "Recovery continues beyond the sprint unlock threshold")
	player.set("stamina", player.get("stamina_max"))
	for index in range(10):
		breath.call("_process", 0.1)
	expect(not tired.playing and not breath.playing, "Both voices fade to silence after full recovery")
	print("RESULT synchronized flashlight and user breathing: %d failure(s)" % failures)
	player.free()
	quit(0 if failures == 0 else 1)
