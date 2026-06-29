extends PanelContainer

@onready var dismiss_button: Button = %TutorialDismiss


func _ready() -> void:
	visible = false
	dismiss_button.pressed.connect(_dismiss)


func maybe_show() -> void:
	if GameState.tutorial_seen:
		return
	visible = true


func _dismiss() -> void:
	visible = false
	GameState.mark_tutorial_seen()
