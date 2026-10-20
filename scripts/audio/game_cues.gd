extends Node

signal cue_changed(cue: StringName)

const CONTEXTS: Array[StringName] = [&"NoBattery", &"PreEnd", &"PreLateNoLight"]
const FADE_IN_SECONDS: float = 4.0
const CROSSFADE_SECONDS: float = 2.0
const FADE_OUT_SECONDS: float = 1.5
const END_FADE_SECONDS: float = 0.35
var current_cue: StringName = &""
var ended: bool = false
var transition: Tween
var target_levels: Dictionary[StringName, float] = {}

func _ready() -> void:
	for cue in CONTEXTS:
		var sound: AudioStreamPlayer = get_node(NodePath(cue))
		target_levels[cue] = sound.volume_linear
		# Loop only these scene-local copies; keep the user's recordings untouched.
		sound.stream = sound.stream.duplicate()
		sound.stream.loop = true

func update_context(collected: int, total: int, charge: float) -> void:
	if ended: return
	var late: bool = total - collected <= 3 and collected < total
	var empty: bool = charge <= 0.0
	var desired: StringName = &"PreLateNoLight" if late and empty else (&"PreEnd" if late else (&"NoBattery" if empty else &""))
	if desired != current_cue: change_context(desired)

func change_context(cue: StringName) -> void:
	var previous: StringName = current_cue
	current_cue = cue
	if is_instance_valid(transition): transition.kill()
	transition = create_tween().set_parallel(true)
	transition.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var duration: float = FADE_IN_SECONDS if previous == &"" else CROSSFADE_SECONDS
	if cue == &"": duration = END_FADE_SECONDS if ended else FADE_OUT_SECONDS
	for name in CONTEXTS:
		var sound: AudioStreamPlayer = get_node(NodePath(name))
		if name == cue:
			if not sound.playing:
				sound.volume_linear = 0.0
				sound.play()
			# Fade amplitude from true silence without a first-frame jump.
			transition.tween_property(sound, "volume_linear", target_levels[name], duration)
		else:
			transition.tween_property(sound, "volume_linear", 0.0, duration)
			transition.tween_callback(sound.stop).set_delay(duration)
	cue_changed.emit(cue)

func finish(victory: bool) -> void:
	if ended: return
	ended = true
	change_context(&"")
	if victory: $AllCollected.play()
