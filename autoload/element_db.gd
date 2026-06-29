extends Node

const EMPTY := 0

var _by_key: Dictionary = {}
var _by_id: Dictionary = {}
var _key_order: Array[String] = []


func _ready() -> void:
	_load()


func _load() -> void:
	var file := FileAccess.open("res://data/elements.json", FileAccess.READ)
	if file == null:
		push_error("ElementDB: failed to open elements.json")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("ElementDB: invalid JSON")
		return
	var keys: Array = parsed.keys()
	keys.sort_custom(func(a, b): return int(parsed[a]["unlock_order"]) < int(parsed[b]["unlock_order"]))
	for key in keys:
		var entry: Dictionary = parsed[key]
		entry["key"] = key
		_by_key[key] = entry
		_by_id[int(entry.id)] = entry
		_key_order.append(key)


func get_key_for_id(material_id: int) -> String:
	if _by_id.has(material_id):
		return _by_id[material_id].key
	return ""


func get_id(key: String) -> int:
	if _by_key.has(key):
		return int(_by_key[key].id)
	return EMPTY


func get_element(key: String) -> Dictionary:
	return _by_key.get(key, {})


func get_by_id(material_id: int) -> Dictionary:
	return _by_id.get(material_id, {})


func get_all_keys() -> Array[String]:
	return _key_order.duplicate()


func get_keys_for_act(act: int) -> Array[String]:
	var result: Array[String] = []
	for key in _key_order:
		if int(_by_key[key].act) == act:
			result.append(key)
	return result


func get_color(key: String) -> Color:
	var entry := get_element(key)
	if entry.is_empty():
		return Color.WHITE
	return Color.html(entry.color)


func get_density(key: String) -> int:
	return int(get_element(key).get("density", 5))


func is_flammable(key: String) -> bool:
	return bool(get_element(key).get("flammable", false))


func get_element_class(key: String) -> String:
	return str(get_element(key).get("class", "POWDER"))
