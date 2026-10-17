extends SceneTree

func _initialize() -> void:
	var world: Node2D = Node2D.new()
	var pickups: Node2D = Node2D.new()
	pickups.name = "Pickups"
	world.add_child(pickups)
	var hero: CharacterBody2D = CharacterBody2D.new()
	var hunter: Node = load("res://scripts/actors/stalker_controller.gd").new()
	hunter.maze = world
	hunter.player = hero
	for distance in [10.0, 30.0, 20.0]:
		var pickup: Node2D = load("res://scripts/world/pickup.gd").new()
		pickup.position = Vector2(distance, 0)
		pickups.add_child(pickup)
	assert(hunter.choose_ambush_objective() == pickups.get_child(2))
	pickups.get_child(0).collected = true
	assert(hunter.choose_ambush_objective() == pickups.get_child(1))
	hero.position = Vector2(35, 0)
	assert(hunter.choose_ambush_objective() == pickups.get_child(2))
	pickups.get_child(2).collected = true
	assert(hunter.choose_ambush_objective() == pickups.get_child(1))
	pickups.get_child(1).collected = true
	assert(hunter.choose_ambush_objective() == null)
	hunter.free()
	hero.free()
	world.free()
	print("RESULT second-nearest ambush target, moving player, collected pickups and final-item fallback: passed")
	quit()
