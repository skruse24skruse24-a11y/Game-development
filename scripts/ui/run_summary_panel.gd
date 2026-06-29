extends PanelContainer

@onready var title_label: Label = %TitleLabel
@onready var body_label: Label = %BodyLabel
@onready var dismiss_button: Button = %DismissButton


func _ready() -> void:
	visible = false
	dismiss_button.pressed.connect(hide)


func show_summary(summary: Dictionary) -> void:
	var insight := int(summary.get("insight_earned", 0))
	var reactions_new := int(summary.get("reactions_new", 0))
	var reactions_total := int(summary.get("reactions_total", 0))
	var act1_reactions := int(summary.get("act1_reactions", 0))
	var act1_progress := float(summary.get("act1_progress", 0.0))
	var time_used := float(summary.get("time_used", 0.0))

	title_label.text = "Run Complete"
	var lines: PackedStringArray = PackedStringArray([
		"Insight earned: +%d" % insight,
		"New reactions: %d" % reactions_new,
		"Total reactions cataloged: %d" % reactions_total,
		"",
		"Act I — Create Reactions",
		"  Reactions discovered: %d / %d" % [act1_reactions, MilestoneTracker.ACT1_REACTION_GOAL],
		"  Milestone progress: %d%%" % int(round(act1_progress * 100.0)),
		"  Time in dish: %.1fs" % time_used,
	])
	if MilestoneTracker.act1_complete:
		lines.append("")
		lines.append("Act I milestone complete!")
	body_label.text = "\n".join(lines)
	visible = true
