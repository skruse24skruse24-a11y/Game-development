extends Node

var _seismic_defs: Dictionary = {}
var _seismic_levels: Dictionary = {}
var insight: int = 0
var unlocked_elements: Dictionary = {"SAND": true}
var discovered_elements: Dictionary = {"SAND": true}
var discovered_reactions: Dictionary = {}
var current_act: int = 1
var run_active: bool = false
var run_time_remaining: float = 0.0
var placement_budget_max: int = 80
var placement_budget_remaining: int = 80
var brush_size: int = 1
var selected_element: String = "SAND"
var total_runs: int = 0
var run_insight_at_start: int = 0
var run_reactions_at_start: int = 0
var tutorial_seen: bool = false


func _ready() -> void:
	_load_seismic_defs()


func _load_seismic_defs() -> void:
	var file := FileAccess.open("res://data/seismic_upgrades.json", FileAccess.READ)
	if file == null:
		return
	_seismic_defs = JSON.parse_string(file.get_as_text())
	for key in _seismic_defs.keys():
		if not _seismic_levels.has(key):
			_seismic_levels[key] = 0


func get_seismic_level(key: String) -> int:
	return int(_seismic_levels.get(key, 0))


func get_seismic_cost(key: String) -> int:
	var def: Dictionary = _seismic_defs.get(key, {})
	var level := get_seismic_level(key)
	var max_level := int(def.get("max_level", 0))
	if level >= max_level:
		return -1
	return int(floor(float(def.base_cost) * pow(float(def.cost_growth), level)))


func get_run_duration() -> float:
	var def: Dictionary = _seismic_defs.get("timer", {})
	var base := float(def.get("base_value", 15.0))
	var per := float(def.get("effect_per_level", 5.0))
	return base + float(get_seismic_level("timer")) * per


func get_placement_budget_max() -> int:
	var def: Dictionary = _seismic_defs.get("budget", {})
	var base := int(def.get("base_value", 80))
	var per := int(def.get("effect_per_level", 50))
	return base + get_seismic_level("budget") * per


func get_insight_per_second() -> float:
	var def: Dictionary = _seismic_defs.get("insight_rate", {})
	var base := float(def.get("base_value", 0.2))
	var per := float(def.get("effect_per_level", 0.05))
	return base + float(get_seismic_level("insight_rate")) * per


func get_brush_size() -> int:
	var def: Dictionary = _seismic_defs.get("brush", {})
	var base := int(def.get("base_value", 1))
	var per := int(def.get("effect_per_level", 1))
	return base + get_seismic_level("brush") * per


func purchase_seismic(upgrade_key: String) -> bool:
	var cost := get_seismic_cost(upgrade_key)
	if cost < 0 or insight < cost:
		return false
	insight -= cost
	_seismic_levels[upgrade_key] = get_seismic_level(upgrade_key) + 1
	EventBus.insight_changed.emit(insight)
	EventBus.seismic_upgraded.emit(upgrade_key, _seismic_levels[upgrade_key])
	SaveManager.save_game()
	return true


func purchase_element_unlock(element_key: String) -> bool:
	if unlocked_elements.get(element_key, false):
		return false
	var entry := ElementDB.get_element(element_key)
	if entry.is_empty():
		return false
	if entry.has("auto_unlock"):
		return false
	var cost := int(entry.get("insight_unlock_cost", 0))
	if insight < cost:
		return false
	_unlock_element(element_key)
	insight -= cost
	EventBus.insight_changed.emit(insight)
	SaveManager.save_game()
	return true


func _unlock_element(element_key: String) -> void:
	unlocked_elements[element_key] = true
	discovered_elements[element_key] = true
	EventBus.element_unlocked.emit(element_key)
	EventBus.element_discovered.emit(element_key)
	EventBus.encyclopedia_updated.emit()


func can_unlock_element(element_key: String) -> bool:
	if unlocked_elements.get(element_key, false):
		return false
	var entry := ElementDB.get_element(element_key)
	if entry.is_empty() or entry.has("auto_unlock"):
		return false
	return insight >= int(entry.get("insight_unlock_cost", 0))


func add_insight(amount: int) -> void:
	if amount <= 0:
		return
	insight += amount
	EventBus.insight_changed.emit(insight)


