extends SceneTree

const RIG = preload("res://scripts/actors/stalker_rig.gd")

func _initialize() -> void:
	var actor: CharacterBody2D = CharacterBody2D.new()
	var rig: Node2D = RIG.new()
	rig.name = "ArticulatedBody"
	rig.preview_mode = true
	rig.setup(actor, true)
	# Reuse the same textured articulated construction as the existing actors.
	for key in rig.parts:
		var texture_part: String = key.trim_prefix("left_").trim_prefix("right_")
		if texture_part == "elbow": continue
		rig.parts[key].texture = load("res://assets/characters/player/rig/%s.tres" % texture_part)
		rig.parts[key].self_modulate = Color(0.16, 0.18, 0.22) if texture_part != "head" else Color(0.24, 0.25, 0.28)
	for child in rig.get_children():
		child.owner = rig
		if String(child.name).ends_with("Elbow"): child.self_modulate = Color(0.12, 0.14, 0.17)
	rig.pose()
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(rig) == OK)
	assert(ResourceSaver.save(packed, "res://scenes/actors/stalker_body.tscn") == OK)
	rig.free()
	actor.free()
	print("Saved native articulated biped stalker")
	quit()
