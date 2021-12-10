extends Reference
class_name Array3D


const EMPTY_HEIGHT := INF

var radius_x: int
var radius_y: int
var radius_z: int
var size_x: int
var size_y: int
var size_z: int
var size_x_pow: int
var size_y_pow: int
var size_z_pow: int
var _data := PoolRealArray()
var _height_data := PoolRealArray()


func _init(rx: int, ry: int, rz: int) -> void:
	set_radius(rx, ry, rz)


func set_value(x: int, y: int, z: int, value: float) -> void:
	_data[ \
			((((x + radius_x) << size_z_pow) + \
			z + radius_z) << size_y_pow) + \
			y \
	] = value


func get_value(x: int, y: int, z: int) -> float:
	return _data[ \
			((((x + radius_x) << size_z_pow) + \
			z + radius_z) << size_y_pow) + \
			y \
	]


func is_cell_empty(x: int, y: int, z: int) -> bool:
	return get_value(x, y, z) == 0.0


func set_height(x: int, z: int, height: float, value_to_write := 1.0) -> void:
	_height_data[((z + radius_z) << size_x_pow) + x + radius_x] = height
	#return
	var xz_offset := (((x + radius_x) << size_z_pow) + z + radius_z) << size_y_pow
	var height_idx: int = ceil(height) + 1
	for current_y_idx in size_y:
		if current_y_idx >= height_idx: value_to_write = 0.0
		_data[xz_offset + current_y_idx] = value_to_write


func get_height(x: int, z: int) -> float:
	if x < -radius_x or x >= radius_x \
	or z < -radius_z or z >= radius_z:
		return -GenParams.max_height # height outside is the lowest
	var saved_height := _height_data[((z + radius_z) << size_x_pow) + x + radius_x]
	if saved_height != EMPTY_HEIGHT:
		return saved_height
	var xz_offset_p1 := ((((x + radius_x) << size_z_pow) + \
			z + radius_z) << size_y_pow) + 1
	var height := -1
	var val_above_h: float
	while height < size_y - 1:
		val_above_h = _data[xz_offset_p1 + height]
		if val_above_h == 0.0: break
		height += 1
	return height as float


func empty_height_data() -> void:
	for i in _height_data:
		_height_data[i] = EMPTY_HEIGHT


func get_top_value(x: int, z: int) -> float:
	var h := get_height(x, z)
	return get_value(x, max(0, floor(h) + 1), z)


func set_radius(x: int, y: int, z: int) -> void:
	size_x_pow = ceil(log(x) / log(2)) + 1 # nearest power of 2 bigger than x
	size_y_pow = ceil(log(y) / log(2))     # for ceil_po2(7) = 8 = 2^3 -> 3
	size_z_pow = ceil(log(z) / log(2)) + 1 # or log2(nearest_po2(value))
	size_x = 1 << size_x_pow
	size_y = 1 << size_y_pow
	size_z = 1 << size_z_pow
	radius_x = size_x >> 1 # size_x / 2
	radius_y = size_y
	radius_z = size_z >> 1
	_data.resize(size_x * size_y * size_z)
	_height_data.resize(size_x * size_z)


func set_power_of_two_radius(x_r_pow: int, y_r_pow: int, z_r_pow: int) -> void:
	size_x_pow = x_r_pow + 1
	size_y_pow = y_r_pow
	size_z_pow = z_r_pow + 1
	radius_x = 1 << x_r_pow
	radius_y = 1 << y_r_pow
	radius_z = 1 << z_r_pow
	size_x = radius_x << 1 # radius_x * 2
	size_y = radius_y
	size_z = radius_z << 1
	_data.resize(size_x * size_y * size_z)
	_height_data.resize(size_x * size_z)


func debug_visualize_data() -> void:
	for ix in size_x:
		for iy in size_y:
			for iz in size_z:
				if _data[ \
						(((ix << size_z_pow) + \
						iz) << size_y_pow) + \
						iy \
				] != 0.0:
#					DebugGeometryDrawer.draw_cube(Vector3(
#							ix - radius_x,
#							iy,
#							iz - radius_z
#					) * 0.25, 0.05)
					DebugGeometryDrawer.draw_box(Vector3(
							ix - radius_x - 0.5,
							iy - 1,
							iz - radius_z - 0.5
					) * 0.25, Vector3.ONE * 0.25)


func debug_visualize_height_data() -> void:
	for ix in size_x:
		for iz in size_z:
			var h := get_height(ix - radius_x, iz - radius_z)
			if h >= 0:
				DebugGeometryDrawer.draw_cube(Vector3(
						ix - radius_x,
						h,
						iz - radius_z
				) * 0.25, 0.05)
