extends Control

@onready var sim: Node = %PowderSimulation
@onready var renderer: SimRenderer = %SimRenderer
@onready var toast_label: Label = %ToastLabel
@onready var seismic_shop: PanelContainer = %SeismicShop
@onready var mastery_panel: PanelContainer = %MasteryPanel
@onready var encyclopedia: PanelContainer = %Encyclopedia
@onready var run_summary: PanelContainer = %RunSummary
@onready var tutorial: PanelContainer = %Tutorial

var _drawing: bool = false
var _toast_timer: float = 0.0


func _ready() -> void:
	add_to_group("main_controller")
	renderer.setup(sim as PowderSimulation)
	EventBus.toast.connect(_show_toast)
	EventBus.run_started.connect(_on_run_started)
	EventBus.run_ended.connect(_on_run_ended)
	tutorial.maybe_show()


func _process(delta: float) -> void:
	if GameState.run_active:
		GameState.tick_run(delta)
		(sim as PowderSimulation).process_delta(delta)
		renderer.refresh()
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			toast_label.visible = false


func start_run() -> void:
	(sim as PowderSimulation).setup_petri_dish()
	GameState.start_run()


func _on_run_started() -> void:
	pass


func _on_run_ended(summary: Dictionary) -> void:
	run_summary.show_summary(summary)


func _unhandled_input(event: InputEvent) -> void:
	if run_summary.visible or tutorial.visible:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_E:
				encyclopedia.toggle()
			KEY_U:
				seismic_shop.toggle()
			KEY_M:
				mastery_panel.toggle()
			KEY_R:
				if not GameState.run_active:
					start_run()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_drawing = true
				_paint_at(event.position)
			else:
				_drawing = false
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			GameState.selected_element = "WALL" if GameState.unlocked_elements.get("WALL", false) else GameState.selected_element
	if event is InputEventMouseMotion and _drawing:
		_paint_at(event.position)


func _paint_at(screen_pos: Vector2) -> void:
	if not GameState.run_active:
		return
	var rect := renderer.get_global_rect()
	if not rect.has_point(screen_pos):
		return
	var local := screen_pos - rect.position
	var psim := sim as PowderSimulation
	var gx := int(local.x / rect.size.x * float(psim.grid_width))
	var gy := int(local.y / rect.size.y * float(psim.grid_height))
	var mat := ElementDB.get_id(GameState.selected_element)
	if mat == ElementDB.EMPTY:
		return
	var radius := GameState.get_brush_size() - 1
	var placed := psim.place_brush(gx, gy, mat, maxi(radius, 0))
	if placed <= 0:
		return
	var key := GameState.selected_element
	var unit_cost := int(ceil(float(placed) * MasteryManager.placement_cost_multiplier(key)))
	if not GameState.try_spend_placement(unit_cost):
		return
	MasteryManager.add_xp(key, placed)
	GameState.discover_element(key)
	if key == "SPARK":
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				var nx := gx + ox
				var ny := gy + oy
				if psim.get_material(nx, ny) == ElementDB.get_id("OIL"):
					psim.set_material(nx, ny, ElementDB.get_id("FIRE"))


func _show_toast(message: String) -> void:
	toast_label.text = message
	toast_label.visible = true
	_toast_timer = 2.5
