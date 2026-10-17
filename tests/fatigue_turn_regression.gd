extends SceneTree

func _initialize() -> void:
	var player: CharacterBody2D = load("res://scripts/actors/player_controller.gd").new()
	var angles: Array[float] = []
	for energy in [100.0, 50.0, 0.0]:
		player.stamina = energy
		player.facing_angle = 0.0
		player.turn_towards(PI * 0.75, 1.0 / 60.0)
		angles.append(player.facing_angle)
	assert(angles[0] > angles[1] and angles[1] > angles[2] and angles[2] > 0.0)
	assert(is_equal_approx(angles[2] / angles[0], 0.55))
	player.stamina = 0.0
	player.restore_stamina(0.25)
	player.facing_angle = 0.0
	player.turn_towards(PI * 0.75, 1.0 / 60.0)
	assert(player.facing_angle > angles[2] and player.facing_angle < angles[1])
	player.stamina_max = 200.0
	player.stamina = 100.0
	player.facing_angle = 0.0
	player.turn_towards(PI * 0.75, 1.0 / 60.0)
	assert(is_equal_approx(player.facing_angle, angles[1]))
	player.free()
	print("RESULT player-only fatigue turn speed, recovery and increased stamina capacity: passed")
	quit()
