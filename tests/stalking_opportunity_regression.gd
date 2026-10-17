extends SceneTree

class Hero extends CharacterBody2D:
	var facing_angle: float = 0.0
	var sprinting: bool = false
	var stamina: float = 100.0
	var stamina_max: float = 100.0
	var point_visible: bool = false
	func is_point_visible(_point: Vector2) -> bool: return point_visible

class World extends Node2D:
	var open: bool = true
	func can_walk_line(_from: Vector2, _to: Vector2) -> bool: return open

class Hunter extends Node2D:
	var player: CharacterBody2D
	var maze: Node2D
	var flank_side: float = 1.0
	var path_timer: float = 1.0
	var dark: bool = true
	func dark_segment(_from: Vector2, _to: Vector2) -> bool: return dark

func _initialize() -> void:
	var hero: Hero = Hero.new()
	var world: World = World.new()
	var hunter: Hunter = Hunter.new()
	hunter.player = hero
	hunter.maze = world
	hunter.position = Vector2(-270, 0)
	var stalking: RefCounted = load("res://scripts/actors/stalker_stalking.gd").new()
	stalking.update(hunter, 0.3)
	assert(stalking.phase == "close" and stalking.pace() == 140.0)
	hero.sprinting = true
	stalking.update(hunter, 0.02)
	assert(stalking.phase == "rush" and stalking.pace() == 360.0)
	stalking.update(hunter, 0.66)
	stalking.update(hunter, 0.02)
	assert(stalking.phase == "close" and stalking.burst_rest > 0.8)
	hero.facing_angle = PI
	hero.point_visible = true
	stalking.update(hunter, 0.02)
	assert(stalking.phase == "flank" and stalking.watched and not stalking.can_attack(hunter))
	assert(hunter.flank_side == -1.0 and stalking.pace() == 90.0)
	stalking.update(hunter, 0.02)
	assert(hunter.flank_side == -1.0)
	hero.facing_angle = 0.0
	hero.point_visible = false
	hero.sprinting = false
	hero.stamina = 20.0
	stalking.reset()
	stalking.update(hunter, 0.3)
	assert(stalking.phase == "rush")
	world.open = false
	stalking.reset()
	stalking.update(hunter, 1.0)
	assert(stalking.phase != "rush")
	world.open = true
	hunter.dark = false
	stalking.update(hunter, 1.0)
	assert(stalking.phase != "rush")
	hunter.dark = true
	hero.stamina = 100.0
	stalking.reset()
	stalking.update(hunter, 0.26)
	hero.facing_angle = 0.4
	stalking.update(hunter, 0.05)
	assert(stalking.phase == "rush", "Looking away quickly creates an opening")
	hero.facing_angle = 0.0
	hero.position = Vector2.ZERO
	hero.velocity = Vector2(180, 0)
	hunter.position = Vector2(-270, 0)
	stalking.reset()
	var caught: bool = false
	for tick in range(300):
		hero.position += hero.velocity / 60.0
		stalking.update(hunter, 1.0 / 60.0)
		hunter.position += hunter.position.direction_to(stalking.target(hunter)) * stalking.pace() / 60.0
		if hunter.position.distance_to(hero.position) < 170.0 and stalking.can_attack(hunter):
			caught = true
			break
	assert(caught, "Short blind-side bursts can catch a walking player instead of trailing forever")
	stalking.reset()
	hunter.position = hero.position - Vector2(600, 0)
	stalking.update(hunter, 0.02)
	assert(stalking.phase == "shadow" and stalking.pace() == 300.0)
	hunter.free()
	hero.free()
	world.free()
	print("RESULT blind-side bursts, observation cancellation, exhaustion, cover safety and catching a walking player: passed")
	quit()
