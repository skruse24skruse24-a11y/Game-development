class_name SimRenderer
extends TextureRect

var _image: Image
var _texture: ImageTexture
var _sim: PowderSimulation


func setup(sim: PowderSimulation) -> void:
	_sim = sim
	_image = Image.create(sim.grid_width, sim.grid_height, false, Image.FORMAT_RGBA8)
	_texture = ImageTexture.create_from_image(_image)
	texture = _texture
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE


func refresh() -> void:
	if _sim == null:
		return
	var grid := _sim.get_grid_copy()
	for y in _sim.grid_height:
		for x in _sim.grid_width:
			var mat := grid[y * _sim.grid_width + x]
			var color := Color(0.08, 0.08, 0.12, 1.0)
			if mat != ElementDB.EMPTY:
				var key := ElementDB.get_key_for_id(mat)
				color = ElementDB.get_color(key)
			_image.set_pixel(x, y, color)
	_texture.update(_image)
