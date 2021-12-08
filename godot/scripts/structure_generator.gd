extends Node
# structure generator


func generate_structures(progress: Control) -> void:
	var noise: OpenSimplexNoise = GenParams.landmass_noise
	var number_of_structures := 10
	
	for s in number_of_structures:
		var rand_pos := _get_random_land_pos()
		level_terrain(rand_pos.x, rand_pos.z, 5, 4, rand_pos.y)
		
		#DebugGeometryDrawer.draw_cube(rand_pos * 0.25, 0.2)
		DebugGeometryDrawer.draw_box(
				rand_pos * 0.25, Vector3(5, 3, 4) * 0.25, Color.crimson)
		#print(s, ": ", rand_pos)
		progress.set_part_progress(s as float / number_of_structures)


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


func level_terrain(fx: int, fz: int, sx: int, sz: int, height: int) -> void:
	# from (fx, fz), size (sx, sz)
	for ix in sx + 1:
		for iz in sz + 1:
			GenParams.landmass_array.set_height(fx + ix, fz + iz, height)
