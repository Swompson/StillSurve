@tool
extends StaticBody2D

signal vision_geometry_changed

const TOP_SHADER = preload("res://shaders/warehouse_top.gdshader")

var cached_transform: Transform2D
var cached_size: Vector2 = Vector2.INF
var cached_corners: PackedVector2Array = PackedVector2Array()
var cached_polygon: PackedVector2Array = PackedVector2Array()
var observer: CharacterBody2D
var fixtures: Array[Node] = []
var ambient_softness: float = 72.0
var probe_timer: float = 0.0
var top_target: Color = Color(0.0, 0.0, 0.0, 0.0)
var top_current: Color = Color(0.0, 0.0, 0.0, 0.0)
var top_probe_count: int = 0
var top_ray_count: int = 0
var top_material: ShaderMaterial
var occluder_revision: int = -1

@onready var surface: Sprite2D = $Surface

func _ready() -> void:
	set_notify_transform(true)
	add_to_group("vision_blockers")
	set_process(not Engine.is_editor_hint())
	if not Engine.is_editor_hint():
		surface.hide()
		surface.modulate = Color(0.0, 0.0, 0.0, 0.0)
		if surface.material is ShaderMaterial and surface.material.shader == TOP_SHADER:
			top_material = surface.material.duplicate() as ShaderMaterial
		else:
			top_material = ShaderMaterial.new()
			top_material.shader = TOP_SHADER
		top_material.set_shader_parameter("editor_preview", false)
		surface.material = top_material
		call_deferred("cache_lighting_sources")
		process_priority = 13

func cache_lighting_sources() -> void:
	var game: Node = get_tree().current_scene
	if is_instance_valid(game):
		observer = game.get_node_or_null("Player") as CharacterBody2D
		var visibility: Node = game.get_node_or_null("Visibility")
		if visibility != null:
			ambient_softness = float(visibility.get("ambient_softness"))
	fixtures = get_tree().get_nodes_in_group("ceiling_fixtures")

func _process(delta: float) -> void:
	update_top_lighting()
	if top_target.a <= 0.001:
		# Hidden props have no temporal tail behind a corner.
		surface.hide()
		top_current = Color(0.0, 0.0, 0.0, 0.0)
		return
	update_view_uniforms()
	top_current = top_target
	surface.modulate = top_current
	surface.show()

func update_view_uniforms() -> void:
	if not is_instance_valid(observer) or top_material == null:
		return
	# The top and fog use the same interpolated observer and render-frame aim.
	var render_observer: Vector2 = observer.call("get_render_observer")
	# Derive pixel positions from UVs so canvas batching cannot shift the light mask.
	var texture_size: Vector2 = surface.texture.get_size()
	var pixel_origin: Vector2 = surface.to_global(surface.offset - texture_size * 0.5)
	top_material.set_shader_parameter("surface_origin", pixel_origin)
	top_material.set_shader_parameter("surface_axis_x", surface.global_transform.x * texture_size.x)
	top_material.set_shader_parameter("surface_axis_y", surface.global_transform.y * texture_size.y)
	top_material.set_shader_parameter("observer_position", render_observer)
	top_material.set_shader_parameter("light_origin", observer.call("get_view_origin_at", render_observer))
	top_material.set_shader_parameter("facing_angle", float(observer.call("get_view_angle")))
	top_material.set_shader_parameter("beam_strength", float(observer.get("flashlight_strength")))
	update_occluders()

