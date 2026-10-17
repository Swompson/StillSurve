@tool
extends CharacterBody2D

@export var sight_radius: float = 760.0
@export var hearing_multiplier: float = 1.0
@export var field_of_view: float = 105.0
@export var run_speed: float = 340.0
@export var hunt_speed: float = 230.0
@export var attack_radius: float = 60.0
@export var escape_distance: float = 892.5
@export var stamina_regen: float = 20.0 / 1.1 / 0.9 * 0.8
@export var detection_delay: float = 0.5
var detection_remaining: float = 0.0
var escape_timer: float = 0.0
var disengage_timer: float = 0.0
var game: Node
var maze: Node2D
var player: CharacterBody2D
var active: bool = true
var state: String = "patrol"
var target: Vector2 = Vector2.ZERO
var last_heard: Vector2 = Vector2.ZERO
var last_known: Vector2 = Vector2.ZERO
var memory: float = 0.0
var stamina: float = 100.0
var sprinting: bool = false
var recovering: bool = false
var facing_angle: float = PI * 0.5
var sense_timer: float = 0.0
var path_timer: float = 0.0
var path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0
var gait: float = 0.0
var glass_step_distance: float = 0.0
var path_goal: int = -1
var search_timer: float = 0.0
var stuck_timer: float = 0.0
var path_rebuilds: int = 0
var previous_patrol_cell: int = -1
var recent_patrol_cells: Array[int] = []
var saved_patrol_target: Vector2
var has_saved_patrol: bool = false
var investigation_route: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	set_physics_process(not Engine.is_editor_hint())

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not active or not is_instance_valid(player):
		return
	if state == "alert":
		detection_remaining = maxf(0.0, detection_remaining - delta)
		velocity = Vector2.ZERO
		sprinting = false
		facing_angle = rotate_toward(facing_angle, (last_known - global_position).angle(), delta * 12.0)
		if detection_remaining > 0.0:
			return
		state = "hunt"
		sense_timer = 0.0
	sense_timer -= delta
	path_timer -= delta
	memory = maxf(0.0, memory - delta)
	disengage_timer = maxf(0.0, disengage_timer - delta)
	var player_distance: float = global_position.distance_to(player.global_position)
	escape_timer = escape_timer + delta if state == "hunt" and player_distance > escape_distance else 0.0
	if state == "hunt" and (escape_timer >= 2.0 or memory <= 0.0):
		begin_investigation(last_known)
		disengage_timer = 4.0
		escape_timer = 0.0
	if sense_timer <= 0.0:
		perceive()
		sense_timer = 0.18
	if state == "alert":
		velocity = Vector2.ZERO
		sprinting = false
		return
	if state == "hunt":
		target = last_known
	elif state == "patrol" and global_position.distance_to(target) < 28.0:
		choose_patrol_target()
	var searching: bool = state == "investigate" and global_position.distance_to(target) < 28.0
	if searching:
		search_timer += delta
		if search_timer >= 0.9:
			choose_patrol_target()
			searching = false
	var goal: int = int(maze.call("cell_at", target))
	if goal != path_goal or path.is_empty() or (path_timer <= 0.0 and stuck_timer > 0.8):
		rebuild_path(goal)
	var destination: Vector2 = global_position if searching else navigation_destination()
	var direction: Vector2 = global_position.direction_to(destination)
	sprinting = state == "hunt" and not recovering and stamina > 0.0 and player_distance > attack_radius
	if sprinting:
		stamina = maxf(0.0, stamina - 34.0 * delta)
		if stamina <= 0.0:
			recovering = true
	else:
		stamina = minf(100.0, stamina + stamina_regen * delta)
		if stamina >= 80.0:
			recovering = false
	var speed: float = run_speed if sprinting else (hunt_speed if state == "hunt" else 115.0)
	# Brake before a waypoint instead of overshooting it and reversing direction.
	var desired_speed: float = minf(speed, global_position.distance_to(destination) * 7.0)
	var desired_velocity: Vector2 = direction * desired_speed
	velocity = velocity.lerp(desired_velocity, 1.0 - exp(-12.0 * delta))
	var before: Vector2 = global_position
	move_and_slide()
	update_glass_steps(global_position.distance_to(before))
	if desired_speed > 20.0 and global_position.distance_to(before) < desired_speed * delta * 0.12:
		stuck_timer += delta
	else:
		stuck_timer = maxf(0.0, stuck_timer - delta * 2.0)
	if stuck_timer > 2.5 and state != "hunt":
		choose_patrol_target()
		stuck_timer = 0.0
	if not velocity.is_zero_approx():
		facing_angle = lerp_angle(facing_angle, velocity.angle(), 1.0 - exp(-10.0 * delta))
	gait += delta * (18.0 if sprinting else 8.0)
	if state == "hunt" and global_position.distance_to(player.global_position) < attack_radius and maze.call("clear_line", global_position, player.global_position):
		game.call("kill_player")

func begin_investigation(point: Vector2) -> void:
	remember_patrol()
	investigation_route.clear()
	state = "investigate"
	# Approach the sound itself; back off toward its cell only if body clearance fails.
	var center: Vector2 = maze.call("cell_position", maze.call("cell_at", point))
	target = center
	for step in range(13):
		var candidate: Vector2 = point.lerp(center, float(step) / 12.0)
		if maze.call("can_walk_line", center, candidate):
			target = candidate
			break
	search_timer = 0.0
	path_goal = -1
	path_timer = 0.0

