extends SceneTree

const SIDES: Array[String] = ["left", "right"]
const LIMB_PARTS: Array[String] = ["Thigh", "Shin", "Knee", "Foot", "Shoulder", "UpperArm", "Forearm", "Elbow", "Hand"]
const SAMPLE_COUNT: int = 240
const CREATURES: Dictionary = {
	"monster": "res://scenes/actors/monster_body.tscn",
	"stalker": "res://scenes/actors/stalker_body.tscn",
}

class MotionActor extends CharacterBody2D:
	var active: bool = true
	var sprinting: bool = false
	var facing_angle: float = PI * 0.5
	var state: String = "stalk"
	var leap_progress: float = 0.0
	var attack_elapsed: float = 0.0

var failures: Array[String] = []
var checked_cutouts: Dictionary = {}
var source_atlases: Dictionary = {}

func _initialize() -> void:
	call_deferred("check_creatures")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func part_bounds(part: Sprite2D) -> Rect2:
	var rect: Rect2 = part.get_rect()
	var result: Rect2 = Rect2(part.transform * rect.position, Vector2.ZERO)
	for point in [Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		result = result.expand(part.transform * point)
	return result

func covered_fraction(part: Sprite2D, torso: Sprite2D) -> float:
	var bounds: Rect2 = part_bounds(part)
	return bounds.intersection(part_bounds(torso)).get_area() / maxf(bounds.get_area(), 0.0001)

func check_cutout(texture: AtlasTexture, kind: String) -> void:
	var path: String = texture.resource_path
	var version: String = "rig_v5" if kind == "monster" else "rig_v4"
	if checked_cutouts.has(path):
		return
	checked_cutouts[path] = true
	expect(path.contains("/%s/%s/" % [kind, version]) and path.ends_with(".tres"), "%s must use its current authored cutouts: %s" % [kind, path])
	expect(texture.atlas != null, "%s cutout must have a source atlas" % path)
	if texture.atlas == null:
		return
	var atlas_path: String = texture.atlas.resource_path
	expect(atlas_path.ends_with("/%s/%s/overhead_parts.png" % [kind, version]), "%s must use its own newly painted overhead atlas" % path)
	if not source_atlases.has(atlas_path):
		source_atlases[atlas_path] = Image.load_from_file(ProjectSettings.globalize_path(atlas_path))
	var source: Image = source_atlases[atlas_path]
	expect(source != null and not source.is_empty(), "%s source PNG must be readable" % atlas_path)
	if source == null or source.is_empty():
		return
	expect(source.detect_alpha() != Image.ALPHA_NONE, "%s must contain genuine PNG alpha" % atlas_path)
	var region: Rect2i = Rect2i(texture.region)
	expect(region.size.x > 0 and region.size.y > 0 and Rect2i(Vector2i.ZERO, source.get_size()).encloses(region), "%s region must lie inside the atlas" % path)
	if region.size.x <= 0 or region.size.y <= 0:
		return
	var clear_count: int = 0
	var painted_count: int = 0
	var step: int = maxi(1, mini(region.size.x, region.size.y) / 80)
	for y in range(region.position.y, region.end.y, step):
		for x in range(region.position.x, region.end.x, step):
			var alpha: float = source.get_pixel(x, y).a
			clear_count += 1 if alpha < 0.01 else 0
			painted_count += 1 if alpha > 0.80 else 0
	expect(painted_count > 0, "%s must contain opaque painted fabric/hide" % path)
	if not path.ends_with("/elbow.tres"):
		expect(clear_count > 0, "%s must have transparent surroundings" % path)

func check_saved_parts(rig: Node2D, kind: String) -> bool:
	var complete: bool = true
	for prefix in ["Left", "Right"]:
		for suffix in LIMB_PARTS:
			var part: Sprite2D = rig.get_node_or_null(NodePath(prefix + suffix)) as Sprite2D
			expect(part != null, "%s must save %s%s in its scene before setup" % [kind, prefix, suffix])
			complete = complete and part != null
	for part_name in ["Torso", "Head"]:
		expect(rig.get_node_or_null(NodePath(part_name)) is Sprite2D, "%s must save its %s sprite" % [kind, part_name])
		complete = complete and rig.get_node_or_null(NodePath(part_name)) is Sprite2D
	var sprite_count: int = 0
	for node in rig.find_children("*", "", true, false):
		expect(not node is SubViewport and not node is Node3D, "%s must use direct 2D cutouts without a second 3D model" % kind)
		if not node is Sprite2D:
			continue
		sprite_count += 1
		var part: Sprite2D = node
		expect(part.visible and part.modulate.a > 0.0 and part.self_modulate.a > 0.0, "%s/%s must already be visible in the editor" % [kind, part.name])
		var texture: AtlasTexture = part.texture as AtlasTexture
		expect(texture != null, "%s/%s must use a painted atlas cutout" % [kind, part.name])
		if texture != null:
			check_cutout(texture, kind)
			if texture.resource_path.ends_with("/elbow.tres"):
				var fold: ShaderMaterial = part.material as ShaderMaterial
				expect(fold != null and fold.shader != null and fold.shader.resource_path == "res://shaders/sleeve_fold.gdshader", "%s/%s cloth crop must use the same feathered sleeve fold as the hero" % [kind, part.name])
	var expected_count: int = 23 if kind == "monster" else 20
	expect(sprite_count == expected_count, "%s must contain its complete %d saved sprites" % [kind, expected_count])
	if kind == "monster":
		expect(rig.get_node_or_null("NeckMane") is Sprite2D, "Hunter must save its neck mane")
		for prefix in ["Left", "Right"]:
			expect(rig.get_node_or_null(NodePath(prefix + "AnkleFold")) is Sprite2D, "Hunter bare ankle connections must be covered by saved skin folds")
		var tail: Polygon2D = rig.get_node_or_null("Tail") as Polygon2D
		expect(tail != null and tail.texture != null and tail.polygon.size() > 20, "Hunter must save a complete textured continuous tail mesh")
		expect(not rig.has_node("TailRoot") and not rig.has_node("TailMiddle") and not rig.has_node("TailTip"), "The disconnected rigid tail cutouts must be removed from the scene")
	var script: Script = rig.get_script() as Script
	expect(script != null and script.is_tool(), "%s must share its pose code with the Godot editor" % kind)
	for method in ["setup", "advance", "pose", "apply_editor_pose"]:
		expect(rig.has_method(method), "%s must provide the %s rig API" % [kind, method])
	var properties: Dictionary = {}
	for item in rig.get_property_list():
		properties[String(item.name)] = item
	for property_name in ["preview_animation", "preview_state", "preview_cycle", "preview_direction"]:
		expect(properties.has(property_name) and (int(properties[property_name].usage) & PROPERTY_USAGE_EDITOR) != 0, "%s must expose %s in the inspector" % [kind, property_name])
	var animations: AnimationPlayer = rig.get_node_or_null("AnimationPlayer") as AnimationPlayer
	expect(animations != null, "%s must save editable animation clips" % kind)
	if animations != null:
		var states: Array[String] = ["idle", "walk", "run", "RESET"]
		if kind == "stalker":
			states.append_array(["leap", "grab"])
		for state in states:
			expect(animations.has_animation(state), "%s must save the %s animation" % [kind, state])
			if animations.has_animation(state):
				expect(animations.get_animation(state).get_track_count() >= sprite_count, "%s/%s must animate every saved sprite" % [kind, state])
	return complete

func apply_pose(rig: Node2D, state: String, cycle: float, direction: Vector2 = Vector2.DOWN) -> void:
	rig.set("preview_mode", true)
	rig.set("preview_animation", false)
	rig.set("preview_state", state)
	rig.set("movement", 0.0 if state in ["idle", "leap", "grab"] else 1.0)
	rig.set("running", 1.0 if state == "run" else 0.0)
	rig.set("travel_direction", direction)
	rig.set("phase", cycle * TAU)
	if "tail_phase" in rig:
		rig.set("tail_phase", cycle * TAU)
	rig.call("pose")

func check_layers_and_idle(rig: Node2D, kind: String) -> void:
	apply_pose(rig, "idle", 0.0)
	var parts: Dictionary = rig.get("parts")
	var torso: Sprite2D = parts.torso
	var minimum_coverage: float = 1.0
	for side in SIDES:
		for key in ["thigh", "shin", "knee", "foot", "shoulder", "upper_arm", "forearm", "elbow", "hand"]:
			var part: Sprite2D = parts[side + "_" + key]
			expect(part.z_index < torso.z_index, "%s %s must be occluded by the torso" % [kind, part.name])
			if key in ["thigh", "shin", "knee"]:
				minimum_coverage = minf(minimum_coverage, covered_fraction(part, torso))
				expect(part_bounds(part).size.y < part_bounds(torso).size.y * 0.65, "%s idle %s must remain a short overhead projection" % [kind, part.name])
		expect(parts[side + "_foot"].z_index < parts[side + "_shin"].z_index, "%s shin must cover the boot opening" % kind)
		expect(parts[side + "_hand"].z_index < parts[side + "_forearm"].z_index, "%s sleeve must cover the wrist" % kind)
		expect(parts[side + "_upper_arm"].z_index < parts[side + "_elbow"].z_index and parts[side + "_forearm"].z_index < parts[side + "_elbow"].z_index, "%s elbow fold must cover both sleeve openings" % kind)
	expect(minimum_coverage > 0.80, "%s torso must hide its resting thighs, shins and knees (%.1f%%)" % [kind, minimum_coverage * 100.0])
	print("%s IDLE minimum torso coverage %.1f%%" % [kind.to_upper(), minimum_coverage * 100.0])

func segment_error(part: Sprite2D, start: Vector2, finish: Vector2) -> float:
	var center_error: float = part.position.distance_to((start + finish) * 0.5)
	var axis: Vector2 = Vector2.DOWN.rotated(part.rotation)
	var length: float = start.distance_to(finish)
	var axis_error: float = absf(axis.cross(start.direction_to(finish))) * length
	var visible_length: float = part.texture.get_size().y * absf(part.scale.y)
	var gap: float = maxf(0.0, length - visible_length)
	return maxf(center_error, maxf(axis_error, gap))

func check_gait(rig: Node2D, kind: String) -> void:
	var parts: Dictionary = rig.get("parts")
	var worst_jump: float = 0.0
	var worst_attachment: float = 0.0
	var worst_arm_length: float = 0.0
	var minimum_arm_projection: float = INF
	var elbows_outside: bool = true
	var foot_travel: Dictionary = {"left": 0.0, "right": 0.0}
	var cloth_travel: Dictionary = {"thigh": 0.0, "shin": 0.0}
	var revealed_cloth: float = 0.0
	for state in ["walk", "run"]:
		for direction_index in range(8):
			var direction: Vector2 = Vector2.from_angle(direction_index * TAU / 8.0)
			var previous: Dictionary = {}
			var first: Dictionary = {}
			for sample in range(SAMPLE_COUNT + 1):
				apply_pose(rig, state, float(sample) / SAMPLE_COUNT, direction)
				var joints: Dictionary = rig.get("joints")
				for side in SIDES:
					var shoulder: Vector2 = joints[side + "_shoulder"]
					var elbow: Vector2 = joints[side + "_elbow"]
					var hand: Vector2 = joints[side + "_hand"]
					var sign_value: float = -1.0 if side == "left" else 1.0
					if kind == "monster":
						# A crouched hunter folds backward under its mane when turning;
						# its limbs must stay on their own side without a pole flip.
						elbows_outside = elbows_outside and elbow.x * sign_value > 0.0 and hand.x * sign_value > 0.0
					else:
						elbows_outside = elbows_outside and (elbow.x - shoulder.x) * sign_value > 0.0
					worst_attachment = maxf(worst_attachment, segment_error(parts[side + "_upper_arm"], shoulder, elbow))
					worst_attachment = maxf(worst_attachment, segment_error(parts[side + "_forearm"], elbow, hand))
					worst_attachment = maxf(worst_attachment, parts[side + "_elbow"].position.distance_to(elbow))
					var hip: Vector2 = joints[side + "_hip"]
					var knee: Vector2 = joints[side + "_knee"]
					var ankle: Vector2 = joints.get(side + "_ankle", Vector2(joints[side + "_foot"]) - Vector2(0.0, 5.0))
					worst_attachment = maxf(worst_attachment, segment_error(parts[side + "_thigh"], hip, knee))
					worst_attachment = maxf(worst_attachment, segment_error(parts[side + "_shin"], knee, ankle))
					var hand_sprite: Sprite2D = parts[side + "_hand"]
					worst_attachment = maxf(worst_attachment, maxf(0.0, hand_sprite.position.distance_to(hand) - hand_sprite.texture.get_size().y * absf(hand_sprite.scale.y) * 0.5))
					minimum_arm_projection = minf(minimum_arm_projection, minf(shoulder.distance_to(elbow), elbow.distance_to(hand)))
					if kind == "monster":
						worst_arm_length = maxf(worst_arm_length, maxf(0.0, shoulder.distance_to(elbow) - 26.0))
						worst_arm_length = maxf(worst_arm_length, maxf(0.0, elbow.distance_to(hand) - 34.0))
					else:
						worst_arm_length = maxf(worst_arm_length, maxf(0.0, shoulder.distance_to(elbow) - 21.0))
						worst_arm_length = maxf(worst_arm_length, maxf(0.0, elbow.distance_to(hand) - 27.0))
					for key in ["shoulder", "elbow", "hand", "hip", "knee", "foot"]:
						var name: String = side + "_" + key
						var point: Vector2 = joints[name]
						expect(point.is_finite(), "%s %s joint must remain finite" % [kind, name])
						if previous.has(name):
							worst_jump = maxf(worst_jump, point.distance_to(previous[name]))
						previous[name] = point
					for key in ["foot", "thigh", "shin"]:
						var name: String = side + "_" + key
						var part: Sprite2D = parts[name]
						if not first.has(name):
							first[name] = part.position
						var travel: float = part.position.distance_to(first[name])
						if key == "foot":
							foot_travel[side] = maxf(foot_travel[side], travel)
						else:
							cloth_travel[key] = maxf(cloth_travel[key], travel)
							revealed_cloth = maxf(revealed_cloth, 1.0 - covered_fraction(part, parts.torso))
	expect(elbows_outside, "%s elbows must keep their natural bend and remain on their own side through all eight directions" % kind)
	expect(minimum_arm_projection > 0.1, "%s connected arms must keep a nonzero overhead projection" % kind)
	expect(worst_arm_length < 0.01, "%s arm segments must respect their physical lengths" % kind)
	expect(worst_attachment < 0.01, "%s sleeves, caps and wrists must remain attached to the same skeleton" % kind)
	expect(worst_jump < 4.0, "%s joints must move continuously across all gait phases, including the loop boundary" % kind)
	for side in SIDES:
		expect(float(foot_travel[side]) > 20.0, "%s %s foot must visibly step" % [kind, side])
	expect(float(cloth_travel.thigh) > 3.0 and float(cloth_travel.shin) > 6.0, "%s must animate thighs and shins together with its feet" % kind)
	expect(revealed_cloth > 0.10, "%s stepping must reveal short sections of intermediate limb texture" % kind)
	print("%s GAIT max joint jump %.3f; attachment error %.6f; arm error %.6f; cloth reveal %.1f%%" % [kind.to_upper(), worst_jump, worst_attachment, worst_arm_length, revealed_cloth * 100.0])

func correlation(first: Array[float], second: Array[float]) -> float:
	var first_mean: float = 0.0
	var second_mean: float = 0.0
	for index in range(first.size()):
		first_mean += first[index] / first.size()
		second_mean += second[index] / second.size()
	var covariance: float = 0.0
	var first_variance: float = 0.0
	var second_variance: float = 0.0
	for index in range(first.size()):
		var first_delta: float = first[index] - first_mean
		var second_delta: float = second[index] - second_mean
		covariance += first_delta * second_delta
		first_variance += first_delta * first_delta
		second_variance += second_delta * second_delta
	return covariance / maxf(sqrt(first_variance * second_variance), 0.0001)

func check_limb_coordination(rig: Node2D, kind: String) -> void:
	for state in ["walk", "run"]:
		for side in SIDES:
			var hand_samples: Array[float] = []
			var foot_samples: Array[float] = []
			for sample in range(241):
				apply_pose(rig, state, float(sample) / 240.0)
				var joints: Dictionary = rig.get("joints")
				hand_samples.append(Vector2(joints[side + "_hand"]).y)
				var foot_side: String = ("right" if side == "left" else "left") if kind == "monster" else side
				foot_samples.append(Vector2(joints[foot_side + "_foot"]).y)
			var coordination: float = correlation(hand_samples, foot_samples)
			if kind == "monster":
				expect(coordination > 0.85, "Hunter must pair its %s forepaw with the opposite hind foot during %s" % [side, state])
			else:
				expect(coordination < -0.90, "Stalker %s hand must swing opposite its same-side foot during %s" % [side, state])
			print("%s %s %s limb correlation %.3f" % [kind.to_upper(), state, side, coordination])

func check_runtime_blends(rig: Node2D, kind: String) -> void:
	var actor: MotionActor = MotionActor.new()
	root.add_child(actor)
	rig.call("setup", actor, true)
	rig.set("preview_mode", false)
	rig.set("phase", 1.25)
	rig.set("movement", 0.0)
	rig.set("running", 0.0)
	rig.call("advance", 1.0 / 60.0)
	expect(is_equal_approx(float(rig.get("phase")), 1.25), "%s idle must preserve planted gait phase" % kind)
	actor.velocity = Vector2(0.0, 180.0)
	rig.call("advance", 1.0 / 60.0)
	expect(float(rig.get("movement")) > 0.0 and float(rig.get("movement")) < 1.0, "%s must blend smoothly into walking" % kind)
	for frame in range(60):
		rig.call("advance", 1.0 / 60.0)
	actor.sprinting = true
	actor.velocity = Vector2(0.0, 310.0)
	var phase_before: float = rig.get("phase")
	rig.call("advance", 1.0 / 60.0)
	expect(float(rig.get("running")) > 0.0 and float(rig.get("running")) < 1.0, "%s must blend smoothly into running" % kind)
	expect(fposmod(float(rig.get("phase")) - phase_before, TAU) < 0.5, "%s running must retain its existing stride phase" % kind)
	actor.velocity = Vector2.ZERO
	actor.sprinting = false
	phase_before = rig.get("phase")
	for frame in range(120):
		rig.call("advance", 1.0 / 60.0)
	expect(is_equal_approx(float(rig.get("phase")), phase_before), "%s stopping must freeze the planted stride phase" % kind)
	expect(float(rig.get("movement")) < 0.001 and float(rig.get("running")) < 0.001, "%s stopping must settle into its idle pose" % kind)
	rig.call("setup", null, true)
	actor.free()

func check_attacks(rig: Node2D) -> void:
	var parts: Dictionary = rig.get("parts")
	apply_pose(rig, "idle", 0.0)
	var idle_hand: Vector2 = rig.get("joints").left_hand
	var maximum_reach: float = 0.0
	var maximum_jump: float = 0.0
	var maximum_attachment: float = 0.0
	for state in ["leap", "grab"]:
		var previous: Dictionary = {}
		for sample in range(241):
			apply_pose(rig, state, float(sample) / 240.0)
			var joints: Dictionary = rig.get("joints")
			maximum_reach = maxf(maximum_reach, Vector2(joints.left_hand).distance_to(idle_hand))
			for side in SIDES:
				var shoulder: Vector2 = joints[side + "_shoulder"]
				var elbow: Vector2 = joints[side + "_elbow"]
				var hand: Vector2 = joints[side + "_hand"]
				maximum_attachment = maxf(maximum_attachment, segment_error(parts[side + "_upper_arm"], shoulder, elbow))
				maximum_attachment = maxf(maximum_attachment, segment_error(parts[side + "_forearm"], elbow, hand))
				for key in ["elbow", "hand", "knee", "foot"]:
					var name: String = side + "_" + key
					var point: Vector2 = joints[name]
					if previous.has(name):
						maximum_jump = maxf(maximum_jump, point.distance_to(previous[name]))
					previous[name] = point
	expect(maximum_reach > 25.0, "Stalker leap and grab must visibly extend its connected hands toward the target")
	expect(maximum_jump < 4.0, "Stalker leap and grab must retain continuous hands and feet")
	expect(maximum_attachment < 0.01, "Stalker attack sleeves must remain attached at both joints")
	print("STALKER ATTACK reach %.2f; max joint jump %.3f; attachment error %.6f" % [maximum_reach, maximum_jump, maximum_attachment])

func check_hunter_tail(rig: Node2D) -> void:
	var parts: Dictionary = rig.get("parts")
	var tail: Polygon2D = parts.tail
	var maximum_jump: float = 0.0
	var maximum_travel: float = 0.0
	var leftmost: float = INF
	var rightmost: float = -INF
	var first: Vector2
	var previous: Vector2
	var source: Image = source_atlases[tail.texture.resource_path]
	for sample in range(481):
		apply_pose(rig, "run", float(sample) / 480.0)
		var points: Dictionary = rig.get("joints")
		var mesh: PackedVector2Array = tail.polygon
		var faces: Array = tail.polygons
		expect(mesh.size() == tail.uv.size() and faces.size() * 2 + 2 == mesh.size(), "Tail must remain one complete strip with shared section vertices")
		for section in range(faces.size()):
			var face: PackedInt32Array = faces[section]
			var first_area: float = (mesh[face[1]] - mesh[face[0]]).cross(mesh[face[2]] - mesh[face[0]])
			var second_area: float = (mesh[face[2]] - mesh[face[0]]).cross(mesh[face[3]] - mesh[face[0]])
			expect(first_area * second_area > 0.0 and absf(first_area) > 0.01, "Tail skin must not fold over or collapse at a bend")
			if section + 1 < faces.size():
				expect(face[2] == faces[section + 1][1] and face[3] == faces[section + 1][0], "Adjacent tail sections must share the same two vertices")
			var center_uv: Vector2 = (tail.uv[section * 2] + tail.uv[section * 2 + 1]) * 0.5
			expect(source.get_pixelv(Vector2i(center_uv)).a > 0.8, "Fur along the tail centerline must remain opaque without cutout gaps")
		var tip: Vector2 = points.tail_tip
		leftmost = minf(leftmost, tip.x)
		rightmost = maxf(rightmost, tip.x)
		expect(points.tail_base.distance_to(Vector2(0.0, -22.0)) < 0.001, "Wagging must keep the tail root attached beneath the back")
		if sample == 0:
			first = tip
		else:
			maximum_jump = maxf(maximum_jump, tip.distance_to(previous))
		maximum_travel = maxf(maximum_travel, tip.distance_to(first))
		previous = tip
	expect(tail.z_index > parts.left_knee.z_index and tail.z_index < parts.torso.z_index, "The suspended tail must cover crossing hind legs while its root stays beneath the back")
	expect(parts.neck_mane.z_index > parts.torso.z_index and parts.neck_mane.z_index < parts.head.z_index, "Hunter mane must connect the shoulder fur to the iron mask")
	expect(maximum_jump < 1.0 and maximum_travel > 6.0, "Hunter tail must follow a continuous visible motion")
	expect(leftmost < -30.0 and rightmost > 30.0, "Hunter tail must sweep clearly across both sides of the body")
	expect(previous.distance_to(first) < 0.001, "Tail wag must close its animation loop without a jump")
	apply_pose(rig, "idle", 0.25)
	var idle_right: Vector2 = rig.get("joints").tail_tip
	apply_pose(rig, "idle", 0.75)
	var idle_left: Vector2 = rig.get("joints").tail_tip
	expect(idle_right.x > 20.0 and idle_left.x < -20.0, "The resting hunter must also wag to both sides")
	var resting_phase: float = rig.get("tail_phase")
	rig.call("advance_tail", 0.1, 0.0)
	expect(float(rig.get("tail_phase")) > resting_phase, "Tail clock must continue while the paws stand still")
	apply_pose(rig, "walk", 0.371)
	var expected_mesh: PackedVector2Array = tail.polygon.duplicate()
	var animations: AnimationPlayer = rig.get_node("AnimationPlayer")
	animations.play("walk")
	animations.seek(animations.get_animation("walk").length * 0.371, true)
	animations.advance(0.0)
	var editor_error: float = 0.0
	for vertex in range(expected_mesh.size()):
		editor_error = maxf(editor_error, expected_mesh[vertex].distance_to(tail.polygon[vertex]))
	animations.stop()
	expect(editor_error < 0.05, "The saved tail clip must interpolate the same continuous skin as gameplay")
	print("HUNTER TAIL continuous %d-section skin; jump %.3f; travel %.2f" % [tail.polygons.size(), maximum_jump, maximum_travel])

func check_hunter_contacts(rig: Node2D) -> void:
	var maximum_slip: float = 0.0
	for state in ["walk", "run"]:
		for side in SIDES:
			var start: float = 0.1 if side == "left" else 0.6
			apply_pose(rig, state, start)
			var first: Vector2 = rig.get("joints")[side + "_hand"]
			var palm: Sprite2D = rig.get("parts")[side + "_hand"]
			var first_angle: float = palm.rotation
			var distance: float = rig.call("stride_length")
			apply_pose(rig, state, start + 0.2)
			var last: Vector2 = rig.get("joints")[side + "_hand"]
			maximum_slip = maxf(maximum_slip, (last + Vector2.DOWN * distance * 0.2).distance_to(first))
			expect(absf(angle_difference(first_angle, palm.rotation)) < 0.001, "A planted forepaw must retain its ground orientation")
		rig.set("running", 1.0 if state == "run" else 0.0)
		var contact: float = rig.call("contact_fraction")
		var epsilon: float = 0.0001
		for boundary in [0.0, contact]:
			var before: Vector2 = rig.call("paw_cycle", (boundary - epsilon) * TAU)
			var center: Vector2 = rig.call("paw_cycle", boundary * TAU)
			var after: Vector2 = rig.call("paw_cycle", (boundary + epsilon) * TAU)
			expect(((center - before) / epsilon).distance_to((after - center) / epsilon) < 0.08, "Paw velocity must remain continuous at liftoff, touchdown and loop closure")
	expect(maximum_slip < 0.01, "Forepaw contact must cancel the body's motion instead of sliding across the floor")
	print("HUNTER CONTACT maximum planted paw slip %.6f px" % maximum_slip)

func check_attack_transitions(rig: Node2D) -> void:
	var actor: MotionActor = MotionActor.new()
	root.add_child(actor)
	rig.set("preview_mode", false)
	rig.set("phase", 0.0)
	rig.set("movement", 0.0)
	rig.set("running", 0.0)
	rig.call("setup", actor, true)
	var maximum_jump: float = 0.0
	var maximum_attachment: float = 0.0
	var previous: Dictionary = {}
	var parts: Dictionary = rig.get("parts")
	for interrupted in [false, true]:
		for state in ["stalk", "leap", "grab", "flee"]:
			if interrupted and state == "grab":
				continue
			actor.state = state
			actor.sprinting = state == "flee"
			actor.velocity = Vector2.DOWN * (240.0 if state == "flee" else (120.0 if state == "stalk" else 0.0))
			var frames: int = 8 if interrupted and state == "leap" else (180 if state == "grab" else 60)
			for frame in range(frames):
				actor.leap_progress = float(frame) / 59.0
				actor.attack_elapsed = frame / 60.0
				rig.call("advance", 1.0 / 60.0)
				var joints: Dictionary = rig.get("joints")
				for side in SIDES:
					var shoulder: Vector2 = joints[side + "_shoulder"]
					var elbow: Vector2 = joints[side + "_elbow"]
					var hand: Vector2 = joints[side + "_hand"]
					maximum_attachment = maxf(maximum_attachment, segment_error(parts[side + "_upper_arm"], shoulder, elbow))
					maximum_attachment = maxf(maximum_attachment, segment_error(parts[side + "_forearm"], elbow, hand))
					for key in ["elbow", "hand"]:
						var name: String = side + "_" + key
						var point: Vector2 = joints[name]
						if previous.has(name):
							maximum_jump = maxf(maximum_jump, point.distance_to(previous[name]))
						previous[name] = point
	expect(maximum_jump < 8.0, "Stalker attack entry, release and interrupted leap must not teleport its wrists")
	expect(maximum_attachment < 0.01, "Stalker runtime attack transitions must keep every sleeve connected")
	print("STALKER TRANSITIONS max joint jump %.3f; attachment error %.6f" % [maximum_jump, maximum_attachment])
	rig.call("setup", null, true)
	actor.free()

func check_creatures() -> void:
	for kind in CREATURES:
		var packed: PackedScene = load(CREATURES[kind]) as PackedScene
		expect(packed != null, "%s scene must load" % kind)
		if packed == null:
			continue
		var rig: Node2D = packed.instantiate() as Node2D
		if not check_saved_parts(rig, kind):
			rig.free()
			continue
		var saved_transforms: Dictionary = {}
		var saved_tail: PackedVector2Array = PackedVector2Array()
		if kind == "monster":
			saved_tail = rig.get_node("Tail").polygon.duplicate()
		for child in rig.get_children():
			if child is Sprite2D:
				saved_transforms[child.name] = child.transform
		root.add_child(rig)
		rig.set_process(false)
		rig.call("setup", null, true)
		if kind == "monster":
			var active_tail: PackedVector2Array = rig.get_node("Tail").polygon
			expect(saved_tail.size() == active_tail.size(), "The complete tail skin must already be saved in the scene")
			for vertex in range(mini(saved_tail.size(), active_tail.size())):
				expect(saved_tail[vertex].distance_to(active_tail[vertex]) < 0.001, "Saved tail vertices must match runtime idle without rebuilding the model")
		for child in rig.get_children():
			if child is Sprite2D:
				var saved: Transform2D = saved_transforms[child.name]
				expect(child.transform.is_equal_approx(saved), "%s/%s saved editor pose must match its runtime idle pose" % [kind, child.name])
		check_layers_and_idle(rig, kind)
		check_gait(rig, kind)
		check_limb_coordination(rig, kind)
		check_runtime_blends(rig, kind)
		if kind == "monster":
			check_hunter_tail(rig)
			check_hunter_contacts(rig)
		if kind == "stalker":
			check_attacks(rig)
			check_attack_transitions(rig)
		rig.free()
	print("RESULT authored hunter/stalker 2D cutouts, overhead layers, connected gait and attacks: %d failure(s)" % failures.size())
	quit(0 if failures.is_empty() else 1)
