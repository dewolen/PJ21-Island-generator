extends Node
# structure generator


var plots := [] # Rect2 array
var structures := [] # AABB array
var flatness_sample_r: int = 1
var number_of_structures: int = 50
var number_of_paths: int = GenParams.radius / 20
var structure_slope_max: float = 0.1
var structure_size_min: int = 6
var structure_size_range: int = 12 / 2


func reset() -> void:
	plots = []
	structures = []


func generate_flatness_map(progress: Control) -> void:
	var fmap := GenParams.flatness_map
	var scaled_r: int = GenParams.radius >> fmap.scale_pow
	var arr: Array3D = GenParams.landmass_array
	var half_off: int = (1 << fmap.scale_pow) / 2 # used to sample middle point
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
							((mcx + isx) << fmap.scale_pow) + half_off,
							((mcz + isz) << fmap.scale_pow) + half_off)
			var mean_height: float = mean_acc / sample_area
			var md_acc: float = 0.0
			for isx in sample_d:
				for isz in sample_d:
					var deviation := arr.get_height(
							((mcx + isx) << fmap.scale_pow) + half_off,
							((mcz + isz) << fmap.scale_pow) + half_off
					) - mean_height
					md_acc += deviation * deviation
			fmap.set_value(x, z, (md_acc / sample_area)) # mean deviation
		progress.set_part_progress(x as float / scaled_r / 2.0 + 0.5)


func generate_structures(progress: Control) -> void:
	var arr: Array3D = GenParams.landmass_array
	# generate structures
	for s in number_of_structures:
		var structure_size := Vector3(
				(randi() % structure_size_range) * 2 + structure_size_min,
				randi() % 3 + 3,
				(randi() % structure_size_range) * 2 + structure_size_min)
		var plot: Rect2 = _get_random_empty_plot(
				Vector2(structure_size.x, structure_size.z), true)
		if not plot: continue
		var plot_height := max(0, arr.get_height(
				plot.position.x + (structure_size.x / 2),
				plot.position.y + (structure_size.z / 2)))
		var structure_position := Vector3(
				plot.position.x, floor(plot_height), plot.position.y)
		if structure_position.x + structure_size.x >= GenParams.radius \
		or structure_position.z + structure_size.z >= GenParams.radius:
			#print("Structure tried to generate outside island")
			continue
		structures.append(AABB(structure_position, structure_size))

	# modify land to structures
	var s_size := structures.size()
	for s in s_size:
		var structure: AABB = structures[s]
		level_terrain(structure.position.x, structure.position.z,
				structure.size.x, structure.size.z,
				structure.position.y, 1.0, false)

		DebugGeometryDrawer.draw_cube(
				(structure.position + (structure.size / 2.0)) * 0.25, 0.2)
		DebugGeometryDrawer.draw_box(
				structure.position * 0.25, structure.size * 0.25, Color.crimson)
		#print(s, ": ", structure.position, " ", structure.size)
		progress.set_part_progress(s as float / s_size)
	
	# generate random paths
	for p in number_of_paths:
		var pos1 := _get_random_land_pos()
		var pos2 := _get_random_land_pos()
		var success := create_path(pos1, pos2)
		var i := 0
		while not success and i < 100:
			i += 1
			pos2 = _get_random_land_pos()
			success = create_path(pos1, pos2)


func create_path(from: Vector3, to: Vector3, surface_value := 1, thick := true) -> bool:
	var arr: Array3D = GenParams.landmass_array
	var astar: AStar = PathfindingGenerator.astar
	var from_idx: int = (((from.x as int) + arr.radius_x) << arr.size_z_pow) + \
			(from.z as int) + arr.radius_z
	var to_idx: int = (((to.x as int) + arr.radius_x) << arr.size_z_pow) + \
			(to.z as int) + arr.radius_z
	if not astar.has_point(from_idx) or not astar.has_point(to_idx):
		return false
	var path: PoolIntArray = astar.get_id_path(from_idx, to_idx)
	if path.size() == 0: return false
	for p in path:
		arr.set_surface_value_by_idx(p, surface_value)
		if thick:
			arr.set_surface_value_by_idx(p - 1, surface_value)
			arr.set_surface_value_by_idx(p + 1, surface_value)
			arr.set_surface_value_by_idx(p - arr.size_z, surface_value)
			arr.set_surface_value_by_idx(p + arr.size_z, surface_value)
#	DebugGeometryDrawer.draw_cube(from * 0.25, 0.25, Color.deeppink)
#	DebugGeometryDrawer.draw_cube(to * 0.25, 0.25, Color.hotpink)
#	DebugGeometryDrawer.draw_line(from * 0.25, to * 0.25, Color.lightpink)
	return true


func _get_random_land_pos(slope_min := 0.0, slope_max := 1.0) -> Vector3:
	var i := 0
	while i < 100:
		i += 1
		var probe_x: int = (randi() % (2 * GenParams.radius)) - GenParams.radius
		var probe_z: int = (randi() % (2 * GenParams.radius)) - GenParams.radius
		var land_height := GenParams.landmass_array.get_height(probe_x, probe_z)
		var slope := get_slope(probe_x, probe_z)
		if slope <= slope_min or slope >= slope_max:
			#print("Slope too high: ", slope)
			continue # try again
		if land_height < 0: continue # try again
		return Vector3(probe_x, land_height, probe_z)
	return Vector3.ZERO


func _get_random_empty_plot(size: Vector2, check_corners := true,
		slope_min := 0.0, slope_max := structure_slope_max) -> Rect2:
	var i := 0
	while i < 100:
		i += 1
		var rand_pos := _get_random_land_pos(slope_min, slope_max)
		var rand_plot := Rect2(
				Vector2(rand_pos.x, rand_pos.z) - (size / 2.0),
				size)
		if check_corners:
			var slope_tl := get_slope(rand_plot.position.x, rand_plot.position.y)
			var slope_tr := get_slope(rand_plot.end.x, rand_plot.position.y)
			var slope_bl := get_slope(rand_plot.position.x, rand_plot.end.y)
			var slope_br := get_slope(rand_plot.end.x, rand_plot.end.y)
			if slope_tl <= slope_min or slope_tl >= slope_max \
			or slope_tr <= slope_min or slope_tr >= slope_max \
			or slope_bl <= slope_min or slope_bl >= slope_max \
			or slope_br <= slope_min or slope_br >= slope_max :
				#print("Uneven structure foundation")
				continue
		var space_occupied := false
		for p in plots:
			if p.intersects(rand_plot, true):
				space_occupied = true
				break
		if space_occupied: continue # try different position
		plots.append(rand_plot)
		return rand_plot
	#print("Empty plot not found")
	return Rect2()


func get_slope(x: int, z: int) -> float:
	return GenParams.flatness_map.get_value_scaled(x, z)


func level_terrain(fx: int, fz: int, sx: int, sz: int, height: float,
		new_surface := 999, resurface_br_edge := false) -> void:
	# from (fx, fz), size (sx, sz)
	var arr := GenParams.landmass_array
	for ix in sx + 1:
		var x: int = fx + ix
		for iz in sz + 1:
			var z: int = fz + iz
			arr.set_height(x, z, height)
			if new_surface != 999:
				if (ix == sx or iz == sz) and not resurface_br_edge:
					continue
				arr.set_surface_value(x, z, new_surface)
