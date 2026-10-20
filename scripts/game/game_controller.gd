extends Node2D

signal glass_crunched(point: Vector2, source: Node)

const TOTAL_FIGURINES: int = 12
var monsters: Array[CharacterBody2D] = []
var hard_mode: bool = false
var survived_seconds: float = 0.0
@onready var maze: Node2D = $Maze
@onready var player: CharacterBody2D = $Player
@onready var monster: CharacterBody2D = $Monster
@onready var hud: CanvasLayer = $HUD
const GLASS_SOUNDS: Array[AudioStream] = [preload("res://assets/audio/user_originals/steklo1.mp3"), preload("res://assets/audio/user_originals/steklo2.mp3"), preload("res://assets/audio/user_originals/steklo3.mp3")]
var last_glass: int = -1
var last_glass_voice: int = -1
var glass_voice_sources: Array[int] = [0, 0, 0]
var collected: int = 0
var finished: bool = false
var won: bool = false
var spawn_cell: int = -1
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var restart_requested: bool = false
var spotted_notice_cooldown: float = 0.0
var immortal: bool = false
var cheat_progress: int = 0
const IMMORTAL_KEYS: Array[int] = [KEY_Q, KEY_A, KEY_Z]

func _ready() -> void:
	RuntimeBudget.set_paused(false)
	var settings: ConfigFile = ConfigFile.new()
	settings.load("user://settings.cfg")
	hard_mode = bool(get_tree().get_meta("hard_mode", settings.get_value("gameplay", "hard_mode", false)))
	rng.randomize()
	if hard_mode:
		var extra_battery: Node = maze.get_node("Pickups/Battery05")
		extra_battery.get_parent().remove_child(extra_battery)
		extra_battery.queue_free()
	var candidates: Array[int] = maze.call("spawn_candidates")
	for pickup in maze.get_node("Pickups").get_children():
		candidates.erase(int(maze.call("cell_at", pickup.global_position)))
	spawn_cell = candidates[rng.randi_range(0, candidates.size() - 1)]
	player.global_position = maze.call("cell_position", spawn_cell)
	player.reset_physics_interpolation()
	var camera: Camera2D = player.get_node("Camera") as Camera2D
	camera.reset_smoothing()
	camera.force_update_scroll()
	player.set("game", self)
	var second: CharacterBody2D = $SecondMonster
	# Give each hunter a different half, with a safe initial distance to the player.
	for index in range(2):
		var hunter: CharacterBody2D = [monster, second][index]
		var side: int = -1 if index == 0 else 1
		hunter.set("patrol_side", side)
		var best_score: float = -INF
		for cell in range(int(maze.get("width")) * int(maze.get("height"))):
			var column: int = cell % int(maze.get("width"))
			var middle: float = float(int(maze.get("width")) - 1) * 0.5
			if (float(column) - middle) * float(side) < 1.0:
				continue
			var point: Vector2 = maze.call("cell_position", cell)
			var score: float = point.distance_to(player.global_position) + rng.randf_range(0.0, 160.0)
			if score > best_score:
				best_score = score
				hunter.global_position = point
	for hunter in [monster, second]:
		hunter.reset_physics_interpolation()
		hunter.set("game", self)
		hunter.set("maze", maze)
		hunter.set("player", player)
		hunter.set("hearing_multiplier", 1.22 if hard_mode else 1.0)
		hunter.set("field_of_view", 125.0 if hard_mode else 105.0)
		monsters.append(hunter)
		hunter.call("choose_patrol_target")
	var stalker: CharacterBody2D = $Stalker
	if hard_mode:
		var stalker_score: float = -1.0
		for cell in range(int(maze.get("width")) * int(maze.get("height"))):
			var point: Vector2 = maze.call("cell_position", cell)
			var score: float = minf(point.distance_to(player.global_position), minf(point.distance_to(monster.global_position), point.distance_to(second.global_position)))
			if score > stalker_score:
				stalker_score = score
				stalker.global_position = point
		stalker.reset_physics_interpolation()
		stalker.call("activate", self, maze, player)
		monsters.append(stalker)
	else:
		stalker.hide()
		stalker.process_mode = Node.PROCESS_MODE_DISABLED
	for pickup in maze.get_node("Pickups").get_children():
		pickup.set("game", self)
	hud.call("bind_game", self)
	hud.call("notify", "Соберите 12 фигурок. Батарейки подбираются автоматически.", 5.0)
	$Heartbeat.stream = $Heartbeat.stream.duplicate()
	($Heartbeat.stream as AudioStreamMP3).loop = true
	$StartGame.play()
	monster.get_node("Growl").call("play_scheduled_howl", true)

func _process(delta: float) -> void:
	spotted_notice_cooldown = maxf(0.0, spotted_notice_cooldown - delta)
	if not finished:
		survived_seconds += delta
		$GameCues.update_context(collected, TOTAL_FIGURINES, float(player.get("battery")))
	update_chase_audio(delta)

func notify_player_spotted(_hunter: Node) -> void:
	if not finished and spotted_notice_cooldown <= 0.0:
		$Danger.play()
		hud.call("notify", "вас увидели", 2.8)
		spotted_notice_cooldown = 3.0

func emit_player_noise(point: Vector2, radius: float) -> void:
	if not finished:
		for hunter in monsters:
			hunter.call("hear_noise", point, radius)

func collect_pickup(pickup: Node2D) -> void:
	if finished or pickup.get("collected"):
		return
	pickup.set("collected", true)
	pickup.hide()
	var clue: Node2D = maze.get_node_or_null("BloodClues/" + String(pickup.name))
	if clue:
		clue.hide()
	if pickup.get("kind") == "battery":
		player.call("add_battery", 20.0)
		hud.call("notify_pickup", "+20 заряда · +10 максимальной выносливости", 3.0)
	else:
		collected += 1
		if collected < TOTAL_FIGURINES: $ToyPickup.play()
		player.call("restore_stamina", 0.25)
		hud.call("notify_pickup", "+25% выносливости", 2.4)
		if collected >= TOTAL_FIGURINES:
			finish(true)
	if not finished:
		$GameCues.update_context(collected, TOTAL_FIGURINES, float(player.get("battery")))

