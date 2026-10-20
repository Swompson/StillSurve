extends SceneTree

var failures: int = 0

func expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var saved: Node = load("res://scenes/world/corridor_details.tscn").instantiate()
	var count: int = 0
	var variants: Dictionary = {}
	for pile in saved.get_children():
		if not pile.has_method("build_surface"): continue
		count += 1
		if not variants.has(pile.visual_variant): variants[pile.visual_variant] = true
		var surface: Sprite2D = pile.get_node("Surface")
		var collision: CollisionShape2D = pile.get_node("Collision")
		expect(surface.material is ShaderMaterial and bool(surface.material.get_shader_parameter("use_detail_texture")), "Saved stones sample the supplied concrete texture")
		if surface.material is ShaderMaterial:
			expect(surface.material.get_shader_parameter("detail_texture").resource_path == "res://assets/textures/rubble/user_rock_original.png", "Editor materials reference the preserved original image")
			expect(bool(surface.material.get_shader_parameter("editor_preview")), "The supplied surface remains visible before running the game")
		expect(collision != null and collision.shape is ConvexPolygonShape2D, "Every saved stone has a real polygon collider before the game starts")
		expect(surface.z_index == 101 and not surface.z_as_relative and (surface.scale * surface.texture.get_size()).is_equal_approx(Vector2(88, 56)), "Stone tops use the same rendering arrangement as crates without enlarging their footprint")
		expect(pile.is_in_group("warehouse_props") and pile.collision_layer == 2, "Saved stones block movement and share crate lighting")
		if variants[pile.visual_variant] is Image: continue
		var image: Image = surface.texture.get_image()
		variants[pile.visual_variant] = image
		var outline: PackedVector2Array = collision.shape.points
		var outside: int = 0
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				if image.get_pixel(x, y).a < 0.5: continue
				var local: Vector2 = (Vector2(x + 0.5, y + 0.5) - Vector2(image.get_size()) * 0.5) * surface.scale
				if Geometry2D.is_point_in_polygon(local, outline): continue
				var distance: float = INF
				for edge in range(outline.size()):
					distance = minf(distance, local.distance_to(Geometry2D.get_closest_point_to_segment(local, outline[edge], outline[(edge + 1) % outline.size()])))
				if distance > 1.0: outside += 1
		expect(outside == 0, "No painted fragments extend outside the physical stone silhouette")
	expect(count == 28 and variants.size() == 4, "All existing stone placements and four visual variants remain saved")
	saved.free()
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(8): await physics_frame
	var game: Node = current_scene
	for actor in game.monsters: actor.set_physics_process(false)
	var player: CharacterBody2D = game.player
	player.set_physics_process(false)
	player.set_process(false)
	player.get_node("Sprite").set_process(false)
	var pile: Node2D = game.get_node("Maze/CorridorDetails/Rubble00")
	var neighbor: Node2D = game.get_node("Maze/CorridorDetails/Rubble01")
	pile.set_process(false)
	pile.global_position = Vector2(10000, 10000)
	neighbor.global_position = pile.global_position + Vector2(140, 20)
	player.global_position = pile.global_position - Vector2(250, 0)
	player.facing_angle = 0.0
	player.flashlight_reveal = 1.0
	player.flashlight_strength = 1.0
	for frame in range(2): await physics_frame
	pile.call("_process", 0.0)
	expect(pile.get_node("Surface").visible and pile.top_target.a > 0.9, "The flashlight reveals a distant stone top")
	expect(pile.top_material.shader == load("res://shaders/warehouse_top.gdshader"), "Stones and crates use the same lighting shader")
	expect(bool(pile.top_material.get_shader_parameter("use_detail_texture")) and not bool(pile.top_material.get_shader_parameter("editor_preview")), "Runtime preserves the supplied texture while enabling full dynamic lighting")
	expect(pile.top_material.get_shader_parameter("polygon_edge_count") >= 8, "Neighboring stone edges participate in per-pixel occlusion")
	var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(player.global_position, pile.global_position + Vector2(120, 0), 2)
	var hit: Dictionary = player.get_world_2d().direct_space_state.intersect_ray(ray)
	expect(not hit.is_empty() and hit.collider == pile, "The actual stone blocks light and movement rays")
	player.facing_angle = PI
	pile.call("_process", 0.0)
	expect(not pile.get_node("Surface").visible, "Turning the beam away hides the stone beyond ambient range")
	print("RESULT saved solid stones, silhouettes, crate lighting and physical occlusion: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
