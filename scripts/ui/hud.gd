extends PanelContainer

@onready var insight_label: Label = %InsightLabel
@onready var timer_label: Label = %TimerLabel
@onready var budget_label: Label = %BudgetLabel
@onready var act_label: Label = %ActLabel
@onready var act_progress: ProgressBar = %ActProgress
@onready var run_button: Button = %RunButton


func _ready() -> void:
	EventBus.insight_changed.connect(_on_insight)
	EventBus.run_timer_changed.connect(_on_timer)
	EventBus.placement_budget_changed.connect(_on_budget)
	EventBus.run_started.connect(_on_run_started)
	EventBus.run_ended.connect(_on_run_ended)
	EventBus.act_progress_changed.connect(_on_act_progress)
	EventBus.act_milestone_complete.connect(_on_act_milestone)
	_on_insight(GameState.insight)
	_on_timer(0.0)
	_on_budget(GameState.placement_budget_remaining, GameState.placement_budget_max)
	_refresh_act_progress()
	run_button.pressed.connect(_on_run_pressed)


func _on_insight(value: int) -> void:
	insight_label.text = "Insight: %d" % value


func _on_timer(remaining: float) -> void:
	timer_label.text = "Time: %.1fs" % remaining


func _on_budget(remaining: int, maximum: int) -> void:
	budget_label.text = "Budget: %d / %d" % [remaining, maximum]


func _on_run_started() -> void:
	run_button.text = "Running..."
	run_button.disabled = true
	_refresh_act_progress()


func _on_run_ended(_summary: Dictionary) -> void:
	run_button.text = "Start Run (R)"
	run_button.disabled = false
	_refresh_act_progress()


func _on_act_progress(_progress: float) -> void:
	_refresh_act_progress()


func _on_act_milestone(act: int, _name: String) -> void:
	if act == 1:
		_refresh_act_progress()


func _refresh_act_progress() -> void:
	var reactions := MilestoneTracker.get_act1_reaction_count()
	var goal := MilestoneTracker.ACT1_REACTION_GOAL
	var progress := MilestoneTracker.get_act1_progress()
	act_progress.value = progress
	if MilestoneTracker.act1_complete:
		act_label.text = "Act I complete!"
	elif MilestoneTracker.steam_cycle_active:
		var cycle_pct := int(round(MilestoneTracker.steam_cycle_progress * 100.0))
		act_label.text = "Act I: %d/%d reactions · steam cycle %d%%" % [reactions, goal, cycle_pct]
	else:
		act_label.text = "Act I: %d/%d reactions" % [reactions, goal]


func _on_run_pressed() -> void:
	if not GameState.run_active:
		get_tree().call_group("main_controller", "start_run")
