extends Node2D

# One mesh covers the unseen world; a second mesh lights only first-hit wall faces.
@export var fog_color: Color = Color.BLACK
@export_range(48, 256) var angular_samples: int = 160
@export_range(1.0, 30.0) var edge_softness_degrees: float = 12.0
@export_range(0.0, 32.0) var wall_softness: float = 3.0
@export_range(1.0, 128.0) var ambient_softness: float = 72.0

const EDGE_SHADER = preload("res://shaders/flashlight_edges.gdshader")

var player: CharacterBody2D
var fog_mesh: ArrayMesh = ArrayMesh.new()
var fog_material: ShaderMaterial = ShaderMaterial.new()
var previous_origin: Vector2 = Vector2.INF
var previous_ambient_center: Vector2 = Vector2.INF
var previous_radius: float = 0.0
var previous_extent: float = 0.0
var previous_blockers: PackedVector2Array = PackedVector2Array()
var contact_node: MeshInstance2D
var contact_mesh: ArrayMesh = ArrayMesh.new()
var floor_material: ShaderMaterial
var glass_material: ShaderMaterial
var glass_occlusion_origin: Vector2 = Vector2.INF
var glass_occlusion_revision: int = -1
var glass_occlusion_range: float = 0.0
var glass_occlusion_valid: bool = true
var contact_material: ShaderMaterial
var pose_initialized: bool = false
var previous_observer: Vector2
var current_observer: Vector2
var previous_muzzle: Vector2
var current_muzzle: Vector2
var previous_facing: float = 0.0
var current_facing: float = 0.0
var geometry_dirty: bool = true
var geometry_revision: int = 0
var geometry_corners: PackedVector2Array = PackedVector2Array()
var geometry_outlines: Array[PackedVector2Array] = []
var geometry_circles: Array[Vector3] = []
var fog_indices: PackedInt32Array = PackedInt32Array()
var fog_colors: PackedColorArray = PackedColorArray()
var topology_ray_count: int = -1
var ray_query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.new()
var light_settings: Array = []
var glass_settings: Array = []

func _ready() -> void:
	player = get_parent().get_node("Player") as CharacterBody2D
	fog_material.shader = EDGE_SHADER
	material = fog_material
	# Mesh vertices are rebuilt at render time; interpolating the node again would
	# mix a new wall intersection mesh with the previous flashlight origin.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	contact_node = MeshInstance2D.new()
	contact_node.name = "LitWallFaces"
	contact_node.z_index = 21
	contact_material = ShaderMaterial.new()
	contact_material.shader = preload("res://shaders/wall_faces.gdshader")
	contact_node.material = contact_material
	contact_node.mesh = contact_mesh
	add_child(contact_node)
	floor_material = get_parent().get_node("Maze/Floor").material
	glass_material = get_parent().get_node("Maze/FloorGlass").material
	ray_query.collision_mask = 2
	ray_query.hit_from_inside = true
	# Resolve the light after character visuals have advanced for this render frame.
	process_priority = 10
	process_physics_priority = 10
	get_tree().node_added.connect(invalidate_geometry)
	get_tree().node_removed.connect(invalidate_geometry)

func invalidate_geometry(_node: Node = null) -> void:
	geometry_dirty = true

func get_blocker_corners() -> PackedVector2Array:
	if geometry_dirty:
		geometry_corners = PackedVector2Array()
		geometry_circles.clear()
		var outlines: Array[PackedVector2Array] = []
		for wall in get_tree().get_nodes_in_group("vision_blockers"):
			var collision: CollisionShape2D = wall.get_node_or_null("Collision") as CollisionShape2D
			if collision != null and collision.shape is CircleShape2D and not collision.disabled:
				var center: Vector2 = collision.global_position
				var circle_scale: float = maxf(collision.global_transform.x.length(), collision.global_transform.y.length())
				geometry_circles.append(Vector3(center.x, center.y, collision.shape.radius * circle_scale))
			var points: PackedVector2Array = wall.call("get_vision_corners")
			geometry_corners.append_array(points)
			if wall.has_method("get_wall_rectangles"):
				for start in range(0, points.size(), 4):
					outlines.append(points.slice(start, start + 4))
			else:
				outlines.append(points)
			if wall.has_signal("vision_geometry_changed") and not wall.is_connected("vision_geometry_changed", invalidate_geometry):
				wall.connect("vision_geometry_changed", invalidate_geometry)
		geometry_outlines = outlines
		var bounds: Array[Rect2] = []
		for outline in outlines: bounds.append(polygon_bounds(outline).grow(0.01))
		# Overlapping rectangles create junction vertices which are not corners of
		# either collider. Missing them lets shadow edges jump between adjacent rays.
		for first in range(outlines.size()):
			var a: PackedVector2Array = outlines[first]
			var a_bounds: Rect2 = bounds[first]
			for second in range(first + 1, outlines.size()):
				var b: PackedVector2Array = outlines[second]
				if not a_bounds.intersects(bounds[second]): continue
				for ai in range(a.size()):
					for bi in range(b.size()):
						var crossing: Variant = Geometry2D.segment_intersects_segment(a[ai], a[(ai + 1) % a.size()], b[bi], b[(bi + 1) % b.size()])
						if crossing != null: geometry_corners.append(crossing)
		geometry_dirty = false
		geometry_revision += 1
	return geometry_corners