func update_occluders() -> void:
	var visibility: Node = get_tree().current_scene.get_node_or_null("Visibility")
	if visibility == null:
		return
	visibility.call("get_blocker_corners")
	var revision: int = int(visibility.get("geometry_revision"))
	if revision == occluder_revision:
		return
	occluder_revision = revision
	var boxes: Array[Vector4] = []
	var circles: Array[Vector4] = []
	var polygon_edges: Array[Vector4] = []
	for blocker in get_tree().get_nodes_in_group("vision_blockers"):
		if blocker == self:
			continue
		var points: PackedVector2Array = blocker.call("get_vision_corners")
		var polygon_collision: CollisionShape2D = blocker.get_node_or_null("Collision") as CollisionShape2D
		if polygon_collision != null and polygon_collision.shape is ConvexPolygonShape2D:
			var polygon_bounds: Rect2 = Rect2(points[0], Vector2.ZERO)
			for point in points: polygon_bounds = polygon_bounds.expand(point)
			if polygon_bounds.grow(1000.0).has_point(global_position):
				for index in range(points.size()):
					var a: Vector2 = points[index]
					var b: Vector2 = points[(index + 1) % points.size()]
					polygon_edges.append(Vector4(a.x, a.y, b.x, b.y))
			continue
		if blocker.is_in_group("warehouse_props") and blocker.get_node("Collision").shape is CircleShape2D:
			var collision: CollisionShape2D = blocker.get_node("Collision")
			circles.append(Vector4(collision.global_position.x, collision.global_position.y, collision.shape.radius, 0.0))
			continue
		for start in range(0, points.size(), 4):
			var bounds: Rect2 = Rect2(points[start], Vector2.ZERO)
			for index in range(start, mini(start + 4, points.size())):
				bounds = bounds.expand(points[index])
			# Every contributing source is within 1000 pixels of this prop.
			if bounds.grow(1000.0).has_point(global_position):
				boxes.append(Vector4(bounds.position.x, bounds.position.y, bounds.end.x, bounds.end.y))
	assert(boxes.size() <= 96 and circles.size() <= 8 and polygon_edges.size() <= 256, "Storage shader occluder capacity exceeded")
	top_material.set_shader_parameter("polygon_edge_count", polygon_edges.size())
	polygon_edges.resize(256)
	top_material.set_shader_parameter("occluder_polygon_edges", polygon_edges)
	top_material.set_shader_parameter("box_count", boxes.size())
	top_material.set_shader_parameter("circle_count", circles.size())
	boxes.resize(96)
	circles.resize(8)
	top_material.set_shader_parameter("occluder_boxes", boxes)
	top_material.set_shader_parameter("occluder_circles", circles)

