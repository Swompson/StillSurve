extends SceneTree

const RIG = preload("res://scripts/actors/articulated_actor.gd")

func _initialize() -> void:
	for kind in ["monster"]:
		var body: CharacterBody2D = CharacterBody2D.new()
		var rig: Node2D = RIG.new()
		rig.name = "ArticulatedBody"
		rig.set("preview_mode", true)
		rig.call("setup", body, kind == "monster")
		for child in rig.get_children():
			child.owner = rig
		var scene: PackedScene = PackedScene.new()
		assert(scene.pack(rig) == OK)
		assert(ResourceSaver.save(scene, "res://scenes/actors/%s_body.tscn" % kind) == OK)
		rig.free()
		body.free()
	print("Saved actor bodies as editable native scenes")
	quit()
