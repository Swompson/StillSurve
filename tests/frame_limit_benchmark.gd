extends SceneTree

var hero: CharacterBody2D
var origin: Vector2
var clock: float = 0.0
var animate: bool = false

func _initialize() -> void:
	call_deferred("run")

func _process(delta: float) -> bool:
	if animate and is_instance_valid(hero) and not paused:
		clock += delta
		hero.global_position = origin + Vector2(sin(clock) * 60.0, cos(clock) * 40.0)
		hero.facing_angle = clock * 0.9
		hero.get_node("Sprite").rotation = hero.facing_angle - PI * 0.5
		hero.update_flashlight()
	return false

func sample(label: String, expected: int) -> bool:
	for frame in range(8): await process_frame
	var started: int = Time.get_ticks_usec()
	var frames: int = 0
	while Time.get_ticks_usec() - started < 1200000:
		await process_frame
		frames += 1
	var fps: float = float(frames) * 1000000.0 / float(Time.get_ticks_usec() - started)
	print("FRAME LIMIT %s: %.1f FPS; Engine.max_fps=%d; low_usage=%s" % [label, fps, Engine.max_fps, OS.low_processor_usage_mode])
	if expected == 15: return fps > 11.0 and fps < 19.0
	return fps > 35.0 and (expected == 0 or fps < expected * 1.15)

func run() -> void:
	print("Display refresh rate: %.1f Hz; physics tick rate: %d" % [DisplayServer.screen_get_refresh_rate(), Engine.physics_ticks_per_second])
	set_meta("hard_mode", true)
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(8): await process_frame
	var budget: Node = root.get_node("RuntimeBudget")
	# The benchmark forces foreground/background states, even in a hidden test window.
	budget.set_process(false)
	budget.mark_focused()
	var game: Node = current_scene
	game.immortal = true
	hero = game.get_node("Player")
	hero.set_physics_process(false)
	hero.velocity = Vector2(100, 0)
	origin = game.get_node("Maze").cell_position(48)
	hero.global_position = origin
	hero.reset_physics_interpolation()
	hero.flashlight_strength = 1.0
	hero.flashlight_reveal = 1.0
	var camera: Camera2D = hero.get_node("Camera")
	camera.position_smoothing_enabled = false
	camera.force_update_scroll()
	game.get_node("Visibility").pose_initialized = false
	for hunter in game.monsters: hunter.set_physics_process(false)
	animate = true
	var success: bool = true
	for limit in [60, 144, 180, 0]:
		budget.set_fps(limit, false)
		success = (await sample(str(limit), limit)) and success
	budget.set_fps(180, false)
	game.get_node("HUD").set_paused(true)
	success = (await sample("paused 180", 180)) and success
	budget.focused = false
	budget.apply_budget()
	success = (await sample("background", 15)) and success
	paused = false
	print("RESULT measured rendering frame limits: ", "PASS" if success else "FAIL")
	quit(0 if success else 1)