func discover_element(element_key: String) -> void:
	if discovered_elements.get(element_key, false):
		_try_auto_unlock(element_key)
		return
	discovered_elements[element_key] = true
	EventBus.element_discovered.emit(element_key)
	EventBus.encyclopedia_updated.emit()
	_try_auto_unlock(element_key)


func _try_auto_unlock(element_key: String) -> void:
	if unlocked_elements.get(element_key, false):
		return
	var entry := ElementDB.get_element(element_key)
	if entry.is_empty() or not entry.has("auto_unlock"):
		return
	_unlock_element(element_key)
	EventBus.toast.emit("Unlocked %s!" % entry.get("name", element_key))


func discover_reaction(reaction_id: String) -> void:
	if discovered_reactions.get(reaction_id, false):
		return
	discovered_reactions[reaction_id] = true
	EventBus.encyclopedia_updated.emit()


func start_run() -> void:
	run_active = true
	total_runs += 1
	run_insight_at_start = insight
	run_reactions_at_start = discovered_reactions.size()
	run_time_remaining = get_run_duration()
	placement_budget_max = get_placement_budget_max()
	placement_budget_remaining = placement_budget_max
	brush_size = get_brush_size()
	EventBus.run_started.emit()
	EventBus.run_timer_changed.emit(run_time_remaining)
	EventBus.placement_budget_changed.emit(placement_budget_remaining, placement_budget_max)


func end_run() -> void:
	if not run_active:
		return
	run_active = false
	var summary := {
		"insight_earned": insight - run_insight_at_start,
		"reactions_total": discovered_reactions.size(),
		"reactions_new": discovered_reactions.size() - run_reactions_at_start,
		"time_used": get_run_duration() - run_time_remaining,
		"act1_progress": MilestoneTracker.get_act1_progress(),
		"act1_reactions": MilestoneTracker.get_act1_reaction_count(),
	}
	EventBus.run_ended.emit(summary)
	SaveManager.save_game()


func tick_run(delta: float) -> void:
	if not run_active:
		return
	run_time_remaining = maxf(run_time_remaining - delta, 0.0)
	var earned := int(floor(delta * get_insight_per_second()))
	if earned > 0:
		add_insight(earned)
	MilestoneTracker.tick_run(delta)
	EventBus.run_timer_changed.emit(run_time_remaining)
	if run_time_remaining <= 0.0:
		end_run()


func try_spend_placement(cost: int) -> bool:
	if placement_budget_remaining < cost:
		return false
	placement_budget_remaining -= cost
	EventBus.placement_budget_changed.emit(placement_budget_remaining, placement_budget_max)
	return true


func mark_tutorial_seen() -> void:
	tutorial_seen = true
	SaveManager.save_game()


func get_save_data() -> Dictionary:
	return {
		"insight": insight,
		"seismic_levels": _seismic_levels.duplicate(),
		"unlocked_elements": unlocked_elements.duplicate(),
		"discovered_elements": discovered_elements.duplicate(),
		"discovered_reactions": discovered_reactions.duplicate(),
		"current_act": current_act,
		"total_runs": total_runs,
		"tutorial_seen": tutorial_seen,
		"mastery": MasteryManager.get_save_data(),
		"milestones": MilestoneTracker.get_save_data(),
	}


func apply_save_data(data: Dictionary) -> void:
	insight = int(data.get("insight", 0))
	_seismic_levels = data.get("seismic_levels", _seismic_levels).duplicate()
	unlocked_elements = data.get("unlocked_elements", {"SAND": true}).duplicate()
	discovered_elements = data.get("discovered_elements", {"SAND": true}).duplicate()
	discovered_reactions = data.get("discovered_reactions", {}).duplicate()
	current_act = int(data.get("current_act", 1))
	total_runs = int(data.get("total_runs", 0))
	tutorial_seen = bool(data.get("tutorial_seen", false))
	if data.has("mastery"):
		MasteryManager.apply_save_data(data.mastery)
	if data.has("milestones"):
		MilestoneTracker.apply_save_data(data.milestones)
	EventBus.insight_changed.emit(insight)
	EventBus.encyclopedia_updated.emit()