func ray_clear(from: Vector2, to: Vector2) -> bool:
	top_ray_count += 1
	var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to, 2)
	ray.hit_from_inside = true
	# The solid body still casts its normal shadow on the floor behind it.
	# Only the top's exposure probe ignores its own collision shape.
	ray.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func update_top_lighting() -> void:
	top_probe_count += 1
	top_target = Color(0.0, 0.0, 0.0, 0.0)
	if not is_instance_valid(observer):
		cache_lighting_sources()
		if not is_instance_valid(observer):
			return
	if global_position.distance_squared_to(observer.global_position) > 1000.0 * 1000.0:
		return
	var origin: Vector2 = observer.call("get_view_origin")
	var observer_position: Vector2 = observer.global_position
	var points: PackedVector2Array = get_vision_corners()
	var closest: Vector2 = points[0]
	for point in points:
		if point.distance_squared_to(observer_position) < closest.distance_squared_to(observer_position):
			closest = point
	var exposure_point: Vector2 = closest.lerp(global_position, 0.05)
	var ambient_radius: float = float(observer.get("ambient_view_distance"))
	var ambient: float = 1.0 - smoothstep(maxf(ambient_radius - ambient_softness, 0.0), ambient_radius, observer_position.distance_to(exposure_point))
	var half_fov: float = deg_to_rad(float(observer.get("field_of_view"))) * 0.5
	var relative: float = absf(angle_difference(float(observer.call("get_view_angle")), origin.direction_to(exposure_point).angle()))
	var cone: float = 1.0 - smoothstep(maxf(half_fov - deg_to_rad(12.0), 0.0), half_fov, relative)
	var reach: float = float(observer.call("get_beam_distance"))
	var radial: float = 1.0 - smoothstep(reach * float(observer.get("beam_fade_start")), reach, origin.distance_to(exposure_point))
	var beam: float = cone * radial * float(observer.get("flashlight_strength"))
	var lamp: float = 0.0
	var lamp_tint: Color = Color(1.0, 0.91, 0.66)
	var lamp_position: Vector2 = Vector2(-100000.0, -100000.0)
	var lamp_radius: float = 245.0
	for fixture in fixtures:
		if not is_instance_valid(fixture):
			continue
		var distance: float = exposure_point.distance_to(fixture.global_position)
		var amount: float = (1.0 - smoothstep(25.0, float(fixture.get("light_radius")), distance)) * float(fixture.get("light_power"))
		if amount > lamp and ray_clear(fixture.global_position, exposure_point):
			lamp = amount
			lamp_tint = fixture.get("light_tint")
			lamp_position = fixture.global_position
			lamp_radius = float(fixture.get("light_radius"))
	# A nearby corner can sit outside the beam while the center is illuminated.
	# Use all five points for the conservative CPU gate; the shader shades each
	# visible top pixel with the actual cone and ambient falloff.
	for point in points:
		ambient = maxf(ambient, 1.0 - smoothstep(maxf(ambient_radius - ambient_softness, 0.0), ambient_radius, observer_position.distance_to(point)))
		var point_angle: float = absf(angle_difference(float(observer.call("get_view_angle")), origin.direction_to(point).angle()))
		var point_cone: float = 1.0 - smoothstep(maxf(half_fov - deg_to_rad(12.0), 0.0), half_fov, point_angle)
		var point_reach: float = 1.0 - smoothstep(reach * float(observer.get("beam_fade_start")), reach, origin.distance_to(point))
		beam = maxf(beam, point_cone * point_reach * float(observer.get("flashlight_strength")))
	var illumination: float = maxf(ambient, beam)
	if illumination <= 0.015:
		return
	# A single exposed sample opens the CPU gate immediately. Per-pixel shader
	# occlusion retains the hidden portion instead of waiting for every corner.
	var sight_origin: Vector2 = origin if beam > ambient else observer_position
	var exposed: bool = ray_clear(sight_origin, global_position)
	for point in points:
		if exposed:
			break
		exposed = ray_clear(sight_origin, point.lerp(global_position, 0.03))
	if not exposed:
		return
	top_material.set_shader_parameter("half_fov", half_fov)
	top_material.set_shader_parameter("beam_range", reach)
	top_material.set_shader_parameter("beam_fade_start", reach * float(observer.get("beam_fade_start")))
	top_material.set_shader_parameter("ambient_radius", ambient_radius)
	top_material.set_shader_parameter("ambient_softness", ambient_softness)
	top_material.set_shader_parameter("lamp_position", lamp_position)
	top_material.set_shader_parameter("lamp_radius", lamp_radius)
	# The exposure was measured at the front; preserve the actual source power
	# so the shader applies radial falloff exactly once.
	var source_power: float = lamp / maxf(0.001, 1.0 - smoothstep(25.0, lamp_radius, exposure_point.distance_to(lamp_position))) if lamp > 0.0 else 0.0
	top_material.set_shader_parameter("lamp_power", source_power)
	top_material.set_shader_parameter("lamp_tint", lamp_tint)
	update_view_uniforms()
	top_target = Color.WHITE

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		vision_geometry_changed.emit()

func get_vision_corners() -> PackedVector2Array:
	# The saved collision shape is also the authoritative lighting outline.
	var collision: CollisionShape2D = $Collision
	var shape: Shape2D = collision.shape
	if shape is ConvexPolygonShape2D:
		if global_transform != cached_transform or shape.points != cached_polygon:
			cached_corners = PackedVector2Array()
			for point in shape.points: cached_corners.append(collision.to_global(point))
			cached_polygon = shape.points
			cached_transform = global_transform
		return cached_corners
	var size: Vector2 = Vector2.ONE * shape.radius * 2.0 if shape is CircleShape2D else shape.size
	if global_transform == cached_transform and size == cached_size:
		return cached_corners
	if shape is CircleShape2D:
		cached_corners = PackedVector2Array()
		for index in range(16):
			cached_corners.append(collision.to_global(Vector2.from_angle(TAU * index / 16.0) * shape.radius))
		cached_size = size
		cached_transform = global_transform
		return cached_corners
	var half: Vector2 = size * 0.5
	cached_corners = PackedVector2Array([
		collision.to_global(-half), collision.to_global(Vector2(half.x, -half.y)),
		collision.to_global(half), collision.to_global(Vector2(-half.x, half.y))])
	cached_size = size
	cached_transform = global_transform
	return cached_corners
