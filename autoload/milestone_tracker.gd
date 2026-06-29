extends Node

const ACT1_REACTION_GOAL := 15
const STEAM_CYCLE_SECONDS := 30.0

var act1_complete: bool = false
var steam_cycle_progress: float = 0.0
var _run_reaction_types: Dictionary = {}
var _steam_cycle_timer: float = 0.0
var steam_cycle_active: bool = false
var _seen_steam_this_run: bool = false
var _seen_condense_this_run: bool = false


func _ready() -> void:
	EventBus.run_started.connect(_on_run_started)
	EventBus.phase_change.connect(_on_phase_change)
	EventBus.reaction_discovered.connect(_on_reaction_discovered)


func _on_run_started() -> void:
	_run_reaction_types.clear()
	_steam_cycle_timer = 0.0
	steam_cycle_active = false
	_seen_steam_this_run = false
	_seen_condense_this_run = false


func _on_reaction_discovered(reaction_id: String, _e1: String, _e2: String) -> void:
	if not GameState.run_active:
		return
	_run_reaction_types[reaction_id] = true
	_check_act1_progress()


func _on_phase_change(from_key: String, to_key: String) -> void:
	if not GameState.run_active:
		return
	if from_key == "WATR" and to_key == "STEAM":
		_seen_steam_this_run = true
		_try_steam_cycle()
	elif from_key == "STEAM" and to_key == "WATR":
		_seen_condense_this_run = true
		_try_steam_cycle()


func _try_steam_cycle() -> void:
	if _seen_steam_this_run and _seen_condense_this_run:
		steam_cycle_active = true


func tick_run(delta: float) -> void:
	if not steam_cycle_active or act1_complete:
		return
	_steam_cycle_timer += delta
	steam_cycle_progress = clampf(_steam_cycle_timer / STEAM_CYCLE_SECONDS, 0.0, 1.0)
	EventBus.act_progress_changed.emit(get_act1_progress())
	if _steam_cycle_timer >= STEAM_CYCLE_SECONDS:
		_complete_act1()


func get_act1_reaction_count() -> int:
	return _count_act1_reactions(GameState.discovered_reactions)


func get_act1_run_reaction_count() -> int:
	return _run_reaction_types.size()


func get_act1_progress() -> float:
	var reaction_p := float(get_act1_reaction_count()) / float(ACT1_REACTION_GOAL)
	var cycle_p := steam_cycle_progress if steam_cycle_active else 0.0
	return clampf(reaction_p * 0.6 + cycle_p * 0.4, 0.0, 1.0)


func _count_act1_reactions(discovered: Dictionary) -> int:
	var count := 0
	for reaction in ReactionDB.get_all():
		if int(reaction.act) != 1:
			continue
		if discovered.get(reaction.id, false):
			count += 1
	return count


func _check_act1_progress() -> void:
	EventBus.act_progress_changed.emit(get_act1_progress())
	if get_act1_reaction_count() >= ACT1_REACTION_GOAL and steam_cycle_active:
		if _steam_cycle_timer >= STEAM_CYCLE_SECONDS:
			_complete_act1()


func _complete_act1() -> void:
	if act1_complete:
		return
	act1_complete = true
	GameState.current_act = maxi(GameState.current_act, 2)
	GameState.add_insight(500)
	EventBus.act_milestone_complete.emit(1, "Create Reactions")
	EventBus.toast.emit("Act I complete: Create Reactions! +500 Insight")
	SaveManager.save_game()


func get_save_data() -> Dictionary:
	return {
		"act1_complete": act1_complete,
		"steam_cycle_progress": steam_cycle_progress,
	}


func apply_save_data(data: Dictionary) -> void:
	act1_complete = bool(data.get("act1_complete", false))
	steam_cycle_progress = float(data.get("steam_cycle_progress", 0.0))
