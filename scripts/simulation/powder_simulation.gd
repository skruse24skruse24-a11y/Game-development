class_name PowderSimulation
extends Node

const CHUNK_SIZE := 16

@export var grid_width: int = 96
@export var grid_height: int = 96
@export var ticks_per_second: int = 60

var _grid: PackedInt32Array
var _fire_life: PackedInt32Array
var _spark_life: PackedInt32Array
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
	_spark_life = PackedInt32Array()
	_spark_life.resize(size)
	_grid.fill(ElementDB.EMPTY)
	_fire_life.fill(0)
	_spark_life.fill(0)
	_mark_all_dirty()


func clear_grid() -> void:
	_grid.fill(ElementDB.EMPTY)
	_fire_life.fill(0)
	_spark_life.fill(0)
	_mark_all_dirty()


func setup_petri_dish() -> void:
	clear_grid()
	var wall := ElementDB.get_id("WALL")
	for x in grid_width:
		set_material(x, 0, wall)
		set_material(x, grid_height - 1, wall)
	for y in grid_height:
		set_material(0, y, wall)
		set_material(grid_width - 1, y, wall)
	_mark_all_dirty()


func get_material(x: int, y: int) -> int:
	if not _in_bounds(x, y):
		return ElementDB.EMPTY
	return _grid[y * grid_width + x]


func set_material(x: int, y: int, mat: int, emit_phase: bool = true) -> void:
	if not _in_bounds(x, y):
		return
	var idx := y * grid_width + x
	var old := _grid[idx]
	if old == mat:
		return
	if emit_phase and old != ElementDB.EMPTY and mat != ElementDB.EMPTY:
		_emit_phase(MaterialId.key(old), MaterialId.key(mat))
	_grid[idx] = mat
	_fire_life[idx] = 0
	_spark_life[idx] = 0
	if mat == ElementDB.get_id("FIRE"):
		_set_fire_life(x, y, 35)
	elif mat == ElementDB.get_id("SPARK"):
		_spark_life[idx] = 8
	_mark_dirty_at(x, y)


func _emit_phase(from_key: String, to_key: String) -> void:
	if from_key.is_empty() or to_key.is_empty() or from_key == to_key:
		return
	EventBus.phase_change.emit(from_key, to_key)


func _mark_all_dirty() -> void:
	_dirty_chunks.clear()
	var cx_max := int(ceil(float(grid_width) / float(CHUNK_SIZE)))
	var cy_max := int(ceil(float(grid_height) / float(CHUNK_SIZE)))
	for cy in cy_max:
		for cx in cx_max:
			_dirty_chunks[Vector2i(cx, cy)] = true


func _mark_dirty_at(x: int, y: int) -> void:
	var cx0 := int(floor(float(x) / float(CHUNK_SIZE)))
	var cy0 := int(floor(float(y) / float(CHUNK_SIZE)))
	var cx_max := int(ceil(float(grid_width) / float(CHUNK_SIZE))) - 1
	var cy_max := int(ceil(float(grid_height) / float(CHUNK_SIZE))) - 1
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
	var chunks: Array = _dirty_chunks.keys()
	_dirty_chunks.clear()
	var still_active: Dictionary = {}
	for chunk_variant in chunks:
		var chunk: Vector2i = chunk_variant
		if _tick_chunk(chunk.x, chunk.y):
			still_active[chunk] = true
			for oy in [-1, 0, 1]:
				for ox in [-1, 0, 1]:
					if ox == 0 and oy == 0:
						continue
					var nc := Vector2i(chunk.x + ox, chunk.y + oy)
					if _is_valid_chunk(nc):
						still_active[nc] = true
	_dirty_chunks = still_active


func _is_valid_chunk(chunk: Vector2i) -> bool:
	var cx_max := int(ceil(float(grid_width) / float(CHUNK_SIZE)))
	var cy_max := int(ceil(float(grid_height) / float(CHUNK_SIZE)))
	return chunk.x >= 0 and chunk.y >= 0 and chunk.x < cx_max and chunk.y < cy_max


