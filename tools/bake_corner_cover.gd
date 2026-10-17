extends SceneTree
func _initialize() -> void:
	call_deferred("bake")
func claim(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		child.scene_file_path = ""
		child.owner = scene_root
		for group in child.get_groups():
			if not String(group).begins_with("_"):
				child.add_to_group(group, true)
		claim(child, scene_root)
func bake() -> void:
	var maze: Node2D = load("res://scenes/world/maze.tscn").instantiate()
	root.add_child(maze)
	await process_frame
	var details: Node2D = maze.get_node("CorridorDetails")
	for child in details.get_children():
		if String(child.name).begins_with("CornerCover"):
			details.remove_child(child)
			child.free()
	maze.call("build_corner_cover", details)
	claim(details, details)
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(details) == OK)
	assert(ResourceSaver.save(packed, "res://scenes/world/corridor_details.tscn") == OK)
	print("Saved twelve corner cover piles with collision and vision blocking")
	quit()
