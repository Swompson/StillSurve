@tool
extends Node2D

const SHADOW_SAMPLES: int = 1024
var shadow_texture: ImageTexture
var shadow_revision: int = -1
var fixtures: Array[Node] = []
var surfaces: Array[ShaderMaterial] = []
var previous_camera_center: Vector2 = Vector2.INF
var shadow_origins: PackedVector2Array = PackedVector2Array()
var glow_materials: Array[ShaderMaterial] = []


func _ready() -> void:
	set_process(not Engine.is_editor_hint())
	process_priority = 12
	fixtures = $Fixtures.get_children()
	for layer in ["Pipes", "Beams", "Wires"]:
		var surface: ShaderMaterial = get_node(layer).material as ShaderMaterial
		surface.set_shader_parameter("projection_enabled", not Engine.is_editor_hint())
		surfaces.append(surface)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var camera: Camera2D = get_viewport().get_camera_2d()
	if not camera:
		return
	var camera_center: Vector2 = camera.get_screen_center_position()
	if camera_center != previous_camera_center:
		for surface in surfaces:
			surface.set_shader_parameter("camera_center", camera_center)
		previous_camera_center = camera_center

	var game: Node = get_tree().current_scene
	if not is_instance_valid(game) or not game.has_node("Visibility"):
		return
	var visibility: Node2D = game.get_node("Visibility")
	var fog: ShaderMaterial = visibility.get("fog_material")
	var floor_surface: ShaderMaterial = visibility.get("floor_material")
	visibility.call("get_blocker_corners")
	var revision: int = int(visibility.get("geometry_revision"))
	var origins: PackedVector2Array = PackedVector2Array()
	for fixture in fixtures:
		origins.append(fixture.global_position)
	var origins_changed: bool = shadow_texture == null or origins != shadow_origins
	if shadow_texture == null or revision != shadow_revision or origins_changed:
		build_fixture_shadows(origins)
		shadow_revision = revision
		shadow_origins = origins
	if fog:
		fog.set_shader_parameter("fixture_shadows", shadow_texture)
	if floor_surface:
		floor_surface.set_shader_parameter("fixture_shadows", shadow_texture)

	for index in range(mini(fixtures.size(), 6)):
		var fixture: Node2D = fixtures[index] as Node2D
		var parameter: String = "fixture_" + ["a", "b", "c", "d", "e", "f"][index]
		if fog:
			fog.set_shader_parameter(parameter, fixture.global_position - visibility.global_position)
		if floor_surface and origins_changed:
			floor_surface.set_shader_parameter(parameter, fixture.global_position)
	var powers: Vector4 = Vector4.ZERO
	for index in range(mini(fixtures.size(), 4)):
		powers[index] = float(fixtures[index].get("light_power"))
	if fog:
		fog.set_shader_parameter("fixture_power", powers)
	if floor_surface:
		floor_surface.set_shader_parameter("fixture_power", powers)
	var fifth_power: float = float(fixtures[4].get("light_power")) if fixtures.size() > 4 else 0.0
	if fog:
		fog.set_shader_parameter("fixture_power_e", fifth_power)
	if floor_surface:
		floor_surface.set_shader_parameter("fixture_power_e", fifth_power)
	var sixth_power: float = float(fixtures[5].get("light_power")) if fixtures.size() > 5 else 0.0
	if fog: fog.set_shader_parameter("fixture_power_f", sixth_power)
	if floor_surface: floor_surface.set_shader_parameter("fixture_power_f", sixth_power)

func build_fixture_shadows(origins: PackedVector2Array) -> void:
	var image: Image = Image.create(SHADOW_SAMPLES, 6, false, Image.FORMAT_RF)
	image.fill(Color(1, 0, 0, 1))
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.new()
	query.collision_mask = 2
	query.hit_from_inside = true
	for row in range(mini(origins.size(), 6)):
		query.from = origins[row]
		for sample in range(SHADOW_SAMPLES):
			query.to = query.from + Vector2.from_angle(TAU * (float(sample) + 0.5) / SHADOW_SAMPLES) * 245.0
			var hit: Dictionary = space.intersect_ray(query)
			var reach: float = 245.0 if hit.is_empty() else maxf(0.0, query.from.distance_to(hit.position) - 0.5)
			if not hit.is_empty() and hit.collider.is_in_group("warehouse_props"):
				# The shared lamp shader fades over three pixels, inside the prop.
				reach = minf(245.0, query.from.distance_to(hit.position) + 3.0)
			image.set_pixel(sample, row, Color(reach / 245.0, 0, 0, 1))
	if shadow_texture == null:
		shadow_texture = ImageTexture.create_from_image(image)
	else:
		shadow_texture.update(image)
	if glow_materials.is_empty():
		for fixture in $Fixtures.get_children():
			var glow_material: ShaderMaterial = ShaderMaterial.new()
			glow_material.shader = preload("res://shaders/fixture_glow.gdshader")
			fixture.get_node("Housing/Glow").material = glow_material
			glow_materials.append(glow_material)
	for row in range(glow_materials.size()):
		glow_materials[row].set_shader_parameter("fixture_shadows", shadow_texture)
		glow_materials[row].set_shader_parameter("lamp_origin", origins[row])
		glow_materials[row].set_shader_parameter("lamp_row", row)
