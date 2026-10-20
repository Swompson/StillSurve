extends SceneTree

const SIDES: Array[String] = ["left", "right"]
const LEG_PARTS: Array[String] = ["thigh", "shin", "knee", "foot"]
const REQUIRED_PARTS: Array[String] = [
	"Torso", "Head", "Flashlight",
	"LeftThigh", "LeftShin", "LeftKnee", "LeftFoot",
	"RightThigh", "RightShin", "RightKnee", "RightFoot",
	"LeftShoulder", "LeftUpperArm", "LeftForearm", "LeftElbow", "LeftHand",
	"RightShoulder", "RightUpperArm", "RightForearm", "RightElbow", "RightHand",
]

var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("check_player")

func part_bounds(part: Sprite2D) -> Rect2:
	# Scene geometry gives a conservative coverage estimate without GPU pixels.
	var rect: Rect2 = part.get_rect()
	var result: Rect2 = Rect2(part.transform * rect.position, Vector2.ZERO)
	for point in [Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		result = result.expand(part.transform * point)
	return result

func covered_fraction(part: Sprite2D, torso: Sprite2D) -> float:
	var bounds: Rect2 = part_bounds(part)
	var covered: Rect2 = bounds.intersection(part_bounds(torso))
	return covered.get_area() / maxf(bounds.get_area(), 0.0001)

func check_saved_parts(rig: Node2D) -> bool:
	var all_present: bool = true
	for part_name in REQUIRED_PARTS:
		var part: Sprite2D = rig.get_node_or_null(NodePath(part_name)) as Sprite2D
		expect(part != null, "Saved 2D body must contain %s before entering the scene tree" % part_name)
		all_present = all_present and part != null
	var sprite_count: int = 0
	for node in rig.find_children("*", "", true, false):
		expect(not node is SubViewport and not node is Node3D, "The player body must render directly in 2D without a 3D viewport")
		if not node is Sprite2D:
			continue
		sprite_count += 1
		var part: Sprite2D = node
		if part.name == &"Flashlight":
			expect(part.texture != null and part.texture.resource_path.ends_with("flashlight_overhead.svg"), "Held flashlight must use the overhead housing without a face-on lens")
			continue
		var texture: AtlasTexture = part.texture as AtlasTexture
		expect(texture != null, "Every saved player sprite must use a generated atlas cutout")
		if texture != null:
			expect(texture.atlas != null and texture.atlas.resource_path.contains("/player/rig_v3/"), "Player cutouts must use the new generated rig_v3 atlas")
			expect(texture.region.size.x > 0.0 and texture.region.size.y > 0.0, "Saved atlas cutouts must have nonempty regions")
			expect(part.visible and part.modulate.a > 0.0 and part.self_modulate.a > 0.0, "Authored player parts must be visible in the editor")
	expect(sprite_count >= 21, "The saved body must contain its complete set of at least 21 textured sprites")
	var animations: AnimationPlayer = rig.get_node_or_null("AnimationPlayer") as AnimationPlayer
	expect(animations != null, "The saved body must expose its clips in the Godot animation editor")
	if animations != null:
		for state in ["idle", "walk", "run", "idle_unlit", "walk_unlit", "run_unlit", "stow_flashlight", "draw_flashlight", "RESET"]:
			expect(animations.has_animation(state), "The saved %s clip must be editable without running the game" % state)
			if animations.has_animation(state):
				expect(animations.get_animation(state).get_track_count() >= sprite_count, "Every sprite must participate in the saved %s pose" % state)
		for state in ["stow_flashlight", "draw_flashlight"]:
			if not animations.has_animation(state):
				continue
			var clip: Animation = animations.get_animation(state)
			expect(clip.loop_mode == Animation.LOOP_NONE, "Flashlight gestures must be non-looping editable clips")
			var has_alpha: bool = false
			for track in range(clip.get_track_count()):
				if String(clip.track_get_path(track)) != "Flashlight:modulate":
					continue
				has_alpha = true
				var first: Color = clip.track_get_key_value(track, 0)
				var last: Color = clip.track_get_key_value(track, clip.track_get_key_count(track) - 1)
				expect(first.a == (1.0 if state == "stow_flashlight" else 0.0) and last.a == (0.0 if state == "stow_flashlight" else 1.0), "Editor clips must show the flashlight being placed and picked up")
			expect(has_alpha, "Flashlight placement must be visible in the animation editor")
	if all_present:
		var torso: Sprite2D = rig.get_node("Torso")
		for prefix in ["Left", "Right"]:
			var foot: Sprite2D = rig.get_node(NodePath(prefix + "Foot"))
			var shin: Sprite2D = rig.get_node(NodePath(prefix + "Shin"))
			var thigh: Sprite2D = rig.get_node(NodePath(prefix + "Thigh"))
			var hand: Sprite2D = rig.get_node(NodePath(prefix + "Hand"))
			var forearm: Sprite2D = rig.get_node(NodePath(prefix + "Forearm"))
			var upper_arm: Sprite2D = rig.get_node(NodePath(prefix + "UpperArm"))
			var elbow: Sprite2D = rig.get_node(NodePath(prefix + "Elbow"))
			var shoulder: Sprite2D = rig.get_node(NodePath(prefix + "Shoulder"))
			expect(foot.z_index < shin.z_index and foot.z_index < thigh.z_index, "Saved %s trouser fabric must cover the boot opening" % prefix)
			expect(hand.z_index < forearm.z_index and forearm.z_index < elbow.z_index, "Saved %s sleeve and elbow must cover the wrist and sleeve openings" % prefix)
			expect(upper_arm.z_index < elbow.z_index and elbow.z_index < torso.z_index, "Saved %s elbow must cover the upper sleeve beneath the torso" % prefix)
			expect(shoulder.z_index < torso.z_index, "Saved %s shoulder must remain beneath the torso" % prefix)
			for suffix in ["Thigh", "Shin", "Knee"]:
				var part: Sprite2D = rig.get_node(NodePath(prefix + suffix))
				expect(part.z_index < torso.z_index and covered_fraction(part, torso) > 0.85, "Saved idle %s must already sit beneath the torso in the editor" % part.name)
	return all_present

func check_idle_coverage(rig: Node2D) -> void:
	rig.set("movement", 0.0)
	rig.set("running", 0.0)
	rig.set("phase", 0.0)
	rig.call("pose")
	var parts: Dictionary = rig.get("parts")
	var torso: Sprite2D = parts.torso
	var torso_height: float = torso.texture.get_size().y * absf(torso.scale.y)
	var least_coverage: float = 1.0
	for side in SIDES:
		for key in LEG_PARTS:
			var part: Sprite2D = parts[side + "_" + key]
			expect(part.z_index < torso.z_index, "The torso must occlude every saved %s part" % key)
			if key == "foot":
				continue
			least_coverage = minf(least_coverage, covered_fraction(part, torso))
			var projected_size: Vector2 = part.texture.get_size() * part.scale.abs()
			expect(projected_size.y < torso_height * 0.55, "Idle trouser parts must remain foreshortened beneath the jacket")
	expect(least_coverage > 0.85, "At rest the torso must cover most of the thigh, shin and knee projection")
	var joints: Dictionary = rig.get("joints")
	var free_wrist_distance: float = Vector2(joints.right_hand).distance_to(joints.right_shoulder)
	# Joint distance excludes the extra cloth hidden beneath the elbow and cuff.
	var free_forearm_projection: float = Vector2(joints.right_hand).distance_to(joints.right_elbow)
	expect(free_wrist_distance < 12.0, "The idle free hand must hang near the shoulder in the overhead projection")
	expect(free_forearm_projection < 10.0, "The idle free forearm must be foreshortened beneath the torso")
	expect(Vector2(joints.left_hand).distance_to(joints.left_shoulder) > 15.0, "The flashlight arm must retain its raised holding pose")
	print("IDLE trouser coverage by torso bounds: %.1f%% minimum" % (least_coverage * 100.0))

func check_gait(rig: Node2D, player: CharacterBody2D) -> void:
	var parts: Dictionary = rig.get("parts")
	var torso: Sprite2D = parts.torso
	var torso_height: float = torso.texture.get_size().y * absf(torso.scale.y)
	var worst_length_error: float = 0.0
	var worst_joint_jump: float = 0.0
	var outward_elbows: bool = true
	var free_arm_projection_valid: bool = true
	var maximum_projection: float = 0.0
	var maximum_foot_travel: float = 0.0
	var maximum_thigh_travel: float = 0.0
	var maximum_shin_travel: float = 0.0
	var maximum_revealed_fraction: float = 0.0
	var foot_travel_by_side: Dictionary = {"left": 0.0, "right": 0.0}
	for direction_index in range(8):
		rig.set("travel_direction", Vector2.from_angle(direction_index * TAU / 8.0))
		var previous: Dictionary = {}
		var first: Dictionary = {}
		for sample in range(241):
			rig.set("phase", sample * TAU / 240.0)
			rig.set("movement", 1.0)
			rig.set("running", 1.0)
			player.set("flashlight_reveal", 0.5 - cos(sample * TAU / 240.0) * 0.5)
			rig.call("pose")
			var joints: Dictionary = rig.get("joints")
			for side in SIDES:
				var shoulder: Vector2 = joints[side + "_shoulder"]
				var elbow: Vector2 = joints[side + "_elbow"]
				var hand: Vector2 = joints[side + "_hand"]
				var sign_value: float = -1.0 if side == "left" else 1.0
				outward_elbows = outward_elbows and (elbow.x - shoulder.x) * sign_value > 0.0
				var upper_length: float = shoulder.distance_to(elbow)
				var lower_length: float = elbow.distance_to(hand)
				if side == "left" and is_equal_approx(float(player.get("flashlight_reveal")), 1.0):
					worst_length_error = maxf(worst_length_error, absf(upper_length - 18.0))
					worst_length_error = maxf(worst_length_error, absf(lower_length - 21.0))
				else:
					free_arm_projection_valid = free_arm_projection_valid and upper_length > 0.1 and upper_length <= 18.001 and lower_length > 0.1 and lower_length <= 21.001
				for key in ["elbow", "hand", "knee", "foot"]:
					var joint_name: String = side + "_" + key
					var point: Vector2 = joints[joint_name]
					if previous.has(joint_name):
						worst_joint_jump = maxf(worst_joint_jump, point.distance_to(previous[joint_name]))
					previous[joint_name] = point
				for key in ["thigh", "shin", "foot"]:
					var part_name: String = side + "_" + key
					var part: Sprite2D = parts[part_name]
					if not first.has(part_name):
						first[part_name] = part.position
					var travel: float = part.position.distance_to(first[part_name])
					if key == "foot":
						maximum_foot_travel = maxf(maximum_foot_travel, travel)
						foot_travel_by_side[side] = maxf(foot_travel_by_side[side], travel)
					else:
						maximum_projection = maxf(maximum_projection, part.texture.get_size().y * absf(part.scale.y))
						maximum_revealed_fraction = maxf(maximum_revealed_fraction, 1.0 - covered_fraction(part, torso))
						if key == "thigh":
							maximum_thigh_travel = maxf(maximum_thigh_travel, travel)
						else:
							maximum_shin_travel = maxf(maximum_shin_travel, travel)
	expect(outward_elbows, "Player elbows must point outward throughout all eight gait directions and flashlight poses")
	expect(worst_length_error < 0.001, "The fully raised flashlight arm must preserve its 18/21 pixel segment lengths")
	expect(free_arm_projection_valid, "The free arm must keep a nonzero overhead projection within its 18/21 pixel physical lengths")
	expect(worst_joint_jump < 4.0, "Hands, elbows, knees and feet must move continuously, including the loop boundary")
	expect(maximum_projection < torso_height * 0.85, "Walking leg segments must remain a short overhead projection")
	for side in SIDES:
		expect(float(foot_travel_by_side[side]) > 28.0, "The gait must visibly move the %s boot" % side)
	expect(maximum_thigh_travel > 5.0 and maximum_shin_travel > 10.0, "Stepping must animate the intermediate trouser parts as well as the feet")
	expect(maximum_revealed_fraction > 0.12, "A step must reveal intermediate trouser fabric beyond the torso silhouette")
	print("GAIT arm error %.6f px; joint jump %.3f px; foot/thigh/shin travel %.2f/%.2f/%.2f px; trouser reveal %.1f%%" % [worst_length_error, worst_joint_jump, maximum_foot_travel, maximum_thigh_travel, maximum_shin_travel, maximum_revealed_fraction * 100.0])

func check_free_arm_swing(rig: Node2D) -> void:
	rig.set("travel_direction", Vector2.DOWN)
	rig.set("movement", 1.0)
	for sprinting in [false, true]:
		rig.set("running", 1.0 if sprinting else 0.0)
		var minimum_offset: float = INF
		var maximum_offset: float = -INF
		var hand_samples: Array[float] = []
		var foot_samples: Array[float] = []
		for sample in range(241):
			var cycle: float = sample * TAU / 240.0
			rig.set("phase", cycle)
			rig.call("pose")
			var joints: Dictionary = rig.get("joints")
			var hand_offset: float = Vector2(joints.right_hand).y - Vector2(joints.right_shoulder).y
			var foot_offset: float = Vector2(joints.right_foot).y - 8.0
			minimum_offset = minf(minimum_offset, hand_offset)
			maximum_offset = maxf(maximum_offset, hand_offset)
			hand_samples.append(hand_offset)
			foot_samples.append(foot_offset)
			var arm: Dictionary = rig.call("free_arm_pose")
			expect(float(arm.flexion) >= deg_to_rad(65.0 if sprinting else 45.0), "The free elbow must retain a natural bend while jogging")
		expect(minimum_offset < 0.0 and maximum_offset > 0.0, "The free hand must swing both in front of and behind its shoulder")
		expect(maximum_offset - minimum_offset > 28.0, "The bent free arm must have a visible walking and running swing")
		var hand_mean: float = 0.0
		var foot_mean: float = 0.0
		for sample in range(hand_samples.size()):
			hand_mean += hand_samples[sample] / hand_samples.size()
			foot_mean += foot_samples[sample] / foot_samples.size()
		var covariance: float = 0.0
		var hand_variance: float = 0.0
		var foot_variance: float = 0.0
		for sample in range(hand_samples.size()):
			var hand_delta: float = hand_samples[sample] - hand_mean
			var foot_delta: float = foot_samples[sample] - foot_mean
			covariance += hand_delta * foot_delta
			hand_variance += hand_delta * hand_delta
			foot_variance += foot_delta * foot_delta
		var correlation: float = covariance / sqrt(hand_variance * foot_variance)
		expect(correlation < -0.90, "The connected bent arm must swing opposite to the same-side foot")
		print("FREE ARM %s projection range %.2f to %.2f px" % ["run" if sprinting else "walk", minimum_offset, maximum_offset])

func check_movement_blends(rig: Node2D, player: CharacterBody2D) -> void:
	player.set("flashlight_reveal", 1.0)
	player.set("sprinting", false)
	player.velocity = Vector2.ZERO
	rig.set("movement", 0.0)
	rig.set("running", 0.0)
	rig.set("phase", 1.25)
	rig.set("travel_direction", Vector2.DOWN)
	rig.call("pose")
	var idle_foot: Vector2 = rig.get("joints").left_foot
	rig.call("advance", 1.0 / 60.0)
	expect(is_equal_approx(float(rig.get("phase")), 1.25), "Idle must not advance the walking phase")
	expect(Vector2(rig.get("joints").left_foot).distance_to(idle_foot) < 0.001, "Idle breathing must leave the planted feet still")
	player.velocity = Vector2(0.0, 180.0)
	rig.call("advance", 1.0 / 60.0)
	expect(float(rig.get("movement")) > 0.0 and float(rig.get("movement")) < 1.0, "Starting to walk must blend in the stride")
	for frame in range(59):
		rig.call("advance", 1.0 / 60.0)
	var phase_before: float = rig.get("phase")
	player.set("sprinting", true)
	player.velocity = Vector2(0.0, 310.0)
	rig.call("advance", 1.0 / 60.0)
	var phase_delta: float = fposmod(float(rig.get("phase")) - phase_before, TAU)
	expect(phase_delta > 0.0 and phase_delta < 0.5, "Switching to sprint must retain the current stride phase")
	expect(float(rig.get("running")) > 0.0 and float(rig.get("running")) < 1.0, "Sprint must blend smoothly from the walking pose")
	for frame in range(59):
		rig.call("advance", 1.0 / 60.0)
	expect(float(rig.get("running")) > 0.99, "Sustained sprint must reach the running gait")
	phase_before = rig.get("phase")
	var movement_before: float = rig.get("movement")
	var running_before: float = rig.get("running")
	player.velocity = Vector2.ZERO
	player.set("sprinting", false)
	rig.call("advance", 1.0 / 60.0)
	expect(is_equal_approx(float(rig.get("phase")), phase_before), "Stopping must preserve the stride phase")
	expect(float(rig.get("movement")) > 0.0 and float(rig.get("movement")) < movement_before, "Stopping must smoothly settle the stride")
	expect(float(rig.get("running")) > 0.0 and float(rig.get("running")) < running_before, "Stopping must smoothly release the sprint blend")
	for frame in range(119):
		rig.call("advance", 1.0 / 60.0)
	expect(float(rig.get("movement")) < 0.001 and float(rig.get("running")) < 0.001, "Stopped movement must settle fully into idle")
	expect(Vector2(rig.get("joints").left_foot).distance_to(idle_foot) < 0.01, "After stopping the foot must return beneath the body")

func check_flashlight(rig: Node2D, player: CharacterBody2D) -> void:
	rig.set("movement", 0.0)
	player.set("flashlight_reveal", 0.0)
	rig.call("pose")
	var tucked: Vector2 = rig.call("flashlight_grip")
	player.set("flashlight_reveal", 1.0)
	rig.call("pose")
	var raised: Vector2 = rig.call("flashlight_grip")
	expect(tucked.distance_to(raised) > 10.0, "Drawing the flashlight must move the actual hand")
	var worst_lens_error: float = 0.0
	var worst_view_origin_error: float = 0.0
	var torch: Sprite2D = rig.get("parts").flashlight
	for reveal in [0.0, 0.25, 0.5, 0.75, 1.0]:
		player.set("flashlight_reveal", reveal)
		rig.call("pose")
		var grip: Vector2 = rig.call("flashlight_grip")
		var local_rect: Rect2 = torch.get_rect()
		var lens: Vector2 = torch.transform * Vector2(local_rect.position.x + local_rect.size.x * 0.5, local_rect.end.y)
		var expected_angle: float = rig.call("flashlight_angle")
		var expected_lens: Vector2 = grip + Vector2.DOWN.rotated(expected_angle) * 15.0
		worst_lens_error = maxf(worst_lens_error, lens.distance_to(expected_lens))
		expect(Vector2(rig.get("joints").left_hand).distance_to(grip) < 0.001, "The flashlight grip must follow the animated left hand")
		for facing in [0.0, PI * 0.5, PI, -PI * 0.5]:
			player.set("facing_angle", facing)
			player.get_node("Sprite").rotation = facing - PI * 0.5
			player.call("update_flashlight")
			var view_origin: Vector2 = player.call("get_view_origin")
			worst_view_origin_error = maxf(worst_view_origin_error, (rig.global_transform * lens).distance_to(view_origin))
	expect(worst_lens_error < 2.0, "The visible flashlight lens must align with the grip plus the 15 pixel light-origin offset")
	expect(worst_view_origin_error < 2.0, "The controller's light origin must follow the visible lens at all four facing angles")
	print("FLASHLIGHT lens/view-origin alignment error: %.3f/%.3f px maximum" % [worst_lens_error, worst_view_origin_error])

func check_stow(rig: Node2D, player: CharacterBody2D) -> void:
	rig.set("movement", 0.0)
	player.set("flashlight_reveal", 0.4)
	rig.call("pose")
	expect(Vector2(rig.get("joints").left_hand).distance_to(Vector2(-24.0, 2.0)) < 0.1, "The stowing hand must reach the left flank before releasing the flashlight")
	player.set("flashlight_reveal", 0.0)
	rig.call("pose")
	var joints: Dictionary = rig.get("joints")
	expect(Vector2(joints.left_hand).distance_to(Vector2(-joints.right_hand.x, joints.right_hand.y)) < 0.001, "Both idle arms must use the same natural pose once the flashlight is stored")
	expect(float(rig.get("parts").flashlight.modulate.a) == 0.0, "The flashlight must disappear beneath the jacket after it is stored")
	var maximum_jump: float = 0.0
	for moving in [0.0, 1.0]:
		rig.set("movement", moving)
		var previous: Vector2
		for sample in range(181):
			player.set("flashlight_reveal", 1.0 - float(sample) / 180.0)
			rig.set("phase", float(sample) * TAU / 60.0)
			rig.call("pose")
			var hand: Vector2 = rig.get("joints").left_hand
			if sample > 0:
				maximum_jump = maxf(maximum_jump, hand.distance_to(previous))
			previous = hand
		expect(float(rig.get("parts").flashlight.modulate.a) == 0.0, "The stored flashlight must remain hidden during gait")
	expect(maximum_jump < 4.0, "Stowing and releasing the hand into gait must not teleport the wrist")
	print("STOW connected hand movement: %.3f px maximum per sample" % maximum_jump)

func check_player() -> void:
	var packed: PackedScene = load("res://scenes/actors/player.tscn")
	var player: CharacterBody2D = packed.instantiate()
	var rig: Node2D = player.get_node("Sprite/ArticulatedBody")
	if not check_saved_parts(rig):
		player.free()
		quit(1)
		return
	root.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.get_node("Sprite").set_process(false)
	rig.set("preview_mode", false)
	player.set("grabbed", false)
	player.set("alive", true)
	player.set("flashlight_reveal", 1.0)
	check_idle_coverage(rig)
	check_gait(rig, player)
	check_free_arm_swing(rig)
	check_movement_blends(rig, player)
	check_flashlight(rig, player)
	check_stow(rig, player)
	print("RESULT saved 2D survivor, overhead occlusion, continuous gait and flashlight: %d failure(s)" % failures.size())
	player.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
