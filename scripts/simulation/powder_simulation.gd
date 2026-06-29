class_name PowderSimulation
extends Node

const CHUNK_SIZE := 16

@export var grid_width: int = 96
@export var grid_height: int = 96
@export var ticks_per_second: int = 60

var _grid: PackedInt32Array
var _fire_life: PackedInt32Array
var _dirty_chunks: Dictionary = {}
var _accumulator: float = 0.0
var _scan_left_to_right: bool = true


func _ready() -> void:
	resize(grid_width, grid_height)


func resize(w: int, h: int) -> void:
	grid_width = w
	grid_height = h
	var size := w * h
	_grid = PackedInt32Array()
	_grid.resize(size)
	_fire_life = PackedInt32Array()
	_fire_life.resize(size)
	_grid.fill(ElementDB.EMPTY)
	_fire_life.fill(0)
	_mark_all_dirty()


func clear_grid() -> void:
	_grid.fill(ElementDB.EMPTY)
	_fire_life.fill(0)
	_mark_all_dirty()


func get_material(x: int, y: int) -> int:
	if not _in_bounds(x, y):
		return ElementDB.EMPTY
	return _grid[y * grid_width + x]


func set_material(x: int, y: int, mat: int) -> void:
	if not _in_bounds(x, y):
		return
	var idx := y * grid_width + x
	_grid[idx] = mat
	_fire_life[idx] = 0
	_mark_dirty_at(x, y)


func _mark_all_dirty() -> void:
	_dirty_chunks.clear()
	var cx_max := int(ceil(float(grid_width) / CHUNK_SIZE))
	var cy_max := int(ceil(float(grid_height) / CHUNK_SIZE))
	for cy in cy_max:
		for cx in cx_max:
			_dirty_chunks[Vector2i(cx, cy)] = true


func _mark_dirty_at(x: int, y: int) -> void:
	var cx0 := int(floor(float(x) / CHUNK_SIZE))
	var cy0 := int(floor(float(y) / CHUNK_SIZE))
	var cx_max := int(ceil(float(grid_width) / CHUNK_SIZE)) - 1
	var cy_max := int(ceil(float(grid_height) / CHUNK_SIZE)) - 1
	for oy in [-1, 0, 1]:
		for ox in [-1, 0, 1]:
			_dirty_chunks[Vector2i(clampi(cx0 + ox, 0, cx_max), clampi(cy0 + oy, 0, cy_max))] = true


func process_delta(delta: float) -> void:
	_accumulator += delta
	var step := 1.0 / float(ticks_per_second)
	while _accumulator >= step:
		tick()
		_accumulator -= step


func tick() -> void:
	if _dirty_chunks.is_empty():
		return
	var chunks := _dirty_chunks.keys()
	_dirty_chunks.clear()
	for chunk: Vector2i in chunks:
		_tick_chunk(chunk.x, chunk.y)
	# Keep sim alive at edges — wake neighbors if any activity expected next frame
	for chunk: Vector2i in chunks:
		_dirty_chunks[chunk] = true


func _tick_chunk(cx: int, cy: int) -> void:
	var x0 := cx * CHUNK_SIZE
	var y0 := cy * CHUNK_SIZE
	var x1 := mini(x0 + CHUNK_SIZE, grid_width)
	var y1 := mini(y0 + CHUNK_SIZE, grid_height)
	_scan_left_to_right = not _scan_left_to_right
	for y in range(y1 - 1, y0 - 1, -1):
		var xs := range(x0, x1)
		if not _scan_left_to_right:
			xs = range(x1 - 1, x0 - 1, -1)
		for x in xs:
			_update_cell(x, y)


func _update_cell(x: int, y: int) -> void:
	var idx := y * grid_width + x
	var mat := _grid[idx]
	if MaterialId.is_empty(mat):
		return
	if MaterialId.is_solid(mat):
		return
	if MaterialId.is_energy(mat):
		_update_fire(x, y, mat, idx)
		return
	if MaterialId.is_gas(mat):
		_update_gas(x, y, mat, idx)
		return
	if MaterialId.is_liquid(mat):
		_update_liquid(x, y, mat, idx)
		return
	if MaterialId.is_powder(mat):
		_update_powder(x, y, mat, idx)