func polygon_bounds(points: PackedVector2Array) -> Rect2:
	var bounds: Rect2 = Rect2(points[0], Vector2.ZERO)
	for point in points: bounds = bounds.expand(point)
	return bounds

func _physics_process(_delta: float) -> void:
	capture_pose()

func capture_pose() -> void:
	var observer: Vector2 = player.global_position
	var muzzle: Vector2 = player.call("get_view_origin")
	var facing: float = float(player.call("get_view_angle"))
	if not pose_initialized or observer.distance_to(current_observer) > 128.0:
		previous_observer = observer
		previous_muzzle = muzzle
		previous_facing = facing
	else:
		previous_observer = current_observer
		previous_muzzle = current_muzzle
		previous_facing = current_facing
	current_observer = observer
	current_muzzle = muzzle
	current_facing = facing
	pose_initialized = true

func _process(_delta: float) -> void:
	refresh_visibility(true)

func refresh_visibility(interpolated: bool) -> void:
	if not is_instance_valid(player):
		return
	var origin: Vector2
	var observer: Vector2 = player.global_position
	var facing: float = float(player.call("get_view_angle"))
	if interpolated:
		if not pose_initialized:
			capture_pose()
		var fraction: float = Engine.get_physics_interpolation_fraction()
		observer = previous_observer.lerp(current_observer, fraction)
		# Position follows fixed-step interpolation; mouse aim and the held lens
		# are resolved for this rendered frame, rather than quantized to 60 Hz.
		origin = player.call("get_view_origin_at", observer)
	else:
		origin = player.call("get_view_origin")
	var beam_active: bool = bool(player.get("flashlight_on")) or float(player.get("flashlight_strength")) > 0.005
	if not beam_active:
		origin = observer
	var ambient_center: Vector2 = observer - origin
	var radius: float = float(player.call("get_beam_distance")) if beam_active else float(player.get("ambient_view_distance"))
	var fov: float = deg_to_rad(float(player.get("field_of_view"))) if beam_active else TAU
	var strength: float = float(player.get("flashlight_strength"))
	var reach: float = float(player.call("get_beam_distance"))
	var half_angle: float = deg_to_rad(float(player.get("field_of_view"))) * 0.5
	var settings: Array = [reach, half_angle, edge_softness_degrees, player.get("ambient_view_distance"), ambient_softness, fog_color, player.get("beam_fade_start")]
	if light_settings != settings:
		light_settings = settings
		for surface in [contact_material, floor_material]:
			surface.set_shader_parameter("light_range", reach)
			surface.set_shader_parameter("half_fov", half_angle)
		contact_material.set_shader_parameter("angular_feather", deg_to_rad(edge_softness_degrees))
		contact_material.set_shader_parameter("ambient_radius", player.get("ambient_view_distance"))
		contact_material.set_shader_parameter("ambient_softness", ambient_softness)
		fog_material.set_shader_parameter("ambient_radius", player.get("ambient_view_distance"))
		fog_material.set_shader_parameter("ambient_softness", ambient_softness)
		fog_material.set_shader_parameter("angular_feather", deg_to_rad(edge_softness_degrees))
		fog_material.set_shader_parameter("fog_color", fog_color)
		fog_material.set_shader_parameter("beam_range", reach)
		fog_material.set_shader_parameter("fade_start", reach * float(player.get("beam_fade_start")))
	contact_material.set_shader_parameter("light_origin", origin)
	contact_material.set_shader_parameter("observer_position", observer)
	contact_material.set_shader_parameter("light_angle", facing)
	contact_material.set_shader_parameter("light_power", strength)
	floor_material.set_shader_parameter("light_origin", origin)
	floor_material.set_shader_parameter("observer_position", observer)
	floor_material.set_shader_parameter("light_angle", facing)
	floor_material.set_shader_parameter("light_power", strength)
	update_glass_lighting(origin, facing, strength)
	fog_material.set_shader_parameter("beam_strength", strength)
	fog_material.set_shader_parameter("ambient_center", ambient_center)
	fog_material.set_shader_parameter("facing_angle", facing)
	fog_material.set_shader_parameter("half_fov", fov * 0.5)
	var extent: float = float(player.call("get_mask_extent"))
	# Offscreen lamp pools cannot contribute pixels; keep identical rays for visible pools.
	var camera: Camera2D = get_viewport().get_camera_2d()
	var view_size: Vector2 = get_viewport_rect().size / camera.zoom if camera else Vector2.ONE * extent
	var view_center: Vector2 = camera.get_screen_center_position() if camera else observer
	var view_bounds: Rect2 = Rect2(view_center - view_size * 0.5, view_size)
	for fixture in get_tree().get_nodes_in_group("ceiling_fixtures"):
		var lamp_radius: float = float(fixture.get("light_radius"))
		if view_bounds.grow(lamp_radius).has_point(fixture.global_position):
			radius = maxf(radius, minf(extent, origin.distance_to(fixture.global_position) + lamp_radius))

	var corners: PackedVector2Array = get_blocker_corners()
	global_position = origin
	if origin == previous_origin and ambient_center == previous_ambient_center and radius == previous_radius and extent == previous_extent and corners == previous_blockers:
		return
	previous_origin = origin
	previous_ambient_center = ambient_center
	previous_radius = radius
	previous_extent = extent
	previous_blockers = corners
	update_visibility(origin, radius, corners, extent)

