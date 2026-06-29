extends PanelContainer

@onready var list: VBoxContainer = %UpgradeList


func _ready() -> void:
	visible = false
	_rebuild()
	EventBus.insight_changed.connect(func(_v): _rebuild())
	EventBus.seismic_upgraded.connect(func(_k, _l): _rebuild())


func toggle() -> void:
	visible = not visible
	if visible:
		_rebuild()


func _rebuild() -> void:
	for child in list.get_children():
		child.queue_free()
	var defs := {
		"timer": "Chronometer (+5s/run)",
		"budget": "Particle Budget (+50/run)",
		"brush": "Brush Size (+1)",
		"insight_rate": "Observation Array (+insight/s)",
	}
	for key in defs.keys():
		var row := HBoxContainer.new()
		var label := Label.new()
		var level := GameState.get_seismic_level(key)
		var cost := GameState.get_seismic_cost(key)
		label.text = "%s  Lv.%d" % [defs[key], level]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var btn := Button.new()
		if cost < 0:
			btn.text = "MAX"
			btn.disabled = true
		else:
			btn.text = "Buy (%d)" % cost
			btn.disabled = GameState.insight < cost
			btn.pressed.connect(_purchase.bind(key))
		row.add_child(label)
		row.add_child(btn)
		list.add_child(row)
	_add_separator("Unlock Elements")
	for key in ElementDB.get_keys_for_act(1):
		if GameState.unlocked_elements.get(key, false):
			continue
		var entry := ElementDB.get_element(key)
		var cost := int(entry.get("insight_unlock_cost", 0))
		if cost <= 0 and not entry.has("auto_unlock"):
			continue
		if entry.has("auto_unlock"):
			continue
		var row2 := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "Unlock %s" % entry.name
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var btn2 := Button.new()
		btn2.text = "%d Insight" % cost
		btn2.disabled = GameState.insight < cost
		btn2.pressed.connect(_unlock_element.bind(key))
		row2.add_child(lbl)
		row2.add_child(btn2)
		list.add_child(row2)


func _add_separator(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.9))
	list.add_child(lbl)


func _purchase(key: String) -> void:
	if GameState.purchase_seismic(key):
		EventBus.toast.emit("Seismic upgrade purchased!")
		_rebuild()


func _unlock_element(key: String) -> void:
	if GameState.purchase_element_unlock(key):
		EventBus.toast.emit("Unlocked %s!" % ElementDB.get_element(key).name)
		_rebuild()
		get_tree().call_group("palette", "refresh")
