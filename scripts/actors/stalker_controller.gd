extends CharacterBody2D

const NAVIGATION = preload("res://scripts/actors/stalker_navigation.gd")
const STALKING = preload("res://scripts/actors/stalker_stalking.gd")
const AMBUSH = preload("res://scripts/actors/stalker_ambush.gd")
var stalking: RefCounted = STALKING.new()
var game: Node
var glass_contact: RefCounted = preload("res://scripts/world/glass_contact.gd").new()
var maze: Node2D
var player: CharacterBody2D
var active: bool = false
var state: String = "stalk"
var sprinting: bool = false
var facing_angle: float = PI * 0.5
var navigation: AStar2D
var path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0
var path_timer: float = 0.0
var sense_timer: float = 0.0
var flee_remaining: float = 0.0
var flee_target: Vector2
var leap_elapsed: float = 0.0
var leap_progress: float = 0.0
var grab_offset: Vector2 = Vector2.ZERO
var attack_elapsed: float = 0.0
var check_index: int = 0
var check_answered: bool = false
var check_phase: float = 0.0
var green_center: float = 0.0
var green_half_width: float = 0.10
var results: Array[bool] = []
var feedback: String = ""
var stuck_time: float = 0.0
var observed: bool = false
var approach_target: Vector2
var check_started: float = 0.0
var check_deadline: float = 1.0
var successful_checks: int = 0
var feedback_remaining: float = 0.0
const ATTACK_COOLDOWN: float = 15.0
const LEAP_RANGE: float = 170.0
var attack_cooldown: float = 0.0
var strategy: String = "sneak"
var strategy_pending: bool = false
var flank_side: float = 1.0
var ambush_target: Vector2
var ambush_objective: Node2D
var ambush_ready: bool = false
var ambush_planned: bool = false
var ambush_trigger: Vector2
var ambush_entry: Vector2
var plan_timer: float = 0.0
var retreat_refresh: float = 0.0
var light_contact: float = 0.0
var flashlight_contact: bool = false
var lamp_contact: bool = false

func _ready() -> void:
	set_physics_process(false)
	$Visual/ArticulatedBody.setup(self, true)

