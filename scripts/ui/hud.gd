extends PanelContainer

@onready var insight_label: Label = %InsightLabel
@onready var timer_label: Label = %TimerLabel
@onready var budget_label: Label = %BudgetLabel
@onready var run_button: Button = %RunButton


func _ready() -> void:
	EventBus.insight_changed.connect(_on_insight)
	EventBus.run_timer_changed.connect(_on_timer)
	EventBus.placement_budget_changed.connect(_on_budget)
	EventBus.run_started.connect(_on_run_started)
	EventBus.run_ended.connect(_on_run_ended)
	_on_insight(GameState.insight)
	_on_timer(0.0)
	_on_budget(GameState.placement_budget_remaining, GameState.placement_budget_max)
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


func _on_run_ended(_summary: Dictionary) -> void:
	run_button.text = "Start Run"
	run_button.disabled = false


func _on_run_pressed() -> void:
	if not GameState.run_active:
		EventBus.toast.emit("Run started!")
		get_tree().call_group("main_controller", "start_run")
