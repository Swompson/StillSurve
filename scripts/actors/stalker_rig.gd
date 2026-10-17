extends "res://scripts/actors/articulated_actor.gd"

func pose() -> void:
	if parts.is_empty(): return
	var mode: String = "stalk" if preview_mode or not is_instance_valid(actor) else String(actor.get("state"))
	var leap: float = 0.0 if preview_mode or not is_instance_valid(actor) else float(actor.get("leap_progress"))
	var struggle: float = 0.0 if preview_mode or not is_instance_valid(actor) else float(actor.get("attack_elapsed"))
	var arc: float = sin(leap * PI) if mode == "leap" else 0.0
	scale = Vector2.ONE * (1.0 + arc * 0.22)
	var sway: float = sin(phase) * movement * 2.5
	set_static_part("torso", Vector2(sway, -8), Vector2(42, 85))
	parts.torso.rotation = PI + sway * 0.009
	set_static_part("head", Vector2(sway * 0.5, 25.0 + sin(struggle * 27.0) * (2.0 if mode == "grab" else 0.0)), Vector2(24, 33))
	for index in range(2):
		var side: String = "left" if index == 0 else "right"
		var sign_value: float = -1.0 if index == 0 else 1.0
		var cycle: float = phase + index * PI
		# The body hides both legs. Only the two planted/swinging feet remain visible.
		var foot: Vector2 = Vector2(sign_value * 13.0, -44.0) + travel_direction * sin(cycle) * movement * lerpf(15.0, 24.0, running)
		if mode == "leap": foot += Vector2(sign_value * 9.0, 16.0) * arc
		if mode == "grab": foot += Vector2(sign_value * sin(struggle * 23.0) * 5.0, cos(struggle * 19.0 + index) * 8.0)
		set_static_part(side + "_foot", foot, Vector2(13, 25))
		var shoulder: Vector2 = Vector2(sign_value * 19.0 + sway, 3.0)
		var hand: Vector2 = Vector2(sign_value * (31.0 + cos(cycle) * movement * 3.0), 37.0 + sin(cycle) * movement * 15.0)
		if mode == "leap": hand = hand.lerp(Vector2(sign_value * 39.0, 65.0), 0.8)
		if mode == "grab": hand = Vector2(sign_value * (29.0 + sin(struggle * 24.0 + index) * 5.0), 62.0 + cos(struggle * 21.0 + index) * 6.0)
		hand = clamp_tip(shoulder, hand, 32.0, 38.0, 145.0)
		var elbow: Vector2 = solve_joint(shoulder, hand, 32.0, 38.0, -sign_value)
		segment(side + "_upper_arm", shoulder, elbow, 12.0)
		segment(side + "_forearm", elbow, hand, 8.0)
		set_static_part(side + "_elbow", elbow, Vector2.ONE * 9.0)
		set_static_part(side + "_hand", hand, Vector2(10, 23))
		parts[side + "_hand"].rotation = (hand - elbow).angle() - PI * 0.5
		joints[side + "_foot"] = foot
		joints[side + "_hand"] = hand
