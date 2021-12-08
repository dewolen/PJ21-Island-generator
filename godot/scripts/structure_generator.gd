extends Node
# structure generator


var plots := [] # Rect2 array
var structures := [] # AABB array


func reset() -> void:
	plots = []
	structures = []


func generate_structures(progress: Control) -> void:
	var noise: OpenSimplexNoise = GenParams.landmass_noise
	var number_of_structures := 50
	
	# generate structures
	for s in number_of_structures:
		var structure_size := Vector3(
				randi() % 8 + 3, randi() % 3 + 3, randi() % 8 + 3)
		var plot: Rect2 = _get_random_empty_plot(
				Vector2(structure_size.x, structure_size.z))
		var plot_height := max(0, GenParams.landmass_array.get_height(
				plot.position.x + (structure_size.x / 2),
				plot.position.y + (structure_size.z / 2)))
		var structure_position := Vector3(
				plot.position.x, plot_height, plot.position.y)
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
		#print(s, ": ", structure_position, " ", structure_size)
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


func level_terrain(fx: int, fz: int, sx: int, sz: int, height: int) -> void:
	# from (fx, fz), size (sx, sz)
	for ix in sx + 1:
		for iz in sz + 1:
			GenParams.landmass_array.set_height(fx + ix, fz + iz, height)
