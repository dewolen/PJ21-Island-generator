extends Node
# pathfinding generator


var astar: AStar
var max_path_slope := 0.4


func reset() -> void:
	astar = AStar.new()


func generate_paths(progress: Control) -> void:
	_generate_astar_map(progress)


func _generate_astar_map(progress: Control) -> void:
	var arr: Array3D = GenParams.landmass_array
	astar.reserve_space(arr.size_x * arr.size_z)
	# points
	for x in range(-arr.radius_x, arr.radius_x):
		for z in range(-arr.radius_z, arr.radius_z):
			var idx := get_astar_idx(x, z)
			var h := arr.get_height(x, z)
			if h < 0.0: continue
			#var w := 1.0 if h >= 1.0 else 100.0 # high underwater point weight
			astar.add_point(idx, Vector3(x, h, z))
			#if h < 1.0: astar.set_point_disabled(idx, true) # disable underwater points
		progress.set_part_progress(x as float / arr.radius_x / 4.0 + 0.25)
	# connections
	for x in range(-arr.radius_x, arr.radius_x - 1):
		for z in range(-arr.radius_z, arr.radius_z - 1):
			var idx := get_astar_idx(x, z)
			var h := arr.get_height(x, z)
			var h_nx := arr.get_height(x + 1, z)
			var h_nz := arr.get_height(x, z + 1)
			#var h_nxz := arr.get_height(x + 1, z + 1)
			if h < 0.0: continue
			if h_nx >= 0.0 and abs(h - h_nx) <= max_path_slope:
				astar.connect_points(idx, idx + arr.size_z)
			if h_nz >= 0.0 and abs(h - h_nz) <= max_path_slope:
				astar.connect_points(idx, idx + 1)
			#if abs(h - h_nxz) <= max_path_slope:
			#	astar.connect_points(idx, idx + arr.size_z + 1)
		progress.set_part_progress(x as float / arr.radius_x / 4.0 + 0.75)


func set_area_disabled(fx: int, fz: int, sx: int, sz: int, disabled: bool) -> void:
	# from (fx, fz), size (sx, sz)
	var arr := GenParams.landmass_array
	for ix in sx:
		var x: int = fx + ix
		for iz in sz:
			var z: int = fz + iz
			var idx := get_astar_idx(x, z)
			astar.set_point_disabled(idx, disabled)


func get_astar_idx(x: int, z: int) -> int:
	return ((x + GenParams.landmass_array.radius_x) << GenParams.landmass_array.size_z_pow) + \
			z + GenParams.landmass_array.radius_z


func level_points(fx: int, fz: int, sx: int, sz: int, height: float) -> void:
	# from (fx, fz), size (sx, sz)
	for ix in sx + 1:
		var x: int = fx + ix
		for iz in sz + 1:
			var z: int = fz + iz
			astar.set_point_position(get_astar_idx(x, z), Vector3(x, height, z))


func debug_visualize_paths() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	for idx in astar.get_points():
		var ppos := astar.get_point_position(idx)
		var color := Color.crimson
		if astar.is_point_disabled(idx): color = Color.black
		for cp in astar.get_point_connections(idx):
			if astar.is_point_disabled(cp): color = Color.black
			st.add_color(color)
			st.add_vertex(ppos)
			st.add_vertex(astar.get_point_position(cp))
	
	var mi := MeshInstance.new()
	mi.name = "Paths"
	mi.mesh = st.commit()
	mi.material_override = DebugGeometryDrawer.sm_r
	mi.translation
	mi.scale = Vector3.ONE * 0.25
	LandmassGenerator.meshes_container.call_deferred("add_child", mi)
