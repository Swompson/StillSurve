extends SceneTree

const CONTACT = preload("res://scripts/world/glass_contact.gd")
var failures: int = 0

# Keep geometry/gait checks independent from the real patch timer integration test.
class UnthrottledPatch extends Area2D:
	func can_crunch() -> bool: return true
	func start_cooldown() -> void: pass

class World extends Node2D:
	var open: bool = true
	func clear_line(_from: Vector2, _to: Vector2) -> bool: return open

class Controller extends Node:
	var finished: bool = false
	var maze: Node2D
	var events: Array[Dictionary] = []
	func step_on_glass(point: Vector2, player_step: bool, source: Node) -> void:
		events.append({"point": point, "player": player_step, "source": source})

func expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var actor: Node2D = Node2D.new()
	var world: World = World.new()
	var controller: Controller = Controller.new()
	controller.maze = world
	root.add_child(actor)
	root.add_child(world)
	root.add_child(controller)
	var patch: Area2D = UnthrottledPatch.new()
	patch.add_to_group("glass_patches")
	patch.monitoring = false
	patch.collision_layer = 0
	var footprint: CollisionShape2D = CollisionShape2D.new()
	footprint.name = "Footprint"
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 40.0
	footprint.shape = circle
	patch.add_child(footprint)
	root.add_child(patch)
	var contact: RefCounted = CONTACT.new()
	contact.update(actor, Vector2(-48, 0), Vector2(-44, 0), controller, true, 0.02)
	expect(controller.events.size() == 1, "A four-unit entry crunches before a full normal footstep")
	for index in range(100): contact.update(actor, Vector2(-44, 0), Vector2(-44, 0), controller, true, 0.02)
	expect(controller.events.size() == 1, "Standing still never repeats the crunch")
	for index in range(38):
		var from: Vector2 = Vector2(-44 + index * 2, 0)
		contact.update(actor, from, from + Vector2(2, 0), controller, true, 0.02)
		contact.update(actor, from + Vector2(2, 0), from + Vector2(2, 0), controller, true, 0.25)
	expect(controller.events.size() == 2, "Short steps separated by pauses accumulate glass travel")
	controller.events.clear()
	contact = CONTACT.new()
	for index in range(8):
		contact.update(actor, Vector2(-48, 0), Vector2(-44, 0), controller, true, 0.25)
		contact.update(actor, Vector2(-44, 0), Vector2(-48, 0), controller, true, 0.25)
	expect(controller.events.size() == 1, "Repeated edge crossings cannot restart a crunch within the same stride")
	var overlap: Area2D = patch.duplicate()
	root.add_child(overlap)
	circle.radius = 1500.0
	controller.events.clear()
	contact = CONTACT.new()
	for index in range(288):
		contact.update(actor, Vector2(index * 3, 0), Vector2((index + 1) * 3, 0), controller, true, 1.0 / 60.0)
	expect(controller.events.size() == 12, "Twelve walking strides produce twelve crunches even across overlapping patches")
	controller.events.clear()
	contact = CONTACT.new()
	for index in range(372):
		contact.update(actor, Vector2(index * 2.5, 0), Vector2((index + 1) * 2.5, 0), controller, true, 1.0 / 60.0, 77.5)
	expect(controller.events.size() == 12, "Running uses its longer stride instead of multiplying the walking crunches")
	overlap.free()
	circle.radius = 40.0
	controller.events.clear()
	contact = CONTACT.new()
	contact.update(actor, Vector2(-100, 0), Vector2(100, 0), controller, true, 0.02)
	expect(controller.events.size() == 1 and absf(controller.events[0].point.x) < 46.0, "A swept crossing crunches even with both endpoints outside")
	controller.events.clear()
	contact = CONTACT.new()
	contact.update(actor, Vector2(-100, 60), Vector2(100, 60), controller, true, 0.02)
	expect(controller.events.is_empty(), "Moving beside the authored footprint stays silent")
	world.open = false
	contact.update(actor, Vector2(-20, 0), Vector2(20, 0), controller, true, 0.02)
	expect(controller.events.is_empty(), "An intervening wall prevents a false crunch")
	world.open = true
	controller.finished = true
	contact.update(actor, Vector2(-20, 0), Vector2(20, 0), controller, true, 0.02)
	expect(controller.events.is_empty(), "Finished games cannot generate glass events")
	controller.finished = false
	for index in range(2):
		contact = CONTACT.new()
		contact.update(actor, Vector2(-20, 0), Vector2(20, 0), controller, false, 0.02)
	expect(controller.events.size() == 2 and controller.events[0].source == actor and not controller.events[0].player, "Each actor has independent contacts and correct noise ownership")
	var polygon: CollisionPolygon2D = CollisionPolygon2D.new()
	polygon.polygon = PackedVector2Array([Vector2(-120, -10), Vector2(120, -10), Vector2(120, 10), Vector2(-120, 10)])
	polygon.scale = Vector2(-0.5, 0.5)
	polygon.rotation = 0.6
	root.add_child(polygon)
	var tip_entry: Vector2 = CONTACT.footprint_interval(polygon, polygon.to_global(Vector2(-110, -40)), polygon.to_global(Vector2(-110, 0)))
	expect(tip_entry.x >= 0.0 and tip_entry.y == 1.0, "Rotated mirrored outlines detect outer shards beyond the old center radius")
	expect(CONTACT.footprint_interval(polygon, polygon.to_global(Vector2(-110, 100)), polygon.to_global(Vector2(110, 100))).x < 0.0, "Transparent margins outside the outline stay silent")
	polygon.disabled = true
	expect(CONTACT.footprint_interval(polygon, Vector2(-5, 0), Vector2(5, 0)).x < 0.0, "A disabled authored footprint stays silent")
	polygon.free()
	var feet: AudioStreamPlayer2D = load("res://scripts/audio/footstep_audio.gd").new()
	root.add_child(feet)
	for index in range(20):
		feet.add_travel(4.0)
		feet.add_travel(0.0)
	expect(feet.steps_played == 1, "Pauses preserve the ordinary footstep distance too")
	for node in [actor, patch, world, controller, feet]: node.free()
	set_meta("hard_mode", true)
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(8): await physics_frame
	var game: Node = current_scene
	game.player.set_physics_process(false)
	for hunter in game.monsters: hunter.set_physics_process(false)
	var patches: Array[Node] = get_nodes_in_group("glass_patches")
	expect(patches.size() == 13, "All authored glass patches remain")
	var textures: Dictionary = {}
	for node in patches:
		textures[node.get_node("Shards").texture.resource_path] = true
		expect(node.get_node("Footprint") is CollisionPolygon2D and node.get_node("Shards").self_modulate.a <= 0.4, "Every subtle sprite has an editor-visible outline matching its texture")
	expect(textures.size() == 4, "All four new textures are in use")
	var entry: Vector2 = patches[0].global_position
	game.player.global_position = entry - Vector2(10, 0)
	game.player.glass_contact = CONTACT.new()
	game.player.get_node("Footsteps").travel = 0.0
	game.player.get_node("Footsteps").steps_played = 0
	game.last_glass = -1
	Input.action_press("move_right")
	game.player._physics_process(0.02)
	Input.action_release("move_right")
	game.player._physics_process(0.02)
	expect(game.last_glass >= 0 and game.player.get_node("Footsteps").steps_played == 0, "An actual short input tap triggers glass before the player's ordinary footstep")
	for voice_name in ["GlassCrunch", "GlassCrunch2", "GlassCrunch3"]: game.get_node(voice_name).stop()
	game.step_on_glass(Vector2(-500, 0), true, game.player)
	game.step_on_glass(Vector2(500, 0), false, game.monsters[0])
	expect(game.get_node("GlassCrunch").global_position == Vector2(-500, 0), "A second source does not move the first playing crunch")
	expect(game.get_node("GlassCrunch2").playing and game.get_node("GlassCrunch2").global_position == Vector2(500, 0), "Overlapping glass uses a separate positioned voice")
	game.step_on_glass(Vector2(-450, 0), true, game.player)
	var player_voices: int = 0
	for index in range(3):
		if game.glass_voice_sources[index] == game.player.get_instance_id() and game.get_node(["GlassCrunch", "GlassCrunch2", "GlassCrunch3"][index]).playing:
			player_voices += 1
	expect(player_voices == 1 and game.get_node("GlassCrunch").global_position == Vector2(-450, 0), "The next footfall reuses the actor's voice without layering a second recording")
	expect(game.get_node("GlassCrunch2").global_position == Vector2(500, 0), "Reusing the player's voice preserves the other actor's acoustic position")
	var stalker: CharacterBody2D = game.get_node("Stalker")
	var point: Vector2 = patches[0].global_position
	game.player.global_position = point + Vector2(100, 0)
	game.player.flashlight_on = false
	game.player.flashlight_strength = 0.0
	stalker.global_position = point - Vector2(10, 0)
	stalker.state = "leap"
	stalker.sense_timer = 10.0
	stalker.flashlight_contact = false
	stalker.lamp_contact = false
	stalker.attack_cooldown = 0.0
	stalker.glass_contact = CONTACT.new()
	patches[0]._physics_process(patches[0].retrigger_delay)
	game.last_glass_voice = -1
	for voice_name in ["GlassCrunch", "GlassCrunch2", "GlassCrunch3"]: game.get_node(voice_name).stop()
	stalker._physics_process(0.01)
	expect(game.last_glass_voice == 0, "Stalker movement crunches glass too")
	print("RESULT swept glass contacts, short steps, pauses, walls, ownership, authored textures, spatial voices and stalker: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
