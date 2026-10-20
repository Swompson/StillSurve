extends SceneTree

func _initialize() -> void:
	var details: Node2D = load("res://scenes/world/corridor_details.tscn").instantiate()
	var count: int = 0
	for pile in details.get_children():
		if not pile.has_method("build_surface"): continue
		var old_collision: Node = pile.get_node("Collision")
		if old_collision is CollisionPolygon2D:
			pile.remove_child(old_collision)
			old_collision.free()
			var collision: CollisionShape2D = CollisionShape2D.new()
			collision.name = "Collision"
			pile.add_child(collision)
			collision.owner = details
		pile.call("build_surface")
		for group in ["rubble", "vision_blockers", "warehouse_props"]:
			pile.add_to_group(group, true)
		count += 1
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(details) == OK)
	assert(ResourceSaver.save(packed, "res://scenes/world/corridor_details.tscn") == OK)
	print("Migrated %d saved concrete props to crate lighting and matching collision shapes" % count)
	details.free()
	quit()