func _update_powder(x: int, y: int, mat: int, idx: int) -> void:
	if _try_move(x, y, x, y + 1):
		return
	var dir := -1 if randf() < 0.5 else 1
	if _try_move(x, y, x + dir, y + 1):
		return
	_try_move(x, y, x - dir, y + 1)


func _update_liquid(x: int, y: int, mat: int, idx: int) -> void:
	var key := MaterialId.key(mat)
	var spread_bonus := MasteryManager.water_spread_bonus(key) if key == "WATR" else 0.0
	if _try_move_density(x, y, x, y + 1):
		return
	var dir := -1 if randf() < 0.5 else 1
	if randf() < 0.5 + spread_bonus:
		if _try_move_density(x, y, x + dir, y + 1):
			return
		_try_move_density(x, y, x - dir, y + 1)
		return
	if _try_move_density(x, y, x + dir, y):
		return
	_try_move_density(x, y, x - dir, y)


func _update_gas(x: int, y: int, mat: int, idx: int) -> void:
	if mat == ElementDB.get_id("STEAM") and randf() < 0.02:
		set_material(x, y, ElementDB.EMPTY)
		return
	if mat == ElementDB.get_id("SMOK") and randf() < 0.04:
		set_material(x, y, ElementDB.EMPTY)
		return
	if _try_move(x, y, x, y - 1):
		return
	var dir := -1 if randf() < 0.5 else 1
	_try_move(x, y, x + dir, y - 1)


func _update_fire(x: int, y: int, mat: int, idx: int) -> void:
	_fire_life[idx] -= 1
	if _fire_life[idx] <= 0:
		set_material(x, y, ElementDB.EMPTY)
		return
	for offset in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var nx: int = x + offset.x
		var ny: int = y + offset.y
		if not _in_bounds(nx, ny):
			continue
		var nmat := get_material(nx, ny)
		if MaterialId.is_empty(nmat):
			continue
		var nkey := MaterialId.key(nmat)
		if nkey == "WATR":
			set_material(x, y, ElementDB.get_id("STEAM"))
			set_material(nx, ny, ElementDB.EMPTY)
			_emit_reaction("I_002")
			return
		if MaterialId.is_flammable(nmat) or nkey == "OIL":
			var chance := 0.15 + MasteryManager.fire_spread_bonus("FIRE")
			if randf() < chance:
				_ignite(nx, ny)
	_try_move(x, y, x, y - 1)


func _ignite(x: int, y: int) -> void:
	var mat := get_material(x, y)
	if MaterialId.is_empty(mat):
		return
	var key := MaterialId.key(mat)
	if key == "OIL":
		set_material(x, y, ElementDB.get_id("FIRE"))
		_set_fire_life(x, y, 40)
		_try_spawn_smoke(x, y - 1)
		_emit_reaction("I_004")
	elif MaterialId.is_flammable(mat):
		set_material(x, y, ElementDB.get_id("FIRE"))
		_set_fire_life(x, y, 30)


func _set_fire_life(x: int, y: int, base: int) -> void:
	var idx := y * grid_width + x
	_fire_life[idx] = base + MasteryManager.fire_life_bonus("FIRE")


func _try_spawn_smoke(x: int, y: int) -> void:
	if _in_bounds(x, y) and MaterialId.is_empty(get_material(x, y)):
		set_material(x, y, ElementDB.get_id("SMOK"))


func _try_move(x: int, y: int, tx: int, ty: int) -> bool:
	if not _can_enter(tx, ty):
		return false
	return _swap(x, y, tx, ty)


func _try_move_density(x: int, y: int, tx: int, ty: int) -> bool:
	if not _in_bounds(tx, ty):
		return false
	var mat := get_material(x, y)
	var target := get_material(tx, ty)
	if MaterialId.is_empty(target):
		return _swap(x, y, tx, ty)
	if MaterialId.is_solid(target):
		return false
	if MaterialId.density(mat) > MaterialId.density(target):
		return _swap(x, y, tx, ty)
	return false