func activate(controller: Node, world: Node2D, hero: CharacterBody2D) -> void:
	game = controller
	maze = world
	player = hero
	# Wait for authored wall and rubble transforms to reach the physics server.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_instance_valid(player) or game.get("finished"): return
	navigation = NAVIGATION.new()
	navigation.build(maze)
	choose_strategy()
	active = true
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(player) or not player.get("alive"):
		cancel_grab()
		velocity = Vector2.ZERO
		return
	$Visual.rotation = lerp_angle($Visual.rotation, facing_angle - PI * 0.5, 1.0 - exp(-delta * 12.0))
	$Visual/ArticulatedBody.advance(delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	retreat_refresh = maxf(0.0, retreat_refresh - delta)
	plan_timer -= delta
	if strategy_pending and attack_cooldown <= 0.0:
		choose_strategy()
	# A completed grab owns its full three-second sequence; nearby light cannot
	# detach the actor while the skill check is already active.
	if state == "grab":
		light_contact = 0.0
		update_grab(delta)
		return
	sense_timer -= delta
	if sense_timer <= 0.0:
		sense_timer = 0.08
		observed = player.call("is_point_visible", global_position)
		flashlight_contact = is_flashlight_illuminated()
		lamp_contact = is_lamp_illuminated()
	light_contact = light_contact + delta if flashlight_contact else 0.0
	if lamp_contact or light_contact >= 0.24:
		if state != "flee": begin_flee(4.5, light_contact >= 0.24)
		else:
			flee_remaining = maxf(flee_remaining, 1.5)
			if retreat_refresh <= 0.0 and global_position.distance_to(flee_target) < 80.0:
				choose_flee_target()
	# Cooldown prevents attacks, not defensive movement when the player follows.
	if (state == "flee" or attack_cooldown > 0.0) and retreat_refresh <= 0.0 and global_position.distance_to(flee_target) < 80.0 and global_position.distance_to(player.global_position) < 650.0:
		choose_flee_target()
	if state == "grab":
		update_grab(delta)
		return
	if state == "leap":
		update_leap(delta)
		return
	flee_remaining = maxf(0.0, flee_remaining - delta)
	if state == "flee" and flee_remaining <= 0.0:
		state = "stalk"
		path_timer = 0.0
		stalking.reset()
	if state == "stalk" and strategy == "sneak" and attack_cooldown <= 0.0:
		stalking.update(self, delta)
	path_timer -= delta
	if path_timer <= 0.0 and state != "flee":
		approach_target = choose_approach_target()
	var target: Vector2 = flee_target if state == "flee" else approach_target
	if path_timer <= 0.0:
		if is_ambush_transit():
			path = navigation.concealed_route(global_position, target, player)
			if path.is_empty():
				abandon_ambush()
				return
		else:
			path = navigation.route(global_position, target)
		path_index = 0
		if path.size() > 1 and maze.call("can_walk_line", global_position, path[1]): path_index = 1
		path_timer = 0.22
	var destination: Vector2 = next_destination(target)
	# Recheck between replans: the player can step into the selected detour.
	if is_ambush_transit() and not navigation.concealed_segment(global_position, destination, player):
		abandon_ambush()
		return
	var pace: float = movement_pace()
	sprinting = state == "flee" or (pace >= 300.0 and not observed)
	velocity = global_position.direction_to(destination) * minf(pace, global_position.distance_to(destination) * 8.0)
	var before: Vector2 = global_position
	move_and_slide()
	glass_contact.update(self, before, global_position, game, false, delta)
	var retreat_blocked: bool = (state == "flee" or attack_cooldown > 0.0) and global_position.distance_to(target) > 80.0
	stuck_time = stuck_time + delta if (velocity.length() > 10.0 or retreat_blocked) and global_position.distance_to(before) < 0.2 else 0.0
	if stuck_time > 0.7:
		path_timer = 0.0
		if state == "flee" or attack_cooldown > 0.0: choose_flee_target()
		stuck_time = 0.0
	if velocity.length_squared() > 1.0:
		facing_angle = velocity.angle()
	var offset: Vector2 = global_position - player.global_position
	var flank: bool = offset.normalized().dot(Vector2.from_angle(float(player.get("facing_angle")))) < 0.55
	var in_position: bool = stalking.can_attack(self) if strategy == "sneak" else (ambush_ready and player.global_position.distance_to(ambush_trigger) < 150.0)
	if state == "stalk" and attack_cooldown <= 0.0 and offset.length() < LEAP_RANGE and (flank or offset.length() < 85.0) and in_position and not is_illuminated() and maze.call("can_walk_line", global_position, player.global_position) and dark_segment(global_position, player.global_position):
		state = "leap"
		leap_elapsed = 0.0
		grab_offset = offset.normalized() * 42.0
		facing_angle = (-offset).angle()

func movement_pace() -> float:
	if state == "flee" or attack_cooldown > 0.0: return 430.0
	if strategy == "sneak": return stalking.pace()
	return 170.0 if observed else 700.0

func is_ambush_transit() -> bool:
	return strategy == "ambush" and state == "stalk" and attack_cooldown <= 0.0 and not ambush_ready

func abandon_ambush() -> void:
	strategy = "sneak"
	ambush_planned = false
	ambush_ready = false
	stalking.reset()
	path.clear()
	path_timer = 0.0
	velocity = Vector2.ZERO
	sprinting = false

func choose_strategy() -> void:
	strategy = "sneak" if randf() < 0.5 else "ambush"
	stalking.reset()
	flank_side = -1.0 if randf() < 0.5 else 1.0
	strategy_pending = false
	ambush_objective = null
	ambush_ready = false
	ambush_planned = false
	plan_timer = 0.0
	path_timer = 0.0

func choose_ambush_objective() -> Node2D:
	var nearest: Node2D
	var second: Node2D
	var nearest_distance: float = INF
	var second_distance: float = INF
	for pickup in maze.get_node("Pickups").get_children():
		if pickup.get("collected"): continue
		var distance: float = player.global_position.distance_squared_to(pickup.global_position)
		if distance < nearest_distance:
			second = nearest
			second_distance = nearest_distance
			nearest = pickup
			nearest_distance = distance
		elif distance < second_distance:
			second = pickup
			second_distance = distance
	return second if is_instance_valid(second) else nearest

func plan_ambush() -> void:
	plan_timer = 2.0
	ambush_objective = choose_ambush_objective()
	if not is_instance_valid(ambush_objective):
		strategy = "sneak"
		return
	var plan: Dictionary = AMBUSH.find_corner(self, ambush_objective)
	if plan.is_empty():
		strategy = "sneak"
		stalking.reset()
		ambush_planned = false
	else:
		ambush_target = plan.wait
		ambush_trigger = plan.trigger
		ambush_entry = plan.approach
		ambush_ready = false
		ambush_planned = true

func choose_approach_target() -> Vector2:
	if attack_cooldown > 0.0: return flee_target
	if strategy == "ambush":
		var invalid: bool = not is_instance_valid(ambush_objective) or ambush_objective.get("collected")
		if ambush_planned and (invalid or (ambush_ready and global_position.distance_to(player.global_position) > 1800.0)):
			ambush_planned = false
			ambush_ready = false
		# Keep the chosen corner while travelling and waiting; do not chase the item.
		if not ambush_planned: plan_ambush()
		if strategy == "ambush":
			ambush_ready = global_position.distance_to(ambush_target) < 35.0
			return ambush_target
	return stalking.target(self)

func next_destination(target: Vector2) -> Vector2:
	# Only shortcut when the whole segment is dark; preserve the weighted lamp detour.
	if maze.call("can_walk_line", global_position, target) and dark_segment(global_position, target) and (not is_ambush_transit() or navigation.concealed_segment(global_position, target, player)):
		return target
	while path_index < path.size() and global_position.distance_to(path[path_index]) < 6.0:
		path_index += 1
	return path[path_index] if path_index < path.size() else global_position

func dark_segment(from: Vector2, to: Vector2) -> bool:
	var steps: int = maxi(1, ceili(from.distance_to(to) / 64.0))
	for index in range(steps + 1):
		if navigation.lamp_exposure(from.lerp(to, float(index) / steps)) > 0.08:
			return false
	return true

func is_illuminated() -> bool:
	return is_lamp_illuminated() or is_flashlight_illuminated()

func is_lamp_illuminated() -> bool:
	for fixture in navigation.fixtures:
		if float(fixture.get("light_power")) > 0.25 and global_position.distance_to(fixture.global_position) < float(fixture.get("light_radius")) * 0.88 and maze.call("clear_line", global_position, fixture.global_position):
			return true
	return false

func is_flashlight_illuminated() -> bool:
	if not player.get("flashlight_on") or float(player.get("flashlight_strength")) < 0.2:
		return false
	var origin: Vector2 = player.call("get_view_origin")
	var offset: Vector2 = global_position - origin
	if global_position.distance_to(player.global_position) < 100.0:
		origin = player.global_position
		offset = global_position - origin
	return offset.length() < float(player.call("get_view_distance")) * 0.85 and absf(angle_difference(float(player.call("get_view_angle")), offset.angle())) < deg_to_rad(float(player.get("field_of_view"))) * 0.42 and maze.call("clear_line", origin, global_position)

func begin_flee(duration: float = 6.0, from_light: bool = false) -> void:
	if from_light and state != "flee": $Laugh.play_laugh()
	if state == "grab" or state == "leap":
		attack_cooldown = ATTACK_COOLDOWN
		strategy_pending = true
	cancel_grab()
	state = "flee"
	flee_remaining = duration
	leap_progress = 0.0
	choose_flee_target()
	path_timer = 0.0

func choose_flee_target() -> void:
	retreat_refresh = 0.5
	path_timer = 0.0
	var best: float = -INF
	var start: int = navigation.get_closest_point(global_position)
	for cell in range(int(maze.get("width")) * int(maze.get("height"))):
		var point: Vector2 = maze.call("cell_position", cell)
		var distance: float = global_position.distance_to(point)
		if distance < 420.0 or distance > 1250.0 or navigation.lamp_exposure(point) > 0.1:
			continue
		var id: int = navigation.get_closest_point(point)
		if not navigation.has_route(start, id): continue
		var score: float = point.distance_to(player.global_position) - distance * 0.32
		if score > best:
			best = score
			flee_target = point
	if best == -INF:
		# Cell centers may be lit; fall back to reachable lateral samples.
		for id in navigation.get_point_ids():
			var point: Vector2 = navigation.get_point_position(id)
			if global_position.distance_to(point) < 100.0 or not navigation.has_route(start, id): continue
			var score: float = point.distance_to(player.global_position) - navigation.lamp_exposure(point) * 1500.0
			if score > best:
				best = score
				flee_target = point

func update_leap(delta: float) -> void:
	leap_elapsed += delta
	leap_progress = clampf(leap_elapsed / 0.3, 0.0, 1.0)
	velocity = global_position.direction_to(player.global_position + grab_offset) * 650.0
	var before: Vector2 = global_position
	move_and_slide()
	glass_contact.update(self, before, global_position, game, false, delta)
	if global_position.distance_to(player.global_position) < 68.0 and maze.call("clear_line", global_position, player.global_position):
		begin_grab()
	elif leap_elapsed >= 0.35:
		begin_flee(3.0)

func begin_grab() -> void:
	if player.get("grabbed"):
		begin_flee()
		return
	state = "grab"
	light_contact = 0.0
	velocity = Vector2.ZERO
	sprinting = false
	attack_elapsed = 0.0
	check_index = 0
	successful_checks = 0
	green_half_width = 0.10
	feedback_remaining = 0.0
	results.clear()
	feedback = ""
	player.call("set_grabbed", true)
	$Screamer.play()
	begin_check()

func begin_check() -> void:
	check_answered = false
	check_started = attack_elapsed
	check_deadline = attack_elapsed + (3.0 - attack_elapsed) / float(3 - results.size())
	check_phase = randf_range(0.0, 1.0)
	green_center = fposmod(check_phase + randf_range(0.3, 0.65), 1.0)

func needle_phase() -> float:
	return fposmod(check_phase + attack_elapsed - check_started, 1.0)

func submit_check(displayed_phase: float = -1.0) -> void:
	if state != "grab" or check_answered or get_tree().paused:
		return
	var phase: float = needle_phase() if displayed_phase < 0.0 else displayed_phase
	var error: float = absf(wrapf(phase - green_center, -0.5, 0.5))
	resolve_check(error <= green_half_width)

func resolve_check(success: bool) -> void:
	if check_answered: return
	check_answered = true
	results.append(success)
	var drain: float = 4.0 if success else 10.0
	var empty: bool = float(player.get("battery")) <= 0.0
	if empty:
		var capacity: float = maxf(1.0, float(player.get("stamina_max")) - drain)
		drain = float(player.get("stamina_max")) - capacity
		player.set("stamina_max", capacity)
		player.set("stamina", minf(float(player.get("stamina")), capacity))
	else:
		player.call("drain_flashlight", drain)
	feedback = ("ВОВРЕМЯ" if success else "ПРОМАХ") + " · −%d %s" % [int(drain), "МАКС. ВЫНОСЛИВОСТИ" if empty else "ЗАРЯДА"]
	if is_instance_valid(game):
		game.get_node("HUD").call("notify_pickup", feedback, 2.0, Color("f17a70"))
	feedback_remaining = 0.55
	if success:
		successful_checks += 1
		green_half_width = maxf(0.05, 0.10 - mini(successful_checks, 2) * 0.025)
	check_index = mini(results.size(), 2)
	if results.size() < 3:
		begin_check()
	else:
		begin_flee(randf_range(6.0, 8.0))

func update_grab(delta: float) -> void:
	feedback_remaining = maxf(0.0, feedback_remaining - delta)
	var remaining: float = delta
	# Advance immediately after input; unanswered rounds share the remaining time.
	while remaining > 0.0 and state == "grab":
		var deadline: float = check_deadline if results.size() < 3 else 3.0
		var step: float = minf(remaining, maxf(0.0, deadline - attack_elapsed))
		attack_elapsed += step
		remaining -= step
		if attack_elapsed >= 3.0 - 0.00001:
			if results.size() < 3: resolve_check(false)
			if state == "grab": begin_flee(randf_range(6.0, 8.0))
		elif attack_elapsed >= deadline - 0.00001:
			resolve_check(false)
	if state == "grab":
		var attachment: Vector2 = player.global_position + grab_offset
		velocity = (attachment - global_position) / maxf(delta, 0.001)
		move_and_slide()
		facing_angle = global_position.direction_to(player.global_position).angle()

func cancel_grab() -> void:
	if state == "grab" and is_instance_valid(player):
		player.call("set_grabbed", false)

func hear_noise(_point: Vector2, _radius: float) -> void:
	# This silent hunter always knows the player position; noise cannot distract it.
	pass

func _exit_tree() -> void:
	cancel_grab()
