extends RefCounted

var phase: String = "shadow"
var watched: bool = false
var unseen_time: float = 0.0
var rush_remaining: float = 0.0
var burst_rest: float = 0.0
var reposition_remaining: float = 0.0
var previous_facing: float = 0.0
var initialized: bool = false

func reset() -> void:
	phase = "shadow"
	watched = false
	unseen_time = 0.0
	rush_remaining = 0.0
	burst_rest = 0.0
	reposition_remaining = 0.0
	initialized = false

func update(hunter: Node2D, delta: float) -> void:
	var hero: CharacterBody2D = hunter.player
	var facing: float = hero.facing_angle
	var turn_rate: float = absf(angle_difference(previous_facing, facing)) / maxf(delta, 0.001) if initialized else 0.0
	previous_facing = facing
	initialized = true
	var offset: Vector2 = hunter.global_position - hero.global_position
	var looking: bool = offset.normalized().dot(Vector2.from_angle(facing)) > 0.15
	var seen: bool = looking and hero.is_point_visible(hunter.global_position)
	burst_rest = maxf(0.0, burst_rest - delta)
	reposition_remaining = maxf(0.0, reposition_remaining - delta)
	if seen:
		if not watched:
			hunter.flank_side *= -1.0
			reposition_remaining = 1.1
			hunter.path_timer = 0.0
		watched = true
		unseen_time = 0.0
		rush_remaining = 0.0
		burst_rest = 0.8
		phase = "flank"
		return
	watched = false
	unseen_time += delta
	if rush_remaining > 0.0:
		rush_remaining = maxf(0.0, rush_remaining - delta)
		phase = "rush"
		if rush_remaining <= 0.0: burst_rest = 0.9
		return
	if reposition_remaining > 0.0:
		phase = "flank"
	elif offset.length() > 330.0:
		phase = "shadow"
	else:
		phase = "close"
		var distracted: bool = hero.sprinting or turn_rate > 1.3 or hero.stamina / maxf(hero.stamina_max, 1.0) < 0.3
		var rear: bool = offset.normalized().dot(Vector2.from_angle(facing)) < 0.15
		if rear and burst_rest <= 0.0 and unseen_time > 0.25 and (distracted or unseen_time > 0.9) and hunter.maze.can_walk_line(hunter.global_position, hero.global_position) and hunter.dark_segment(hunter.global_position, hero.global_position):
			phase = "rush"
			rush_remaining = 0.65
			hunter.path_timer = 0.0

func pace() -> float:
	if watched: return 90.0
	match phase:
		"shadow": return 300.0
		"flank": return 240.0
		"rush": return 360.0
	return 140.0

func can_attack(hunter: Node2D) -> bool:
	var offset: Vector2 = hunter.global_position - hunter.player.global_position
	return not watched and offset.normalized().dot(Vector2.from_angle(float(hunter.player.facing_angle))) < 0.35

func target(hunter: Node2D) -> Vector2:
	var hero: CharacterBody2D = hunter.player
	var facing: Vector2 = Vector2.from_angle(float(hero.facing_angle))
	var lead: Vector2 = (hero.velocity * 0.2).limit_length(65.0)
	var behind: Vector2 = hero.global_position + lead - facing * 55.0 + facing.orthogonal() * hunter.flank_side * 35.0
	if phase == "shadow": behind = hero.global_position + lead - facing * 230.0 + facing.orthogonal() * hunter.flank_side * 90.0
	if phase != "flank" and hunter.maze.can_walk_line(hero.global_position, behind): return behind
	if phase != "flank":
		# A wall directly behind the player must not make stalking stall forever.
		for side in [hunter.flank_side, -hunter.flank_side]:
			var lateral: Vector2 = hero.global_position - facing * 20.0 + facing.orthogonal() * side * 110.0
			if hunter.maze.can_walk_line(hero.global_position, lateral) and hunter.dark_segment(hero.global_position, lateral): return lateral
	# Once spotted, change side and seek an actual occluded corner.
	var best: float = INF
	var chosen: Vector2 = behind
	for index in range(16):
		var angle: float = float(hero.facing_angle) + PI + hunter.flank_side * (0.35 + index * 0.15)
		var sample: Vector2 = hero.global_position + Vector2.from_angle(angle) * (150.0 if index % 2 == 0 else 300.0)
		var point: Vector2 = hunter.navigation.get_point_position(hunter.navigation.get_closest_point(sample))
		if hunter.navigation.lamp_exposure(point) > 0.08 or point.distance_to(hero.global_position) < 85.0: continue
		var hidden: bool = not hunter.maze.clear_line(hero.global_position, point)
		var score: float = point.distance_to(behind) * 0.65 + point.distance_to(hunter.global_position) * 0.4 - (450.0 if hidden else 0.0)
		if (point - hero.global_position).normalized().dot(facing) > 0.15: score += 600.0
		if score < best and not hunter.navigation.route(hunter.global_position, point).is_empty():
			best = score
			chosen = point
	return chosen