func choose_patrol_target() -> void:
	state = "patrol"
	investigation_route.clear()
	if has_saved_patrol:
		target = saved_patrol_target
		has_saved_patrol = false
		search_timer = 0.0
		path_goal = -1
		return
	var current_cell: int = int(maze.call("cell_at", global_position))
	var candidate: int = local_patrol_cell(current_cell)
	previous_patrol_cell = current_cell
	recent_patrol_cells.append(current_cell)
	if recent_patrol_cells.size() > 6:
		recent_patrol_cells.pop_front()
	target = maze.call("cell_position", candidate)
	search_timer = 0.0
	path_goal = -1

func local_patrol_cell(current_cell: int) -> int:
	var graph: AStar2D = maze.get("graph")
	# One bounded breadth-first search replaces random cross-map destinations.
	var cells: Array[int] = [current_cell]
	var distances: Dictionary = {current_cell: 0}
	var cursor: int = 0
	while cursor < cells.size():
		var cell: int = cells[cursor]
		cursor += 1
		if int(distances[cell]) >= 4:
			continue
		for neighbor in graph.get_point_connections(cell):
			if not distances.has(neighbor):
				distances[neighbor] = int(distances[cell]) + 1
				cells.append(neighbor)
	var interest: Dictionary = {}
	var pickups: Node = maze.get_node_or_null("Pickups")
	if pickups:
		for pickup in pickups.get_children():
			if pickup.get("kind") != "figurine" or pickup.get("collected"):
				continue
			var doll_cell: int = int(maze.call("cell_at", pickup.global_position))
			if not graph.has_point(doll_cell):
				continue
			interest[doll_cell] = true
			for neighbor in graph.get_point_connections(doll_cell):
				interest[neighbor] = true
	var candidate: int = current_cell
	var best_score: float = -INF
	for cell in cells:
		if cell == current_cell:
			continue
		var depth: int = int(distances[cell])
		var score: float = (2.0 if interest.has(cell) else 0.0) - float(depth) * 0.35 + randf() * 0.3
		if depth == 1:
			score -= 2.0
		if cell == previous_patrol_cell or recent_patrol_cells.has(cell):
			score -= 3.0
		if is_instance_valid(game):
			for hunter in game.get("monsters"):
				if hunter != self and hunter.has_method("local_patrol_cell") and int(maze.call("cell_at", hunter.get("target"))) == cell:
					score -= 2.5
		if score > best_score:
			best_score = score
			candidate = cell
	return candidate

func rebuild_path(goal: int) -> void:
	path = investigation_route if state == "investigate" and not investigation_route.is_empty() else maze.call("find_path", global_position, target)
	path_goal = goal
	path_index = 0
	path_timer = 0.65
	path_rebuilds += 1
	if not investigation_route.is_empty() and state == "investigate":
		return
	# Start at the furthest reachable waypoint, never at a center already behind us.
	for index in range(path.size() - 1, -1, -1):
		if maze.call("can_walk_line", global_position, path[index]):
			path_index = index
			break

func navigation_destination() -> Vector2:
	if state == "investigate" and not investigation_route.is_empty():
		while path_index < path.size() and global_position.distance_to(path[path_index]) < 18.0:
			path_index += 1
		return path[path_index] if path_index < path.size() else target
	if maze.call("can_walk_line", global_position, target):
		return target
	while path_index < path.size() - 1:
		if global_position.distance_to(path[path_index]) < 18.0 or maze.call("can_walk_line", global_position, path[path_index + 1]):
			path_index += 1
		else:
			break
	if path_index < path.size():
		return path[path_index]
	return global_position

func perceive() -> void:
	if disengage_timer > 0.0:
		return
	var offset: Vector2 = player.global_position - global_position
	var radius: float = sight_radius
	var in_front: bool = state in ["alert", "hunt"] or absf(angle_difference(facing_angle, offset.angle())) < deg_to_rad(field_of_view) * 0.5 or offset.length() < 180.0
	if offset.length() <= radius and in_front and maze.call("clear_line", global_position, player.global_position):
		if state not in ["alert", "hunt"]:
			remember_patrol()
			investigation_route.clear()
			state = "alert"
			detection_remaining = detection_delay
			velocity = Vector2.ZERO
			sprinting = false
			if is_instance_valid(game):
				game.call("notify_player_spotted", self)
		last_known = player.global_position
		memory = 3.0

func hear_noise(point: Vector2, radius: float) -> void:
	if not active or not is_instance_valid(maze) or disengage_timer > 0.0 or state == "alert":
		return
	var reach: float = radius * hearing_multiplier
	if not maze.call("clear_line", global_position, point):
		reach *= 0.45
	if global_position.distance_to(point) > reach:
		return
	last_heard = point
	# Hearing stores a fixed source, never the player's live position through a wall.
	if state in ["alert", "hunt"] and maze.call("clear_line", global_position, player.global_position):
		return
	# Repeated crunches in the same cell must not restart or erase the flank.
	if state == "investigate" and not investigation_route.is_empty() and int(maze.call("cell_at", point)) == int(maze.call("cell_at", target)):
		return
	var old_goal: int = path_goal if investigation_route.is_empty() else -1
	begin_investigation(point)
	if old_goal == int(maze.call("cell_at", target)):
		path_goal = old_goal

func remember_patrol() -> void:
	if state == "patrol" and not has_saved_patrol:
		saved_patrol_target = target
		has_saved_patrol = true

func assign_investigation_route(route: PackedVector2Array) -> void:
	investigation_route = route
	path_goal = -1
	path_timer = 0.0

func update_glass_steps(distance: float) -> void:
	glass_step_distance += distance
	if glass_step_distance < 58.0 or not is_instance_valid(game):
		return
	glass_step_distance = fmod(glass_step_distance, 58.0)
	for patch in get_tree().get_nodes_in_group("glass_patches"):
		if patch.global_position.distance_squared_to(global_position) < 58.0 * 58.0:
			game.call("step_on_glass", global_position, false, self)
			break
