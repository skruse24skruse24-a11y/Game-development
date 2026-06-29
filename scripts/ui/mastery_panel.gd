extends PanelContainer

@onready var element_option: OptionButton = %ElementOption
@onready var upgrade_list: VBoxContainer = %MasteryUpgradeList


func _ready() -> void:
	visible = false
	element_option.item_selected.connect(_on_element_selected)
	EventBus.mastery_changed.connect(func(_k, _l, _x): _refresh_upgrades())
	_refresh_elements()


func toggle() -> void:
	visible = not visible
	if visible:
		_refresh_elements()


func _refresh_elements() -> void:
	element_option.clear()
	for key in ElementDB.get_all_keys():
		if not GameState.unlocked_elements.get(key, false):
			continue
		var idx := element_option.item_count
		element_option.add_item(Encyclopedia.get_display_name(key), idx)
		element_option.set_item_metadata(idx, key)
	if element_option.item_count > 0:
		_on_element_selected(0)


func _on_element_selected(index: int) -> void:
	_refresh_upgrades()


func _current_element() -> String:
	var idx := element_option.selected
	if idx < 0:
		return ""
	return str(element_option.get_item_metadata(idx))


func _refresh_upgrades() -> void:
	for child in upgrade_list.get_children():
		child.queue_free()
	var key := _current_element()
	if key.is_empty():
		return
	var header := Label.new()
	header.text = "Mastery Lv.%d  XP: %d" % [MasteryManager.get_level(key), MasteryManager.get_xp(key)]
	upgrade_list.add_child(header)
	for upgrade in MasteryManager.get_upgrades_for(key):
		var row := HBoxContainer.new()
		var lbl := Label.new()
		var lvl := MasteryManager.get_upgrade_level(key, upgrade.id)
		lbl.text = "%s (%d/%d)" % [upgrade.name, lvl, upgrade.max_level]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var btn := Button.new()
		var cost := MasteryManager.get_upgrade_cost(key, upgrade.id)
		if cost < 0:
			btn.text = "MAX"
			btn.disabled = true
		else:
			btn.text = "%d XP" % cost
			btn.disabled = MasteryManager.get_xp(key) < cost
			btn.pressed.connect(_buy.bind(key, upgrade.id))
		row.add_child(lbl)
		row.add_child(btn)
		upgrade_list.add_child(row)


func _buy(element_key: String, upgrade_id: String) -> void:
	if MasteryManager.purchase_upgrade(element_key, upgrade_id):
		EventBus.toast.emit("Mastery upgrade!")
		_refresh_upgrades()
