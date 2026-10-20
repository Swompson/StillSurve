extends SceneTree

var failures: int = 0

func expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	set_meta("hard_mode", true)
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(6): await physics_frame
	var game: Node = current_scene
	for hunter in game.monsters: hunter.set_physics_process(false)
	var stalker: CharacterBody2D = game.get_node("Stalker")
	var rig: Node2D = stalker.get_node("Visual/ArticulatedBody")
	rig.movement = 1.0
	rig.running = 1.0
	for mode in ["stalk", "leap", "grab", "flee"]:
		stalker.state = mode
		for sample in range(180):
			rig.phase = float(sample) * TAU / 180.0
			stalker.leap_progress = float(sample) / 180.0
			stalker.attack_elapsed = float(sample) / 60.0
			rig.pose()
			for side in ["left", "right"]:
				var sign_value: float = -1.0 if side == "left" else 1.0
				var shoulder: Vector2 = rig.joints[side + "_shoulder"]
				var elbow: Vector2 = rig.joints[side + "_elbow"]
				var hand: Vector2 = rig.joints[side + "_hand"]
				expect((elbow.x - shoulder.x) * sign_value > 0.0 and hand.x * sign_value > 0.0, "Stalker forearms stay on their own side with outward elbows")
	var torso: Sprite2D = game.get_node("Monster/Visual/ArticulatedBody/Torso")
	var torso_size: Vector2 = torso.texture.get_size() * torso.scale
	expect(torso_size.x / torso_size.y > 1.1 and torso_size.x / torso_size.y < 1.3, "Hunter must keep a broad front-heavy shoulder mass rather than a narrow animal torso")
	for kind in ["player", "monster", "stalker"]:
		var body: Node2D = load("res://scenes/actors/%s_body.tscn" % kind).instantiate()
		var saved_torso: Sprite2D = body.get_node("Torso")
		for prefix in ["Left", "Right"]:
			for suffix in ["Thigh", "Shin", "Knee", "Foot"]:
				var part: Sprite2D = body.get_node_or_null(NodePath(prefix + suffix)) as Sprite2D
				expect(part != null, "%s steps must use a complete saved %s%s segment" % [kind, prefix, suffix])
				if part != null:
					expect(part.z_index < saved_torso.z_index, "%s %s%s must remain beneath the body" % [kind, prefix, suffix])
		body.free()
	print("RESULT overhead poses: 720 stalker poses without crossed arms, shaggy hunter and complete saved legs: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
