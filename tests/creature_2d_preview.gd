extends SceneTree

const WIDTH: int = 1440
const HEIGHT: int = 1600
const CELL_WIDTH: float = 360.0
const BODY_PATHS: Array[String] = [
	"res://scenes/actors/player_body.tscn",
	"res://scenes/actors/monster_body.tscn",
	"res://scenes/actors/stalker_body.tscn",
]
const OUTPUT_PATH: String = "res://docs/visuals/creature_2d_v6.png"
const FRAME_PATH: String = "res://.godot/creature_v6_preview_frames"

var rigs: Array[Node2D] = []
var poses: Array[String] = []
var directions: Array[Vector2] = []
var scales: Array[float] = []
var font: Font

func _initialize() -> void:
	call_deferred("capture")

func add_label(text: String, point: Vector2, width: float, font_size: int = 24, tint: Color = Color("c2cdc5")) -> void:
	var label: Label = Label.new()
	label.text = text
	label.position = point
	label.size.x = width
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	root.add_child(label)

func add_body(path: String, state: String, point: Vector2, direction: Vector2 = Vector2.DOWN, body_scale: float = 2.35) -> void:
	var rig: Node2D = load(path).instantiate() as Node2D
	rig.set("preview_mode", true)
	rig.set("preview_animation", false)
	rig.position = point
	root.add_child(rig)
	rig.call("setup", null, true)
	rig.set_process(false)
	rigs.append(rig)
	poses.append(state)
	directions.append(direction)
	scales.append(body_scale)

func update_pose(index: int, cycle: float, seconds: float) -> void:
	var rig: Node2D = rigs[index]
	var state: String = poses[index]
	rig.set("preview_state", state)
	rig.set("movement", 0.0 if state in ["idle", "leap", "grab"] else 1.0)
	rig.set("running", 1.0 if state == "run" else 0.0)
	rig.set("travel_direction", directions[index])
	rig.set("phase", cycle * TAU)
	if "tail_phase" in rig:
		rig.set("tail_phase", cycle * TAU * 0.5)
	if "breath_clock" in rig:
		rig.set("breath_clock", seconds)
	rig.call("pose")
	# The attack scales its own root; apply the comparison magnification afterward.
	rig.scale *= scales[index]

func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Run creature_2d_preview.gd with a rendering display, without --headless")
		quit(1)
		return
	root.mode = Window.MODE_WINDOWED
	root.position = Vector2i(-1800, -1400)
	root.size = Vector2i(WIDTH, HEIGHT)
	root.content_scale_size = Vector2i(WIDTH, HEIGHT)
	var backdrop: ColorRect = ColorRect.new()
	backdrop.z_index = -20
	backdrop.color = Color("171e1b")
	backdrop.size = Vector2(WIDTH, HEIGHT)
	root.add_child(backdrop)
	font = load("res://assets/fonts/sjz/Sjz.otf")
	add_label("ЕДИНАЯ ПРОЕКЦИЯ И СБОРКА КОНЕЧНОСТЕЙ", Vector2(0, 20), WIDTH, 30)
	for column in range(3):
		add_label(["ГЛАВНЫЙ ГЕРОЙ", "ОХОТНИК", "СТАЛКЕР"][column], Vector2(300 + column * CELL_WIDTH, 76), CELL_WIDTH, 26)
	for row in range(3):
		var center_y: float = 280.0 + row * 280.0
		add_label(["ПОКОЙ", "ХОДЬБА", "БЕГ"][row], Vector2(4, center_y - 15), 260, 26)
		for column in range(3):
			add_body(BODY_PATHS[column], ["idle", "walk", "run"][row], Vector2(480 + column * CELL_WIDTH, center_y))
	var divider: ColorRect = ColorRect.new()
	divider.position = Vector2(60, 995)
	divider.size = Vector2(WIDTH - 120, 1)
	divider.color = Color("36453a")
	root.add_child(divider)
	add_label("СТАЛКЕР — СВЯЗАННЫЕ ПОЗЫ АТАКИ", Vector2(0, 1020), WIDTH, 26)
	add_body(BODY_PATHS[2], "leap", Vector2(480, 1170), Vector2.DOWN, 2.1)
	add_body(BODY_PATHS[2], "grab", Vector2(960, 1170), Vector2.DOWN, 2.1)
	add_label("ПРЫЖОК", Vector2(300, 1290), CELL_WIDTH, 24)
	add_label("ЗАХВАТ", Vector2(780, 1290), CELL_WIDTH, 24)
	add_label("ИГРОВОЙ РАЗМЕР · 1:1", Vector2(0, 1370), WIDTH, 26)
	for column in range(3):
		add_body(BODY_PATHS[column], "walk", Vector2(480 + column * CELL_WIDTH, 1510), Vector2.DOWN, 1.0)
	DirAccess.make_dir_recursive_absolute("res://docs/visuals")
	DirAccess.make_dir_recursive_absolute(FRAME_PATH)
	var motion: bool = "--motion" in OS.get_cmdline_user_args()
	for frame in range(32 if motion else 1):
		var cycle: float = float(frame) / 32.0 if motion else 0.21
		for index in range(rigs.size()):
			# Non-stalker rigs do not reset their own root scale during posing.
			rigs[index].scale = Vector2.ONE
			update_pose(index, cycle, frame / 24.0)
		for settle in range(3 if frame == 0 else 1):
			await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		var path: String = "%s/%03d.png" % [FRAME_PATH, frame] if motion else OUTPUT_PATH
		var error: Error = image.save_png(path)
		if error != OK:
			push_error("Failed to save creature preview: %s (%d)" % [path, error])
			quit(1)
			return
		if motion and frame == 7:
			image.save_png(OUTPUT_PATH)
	print("Saved %s at %s" % ["32 creature animation frames" if motion else "hero/hunter/stalker comparison", FRAME_PATH if motion else OUTPUT_PATH])
	quit()
