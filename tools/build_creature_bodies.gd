extends SceneTree

## Offline authoring: save the same sprites and sampled poses used during play.
const SAMPLE_COUNT: int = 48
var body: Node2D
var kind: String

func _initialize() -> void:
	call_deferred("build")

func add_part(label: String, texture_key: String, depth: int, mirrored: bool = false) -> void:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = label
	var version: String = "rig_v5" if kind == "monster" else "rig_v4"
	sprite.texture = load("res://assets/characters/%s/%s/%s.tres" % [kind, version, texture_key])
	assert(sprite.texture != null, "Missing authored creature cutout: " + texture_key)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.z_index = depth
	sprite.flip_h = mirrored
	if texture_key == "elbow":
		var fold: ShaderMaterial = ShaderMaterial.new()
		fold.shader = load("res://shaders/sleeve_fold.gdshader")
		sprite.material = fold
	body.add_child(sprite)
	sprite.owner = body

func sample_pose(state: String, cycle: float) -> void:
	body.set("preview_state", state)
	body.set("phase", cycle * TAU)
	if kind == "monster":
		body.set("tail_phase", cycle * TAU)
		if state in ["walk", "run"]:
			body.set("phase", cycle * TAU * 2.0)
	body.set("movement", 1.0 if state in ["walk", "run", "stalk", "flee"] else 0.0)
	body.set("running", 1.0 if state in ["run", "flee"] else 0.0)
	body.call("pose")

func add_tail() -> void:
	var tail: Polygon2D = Polygon2D.new()
	tail.name = "Tail"
	tail.z_index = -6
	tail.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tail.texture = load("res://assets/characters/monster/rig_v5/overhead_parts.png")
	var source: AtlasTexture = load("res://assets/characters/monster/rig_v5/tail_middle.tres")
	body.set("tail_region", source.region)
	body.add_child(tail)
	tail.owner = body

func add_animations() -> void:
	var sprites: Array[Sprite2D] = []
	for child in body.get_children():
		if child is Sprite2D:
			sprites.append(child)
	var library: AnimationLibrary = AnimationLibrary.new()
	var states: Array[String] = ["RESET", "idle", "walk", "run"]
	if kind == "stalker":
		states.append_array(["stalk", "flee", "leap", "grab"])
	for state in states:
		var clip: Animation = Animation.new()
		clip.length = 0.001 if state == "RESET" else (2.6 if state == "idle" else (0.56 if state in ["run", "flee"] else 0.8))
		if kind == "monster" and state in ["walk", "run"]:
			sample_pose(state, 0.0)
			clip.length = 2.0 * float(body.call("stride_length")) / (340.0 if state == "run" else 115.0)
		clip.loop_mode = Animation.LOOP_NONE if state in ["RESET", "leap"] else Animation.LOOP_LINEAR
		for sprite in sprites:
			var track: int = clip.add_track(Animation.TYPE_VALUE)
			clip.track_set_path(track, NodePath(String(sprite.name) + ":transform"))
			clip.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
		# Leap scales the complete rig as well as moving its connected limbs.
		var scale_track: int = clip.add_track(Animation.TYPE_VALUE)
		clip.track_set_path(scale_track, NodePath(".:scale"))
		var tail_track: int = -1
		if kind == "monster":
			tail_track = clip.add_track(Animation.TYPE_VALUE)
			clip.track_set_path(tail_track, NodePath("Tail:polygon"))
		var count: int = 1 if state == "RESET" else SAMPLE_COUNT
		if kind == "monster" and state in ["walk", "run"]:
			count = SAMPLE_COUNT * 2 - 1
		for sample in range(count):
			var cycle: float = float(sample) / float(maxi(1, count - 1))
			sample_pose("idle" if state == "RESET" else state, cycle)
			for track in range(sprites.size()):
				clip.track_insert_key(track, cycle * clip.length, sprites[track].transform)
			clip.track_insert_key(scale_track, cycle * clip.length, body.scale)
			if tail_track >= 0:
				clip.track_insert_key(tail_track, cycle * clip.length, body.get_node("Tail").polygon)
		library.add_animation(state, clip)
	var version: String = "rig_v5" if kind == "monster" else "rig_v4"
	var path: String = "res://assets/characters/%s/%s/locomotion.tres" % [kind, version]
	assert(ResourceSaver.save(library, path, ResourceSaver.FLAG_CHANGE_PATH) == OK)
	library.take_over_path(path)
	var animations: AnimationPlayer = AnimationPlayer.new()
	animations.name = "AnimationPlayer"
	animations.root_node = NodePath("..")
	animations.add_animation_library("", library)
	body.add_child(animations)
	animations.owner = body

func build() -> void:
	var characters: Array[String] = ["monster", "stalker"]
	if "--hunter-only" in OS.get_cmdline_user_args():
		characters = ["monster"]
	for character in characters:
		kind = character
		body = Node2D.new()
		body.name = "ArticulatedBody"
		body.set_script(load("res://scripts/actors/%s_rig.gd" % ("hunter" if kind == "monster" else "stalker")))
		if kind == "monster":
			add_tail()
		for side in ["Left", "Right"]:
			var mirrored: bool = side == "Right"
			add_part(side + "Foot", "foot", -10, mirrored)
			add_part(side + "Shin", "shin", -9, mirrored)
			add_part(side + "Thigh", "thigh", -8, mirrored)
			add_part(side + "Knee", "knee", -7, mirrored)
			if kind == "monster":
				add_part(side + "AnkleFold", "elbow", -7, mirrored)
			add_part(side + "Hand", "hand", -4, mirrored)
			add_part(side + "Forearm", "forearm", -3, mirrored)
			add_part(side + "UpperArm", "upper_arm", -2, mirrored)
			add_part(side + "Elbow", "elbow", -1, mirrored)
			add_part(side + "Shoulder", "shoulder", 0, mirrored)
		add_part("Torso", "torso", 1)
		if kind == "monster":
			add_part("NeckMane", "neck_mane", 2)
		add_part("Head", "head", 5)
		body.set("preview_mode", true)
		body.call("setup", null, true)
		add_animations()
		sample_pose("idle", 0.0)
		body.set("preview_mode", false)
		var scene: PackedScene = PackedScene.new()
		assert(scene.pack(body) == OK)
		var folder: String = "res://.godot/authored_creatures/" if "--stage-scenes" in OS.get_cmdline_user_args() else "res://scenes/actors/"
		DirAccess.make_dir_recursive_absolute(folder)
		var error: Error = ResourceSaver.save(scene, folder + "%s_body.tscn" % kind)
		if error != OK:
			push_error("Unable to save authored %s scene: %d" % [kind, error])
			body.free()
			quit(1)
			return
		body.free()
		print("Saved %s: %d authored sprites and editable locomotion clips" % [kind, body_sprite_count(scene)])
	quit()

func body_sprite_count(scene: PackedScene) -> int:
	var state: SceneState = scene.get_state()
	var count: int = 0
	for index in range(state.get_node_count()):
		if state.get_node_type(index) == &"Sprite2D":
			count += 1
	return count
