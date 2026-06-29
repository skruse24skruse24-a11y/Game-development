extends Node

enum Visibility { DISCOVERED, UNLOCKED, HINTED, LOCKED }

const ACT_NAMES := {
	1: "Create Reactions",
	2: "Create Cellular Life",
	3: "Create Organisms",
	4: "Create Intelligent Life",
	5: "Create Society",
	6: "Create Advanced Society",
	7: "Create the Singularity",
}


func _ready() -> void:
	EventBus.element_discovered.connect(func(_k): EventBus.encyclopedia_updated.emit())
	EventBus.element_unlocked.connect(func(_k): EventBus.encyclopedia_updated.emit())


func get_element_visibility(element_key: String) -> Visibility:
	var entry := ElementDB.get_element(element_key)
	if entry.is_empty():
		return Visibility.LOCKED
	if GameState.unlocked_elements.get(element_key, false):
		return Visibility.UNLOCKED
	if GameState.discovered_elements.get(element_key, false):
		return Visibility.DISCOVERED
	if _is_hinted(element_key):
		return Visibility.HINTED
	return Visibility.LOCKED


func _is_hinted(element_key: String) -> bool:
	var entry := ElementDB.get_element(element_key)
	if entry.is_empty():
		return false
	var act := int(entry.act)
	if act > GameState.current_act + 1:
		return false
	var order := int(entry.unlock_order)
	for key in ElementDB.get_all_keys():
		var other := ElementDB.get_element(key)
		if int(other.act) != act:
			continue
		if int(other.unlock_order) >= order:
			continue
		if GameState.unlocked_elements.get(key, false) or GameState.discovered_elements.get(key, false):
			return true
	return order == 0


func get_display_name(element_key: String) -> String:
	match get_element_visibility(element_key):
		Visibility.UNLOCKED, Visibility.DISCOVERED:
			return ElementDB.get_element(element_key).get("name", element_key)
		Visibility.HINTED:
			return "?"
		_:
			return "???"


func get_display_color(element_key: String) -> Color:
	var vis := get_element_visibility(element_key)
	if vis == Visibility.UNLOCKED or vis == Visibility.DISCOVERED:
		return ElementDB.get_color(element_key)
	if vis == Visibility.HINTED:
		return ElementDB.get_color(element_key).darkened(0.65)
	return Color(0.25, 0.25, 0.28, 1.0)


func get_description(element_key: String) -> String:
	match get_element_visibility(element_key):
		Visibility.UNLOCKED, Visibility.DISCOVERED:
			return ElementDB.get_element(element_key).get("encyclopedia_desc", "")
		Visibility.HINTED:
			return "An element in Act %d remains hidden. Keep experimenting." % int(ElementDB.get_element(element_key).act)
		_:
			var act := int(ElementDB.get_element(element_key).get("act", 0))
			return "Locked — %s" % ACT_NAMES.get(act, "Unknown future")


func get_reaction_visibility(reaction: Dictionary) -> String:
	var id: String = reaction.id
	if GameState.discovered_reactions.get(id, false):
		return "known"
	var e1: String = reaction.elem1
	var e2: String = reaction.elem2
	var v1 := get_element_visibility(e1)
	var v2 := get_element_visibility(e2)
	if v1 == Visibility.LOCKED and v2 == Visibility.LOCKED:
		return "hidden"
	if v1 == Visibility.LOCKED or v2 == Visibility.LOCKED:
		return "partial"
	if v1 == Visibility.HINTED or v2 == Visibility.HINTED:
		return "unknown"
	if GameState.discovered_elements.get(e1, false) or GameState.discovered_elements.get(e2, false):
		return "unknown"
	return "hidden"


func format_reaction_line(reaction: Dictionary) -> String:
	var vis := get_reaction_visibility(reaction)
	match vis:
		"known":
			return "%s + %s → %s" % [
				_name(reaction.elem1, reaction.result1),
				_name(reaction.elem2, reaction.result2),
				_products(reaction),
			]
		"partial":
			return "%s + ??? → ?" % _elem_label(reaction.elem1)
		"unknown":
			return "%s + %s → ?" % [_elem_label(reaction.elem1), _elem_label(reaction.elem2)]
		_:
			return "??? + ??? → ???"


func _elem_label(key: String) -> String:
	return get_display_name(key)


func _name(key: String, override: Variant) -> String:
	if override != null and str(override) != "":
		return get_display_name(str(override))
	return get_display_name(key)


func _products(reaction: Dictionary) -> String:
	var parts: Array[String] = []
	if reaction.result1 != null and str(reaction.result1) != "":
		parts.append(get_display_name(str(reaction.result1)))
	if reaction.result2 != null and str(reaction.result2) != "":
		parts.append(get_display_name(str(reaction.result2)))
	if reaction.get("dissolve", false):
		parts.append("dissolve")
	if parts.is_empty():
		return "—"
	return " + ".join(parts)


func get_milestone_progress(act: int) -> float:
	if act == 1:
		return MilestoneTracker.get_act1_progress()
	var keys: Array[String] = ElementDB.get_keys_for_act(act)
	if keys.is_empty():
		return 0.0
	var unlocked := 0
	for key in keys:
		if GameState.unlocked_elements.get(key, false):
			unlocked += 1
	return float(unlocked) / float(keys.size())
