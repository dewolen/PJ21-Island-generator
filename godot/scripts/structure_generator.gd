extends Node
# structure generator


var plots := [] # Rect2 array
var structures := [] # AABB array
var flatness_sample_r: int = 1
var number_of_structures := 50


func reset() -> void:
	plots = []
	structures = []


func generate_flatness_map(progress: Control) -> void:
	var fmap := GenParams.flatness_map
	var scale_pow := GenParams.FLATNESS_MAP_SCALE_POW
	var scaled_r: int = GenParams.radius >> scale_pow
	var arr: Array3D = GenParams.landmass_array
	var half_off: int = (1 << scale_pow) / 2 # used to sample middle point
	var sample_d: int = (flatness_sample_r * 2) + 1
	var sample_area: int = sample_d * sample_d
	# generate the mean height
	for x in range(-scaled_r, scaled_r):
		for z in range(-scaled_r, scaled_r):
			var mcx := x - flatness_sample_r # mean top-left corner pos
			var mcz := z - flatness_sample_r
			var mean_acc: float = 0.0
			for isx in sample_d:
				for isz in sample_d:
					mean_acc += arr.get_height(
							((mcx + isx) << scale_pow) + half_off,
							((mcz + isz) << scale_pow) + half_off)
			var mean_height: float = mean_acc / sample_area
			var md_acc: float = 0.0
			for isx in sample_d:
				for isz in sample_d:
					var deviation := arr.get_height(
							((mcx + isx) << scale_pow) + half_off,
							((mcz + isz) << scale_pow) + half_off
					) - mean_height
					md_acc += deviation * deviation
			fmap.set_value(x, z, (md_acc / sample_area)) # mean deviation
		progress.set_part_progress(x as float / scaled_r / 2.0 + 0.5)


func generate_structures(progress: Control) -> void:
	var noise: OpenSimplexNoise = GenParams.landmass_noise
	
	# generate structures
	for s in number_of_structures:
		var structure_size := Vector3(
				randi() % 8 + 3, randi() % 3 + 3, randi() % 8 + 3)
		var plot: Rect2 = _get_random_empty_plot(
				Vector2(structure_size.x, structure_size.z))
		if not plot: continue
		var plot_height := max(0, GenParams.landmass_array.get_height(
				plot.position.x + (structure_size.x / 2),
				plot.position.y + (structure_size.z / 2)))
		var structure_position := Vector3(
				plot.position.x, floor(plot_height), plot.position.y)
		if structure_position.x + structure_size.x >= GenParams.radius \
		or structure_position.z + structure_size.z >= GenParams.radius:
			print("Structure tried to generate outside island")
			continue
		structures.append(AABB(structure_position, structure_size))
	
	# modify land to structures
	var s_size := structures.size()
	for s in s_size:
		var structure: AABB = structures[s]
		level_terrain(structure.position.x, structure.position.z,
				structure.size.x, structure.size.z, structure.position.y)

		#DebugGeometryDrawer.draw_cube(rand_pos * 0.25, 0.2)
		DebugGeometryDrawer.draw_box(
				structure.position * 0.25, structure.size * 0.25, Color.crimson)
		print(s, ": ", structure.position, " ", structure.size)
		progress.set_part_progress(s as float / s_size)


func _get_random_land_pos() -> Vector3:
	var i := 0
	while i < 100:
		i += 1
		var probe_x := (randi() % (2 * GenParams.radius)) - GenParams.radius
		var probe_z := (randi() % (2 * GenParams.radius)) - GenParams.radius
		var land_height := GenParams.landmass_array.get_height(probe_x, probe_z)
		if land_height < 0: continue # try again
		return Vector3(probe_x, land_height, probe_z)
	return Vector3.ZERO


func _get_random_empty_plot(size: Vector2) -> Rect2:
	var i := 0
	while i < 100:
		i += 1
		var rand_pos := _get_random_land_pos()
		var rand_plot := Rect2(Vector2(rand_pos.x, rand_pos.z), size)
		var space_occupied := false
		for p in plots:
			if p.intersects(rand_plot):
				space_occupied = true
				break
		if space_occupied: continue # try different position
		plots.append(rand_plot)
		return rand_plot
	print("Empty plot not found")
	return Rect2()


func level_terrain(fx: int, fz: int, sx: int, sz: int, height: float) -> void:
	# from (fx, fz), size (sx, sz)
	var arr := GenParams.landmass_array
	for ix in sx + 1:
		var x: int = fx + ix
		for iz in sz + 1:
			var z: int = fz + iz
			arr.set_height(x, z, height, arr.get_top_value(x, z))