func update_glass_lighting(origin: Vector2, facing: float, strength: float) -> void:
	if glass_material == null: return
	var reach: float = float(player.call("get_beam_distance"))
	get_blocker_corners()
	if geometry_revision != glass_occlusion_revision or origin.distance_squared_to(glass_occlusion_origin) > 32.0 * 32.0 or reach != glass_occlusion_range:
		var segments: Array[Vector4] = []
		var bounds: Rect2 = Rect2(origin - Vector2.ONE * (reach + 96.0), Vector2.ONE * (reach + 96.0) * 2.0)
		for outline in geometry_outlines:
			if outline.size() < 3 or not bounds.intersects(polygon_bounds(outline)): continue
			for index in range(outline.size()):
				var a: Vector2 = outline[index]
				var b: Vector2 = outline[(index + 1) % outline.size()]
				segments.append(Vector4(a.x, a.y, b.x, b.y))
		glass_occlusion_valid = segments.size() <= 256
		glass_material.set_shader_parameter("occluder_count", segments.size() if glass_occlusion_valid else 0)
		segments.resize(256)
		glass_material.set_shader_parameter("occluder_segments", segments)
		glass_occlusion_origin = origin
		glass_occlusion_revision = geometry_revision
		glass_occlusion_range = reach
	glass_material.set_shader_parameter("light_origin", origin)
	glass_material.set_shader_parameter("light_angle", facing)
	var settings: Array = [reach, player.get("beam_fade_start"), player.get("field_of_view"), edge_softness_degrees]
	if settings != glass_settings:
		glass_settings = settings
		glass_material.set_shader_parameter("light_range", reach)
		glass_material.set_shader_parameter("fade_start", reach * float(player.get("beam_fade_start")))
		glass_material.set_shader_parameter("half_fov", deg_to_rad(float(player.get("field_of_view"))) * 0.5)
		glass_material.set_shader_parameter("angular_feather", deg_to_rad(edge_softness_degrees))
	glass_material.set_shader_parameter("light_power", strength if glass_occlusion_valid else 0.0)

