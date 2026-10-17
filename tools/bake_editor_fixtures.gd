extends SceneTree
func _initialize() -> void: call_deferred("bake")
func claim(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		child.scene_file_path = ""
		child.owner = scene_root
		for group in child.get_groups():
			if not String(group).begins_with("_"):
				child.add_to_group(group, true)
		claim(child, scene_root)
func bake() -> void:
	var overhead: Node2D = load("res://scenes/world/overhead.tscn").instantiate()
	overhead.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(overhead)
	claim(overhead, overhead)
	overhead.process_mode = Node.PROCESS_MODE_INHERIT
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(overhead) == OK)
	assert(ResourceSaver.save(packed, "res://scenes/world/overhead.tscn") == OK)
	print("Saved five complete fixtures as native editable nodes; no fixture scene instances")
	quit()