func _swap(x: int, y: int, tx: int, ty: int) -> bool:
	var i0 := y * grid_width + x
	var i1 := ty * grid_width + tx
	var m0 := _grid[i0]
	var m1 := _grid[i1]
	if not _try_react_pair(x, y, tx, ty, m0, m1):
		pass
	else:
		m0 = _grid[i0]
		m1 = _grid[i1]
		if MaterialId.is_empty(m0):
			return true
	_grid[i0] = m1
	_grid[i1] = m0
	var f0 := _fire_life[i0]
	_fire_life[i0] = _fire_life[i1]
	_fire_life[i1] = f0
	_mark_dirty_at(x, y)
	_mark_dirty_at(tx, ty)
	return true


func _try_react_pair(x: int, y: int, tx: int, ty: int, a: int, b: int) -> bool:
	if MaterialId.is_empty(a) or MaterialId.is_empty(b):
		return false
	var key_a := MaterialId.key(a)
	var key_b := MaterialId.key(b)
	var reaction := ReactionDB.find_reaction(key_a, key_b)
	if reaction.is_empty():
		return false
	var chance := float(reaction.get("chance", 1.0))
	chance += MasteryManager.reaction_chance_bonus(key_a)
	chance += MasteryManager.reaction_chance_bonus(key_b)
	if randf() > chance:
		return false
	var r1: Variant = reaction.get("result1")
	var r2: Variant = reaction.get("result2")
	var dissolve: bool = reaction.get("dissolve", false)
	if dissolve:
		_set_cell_result(x, y, ElementDB.EMPTY)
		_set_cell_result(tx, ty, ElementDB.EMPTY)
	elif reaction.get("oneway", false) and reaction.elem1 == key_a:
		_set_cell_result(x, y, _result_id(r1))
		_set_cell_result(tx, ty, _result_id(r2))
	else:
		_set_cell_result(x, y, _result_id(r1))
		_set_cell_result(tx, ty, _result_id(r2))
	_emit_reaction(str(reaction.id))
	return true


func _set_cell_result(x: int, y: int, mat: int) -> void:
	var idx := y * grid_width + x
	_grid[idx] = mat
	_fire_life[idx] = 0
	if mat == ElementDB.get_id("FIRE"):
		_set_fire_life(x, y, 35)
	_mark_dirty_at(x, y)


func _result_id(result: Variant) -> int:
	if result == null or str(result) == "":
		return ElementDB.EMPTY
	return ElementDB.get_id(str(result))


func _emit_reaction(reaction_id: String) -> void:
	if GameState.discovered_reactions.get(reaction_id, false):
		return
	var reaction := {}
	for r in ReactionDB.get_all():
		if r.id == reaction_id:
			reaction = r
			break
	if reaction.is_empty():
		return
	GameState.discover_reaction(reaction_id)
	var reward := int(reaction.get("insight_reward", 10))
	GameState.add_insight(reward)
	var xp := int(reaction.get("mastery_xp", 5))
	MasteryManager.add_xp(str(reaction.elem1), xp)
	MasteryManager.add_xp(str(reaction.elem2), xp)
	if reaction.result1:
		GameState.discover_element(str(reaction.result1))
	if reaction.result2:
		GameState.discover_element(str(reaction.result2))
	EventBus.reaction_discovered.emit(reaction_id, str(reaction.elem1), str(reaction.elem2))
	EventBus.toast.emit("Reaction discovered: %s" % Encyclopedia.format_reaction_line(reaction))


func place_brush(cx: int, cy: int, mat: int, radius: int) -> int:
	var placed := 0
	for y in range(cy - radius, cy + radius + 1):
		for x in range(cx - radius, cx + radius + 1):
			if not _in_bounds(x, y):
				continue
			if Vector2(x - cx, y - cy).length() > float(radius) + 0.5:
				continue
			if not MaterialId.is_empty(get_material(x, y)) and MaterialId.key(mat) != "WALL":
				continue
			set_material(x, y, mat)
			placed += 1
	return placed


func _can_enter(x: int, y: int) -> bool:
	if not _in_bounds(x, y):
		return false
	var mat := get_material(x, y)
	return MaterialId.is_empty(mat)


func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < grid_width and y < grid_height


func get_grid_copy() -> PackedInt32Array:
	return _grid.duplicate()
