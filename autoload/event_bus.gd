extends Node

signal insight_changed(new_value: int)
signal run_started
signal run_ended(summary: Dictionary)
signal run_timer_changed(remaining: float)
signal placement_budget_changed(remaining: int, max_budget: int)
signal reaction_discovered(reaction_id: String, elem1: String, elem2: String)
signal element_discovered(element_key: String)
signal element_unlocked(element_key: String)
signal seismic_upgraded(upgrade_key: String, level: int)
signal mastery_changed(element_key: String, level: int, xp: int)
signal mastery_upgrade_purchased(element_key: String, upgrade_id: String, level: int)
signal toast(message: String)
signal encyclopedia_updated
