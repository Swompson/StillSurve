@tool
extends TextureRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	fit_to_text()
	get_parent().resized.connect(fit_to_text)
	get_parent().theme_changed.connect(fit_to_text)

func fit_to_text() -> void:
	var button: Button = get_parent() as Button
	if button == null: return
	var font: Font = button.get_theme_font("font")
	var font_size: int = button.get_theme_font_size("font_size")
	# Scene builders run outside the tree, before Godot propagates themes.
	if not button.is_inside_tree():
		var ancestor: Control = button
		while ancestor != null:
			if ancestor.theme != null:
				if ancestor.theme.default_font != null: font = ancestor.theme.default_font
				if ancestor.theme.default_font_size > 0: font_size = ancestor.theme.default_font_size
				break
			ancestor = ancestor.get_parent() as Control
		if button.has_theme_font_override("font"): font = button.get_theme_font("font")
		if button.has_theme_font_size_override("font_size"): font_size = button.get_theme_font_size("font_size")
	var text_width: float = font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	# Center the saved texture on the caption, independent of the clickable row.
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left = -text_width * 0.5 - 24.0
	offset_right = text_width * 0.5 + 24.0
	offset_top = -font_size * 0.5 - 12.0
	offset_bottom = font_size * 0.5 + 12.0

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		modulate.a = 0.65 if get_parent().name == "Resume" else 0.0
		return
	var button: BaseButton = get_parent() as BaseButton
	if not button.is_visible_in_tree(): return
	var active: bool = button.is_hovered() or button.button_pressed
	if button.toggle_mode:
		active = button.is_hovered() or button.button_pressed
	if button.has_focus() and not button.toggle_mode:
		active = true
	var target_alpha: float = 1.15 if active else 0.0
	if is_equal_approx(modulate.a, target_alpha): return
	var next_alpha: float = lerpf(modulate.a, target_alpha, 1.0 - exp(-delta * 14.0))
	modulate.a = target_alpha if absf(next_alpha - target_alpha) < 0.001 else next_alpha
