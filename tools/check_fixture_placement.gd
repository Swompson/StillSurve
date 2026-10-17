extends SceneTree
func _initialize() -> void: call_deferred("check")
func check() -> void:
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(5): await process_frame
	var game: Node = current_scene
	var maze: Node2D = game.get_node("Maze")
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 61.0
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.collision_mask = 2
	for fixture in game.get_node("Maze/Overhead/Fixtures").get_children():
		var centers: Dictionary = {"CeilingLamp1": Vector2(-1600,-1600), "CeilingLamp2": Vector2(1600,-1600), "CeilingLamp3": Vector2(1600,1600), "WallLamp": Vector2(-1600,1600), "CeilingLamp5": Vector2.ZERO}
		var center: Vector2 = centers[String(fixture.name)]
		for offset in [Vector2(-70,70),Vector2(70,70),Vector2(-70,-70),Vector2(70,-70),Vector2.ZERO]:
			var candidate: Vector2 = center + offset
			query.transform = Transform2D(0, maze.to_global(candidate))
			if game.get_node("Player").get_world_2d().direct_space_state.intersect_shape(query).is_empty():
				print(fixture.name, " safe position: ", candidate)
				break
	quit()