func _tick_chunk(cx: int, cy: int) -> bool:
	var x0 := cx * CHUNK_SIZE
	var y0 := cy * CHUNK_SIZE
	var x1 := mini(x0 + CHUNK_SIZE, grid_width)
	var y1 := mini(y0 + CHUNK_SIZE, grid_height)
	var changed := false
	_scan_left_to_right = not _scan_left_to_right
	for y in range(y1 - 1, y0 - 1, -1):
		var xs := range(x0, x1)
		if not _scan_left_to_right:
			xs = range(x1 - 1, x0 - 1, -1)
		for x in xs:
			if _update_cell(x, y):
				changed = true
	return changed


func _update_cell(x: int, y: int) -> bool:
	var idx := y * grid_width + x
	var mat := _grid[idx]
	if MaterialId.is_empty(mat):
		return false
	var key := MaterialId.key(mat)
	if key == "WALL" or key == "STONE":
		return false
	if key == "ICE":
		return _update_ice(x, y, idx)
	if key == "SPARK":
		return _update_spark(x, y, idx)
	if MaterialId.is_energy(mat):
		return _update_fire(x, y, mat, idx)
	if MaterialId.is_gas(mat):
		return _update_gas(x, y, mat, idx)
	if MaterialId.is_liquid(mat):
		return _update_liquid(x, y, mat, idx)
	if MaterialId.is_powder(mat):
		return _update_powder(x, y, mat, idx)
	return false


func _update_powder(x: int, y: int, mat: int, idx: int) -> bool:
	if _try_move(x, y, x, y + 1):
		return true
	var dir := -1 if randf() < 0.5 else 1
	if _try_move(x, y, x + dir, y + 1):
		return true
	return _try_move(x, y, x - dir, y + 1)


func _update_liquid(x: int, y: int, mat: int, idx: int) -> bool:
	var key := MaterialId.key(mat)
	var spread_bonus := MasteryManager.water_spread_bonus(key) if key == "WATR" else 0.0
	if _try_move_density(x, y, x, y + 1):
		return true
	var dir := -1 if randf() < 0.5 else 1
	if randf() < 0.5 + spread_bonus:
		if _try_move_density(x, y, x + dir, y + 1):
			return true
		if _try_move_density(x, y, x - dir, y + 1):
			return true
		return false
	if _try_move_density(x, y, x + dir, y):
		return true
	return _try_move_density(x, y, x - dir, y)


func _update_gas(x: int, y: int, mat: int, idx: int) -> bool:
	var key := MaterialId.key(mat)
	if key == "STEAM":
		if y <= 2 and randf() < 0.015:
			set_material(x, y, ElementDB.get_id("WATR"))
			return true
		if randf() < 0.008:
			set_material(x, y, ElementDB.EMPTY)
			return true
	elif key == "SMOK" and randf() < 0.05:
		set_material(x, y, ElementDB.EMPTY)
		return true
	if _try_move(x, y, x, y - 1):
		return true
	var dir := -1 if randf() < 0.5 else 1
	return _try_move(x, y, x + dir, y - 1)


func _update_ice(x: int, y: int, idx: int) -> bool:
	for offset in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var nx: int = x + offset.x
		var ny: int = y + offset.y
		if not _in_bounds(nx, ny):
			continue
		var nkey := MaterialId.key(get_material(nx, ny))
		if nkey == "FIRE" or nkey == "LAVA":
			set_material(x, y, ElementDB.get_id("WATR"))
			return true
	return false


func _update_spark(x: int, y: int, idx: int) -> bool:
	_spark_life[idx] -= 1
	var changed := false
	for offset in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var nx: int = x + offset.x
		var ny: int = y + offset.y
		if not _in_bounds(nx, ny):
			continue
		var nmat := get_material(nx, ny)
		if MaterialId.is_empty(nmat):
			continue
		var nkey := MaterialId.key(nmat)
		if nkey == "OIL" or MaterialId.is_flammable(nmat):
			_ignite(nx, ny)
			changed = true
	if _spark_life[idx] <= 0:
		set_material(x, y, ElementDB.EMPTY)
		return true
	return changed


func _update_fire(x: int, y: int, mat: int, idx: int) -> bool:
	_fire_life[idx] -= 1
	if _fire_life[idx] <= 0:
		if randf() < 0.35:
			set_material(x, y, ElementDB.get_id("ASH"))
			GameState.discover_element("ASH")
		else:
			set_material(x, y, ElementDB.EMPTY)
		return true
	var changed := false
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
			return true
		if nkey == "ICE":
			set_material(nx, ny, ElementDB.get_id("WATR"))
			changed = true
		if MaterialId.is_flammable(nmat) or nkey == "OIL":
			var chance := 0.15 + MasteryManager.fire_spread_bonus("FIRE")
			if randf() < chance:
				_ignite(nx, ny)
				changed = true
	if _try_move(x, y, x, y - 1):
		return true
	return changed


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
	if MaterialId.is_solid(target) and MaterialId.key(target) != "ICE":
		return false
	if MaterialId.density(mat) > MaterialId.density(target):
		return _swap(x, y, tx, ty)
	return false


