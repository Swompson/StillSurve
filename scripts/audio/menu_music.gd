extends Node

signal track_changed(index: int)

# Skip the measured leading silence without re-encoding the original recording.
const START_BUTTON_OFFSET_SECONDS: float = 0.492

const TRACKS: Array[String] = [
	"res://assets/ui/menu/main_menu_music.mp3",
	"res://assets/ui/menu/main_menu_music1.mp3",
	"res://assets/ui/menu/main_menu_music2.mp3",
	"res://assets/ui/menu/main_menu_music3.mp3",
]
var selected_track: int = 0
var menu_active: bool = false

func _ready() -> void:
	var settings: ConfigFile = ConfigFile.new()
	settings.load("user://settings.cfg")
	selected_track = clampi(int(settings.get_value("audio", "menu_music", 0)), 0, TRACKS.size() - 1)

func select_track(index: int) -> void:
	selected_track = clampi(index, 0, TRACKS.size() - 1)
	RuntimeBudget.save_preference("audio", "menu_music", selected_track)
	if menu_active: play_selected()
	track_changed.emit(selected_track)

func play_start_confirmation() -> void:
	$StartGameButton.play(START_BUTTON_OFFSET_SECONDS)

func set_menu_active(enabled: bool) -> void:
	menu_active = enabled
	if enabled:
		$StartGameButton.stop()
		play_selected()
	else: $Music.stop()

func play_selected() -> void:
	var stream: AudioStreamMP3 = load(TRACKS[selected_track])
	stream.loop = true
	$Music.stream = stream
	$Music.play()
