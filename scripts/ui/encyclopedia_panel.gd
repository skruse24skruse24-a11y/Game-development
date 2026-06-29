extends PanelContainer

enum Tab { ELEMENTS, REACTIONS, MILESTONES }

@onready var tabs: TabContainer = %Tabs
@onready var element_grid: GridContainer = %ElementGrid
@onready var reaction_list: VBoxContainer = %ReactionList
@onready var milestone_list: VBoxContainer = %MilestoneList


func _ready() -> void:
	visible = false
	EventBus.encyclopedia_updated.connect(_refresh_all)
	_refresh_all()


func toggle() -> void:
	visible = not visible
	if visible:
		_refresh_all()


func _refresh_all() -> void:
	_refresh_elements()
	_refresh_reactions()
	_refresh_milestones()


func _refresh_elements() -> void:
	for child in element_grid.get_children():
		child.queue_free()
	for key in ElementDB.get_all_keys():
		var card := VBoxContainer.new()
		card.custom_minimum_size = Vector2(110, 90)
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(100, 36)
		swatch.color = Encyclopedia.get_display_color(key)
		var name_lbl := Label.new()
		name_lbl.text = Encyclopedia.get_display_name(key)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var act_lbl := Label.new()
		var vis := Encyclopedia.get_element_visibility(key)
		if vis == Encyclopedia.Visibility.LOCKED:
			act_lbl.text = "Act %d" % int(ElementDB.get_element(key).act)
		elif vis == Encyclopedia.Visibility.HINTED:
			act_lbl.text = "?"
		else:
			act_lbl.text = "Act %d" % int(ElementDB.get_element(key).act)
		act_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		act_lbl.add_theme_font_size_override("font_size", 11)
		card.add_child(swatch)
		card.add_child(name_lbl)
		card.add_child(act_lbl)
		card.tooltip_text = Encyclopedia.get_description(key)
		element_grid.add_child(card)


func _refresh_reactions() -> void:
	for child in reaction_list.get_children():
		child.queue_free()
	for reaction in ReactionDB.get_all():
		var lbl := Label.new()
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.text = Encyclopedia.format_reaction_line(reaction)
		var vis := Encyclopedia.get_reaction_visibility(reaction)
		if vis == "known":
			lbl.add_theme_color_override("font_color", Color(0.85, 0.95, 0.85))
		elif vis == "hidden":
			lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.38))
		else:
			lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
		reaction_list.add_child(lbl)


func _refresh_milestones() -> void:
	for child in milestone_list.get_children():
		child.queue_free()
	for act in range(1, 8):
		var row := HBoxContainer.new()
		var title := Label.new()
		title.text = Encyclopedia.ACT_NAMES.get(act, "Act %d" % act)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(180, 20)
		bar.max_value = 1.0
		bar.value = Encyclopedia.get_milestone_progress(act)
		bar.show_percentage = false
		row.add_child(title)
		row.add_child(bar)
		milestone_list.add_child(row)
