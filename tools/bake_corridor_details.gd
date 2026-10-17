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
	var previous: Node = maze.get_node_or_null("CorridorDetails")
	if previous:
		maze.remove_child(previous)
		previous.free()
	maze.call("build_corridor_details")
	var details: Node2D = maze.get_node("CorridorDetails")
	claim(details, details)
	var scene: PackedScene = PackedScene.new()
	assert(scene.pack(details) == OK)
	assert(ResourceSaver.save(scene, "res://scenes/world/corridor_details.tscn") == OK)
	print("Saved door jambs and rubble as editable scene nodes")
	quit()
