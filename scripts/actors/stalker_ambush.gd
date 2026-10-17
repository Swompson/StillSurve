extends RefCounted

static func find_corner(hunter: Node2D, objective: Node2D) -> Dictionary:
	var hero: CharacterBody2D = hunter.player
	var route: PackedVector2Array = hunter.maze.find_path(hero.global_position, objective.global_position)
	if route.size() < 3: return {}
	var best: float = INF
	var result: Dictionary = {}
	var progress: float = hero.global_position.distance_to(route[0])
	for index in range(1, route.size() - 1):
		var corner: Vector2 = route[index]
		progress += corner.distance_to(route[index - 1])
		var incoming: Vector2 = route[index - 1].direction_to(corner)
		var outgoing: Vector2 = corner.direction_to(route[index + 1])
		if incoming.dot(outgoing) > 0.5: continue
		if corner.distance_to(objective.global_position) < 220.0 or corner.distance_to(hero.global_position) < 220.0: continue
		var approach: Vector2 = route[index - 1]
		var trigger: Vector2 = corner + outgoing * 224.0
		for id in hunter.navigation.get_point_ids():
			var point: Vector2 = hunter.navigation.get_point_position(id)
			if point.distance_squared_to(trigger) > 150.0 * 150.0: continue
			if point.distance_to(objective.global_position) < 220.0 or point.distance_to(hero.global_position) < 220.0: continue
			var offset: Vector2 = point - corner
			if offset.dot(outgoing) < 30.0 or absf(offset.dot(outgoing.orthogonal())) < 50.0: continue
			if hunter.navigation.lamp_exposure(point) > 0.08: continue
			if hunter.maze.clear_line(approach, point) or hunter.maze.clear_line(hero.global_position, point): continue
			if not hunter.maze.can_walk_line(point, trigger) or not hunter.dark_segment(point, trigger): continue
			var score: float = progress + hunter.global_position.distance_to(point) * 0.3
			if score >= best: continue
			var travel: PackedVector2Array = hunter.navigation.route(hunter.global_position, point)
			if travel.is_empty(): continue
			var length: float = hunter.global_position.distance_to(travel[0])
			for step in range(1, travel.size()): length += travel[step - 1].distance_to(travel[step])
			# Prefer corners the hunter can reach before the player rounds the turn.
			score += maxf(0.0, length / 700.0 + 0.4 - progress / maxf(180.0, hero.velocity.length())) * 350.0
			if score < best:
				best = score
				result = {"wait": point, "trigger": trigger, "approach": approach}
	return result