func _swap(x: int, y: int, tx: int, ty: int) -> bool:
	var i0 := y * grid_width + x
	var i1 := ty * grid_width + tx
	var m0 := _grid[i0]
	var m1 := _grid[i1]
	if _try_react_pair(x, y, tx, ty, m0, m1):
		return true
	_grid[i0] = m1
	_grid[i1] = m0
	var f0 := _fire_life[i0]
	_fire_life[i0] = _fire_life[i1]
	_fire_life[i1] = f0
	var s0 := _spark_life[i0]
	_spark_life[i0] = _spark_life[i1]
	_spark_life[i1] = s0
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
		_apply_result(x, y, ElementDB.EMPTY, key_a, reaction)
		_apply_result(tx, ty, ElementDB.EMPTY, key_b, reaction)
	elif reaction.get("oneway", false) and reaction.elem1 == key_a:
		_apply_result(x, y, _result_id(r1), key_a, reaction)
		_apply_result(tx, ty, _result_id(r2), key_b, reaction)
	else:
		_apply_result(x, y, _result_id(r1), key_a, reaction)
		_apply_result(tx, ty, _result_id(r2), key_b, reaction)
	_emit_reaction(str(reaction.id))
	return true


func _apply_result(x: int, y: int, mat: int, old_key: String, reaction: Dictionary) -> void:
	var new_key := MaterialId.key(mat) if mat != ElementDB.EMPTY else ""
	if not new_key.is_empty() and new_key != old_key:
		_emit_phase(old_key, new_key)
	var idx := y * grid_width + x
	_grid[idx] = mat
	_fire_life[idx] = 0
	_spark_life[idx] = 0
	if mat == ElementDB.get_id("FIRE"):
		_set_fire_life(x, y, 35)
	elif mat == ElementDB.get_id("SPARK"):
		_spark_life[idx] = 8
	_mark_dirty_at(x, y)


func _result_id(result: Variant) -> int:
	if result == null or str(result) == "":
		return ElementDB.EMPTY
	return ElementDB.get_id(str(result))


func _emit_reaction(reaction_id: String) -> void:
	var reaction := ReactionDB.find_by_id(reaction_id)
	if reaction.is_empty():
		return
	var first_time: bool = not GameState.discovered_reactions.get(reaction_id, false)
	if first_time:
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
		EventBus.toast.emit("Reaction: %s" % Encyclopedia.format_reaction_line(reaction))


func place_brush(cx: int, cy: int, mat: int, radius: int) -> int:
	var placed := 0
	var key := MaterialId.key(mat)
	for y in range(cy - radius, cy + radius + 1):
		for x in range(cx - radius, cx + radius + 1):
			if not _in_bounds(x, y):
				continue
			if Vector2(x - cx, y - cy).length() > float(radius) + 0.5:
				continue
			if key != "WALL" and not MaterialId.is_empty(get_material(x, y)):
				continue
			set_material(x, y, mat, false)
			placed += 1
	if key == "SPARK":
		for y in range(cy - radius, cy + radius + 1):
			for x in range(cx - radius, cx + radius + 1):
				if not _in_bounds(x, y):
					continue
				_try_spark_ignite(x, y)
	return placed


func _try_spark_ignite(x: int, y: int) -> void:
	var nmat := get_material(x, y)
	if MaterialId.is_empty(nmat):
		return
	var nkey := MaterialId.key(nmat)
	if nkey == "OIL":
		set_material(x, y, ElementDB.get_id("FIRE"))
		_emit_reaction("I_009")


func _can_enter(x: int, y: int) -> bool:
	if not _in_bounds(x, y):
		return false
	return MaterialId.is_empty(get_material(x, y))


func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < grid_width and y < grid_height


func get_grid_copy() -> PackedInt32Array:
	return _grid.duplicate()


func get_fire_life_copy() -> PackedInt32Array:
	return _fire_life.duplicate()