func update_visibility(origin: Vector2, radius: float, corners: PackedVector2Array, extent: float = 0.0) -> void:
	var angles: Array[float] = []
	for index in range(angular_samples):
		angles.append(TAU * float(index) / float(angular_samples))
	# Circle silhouettes move with the observer. Fixed perimeter samples do not
	# contain the tangent, causing the shadow edge to jump between coarse rays.
	for circle in geometry_circles:
		var offset: Vector2 = Vector2(circle.x, circle.y) - origin
		var distance: float = offset.length()
		if distance <= circle.z or distance - circle.z > radius:
			continue
		var half_angle: float = asin(clampf(circle.z / distance, 0.0, 1.0))
		for side in [-1.0, 1.0]:
			var tangent: float = offset.angle() + side * half_angle
			for epsilon in [-0.0001, 0.0, 0.0001]:
				angles.append(fposmod(tangent + epsilon, TAU))
	# Cast a complete, stable visibility polygon. Cone clipping happens in shaders,
	# so turning cannot add/remove rays or make first-hit wall strips blink.
	for corner in corners:
		if corner.distance_squared_to(origin) > radius * radius:
			continue
		var angle: float = (corner - origin).angle()
		for epsilon in [-0.0001, 0.0, 0.0001]:
			angles.append(fposmod(angle + float(epsilon), TAU))
	angles.sort()
	var unique_angles: Array[float] = []
	for angle in angles:
		if unique_angles.is_empty() or angle - unique_angles[-1] > 0.000001:
			unique_angles.append(angle)
	angles = unique_angles

	var vertices: PackedVector2Array = PackedVector2Array()
	vertices.resize(angles.size() * 3 + 1)
	ensure_visibility_topology(angles.size())
	var outer_radius: float = extent if extent > 0.0 else float(player.call("get_mask_extent"))
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var contact_points: PackedVector2Array = PackedVector2Array()
	var contact_normals: PackedVector2Array = PackedVector2Array()
	contact_points.resize(angles.size())
	contact_normals.resize(angles.size())
	ray_query.from = origin
	for index in range(angles.size()):
		var direction: Vector2 = Vector2.from_angle(angles[index])
		var distance: float = 0.0
		var inward_softness: float = wall_softness
		var outward_softness: float = 0.0
		if radius > 0.0:
			ray_query.to = origin + direction * radius
			var hit: Dictionary = space.intersect_ray(ray_query)
			distance = radius if hit.is_empty() else origin.distance_to(hit["position"])
			# Stop at the first surface; exiting separate overlapping rectangles
			# produced alternating shadow wedges at wall joints.
			if not hit.is_empty():
				if hit.collider.is_in_group("warehouse_props"):
					# Shade behind the true silhouette, never on the floor in front.
					inward_softness = 0.0
					outward_softness = 0.75
				else:
					distance = maxf(0.0, distance - 0.5)
				# Storage tops shade their own texture; wall strips create offset
				# patches and broken highlights on curved drum surfaces.
				if not hit.collider.is_in_group("warehouse_props"):
					contact_points[index] = Vector2(hit.position) - origin
					contact_normals[index] = hit.normal
		vertices[index * 3] = direction * maxf(distance - inward_softness, 0.0)
		vertices[index * 3 + 1] = direction * (distance + outward_softness)
		vertices[index * 3 + 2] = direction * outer_radius
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = fog_colors
	arrays[Mesh.ARRAY_INDEX] = fog_indices
	fog_mesh.clear_surfaces()
	fog_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	build_wall_contacts(contact_points, contact_normals)
	queue_redraw()

func ensure_visibility_topology(count: int) -> void:
	if count == topology_ray_count: return
	topology_ray_count = count
	fog_colors.resize(count * 3 + 1)
	fog_colors.fill(Color.WHITE)
	fog_indices.resize(count * 15)
	var center_index: int = count * 3
	fog_colors[center_index] = Color(1, 1, 1, 0)
	for index in range(count):
		var current: int = index * 3
		var following: int = ((index + 1) % count) * 3
		fog_colors[current] = Color(1, 1, 1, 0)
		var triangle_indices: Array[int] = [center_index, current, following,
			current, current + 1, following + 1, current, following + 1, following,
			current + 1, current + 2, following + 2, current + 1, following + 2, following + 1]
		for offset in range(15): fog_indices[index * 15 + offset] = triangle_indices[offset]

func build_wall_contacts(contacts: PackedVector2Array, normals: PackedVector2Array) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	for index in range(contacts.size()):
		var next_index: int = (index + 1) % contacts.size()
		var a: Vector2 = contacts[index]
		var b: Vector2 = contacts[next_index]
		if normals[index].is_zero_approx() or normals[next_index].is_zero_approx():
			continue
		# Adjacent coplanar colliders are one visible face, including door jambs.
		var normal: Vector2 = normals[index]
		if normal.dot(normals[next_index]) < 0.98 or absf((b - a).dot(normal)) > 0.1:
			continue
		var start: int = points.size()
		# The glow goes into the wall, never across an opening or onto a hidden face.
		points.append_array(PackedVector2Array([a, b, b - normals[next_index] * 9.0, a - normal * 9.0]))
		colors.append_array(PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0), Color(1, 1, 1, 0)]))
		indices.append_array(PackedInt32Array([start, start + 1, start + 2, start, start + 2, start + 3]))
	contact_mesh.clear_surfaces()
	if points.is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	contact_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

func _draw() -> void:
	if fog_mesh.get_surface_count() > 0:
		draw_mesh(fog_mesh, null, Transform2D.IDENTITY, Color.WHITE)
