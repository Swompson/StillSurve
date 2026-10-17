extends SceneTree

func own_children(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		own_children(child, owner_node)

func _initialize() -> void:
	var hud: CanvasLayer = load("res://scripts/ui/game_hud.gd").new()
	hud.name = "HUD"
	hud.layer = 10
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.build_layout()
	own_children(hud, hud)
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(hud) == OK)
	DirAccess.make_dir_recursive_absolute("res://scenes/ui")
	assert(ResourceSaver.save(packed, "res://scenes/ui/game_hud.tscn") == OK)
	hud.free()
	print("Saved native HUD and menus")
	quit()
