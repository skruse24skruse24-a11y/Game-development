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
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func refresh() -> void:
	if _sim == null:
		return
	var grid := _sim.get_grid_copy()
	var fire_life := _sim.get_fire_life_copy()
	for y in _sim.grid_height:
		for x in _sim.grid_width:
			var idx := y * _sim.grid_width + x
			var mat := grid[idx]
			var color := Color(0.06, 0.07, 0.11, 1.0)
			if mat != ElementDB.EMPTY:
				var key := ElementDB.get_key_for_id(mat)
				color = ElementDB.get_color(key)
				if key == "FIRE":
					var pulse := 0.85 + 0.15 * sin(float(fire_life[idx]) * 0.4)
					color = color.lightened(pulse * 0.25)
				elif key == "LAVA":
					color = color.lightened(0.12)
				elif key == "SPARK":
					color = Color(1.0, 1.0, 0.6, 1.0)
				elif key == "STEAM":
					color.a = 0.75
				elif key == "SMOK":
					color.a = 0.6
				elif key == "WATR":
					color = color.darkened(0.05)
			_image.set_pixel(x, y, color)
	_texture.update(_image)
