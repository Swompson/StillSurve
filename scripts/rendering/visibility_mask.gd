extends Node2D

# One mesh covers everything outside the visible polygon, including wall shadows.
# Only the cone rays query physics; there are no CPU image operations or uploads.
@export var fog_color: Color = Color.BLACK
@export_range(48, 256) var angular_samples: int = 160
@export_range(1.0, 30.0) var edge_softness_degrees: float = 12.0
@export_range(0.0, 32.0) var wall_softness: float = 3.0
@export_range(1.0, 64.0) var ambient_softness: float = 24.0

const EDGE_SHADER = preload("res://shaders/flashlight_edges.gdshader")

var player: CharacterBody2D
var fog_mesh: ArrayMesh = ArrayMesh.new()
var fog_material: ShaderMaterial = ShaderMaterial.new()
var previous_origin: Vector2 = Vector2.INF
var previous_ambient_center: Vector2 = Vector2.INF
var previous_angle: float = INF
var previous_radius: float = 0.0
var previous_fov: float = 0.0
var previous_extent: float = 0.0
var previous_blockers: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	player = get_parent().get_node("Player") as CharacterBody2D
	fog_material.shader = EDGE_SHADER
	material = fog_material
	# Run after the character has moved for this physics frame.
	process_physics_priority = 10

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var origin: Vector2 = player.call("get_view_origin")
	if not bool(player.get("flashlight_on")):
		origin = player.global_position
	var ambient_center: Vector2 = player.global_position - origin
	var facing: float = float(player.call("get_view_angle"))
	var radius: float = float(player.call("get_view_distance"))
	var fov: float = deg_to_rad(float(player.call("get_effective_fov")))
	var extent: float = float(player.call("get_mask_extent"))
	var corners: PackedVector2Array = PackedVector2Array()
	for wall in get_tree().get_nodes_in_group("vision_blockers"):
		var wall_corners: PackedVector2Array = wall.call("get_vision_corners")
		corners.append_array(wall_corners)
	global_position = origin
	if origin == previous_origin and ambient_center == previous_ambient_center and facing == previous_angle and radius == previous_radius and fov == previous_fov and extent == previous_extent and corners == previous_blockers:
		return
	previous_origin = origin
	previous_ambient_center = ambient_center
	previous_angle = facing
	previous_radius = radius
	previous_fov = fov
	previous_extent = extent
	previous_blockers = corners
	update_visibility(origin, facing, radius, fov, corners)

func update_visibility(origin: Vector2, facing: float, radius: float, fov: float, corners: PackedVector2Array) -> void:
	var ambient_radius: float = float(player.get("ambient_view_distance"))
	var ambient_center: Vector2 = player.global_position - origin
	fog_material.set_shader_parameter("ambient_radius", ambient_radius)
	fog_material.set_shader_parameter("ambient_center", ambient_center)
	fog_material.set_shader_parameter("ambient_softness", ambient_softness)
	fog_material.set_shader_parameter("facing_angle", facing)
	fog_material.set_shader_parameter("half_fov", fov * 0.5)
	fog_material.set_shader_parameter("angular_feather", deg_to_rad(edge_softness_degrees))
	fog_material.set_shader_parameter("fog_color", fog_color)
	var angles: Array[float] = []
	for index in range(angular_samples):
		angles.append(TAU * float(index) / float(angular_samples))
	# Exact cone boundaries and corner rays avoid light leaking past wall edges.
	for boundary in [facing - fov * 0.5, facing + fov * 0.5]:
		for epsilon in [-0.0001, 0.0, 0.0001]:
			angles.append(fposmod(float(boundary) + float(epsilon), TAU))
	for corner in corners:
		if corner.distance_squared_to(origin) > radius * radius:
			continue
		var angle: float = (corner - origin).angle()
		if corner.distance_squared_to(player.global_position) > ambient_radius * ambient_radius and absf(angle_difference(facing, angle)) > fov * 0.5 + 0.02:
			continue
		for epsilon in [-0.0001, 0.0, 0.0001]:
			angles.append(fposmod(angle + float(epsilon), TAU))
	angles.sort()
	var unique_angles: Array[float] = []
	for angle in angles:
		if unique_angles.is_empty() or angle - unique_angles[-1] > 0.000001:
			unique_angles.append(angle)
	angles = unique_angles

	var vertices: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	var outer_radius: float = float(player.call("get_mask_extent"))
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.new()
	query.from = origin
	query.collision_mask = 2
	query.hit_from_inside = true
	for angle in angles:
		var direction: Vector2 = Vector2.from_angle(angle)
		var distance: float = 0.0
		# Intersect each ray with the ambient circle centered on the character.
		var projection: float = direction.dot(ambient_center)
		var circle_distance: float = projection + sqrt(maxf(0.0, ambient_radius * ambient_radius - ambient_center.length_squared() + projection * projection))
		var ray_radius: float = circle_distance
		if bool(player.get("flashlight_on")) and absf(angle_difference(facing, angle)) <= fov * 0.5:
			ray_radius = maxf(radius, circle_distance)
		if ray_radius > 0.0:
			query.to = origin + direction * ray_radius
			var hit: Dictionary = space.intersect_ray(query)
			distance = ray_radius if hit.is_empty() else origin.distance_to(hit["position"])
			# Stop at the first surface; exiting separate overlapping rectangles
			# produced alternating shadow wedges at wall joints.
			if not hit.is_empty():
				distance = maxf(0.0, distance - 0.5)
		vertices.append(direction * maxf(distance - wall_softness, 0.0))
		vertices.append(direction * distance)
		vertices.append(direction * outer_radius)
		colors.append(Color(1, 1, 1, 0))
		colors.append(Color.WHITE)
		colors.append(Color.WHITE)
	var center_index: int = vertices.size()
	vertices.append(Vector2.ZERO)
	colors.append(Color(1, 1, 1, 0))
	for index in range(angles.size()):
		var next_index: int = (index + 1) % angles.size()
		var current: int = index * 3
		var following: int = next_index * 3
		indices.append_array(PackedInt32Array([
			center_index, current, following,
			current, current + 1, following + 1,
			current, following + 1, following,
			current + 1, current + 2, following + 2,
			current + 1, following + 2, following + 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	fog_mesh.clear_surfaces()
	fog_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	queue_redraw()

func _draw() -> void:
	if fog_mesh.get_surface_count() > 0:
		draw_mesh(fog_mesh, null, Transform2D.IDENTITY, Color.WHITE)
