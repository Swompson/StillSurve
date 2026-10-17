extends SceneTree
var failures: int = 0
func expect(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)
func _initialize() -> void:
	call_deferred("run_checks")
func run_checks() -> void:
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(5): await process_frame
	var game: Node = current_scene
	var player: Node2D = game.get_node("Player")
	var monster: Node2D = game.get_node("Monster")
	player.set_physics_process(false)
	monster.set_physics_process(false)
	monster.global_position = player.global_position + Vector2(1000, 0)
	player.set("battery", player.get("battery_max") * 0.25)
	player.call("update_flicker", 0.01)
	expect(player.get("flicker_multiplier") < 1.0, "Flicker at exactly 25 percent")
	player.set("battery", player.get("battery_max"))
	player.call("update_flicker", 0.01)
	expect(player.get("flicker_multiplier") == 1.0, "Full charge outside danger is steady")
	monster.global_position = player.global_position + Vector2(200, 0)
	player.call("update_flicker", 0.01)
	expect(player.get("flicker_multiplier") < 1.0, "Close monster causes flicker at full charge")
	var previous: int = -1
	for index in range(40):
		game.call("step_on_glass", player.global_position)
		var variant: int = game.get("last_glass")
		expect(variant != previous and variant >= 0 and variant < 3, "Glass variant excludes previous")
		previous = variant
	var sound: Node = monster.get_node("MonsterAudio") if monster.has_node("MonsterAudio") else monster.find_child("*", true, false)
	for child in monster.get_children():
		if child.get_script() == load("res://scripts/audio/monster_audio.gd"): sound = child
	previous = -1
	for index in range(30):
		sound.set("howl_timer", 0.0)
		sound.call("_process", 0.01)
		var variant: int = sound.get("last_howl")
		expect(variant != previous and variant >= 0 and variant < 5, "Howls exclude previous")
		expect(sound.get("howl_timer") >= 26.0 and sound.get("howl_timer") <= 40.0, "Howl interval 26 to 40 seconds")
		previous = variant
	expect(get_nodes_in_group("glass_patches").size() == 13, "Glass patches persist in scene")
	var hud: Node = game.get_node("HUD")
	hud.get("notices").clear()
	hud.get("pending_notices").clear()
	for label in hud.get("notice_labels"): label.text = ""
	for text in ["First", "Second", "Third"]: hud.call("notify", text, 4.0)
	var before: float = hud.get("notices")[0].y
	hud.call("update_notices", 0.1)
	expect(hud.get("notices")[0].y < before, "Notice rises from below")
	expect(hud.get("notices")[0].y < hud.get("notices")[1].y, "FIFO rows run top to bottom")
	print("RESULT requested polish: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
