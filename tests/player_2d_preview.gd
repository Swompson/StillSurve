extends SceneTree

const WIDTH: int = 1280
const HEIGHT: int = 440
var rigs: Array[Node2D] = []

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.position = Vector2i(-1800, -1400)
	root.size = Vector2i(WIDTH, HEIGHT)
	root.content_scale_size = Vector2i(WIDTH, HEIGHT)
	var backdrop: ColorRect = ColorRect.new()
	backdrop.z_index = -20
	backdrop.color = Color("171e1b")
	backdrop.size = Vector2(WIDTH, HEIGHT)
	root.add_child(backdrop)
	var font: Font = load("res://assets/fonts/sjz/Sjz.otf")
	for index in range(4):
		var rig: Node2D = load("res://scenes/actors/player_body.tscn").instantiate()
		rig.set("preview_mode", true)
		rig.position = Vector2(160 + index * 320, 240)
		rig.scale = Vector2.ONE * 3.4
		root.add_child(rig)
		rig.set("movement", 0.0 if index == 0 else 1.0)
		rig.set("running", 1.0 if index == 2 else 0.0)
		rig.set("travel_direction", Vector2.RIGHT if index == 3 else Vector2.DOWN)
		rigs.append(rig)
		var label: Label = Label.new()
		label.text = ["ПОКОЙ", "ХОДЬБА", "БЕГ", "ШАГ ВБОК"][index]
		label.position = Vector2(index * 320, 34)
		label.size.x = 320
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 27)
		root.add_child(label)
	DirAccess.make_dir_recursive_absolute("res://.godot/player2d_motion")
	var motion: bool = "--motion" in OS.get_cmdline_user_args()
	var stow_demo: bool = "--flashlight" in OS.get_cmdline_user_args()
	var status: Label = Label.new()
	status.position = Vector2(0, HEIGHT - 33)
	status.size.x = WIDTH
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_override("font", font)
	status.add_theme_font_size_override("font_size", 22)
	root.add_child(status)
	for frame in range(120 if motion else 1):
		var progress: float = 1.0
		if stow_demo:
			if frame >= 18 and frame < 39:
				progress = 1.0 - float(frame - 18) / 20.0
				status.text = "ВЫКЛЮЧАЕТ И УБИРАЕТ К ЛЕВОМУ БОКУ"
			elif frame >= 39 and frame < 82:
				progress = 0.0
				status.text = "ОБЕ РУКИ ДВИЖУТСЯ ЕСТЕСТВЕННО"
			elif frame >= 82 and frame < 99:
				progress = float(frame - 82) / 16.0
				status.text = "ДОСТАЁТ ФОНАРЬ"
			else:
				status.text = "ФОНАРЬ В РУКЕ"
		for index in range(4):
			rigs[index].set("preview_flashlight", progress)
			rigs[index].set("phase", (frame * TAU / (15.0 if index == 2 else 24.0)) if motion else 1.25)
			rigs[index].set("breath_clock", frame / 24.0)
			rigs[index].call("pose")
		for settle in range(3 if frame == 0 else 1):
			await process_frame
		await RenderingServer.frame_post_draw
		var path: String = "res://.godot/player2d_motion/%03d.png" % frame if motion else "res://docs/visuals/player_2d_v3.png"
		root.get_texture().get_image().save_png(path)
	print("Saved %s preview of the occluded 2D hero" % ("120-frame animation" if motion else "pose"))
	quit()
