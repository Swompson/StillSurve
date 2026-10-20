extends SceneTree

const SIZE: Vector2i = Vector2i(1100, 760)
const FRAME_DIR: String = "res://.godot/hunter_motion_frames"
var models: Array[Node2D] = []
var floor_lines: Array[Node2D] = []

func _initialize() -> void:
	call_deferred("capture")

func label(text: String, point: Vector2, width: float, size: int = 26) -> void:
	var node: Label = Label.new()
	node.text = text
	node.position = point - Vector2(width * 0.5, 0.0)
	node.size.x = width
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_theme_font_override("font", load("res://assets/fonts/sjz/Sjz.otf"))
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", Color("c2cdc5"))
	root.add_child(node)

func add_model(column: int, magnification: float, center_y: float) -> void:
	var model: Node2D = load("res://scenes/actors/monster_body.tscn").instantiate()
	model.position = Vector2(280 + column * 540, center_y)
	model.scale = Vector2.ONE * magnification
	root.add_child(model)
	model.set_process(false)
	model.set("preview_mode", true)
	models.append(model)

func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.position = Vector2i(-1800, -1400)
	root.size = SIZE
	root.content_scale_size = SIZE
	var background: ColorRect = ColorRect.new()
	background.size = Vector2(SIZE)
	background.color = Color("171e1b")
	background.z_index = -30
	root.add_child(background)
	label("ОХОТНИК · ПОКАЧИВАНИЕ ХВОСТА", Vector2(550, 22), 1080)
	label("ХОДЬБА", Vector2(280, 76), 480)
	label("БЕГ", Vector2(820, 76), 480)
	label("УВЕЛИЧЕНО · ЗАМЕДЛЕНО ДЛЯ ПРОВЕРКИ ДВИЖЕНИЯ", Vector2(550, 532), 1080, 23)
	label("ИГРОВОЙ МАСШТАБ · 1:1", Vector2(550, 578), 1080, 24)
	for column in range(2):
		var marks: Node2D = Node2D.new()
		marks.z_index = -20
		root.add_child(marks)
		floor_lines.append(marks)
		for index in range(9):
			var line: Line2D = Line2D.new()
			line.width = 1.0
			line.default_color = Color(0.22, 0.28, 0.24, 0.24)
			line.points = PackedVector2Array([Vector2(60 + column * 540, 0), Vector2(500 + column * 540, 0)])
			marks.add_child(line)
		add_model(column, 3.0, 310)
	for column in range(2):
		add_model(column, 1.0, 670)
	DirAccess.make_dir_recursive_absolute(FRAME_DIR)
	for frame in range(48):
		for index in range(models.size()):
			var running: bool = index % 2 == 1
			var cycles: float = float(frame) / 48.0 * (4.0 if running else 2.0)
			var model: Node2D = models[index]
			model.set("preview_state", "run" if running else "walk")
			model.set("movement", 1.0)
			model.set("running", 1.0 if running else 0.0)
			model.set("travel_direction", Vector2.DOWN)
			model.set("phase", fposmod(cycles, 1.0) * TAU)
			model.set("tail_phase", fposmod(cycles * 0.5, 1.0) * TAU)
			model.call("pose")
			if index < 2:
				var traveled: float = cycles * float(model.call("stride_length")) * 3.0
				for line_index in range(9):
					floor_lines[index].get_child(line_index).position.y = 150.0 + fposmod(line_index * 40.0 - traveled, 360.0)
		for settle in range(3 if frame == 0 else 1):
			await process_frame
		await RenderingServer.frame_post_draw
		var picture: Image = root.get_texture().get_image()
		assert(picture.save_png("%s/%03d.png" % [FRAME_DIR, frame]) == OK)
		if frame == 7:
			picture.save_png("res://docs/visuals/hunter_tail_wag.png")
	print("Saved 48 hunter motion inspection frames")
	quit()
