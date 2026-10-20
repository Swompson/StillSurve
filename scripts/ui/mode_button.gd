extends Button

func _make_custom_tooltip(description: String) -> Object:
	var popup: PanelContainer = preload("res://scenes/ui/mode_tooltip.tscn").instantiate()
	var lines: PackedStringArray = description.split("\n", true, 1)
	popup.get_node("Content/Title").text = lines[0]
	popup.get_node("Content/Description").text = lines[1] if lines.size() > 1 else ""
	return popup
