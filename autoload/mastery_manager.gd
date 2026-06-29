extends Node

var _upgrade_defs: Dictionary = {}
var _xp: Dictionary = {}
var _levels: Dictionary = {}
var _upgrade_levels: Dictionary = {}


func _ready() -> void:
	_load_defs()


func _load_defs() -> void:
	var file := FileAccess.open("res://data/element_upgrades.json", FileAccess.READ)
	if file == null:
		push_error("MasteryManager: failed to open element_upgrades.json")
		return
	_upgrade_defs = JSON.parse_string(file.get_as_text())


func xp_for_level(level: int) -> int:
	return int(floor(50.0 * pow(1.18, level)))


func get_xp(element_key: String) -> int:
	return int(_xp.get(element_key, 0))


func get_level(element_key: String) -> int:
	return int(_levels.get(element_key, 0))


func get_upgrade_level(element_key: String, upgrade_id: String) -> int:
	return int(_upgrade_levels.get("%s:%s" % [element_key, upgrade_id], 0))


func get_upgrades_for(element_key: String) -> Array:
	return _upgrade_defs.get(element_key, [])


func add_xp(element_key: String, amount: int) -> void:
	if amount <= 0 or element_key.is_empty():
		return
	var total := get_xp(element_key) + amount
	_xp[element_key] = total
	var leveled := false
	while get_xp(element_key) >= xp_for_level(get_level(element_key)):
		_xp[element_key] = get_xp(element_key) - xp_for_level(get_level(element_key))
		_levels[element_key] = get_level(element_key) + 1
		leveled = true
	EventBus.mastery_changed.emit(element_key, get_level(element_key), get_xp(element_key))
	if leveled:
		EventBus.toast.emit("%s mastery level %d!" % [ElementDB.get_element(element_key).get("name", element_key), get_level(element_key)])


func get_upgrade_cost(element_key: String, upgrade_id: String) -> int:
	for upgrade in get_upgrades_for(element_key):
		if upgrade.id == upgrade_id:
			var lvl := get_upgrade_level(element_key, upgrade_id)
			if lvl >= int(upgrade.max_level):
				return -1
			return int(floor(float(upgrade.base_cost) * pow(float(upgrade.cost_growth), lvl)))
	return -1


func purchase_upgrade(element_key: String, upgrade_id: String) -> bool:
	var cost := get_upgrade_cost(element_key, upgrade_id)
	if cost < 0:
		return false
	if get_xp(element_key) < cost:
		return false
	_xp[element_key] = get_xp(element_key) - cost
	var compound := "%s:%s" % [element_key, upgrade_id]
	_upgrade_levels[compound] = get_upgrade_level(element_key, upgrade_id) + 1
	EventBus.mastery_changed.emit(element_key, get_level(element_key), get_xp(element_key))
	EventBus.mastery_upgrade_purchased.emit(element_key, upgrade_id, get_upgrade_level(element_key, upgrade_id))
	SaveManager.save_game()
	return true


func get_effect(element_key: String, upgrade_id: String) -> float:
	for upgrade in get_upgrades_for(element_key):
		if upgrade.id == upgrade_id:
			return float(upgrade.effect_per_level) * float(get_upgrade_level(element_key, upgrade_id))
	return 0.0


func placement_cost_multiplier(element_key: String) -> float:
	return maxf(0.2, 1.0 - get_effect(element_key, "sand_fine"))


func reaction_chance_bonus(element_key: String) -> float:
	var bonus := 0.0
	bonus += get_effect(element_key, "watr_react")
	bonus += get_effect(element_key, "oil_volatile")
	bonus += get_effect(element_key, "acid_strong")
	return bonus


func fire_spread_bonus(element_key: String) -> float:
	return get_effect(element_key, "fire_spread")


func fire_life_bonus(element_key: String) -> int:
	return int(get_effect(element_key, "fire_life"))


func water_spread_bonus(element_key: String) -> float:
	return get_effect(element_key, "watr_spread")


func get_save_data() -> Dictionary:
	return {
		"xp": _xp.duplicate(),
		"levels": _levels.duplicate(),
		"upgrade_levels": _upgrade_levels.duplicate(),
	}


func apply_save_data(data: Dictionary) -> void:
	_xp = data.get("xp", {}).duplicate()
	_levels = data.get("levels", {}).duplicate()
	_upgrade_levels = data.get("upgrade_levels", {}).duplicate()
