extends Node
# structure generator


var plots := [] # Rect2 array
var structures := [] # AABB array
var flatness_sample_r: int = 1
var number_of_buildings: int = GenParams.radius / 40
var building_slope_max: float = 0.35
var building_size_min: int = 6
var building_size_range: int = 12 / 2
var number_of_paths: int = GenParams.radius / 80
var path_slope_max: float = 0.3


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
	# generate buildings
	var buildings := []
	for b in number_of_buildings:
		var building_size := Vector3(
				(randi() % building_size_range) * 2 + building_size_min,
				randi() % 3 + 3,
				(randi() % building_size_range) * 2 + building_size_min)
		var plot: Rect2 = _get_random_empty_plot(
				Vector2(building_size.x, building_size.z), true)
		if not plot: continue
		var plot_height := max(0, arr.get_height(
				plot.position.x + (building_size.x / 2),
				plot.position.y + (building_size.z / 2)))
		var building_position := Vector3(
				plot.position.x, floor(plot_height), plot.position.y)
		if building_position.x + building_size.x >= GenParams.radius \
		or building_position.z + building_size.z >= GenParams.radius:
			#print("Structure tried to generate outside island")
			continue
		buildings.append(AABB(building_position, building_size))
		structures.append(AABB(building_position, building_size))
		progress.set_part_progress(b as float / number_of_buildings / 3.0)
	# place buildings
	for b in buildings:
		create_building(b)

	# connect structures
	var s_size := structures.size()
	for s in s_size - 1:
		var st_from: AABB = structures[s]
		var st_to: AABB = structures[s + 1]
		var path_from := Vector2(st_from.position.x, st_from.position.z)
		var path_to := Vector2(st_to.position.x, st_to.position.z)
		create_path(path_from, path_to)
		PathfindingGenerator.set_area_disabled(
				st_from.position.x - 2, st_from.position.z - 2,
				st_from.size.x + 4, st_from.size.z + 4, true)
		if s == s_size - 2: # last structure
			PathfindingGenerator.set_area_disabled(
					st_to.position.x - 2, st_to.position.z - 2,
					st_to.size.x + 4, st_to.size.z + 4, true)
		progress.set_part_progress(s as float / s_size / 3.0 + 0.33)
	
	# generate random paths
	for p in number_of_paths:
		var pos1 := _get_random_land_pos(Vector2.ZERO, GenParams.radius, path_slope_max)
		for s in 5:
			var pos2 := _get_random_land_pos(pos1, 64, path_slope_max)
			var success := create_path(pos1, pos2)
			var i := 0
			while not success and i < 100:
				i += 1
				pos2 = _get_random_land_pos(pos1, 64, path_slope_max)
				success = create_path(pos1, pos2)
			pos1 = pos2
		progress.set_part_progress(p as float / number_of_paths / 3.0 + 0.66)
	
#	PathfindingGenerator.debug_visualize_paths()


func create_building(structure: AABB) -> void:
		level_terrain(structure.position.x, structure.position.z,
				structure.size.x, structure.size.z,
				structure.position.y, 1, false)
		PathfindingGenerator.level_points(
				structure.position.x, structure.position.z,
				structure.size.x, structure.size.z,
				structure.position.y)
#		DebugGeometryDrawer.draw_cube(
#				(structure.position + (structure.size / 2.0)) * 0.25, 0.2)
#		DebugGeometryDrawer.draw_box(
#				structure.position * 0.25, structure.size * 0.25, Color.crimson)
		#print(s, ": ", structure.position, " ", structure.size)


func create_path(from: Vector2, to: Vector2, surface_value := 1, thick := true) -> bool:
	var arr: Array3D = GenParams.landmass_array
	var astar: AStar = PathfindingGenerator.astar
	var from_idx: int = (((from.x as int) + arr.radius_x) << arr.size_z_pow) + \
			(from.y as int) + arr.radius_z
	var to_idx: int = (((to.x as int) + arr.radius_x) << arr.size_z_pow) + \
			(to.y as int) + arr.radius_z
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
#	# DEBUG
#	var from3d := Vector3(from.x, arr.get_height(from.x, from.y), from.y)
#	var to3d := Vector3(to.x, arr.get_height(to.x, to.y), to.y)
#	DebugGeometryDrawer.draw_cube(from3d * 0.25, 0.25, Color.deeppink)
#	DebugGeometryDrawer.draw_cube(to3d * 0.25, 0.25, Color.hotpink)
#	DebugGeometryDrawer.draw_line(from3d * 0.25, to3d * 0.25, Color.lightpink)
	return true


func _get_random_land_pos(around := Vector2(0, 0), radius := GenParams.radius,
		slope_max := 1.0, biome_range := Vector2(-1.0, 1.0)) -> Vector2:
	var biome_noise := GenParams.biome_noise
	var i := 0
	while i < 100:
		i += 1
		var probe_x: int = (randi() % (2 * radius)) - radius + around.x
		var probe_z: int = (randi() % (2 * radius)) - radius + around.y
		var land_height := GenParams.landmass_array.get_height(probe_x, probe_z)
		if land_height < 0: continue # try again
		var slope := get_slope(probe_x, probe_z)
		if slope >= slope_max: continue # try again
		var biome := biome_noise.get_noise_2d(probe_x, probe_z)
		if biome < biome_range.x or biome > biome_range.y: continue # try again
		return Vector2(probe_x, probe_z)
	return Vector2.ZERO


func _get_random_empty_plot(size: Vector2, check_corners := true,
		slope_max := building_slope_max) -> Rect2:
	var i := 0
	while i < 100:
		i += 1
		var rand_pos := _get_random_land_pos(Vector2.ZERO, GenParams.radius, slope_max)
		var rand_plot := Rect2(
				Vector2(rand_pos.x, rand_pos.y) - (size / 2.0),
				size)
		if check_corners:
			var slope_tl := get_slope(rand_plot.position.x, rand_plot.position.y)
			var slope_tr := get_slope(rand_plot.end.x, rand_plot.position.y)
			var slope_bl := get_slope(rand_plot.position.x, rand_plot.end.y)
			var slope_br := get_slope(rand_plot.end.x, rand_plot.end.y)
			if slope_tl >= slope_max \
			or slope_tr >= slope_max \
			or slope_bl >= slope_max \
			or slope_br >= slope_max :
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
