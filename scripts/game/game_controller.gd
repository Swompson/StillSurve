extends Node2D

const TOTAL_FIGURINES: int = 12
const MONSTER_SCENE = preload("res://scenes/actors/monster.tscn")
var monsters: Array[CharacterBody2D] = []
var hard_mode: bool = false
var second_monster_spawned: bool = false
var survived_seconds: float = 0.0
@onready var maze: Node2D = $Maze
@onready var player: CharacterBody2D = $Player
@onready var monster: CharacterBody2D = $Monster
@onready var hud: CanvasLayer = $HUD
var collected: int = 0
var finished: bool = false
var won: bool = false
var spawn_cell: int = -1
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var restart_requested: bool = false

func _ready() -> void:
	var settings: ConfigFile = ConfigFile.new()
	settings.load("user://settings.cfg")
	hard_mode = bool(get_tree().get_meta("hard_mode", settings.get_value("gameplay", "hard_mode", false)))
	rng.randomize()
	var candidates: Array[int] = maze.call("spawn_candidates")
	for pickup in maze.get_node("Pickups").get_children():
		candidates.erase(int(maze.call("cell_at", pickup.position)))
	spawn_cell = candidates[rng.randi_range(0, candidates.size() - 1)]
	player.global_position = maze.call("cell_position", spawn_cell)
	var camera: Camera2D = player.get_node("Camera") as Camera2D
	camera.reset_smoothing()
	camera.force_update_scroll()
	player.set("game", self)
	monster.global_position = Vector2.ZERO
	monster.set("game", self)
	monster.set("maze", maze)
	monster.set("player", player)
	monsters.append(monster)
	for pickup in maze.get_node("Pickups").get_children():
		pickup.set("game", self)
	hud.call("bind_game", self)
	hud.call("notify", "Соберите 12 фигурок. Батарейки подбираются автоматически.", 5.0)

func _process(delta: float) -> void:
	if not finished:
		survived_seconds += delta

func emit_player_noise(point: Vector2, radius: float) -> void:
	if not finished:
		for hunter in monsters:
			hunter.call("hear_noise", point, radius)

func collect_pickup(pickup: Node2D) -> void:
	if finished or pickup.get("collected"):
		return
	pickup.set("collected", true)
	pickup.hide()
	if pickup.get("kind") == "battery":
		player.call("add_battery", 50.0)
		hud.call("notify", "Батарейка: +50% заряда · +10 к максимуму выносливости", 3.0)
	else:
		collected += 1
		if hard_mode and collected >= TOTAL_FIGURINES / 2 and not second_monster_spawned:
			spawn_second_monster()
		player.call("restore_stamina", 0.25)
		hud.call("notify", "Фигурка: %d / %d · +25%% выносливости" % [collected, TOTAL_FIGURINES], 2.4)
		if collected >= TOTAL_FIGURINES:
			finish(true)

func spawn_second_monster() -> void:
	second_monster_spawned = true
	var spawn: Vector2 = Vector2.ZERO
	var best_distance: float = -1.0
	for cell in range(int(maze.get("width")) * int(maze.get("height"))):
		var point: Vector2 = maze.call("cell_position", cell)
		var distance: float = point.distance_to(player.global_position)
		if distance > best_distance:
			best_distance = distance
			spawn = point
	var hunter: CharacterBody2D = MONSTER_SCENE.instantiate() as CharacterBody2D
	hunter.name = "SecondMonster"
	hunter.position = maze.to_global(spawn) - global_position
	hunter.set("game", self)
	hunter.set("maze", maze)
	hunter.set("player", player)
	add_child(hunter)
	monsters.append(hunter)
	hud.call_deferred("notify", "Вы разбудили ещё одного. Теперь их двое.", 5.0)

func set_next_hard_mode(enabled: bool) -> void:
	get_tree().set_meta("hard_mode", enabled)
	var settings: ConfigFile = ConfigFile.new()
	settings.load("user://settings.cfg")
	settings.set_value("gameplay", "hard_mode", enabled)
	settings.save("user://settings.cfg")

func kill_player() -> void:
	if not finished:
		finish(false)

func finish(victory: bool) -> void:
	finished = true
	won = victory
	player.set("alive", false)
	player.set("sprinting", false)
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
