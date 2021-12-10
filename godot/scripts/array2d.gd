extends Reference
class_name Array2D


const EMPTY_HEIGHT := INF

var radius_x: int
var radius_z: int
var size_x: int
var size_z: int
var size_x_pow: int
var size_z_pow: int
var _data := PoolRealArray()


func _init(rx: int, rz: int) -> void:
	set_radius(rx, rz)


#func is_cell_empty(x: int, z: int) -> bool:
#	return get_value(x, z) == 0.0


func set_value(x: int, z: int, value: float) -> void:
	_data[((z + radius_z) << size_x_pow) + x + radius_x] = value


func get_value(x: int, z: int) -> float:
	return _data[((z + radius_z) << size_x_pow) + x + radius_x]


func set_radius(x: int, z: int) -> void:
	size_x_pow = ceil(log(x) / log(2)) + 1 # nearest power of 2 bigger than x
	size_z_pow = ceil(log(z) / log(2)) + 1 # for ceil_po2(7) = 8 = 2^3 -> 3
	size_x = 1 << size_x_pow			   # or log2(nearest_po2(value))
	size_z = 1 << size_z_pow
	radius_x = size_x >> 1 # size_x / 2
	radius_z = size_z >> 1
	_data.resize(size_x * size_z)


func set_power_of_two_radius(x_r_pow: int, z_r_pow: int) -> void:
	size_x_pow = x_r_pow + 1
	size_z_pow = z_r_pow + 1
	radius_x = 1 << x_r_pow
	radius_z = 1 << z_r_pow
	size_x = radius_x << 1 # radius_x * 2
	size_z = radius_z << 1
	_data.resize(size_x * size_z)


func debug_visualize_data() -> void:
	for ix in size_x:
		for iz in size_z:
			var v := _data[(iz << size_x_pow) + ix]
			var c := Color(v, v, v)
			DebugGeometryDrawer.draw_cube(Vector3(
					ix - radius_x,
					GenParams.MAX_Y_RADIUS,
					iz - radius_z
			) * 0.25, 0.05, c)
#			DebugGeometryDrawer.draw_box(Vector3(
#					ix - radius_x - 0.5,
#					GenParams.MAX_Y_RADIUS,
#					iz - radius_z - 0.5
#			) * 0.25, Vector3.ONE * 0.25, c)