func set_next_hard_mode(enabled: bool) -> void:
	get_tree().set_meta("hard_mode", enabled)
	var settings: ConfigFile = ConfigFile.new()
	settings.load("user://settings.cfg")
	settings.set_value("gameplay", "hard_mode", enabled)
	settings.save("user://settings.cfg")

func kill_player() -> void:
	if not finished and not immortal:
		finish(false)

func finish(victory: bool) -> void:
	if finished:
		return
	finished = true
	won = victory
	for sound in [$Heartbeat, $Danger, $StartGame, $OpeningHowl, $ToyPickup]:
		sound.stop()
	MenuAudio.get_node("StartGameButton").stop()
	$GameCues.finish(victory)
	if not victory:
		$Screamer.play()
	player.set("alive", false)
	player.set("sprinting", false)
	player.call("set_grabbed", false)
	for hunter in monsters:
		hunter.set("active", false)
	hud.call("show_result", victory)

func restart() -> void:
	if restart_requested:
		return
	restart_requested = true
	_reload_scene.call_deferred()

func _reload_scene() -> void:
	get_tree().paused = false
	var error: Error = get_tree().reload_current_scene()
	if error != OK:
		restart_requested = false
		push_error("Could not restart the scene: %s" % error_string(error))

func step_on_glass(point: Vector2, _caused_by_player: bool = true, source: Node = null) -> void:
	if finished:
		return
	var variant: int = randi_range(0, GLASS_SOUNDS.size() - (2 if last_glass >= 0 else 1))
	if variant >= last_glass and last_glass >= 0:
		variant += 1
	last_glass = variant
	var voices: Array[AudioStreamPlayer2D] = [$GlassCrunch, $GlassCrunch2, $GlassCrunch3]
	if not is_instance_valid(source) and _caused_by_player:
		source = player
	var source_id: int = source.get_instance_id() if is_instance_valid(source) else 0
	var voice_index: int = (last_glass_voice + 1) % voices.size()
	for index in range(voices.size()):
		if not voices[index].playing:
			voice_index = index
			break
	# A new footfall replaces this actor's tail; other actors keep their own voices.
	for index in range(voices.size()):
		if source_id != 0 and glass_voice_sources[index] == source_id and voices[index].playing:
			voice_index = index
			break
	last_glass_voice = voice_index
	glass_voice_sources[voice_index] = source_id
	var voice: AudioStreamPlayer2D = voices[voice_index]
	# Independent sources keep their own position and acoustic routing.
	voice.stop()
	voice.global_position = point
	voice.stream = GLASS_SOUNDS[variant]
	voice.play()
	var responders: Array[CharacterBody2D] = []
	for hunter in monsters:
		if hunter != source and hunter.get("active"):
			hunter.call("hear_noise", point, 12000.0)
			if hunter.has_method("assign_investigation_route") and hunter.get("state") == "investigate" and Vector2(hunter.get("last_heard")).is_equal_approx(point):
				responders.append(hunter)
	if responders.size() == 2:
		coordinate_glass_search(responders, point)
	glass_crunched.emit(point, source)

func coordinate_glass_search(responders: Array[CharacterBody2D], point: Vector2) -> void:
	var first_route: PackedVector2Array = maze.call("find_path", responders[0].global_position, point)
	var second_route: PackedVector2Array = maze.call("find_path", responders[1].global_position, point)
	var near_index: int = 0 if route_length(responders[0].global_position, first_route, point) <= route_length(responders[1].global_position, second_route, point) else 1
	var direct_route: PackedVector2Array = first_route if near_index == 0 else second_route
	var farther: CharacterBody2D = responders[1 - near_index]
	var alternate: PackedVector2Array = maze.call("find_alternate_path", farther.global_position, point, direct_route)
	if not alternate.is_empty():
		farther.call("assign_investigation_route", alternate)

func route_length(origin: Vector2, route: PackedVector2Array, point: Vector2) -> float:
	var length: float = 0.0
	for waypoint in route:
		length += origin.distance_to(waypoint)
		origin = waypoint
	return length + origin.distance_to(point)

func _input(event: InputEvent) -> void:
	if finished or get_tree().paused or not event is InputEventKey:
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		cheat_progress = 0
		return
	var code: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode
	if code == KEY_SHIFT:
		return
	if code == IMMORTAL_KEYS[cheat_progress]:
		cheat_progress += 1
	else:
		cheat_progress = 1 if code == KEY_Q else 0
	if cheat_progress == IMMORTAL_KEYS.size():
		cheat_progress = 0
		immortal = not immortal
		hud.call("notify", "Бессмертие включено" if immortal else "Бессмертие выключено", 2.5)

func update_chase_audio(delta: float) -> void:
	var chasing: bool = false
	if not finished:
		for hunter in monsters:
			if hunter.get("active") and hunter.get("state") in ["alert", "hunt"]:
				chasing = true
				break
	var heartbeat: AudioStreamPlayer = $Heartbeat
	if chasing:
		if not heartbeat.playing:
			heartbeat.volume_db = -30.0
			heartbeat.play()
		heartbeat.volume_db = move_toward(heartbeat.volume_db, -8.0, delta * 24.0)
	else:
		heartbeat.volume_db = move_toward(heartbeat.volume_db, -40.0, delta * 30.0)
		if heartbeat.volume_db <= -40.0:
			heartbeat.stop()
