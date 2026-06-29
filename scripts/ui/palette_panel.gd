extends PanelContainer

@onready var flow: HFlowContainer = %Flow


func _ready() -> void:
	add_to_group("palette")
	refresh()
	EventBus.element_unlocked.connect(func(_k): refresh())
	EventBus.element_discovered.connect(func(_k): refresh())


func refresh() -> void:
	for child in flow.get_children():
		child.queue_free()
	for key in ElementDB.get_all_keys():
		if int(ElementDB.get_element(key).act) > GameState.current_act + 1:
			continue
		if not GameState.unlocked_elements.get(key, false):
			if Encyclopedia.get_element_visibility(key) == Encyclopedia.Visibility.LOCKED:
				continue
		var btn := Button.new()
		btn.toggle_mode = true
		btn.text = Encyclopedia.get_display_name(key)
		btn.modulate = Encyclopedia.get_display_color(key)
		btn.disabled = not GameState.unlocked_elements.get(key, false)
		btn.tooltip_text = Encyclopedia.get_description(key)
		btn.pressed.connect(_select.bind(key, btn))
		if key == GameState.selected_element and GameState.unlocked_elements.get(key, false):
			btn.button_pressed = true
			btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
		flow.add_child(btn)


func _select(key: String, btn: Button) -> void:
	if not GameState.unlocked_elements.get(key, false):
		return
	GameState.selected_element = key
	for child in flow.get_children():
		if child is Button:
			var selected := child == btn
			child.button_pressed = selected
			if selected:
				child.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
			else:
				child.remove_theme_color_override("font_color")
