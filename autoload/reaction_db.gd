extends Node

var _reactions: Array[Dictionary] = []
var _pair_index: Dictionary = {}


func _ready() -> void:
	_load()


func _load() -> void:
	var file := FileAccess.open("res://data/reactions.json", FileAccess.READ)
	if file == null:
		push_error("ReactionDB: failed to open reactions.json")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_error("ReactionDB: expected array")
		return
	for reaction in parsed:
		_reactions.append(reaction)
		var k := _pair_key(str(reaction.elem1), str(reaction.elem2))
		if not _pair_index.has(k):
			_pair_index[k] = []
		_pair_index[k].append(reaction)


func _pair_key(a: String, b: String) -> String:
	if a <= b:
		return "%s|%s" % [a, b]
	return "%s|%s" % [b, a]


func get_all() -> Array[Dictionary]:
	return _reactions


func find_reaction(key_a: String, key_b: String) -> Dictionary:
	var list: Array = _pair_index.get(_pair_key(key_a, key_b), [])
	if list.is_empty():
		return {}
	for reaction in list:
		var e1: String = reaction.elem1
		var e2: String = reaction.elem2
		if (e1 == key_a and e2 == key_b) or (e1 == key_b and e2 == key_a):
			return reaction
		if reaction.get("oneway", false):
			if e1 == key_a and e2 == key_b:
				return reaction
	return {}


func get_reactions_for_element(key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for reaction in _reactions:
		if reaction.elem1 == key or reaction.elem2 == key:
			result.append(reaction)
	return result


func get_reactions_between(act: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for reaction in _reactions:
		if int(reaction.act) == act:
			result.append(reaction)
	return result
