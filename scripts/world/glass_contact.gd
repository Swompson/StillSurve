extends RefCounted

## Sweep actual movement through authored footprints, independently of footstep audio.
const STRIDE: float = 72.0
const FOOT_RADIUS: float = 6.0
const MIN_INTERVAL: float = 0.20
var travel: float = INF
var cooldown: float = 0.0

func update(actor: Node2D, from: Vector2, to: Vector2, game: Node, caused_by_player: bool, delta: float, stride: float = STRIDE) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	var distance: float = from.distance_to(to)
	if distance < 0.0001 or not is_instance_valid(game) or game.get("finished"):
		return
	# Preserve the gait across pauses, patch boundaries and overlapping footprints.
	travel = minf(stride, travel + distance)
	var touched: Array[Node2D] = []
	var ready_patch: bool = false
	var sound_point: Vector2 = to
	for patch in actor.get_tree().get_nodes_in_group("glass_patches"):
		var footprint: Node2D = patch.get_node("Footprint")
		var center: Vector2 = footprint.global_position
		var interval: Vector2 = footprint_interval(footprint, from, to)
		if interval.x < 0.0: continue
		var point: Vector2 = from.lerp(to, (interval.x + interval.y) * 0.5)
		# A footprint beside a wall must not crunch from the adjoining corridor.
		var maze: Node2D = game.get("maze")
		if is_instance_valid(maze) and not maze.call("clear_line", point, center): continue
		touched.append(patch)
		if patch.call("can_crunch"):
			ready_patch = true
			sound_point = point
	if ready_patch and cooldown <= 0.0 and travel >= stride:
		# Overlapping footprints touched by one footfall share its lockout too.
		for patch in touched:
			patch.call("start_cooldown")
		game.call("step_on_glass", sound_point, caused_by_player, actor)
		travel = 0.0
		cooldown = MIN_INTERVAL

static func footprint_interval(footprint: Node2D, from: Vector2, to: Vector2) -> Vector2:
	if footprint.get("disabled"): return Vector2(-1, -1)
	if footprint is CollisionShape2D:
		var radius: float = footprint.shape.radius * absf(footprint.global_scale.x) + FOOT_RADIUS
		return intersection_interval(from, to, footprint.global_position, radius)
	var outline: PackedVector2Array = (footprint as CollisionPolygon2D).polygon
	if outline.size() < 3: return Vector2(-1, -1)
	var polygon: PackedVector2Array = footprint.global_transform * outline
	var winding: float = -1.0 if Geometry2D.is_polygon_clockwise(polygon) else 1.0
	var entry: float = 0.0
	var exit: float = 1.0
	# Clip the swept foot against the convex outline, expanded by the boot radius.
	for index in range(polygon.size()):
		var edge: Vector2 = polygon[(index + 1) % polygon.size()] - polygon[index]
		var origin: float = edge.cross(from - polygon[index]) * winding + FOOT_RADIUS * edge.length()
		var slope: float = edge.cross(to - from) * winding
		if absf(slope) < 0.000001:
			if origin < 0.0: return Vector2(-1, -1)
			continue
		var crossing: float = -origin / slope
		if slope > 0.0: entry = maxf(entry, crossing)
		else: exit = minf(exit, crossing)
		if exit <= entry: return Vector2(-1, -1)
	return Vector2(entry, exit)

static func intersection_interval(from: Vector2, to: Vector2, center: Vector2, radius: float) -> Vector2:
	var motion: Vector2 = to - from
	var offset: Vector2 = from - center
	var length_squared: float = motion.length_squared()
	if length_squared <= 0.00000001: return Vector2(-1, -1)
	var projection: float = offset.dot(motion)
	var discriminant: float = projection * projection - length_squared * (offset.length_squared() - radius * radius)
	if discriminant <= 0.0: return Vector2(-1, -1)
	var root: float = sqrt(discriminant)
	var entry: float = maxf(0.0, (-projection - root) / length_squared)
	var exit: float = minf(1.0, (-projection + root) / length_squared)
	return Vector2(entry, exit) if exit > entry else Vector2(-1, -1)
