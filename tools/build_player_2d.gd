extends SceneTree

## Offline authoring only. Gameplay never creates visual parts in _ready().
const TEXTURE_DIR: String = "res://assets/characters/player/rig_v3/"
const SCENE_PATH: String = "res://scenes/actors/player_body.tscn"
const ANIMATION_PATH: String = TEXTURE_DIR + "locomotion.tres"
const SAMPLE_COUNT: int = 32
var body: Node2D

func _initialize() -> void:
	call_deferred("build")

func add_part(label: String, texture_key: String, depth: int, mirrored: bool = false) -> void:
	var texture: Texture2D = load(TEXTURE_DIR + texture_key + ("_overhead.svg" if texture_key == "flashlight" else ".tres"))
	assert(texture != null, "Generated player texture is missing: " + texture_key)
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = label
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.z_index = depth
	sprite.flip_h = mirrored
	if texture_key == "elbow":
		var cloth: ShaderMaterial = ShaderMaterial.new()
		cloth.shader = load("res://shaders/sleeve_fold.gdshader")
		sprite.material = cloth
	body.add_child(sprite)
	sprite.owner = body

func sprite_parts() -> Array[Sprite2D]:
	var result: Array[Sprite2D] = []
	for child in body.get_children():
		if child is Sprite2D:
			result.append(child)
	return result

func sample_pose(state: String, cycle: float) -> void:
	body.set("preview_state", state)
	body.set("phase", cycle * TAU)
	body.set("movement", 1.0 if state.begins_with("walk") or state.begins_with("run") else 0.0)
	body.set("running", 1.0 if state.begins_with("run") else 0.0)
	# A complete breath closes the idle loop exactly at the last key.
	body.set("breath_clock", cycle * TAU / 2.3 if state.begins_with("idle") else 0.0)
	body.call("pose")

func add_animations() -> void:
	var sprites: Array[Sprite2D] = sprite_parts()
	var library: AnimationLibrary = AnimationLibrary.new()
	for state in ["RESET", "idle", "walk", "run", "idle_unlit", "walk_unlit", "run_unlit", "stow_flashlight", "draw_flashlight"]:
		var clip: Animation = Animation.new()
		if state.begins_with("idle"):
			clip.length = 2.6
		elif state.begins_with("walk"):
			clip.length = 0.8
		elif state.begins_with("run"):
			clip.length = 0.56
		else:
			clip.length = {"RESET": 0.001, "stow_flashlight": 0.82, "draw_flashlight": 0.68}[state]
		clip.loop_mode = Animation.LOOP_NONE if state in ["RESET", "stow_flashlight", "draw_flashlight"] else Animation.LOOP_LINEAR
		for sprite in sprites:
			var track: int = clip.add_track(Animation.TYPE_VALUE)
			clip.track_set_path(track, NodePath(String(sprite.name) + ":transform"))
			clip.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
		var alpha_track: int = clip.add_track(Animation.TYPE_VALUE)
		clip.track_set_path(alpha_track, NodePath("Flashlight:modulate"))
		var count: int = 1 if state == "RESET" else SAMPLE_COUNT
		for sample in range(count):
			var cycle: float = float(sample) / float(SAMPLE_COUNT - 1)
			sample_pose("idle" if state == "RESET" else state, cycle)
			for track in range(sprites.size()):
				clip.track_insert_key(track, cycle * clip.length, sprites[track].transform)
			clip.track_insert_key(alpha_track, cycle * clip.length, body.get_node("Flashlight").modulate)
		library.add_animation(state, clip)
	assert(ResourceSaver.save(library, ANIMATION_PATH, ResourceSaver.FLAG_CHANGE_PATH) == OK, "Unable to save the editable 2D locomotion clips")
	library.take_over_path(ANIMATION_PATH)
	var player: AnimationPlayer = AnimationPlayer.new()
	player.name = "AnimationPlayer"
	player.root_node = NodePath("..")
	player.add_animation_library("", library)
	# No autoplay: the runtime rig still controls pose and flashlight drawing.
	body.add_child(player)
	player.owner = body

func build() -> void:
	body = Node2D.new()
	body.name = "ArticulatedBody"
	body.set_script(load("res://scripts/actors/player_2d_rig.gd"))
	for side in ["Left", "Right"]:
		var mirrored: bool = side == "Right"
		add_part(side + "Foot", "foot", -10, mirrored)
		add_part(side + "Shin", "shin", -9, mirrored)
		add_part(side + "Thigh", "thigh", -8, mirrored)
		add_part(side + "Knee", "knee", -7, mirrored)
	for side in ["Left", "Right"]:
		var mirrored: bool = side == "Right"
		add_part(side + "UpperArm", "upper_arm", -2, mirrored)
		add_part(side + "Shoulder", "shoulder", 0, mirrored)
		add_part(side + "Elbow", "elbow", -1, mirrored)
	add_part("Torso", "torso", 1)
	for side in ["Left", "Right"]:
		add_part(side + "Forearm", "forearm", -3, side == "Right")
	add_part("Flashlight", "flashlight", -5)
	for side in ["Left", "Right"]:
		add_part(side + "Hand", "hand", -4, side == "Right")
	add_part("Head", "head", 5)
	body.set("preview_mode", true)
	body.call("setup", null, false)
	add_animations()
	body.set("preview_state", "idle")
	body.set("phase", 0.0)
	body.set("movement", 0.0)
	body.set("running", 0.0)
	body.set("breath_clock", 0.0)
	body.set("preview_mode", false)
	body.call("pose")
	var scene: PackedScene = PackedScene.new()
	assert(scene.pack(body) == OK, "Unable to pack the authored 2D player")
	assert(ResourceSaver.save(scene, SCENE_PATH) == OK, "Unable to save the authored 2D player")
	print("Saved overhead 2D survivor: %d sprites, connected bent arms, lit/unlit gait and flashlight stow/draw clips" % sprite_parts().size())
	body.free()
	quit()
