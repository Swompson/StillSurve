@tool
extends CharacterBody2D

@export var sight_radius: float = 900.0
@export var field_of_view: float = 105.0
@export var run_speed: float = 340.0
@export var attack_radius: float = 60.0
@export var escape_distance: float = 892.5
@export var stamina_regen: float = 20.0 / 1.1
var escape_timer: float = 0.0
var disengage_timer: float = 0.0
var game: Node
var maze: Node2D
var player: CharacterBody2D
var active: bool = true
var state: String = "patrol"
var target: Vector2 = Vector2.ZERO
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

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not active or not is_instance_valid(player):
		return
	sense_timer -= delta
	path_timer -= delta
	memory = maxf(0.0, memory - delta)
	disengage_timer = maxf(0.0, disengage_timer - delta)
	var player_distance: float = global_position.distance_to(player.global_position)
	escape_timer = escape_timer + delta if state == "hunt" and player_distance > escape_distance else 0.0
	if state == "hunt" and (escape_timer >= 2.0 or memory <= 0.0):
		state = "investigate"
		target = last_known
		disengage_timer = 4.0
		escape_timer = 0.0
		path_timer = 0.0
	if sense_timer <= 0.0:
		perceive()
		sense_timer = 0.18
	if state == "hunt":
		target = last_known
	elif global_position.distance_to(target) < 40.0:
		state = "patrol"
		target = maze.call("cell_position", randi_range(0, 120))
		path_timer = 0.0
	if path_timer <= 0.0:
		path = maze.call("find_path", global_position, target)
		path_index = 0
		if path.size() > 1 and maze.call("can_walk_line", global_position, path[1]):
			path_index = 1
		path_timer = 0.5
	var destination: Vector2 = target
	if path_index < path.size():
		destination = path[path_index]
		if global_position.distance_to(destination) < 10.0:
			path_index += 1
			if path_index < path.size():
				destination = path[path_index]
	if state == "hunt" and maze.call("can_walk_line", global_position, player.global_position):
		destination = player.global_position
	elif maze.call("can_walk_line", global_position, target):
		destination = target
	var direction: Vector2 = global_position.direction_to(destination)
	sprinting = state == "hunt" and not recovering and stamina > 0.0 and global_position.distance_to(player.global_position) > 85.0
	if sprinting:
		stamina = maxf(0.0, stamina - 34.0 * delta)
		if stamina <= 0.0:
			recovering = true
	else:
		stamina = minf(100.0, stamina + stamina_regen * delta)
		if stamina >= 80.0:
			recovering = false
	var speed: float = run_speed if sprinting else (170.0 if state == "hunt" else 115.0)
	velocity = direction * minf(speed, global_position.distance_to(destination) / maxf(delta, 0.001))
	move_and_slide()
	if not velocity.is_zero_approx():
		facing_angle = lerp_angle(facing_angle, velocity.angle(), 1.0 - exp(-10.0 * delta))
	gait += delta * (18.0 if sprinting else 8.0)
	queue_redraw()
	if global_position.distance_to(player.global_position) < attack_radius and maze.call("clear_line", global_position, player.global_position):
		game.call("kill_player")

func perceive() -> void:
	if disengage_timer > 0.0:
		return
	var offset: Vector2 = player.global_position - global_position
	var radius: float = sight_radius + (180.0 if player.get("flashlight_on") else 0.0)
	var in_front: bool = state == "hunt" or absf(angle_difference(facing_angle, offset.angle())) < deg_to_rad(field_of_view) * 0.5 or offset.length() < 180.0
	if offset.length() <= radius and in_front and maze.call("clear_line", global_position, player.global_position):
		state = "hunt"
		last_known = player.global_position
		memory = 3.0

func hear_noise(point: Vector2, radius: float) -> void:
	if not active or not is_instance_valid(maze) or disengage_timer > 0.0:
		return
	var reach: float = radius
	if not maze.call("clear_line", global_position, point):
		reach *= 0.45
	if global_position.distance_to(point) > reach:
		return
	if state != "hunt":
		state = "investigate"
		target = point
		path_timer = 0.0

func _draw() -> void:
	var angle: float = PI * 0.5 if Engine.is_editor_hint() else facing_angle
	draw_set_transform(Vector2.ZERO, angle - PI * 0.5)
	var swing: float = 0.0 if Engine.is_editor_hint() else sin(gait) * (15.0 if sprinting else 7.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-27, -8), Vector2(-19, -25), Vector2(17, -26), Vector2(29, -5), Vector2(19, 20), Vector2(-17, 23)]), Color("333e35"))
	draw_line(Vector2(-22, 0), Vector2(-43, 22 + swing), Color("7d7d65"), 9)
	draw_line(Vector2(23, 0), Vector2(45, 21 - swing), Color("85816b"), 9)
	for hand in [Vector2(-43, 22 + swing), Vector2(45, 21 - swing)]:
		for finger in range(3):
			draw_line(hand + Vector2(finger * 3 - 3, 0), hand + Vector2(finger * 4 - 4, 13), Color("b4a780"), 2)
	draw_circle(Vector2(0, 13), 17, Color("545b47"))
	draw_arc(Vector2(0, 13), 15, 0.0, PI, 12, Color("a79971"), 2)
	draw_circle(Vector2(-6, 24), 2, Color("e2b867"))
	draw_circle(Vector2(6, 24), 2, Color("e2b867"))
	draw_set_transform(Vector2.ZERO)
