extends Node
# pathfinding generator


var astar: AStar
var max_path_slope := 0.6


func reset() -> void:
	astar = AStar.new()


func generate_paths(progress: Control) -> void:
	_generate_astar_map(progress)
	
	# DEBUG astar visualization
	var ig := ImmediateGeometry.new()
	LandmassGenerator.meshes_container.add_child(ig)
	ig.scale = Vector3.ONE * 0.25
	ig.material_override = DebugGeometryDrawer.sm_r
	ig.begin(Mesh.PRIMITIVE_LINES)
	for idx in astar.get_points():
		var ppos := astar.get_point_position(idx)
		for cp in astar.get_point_connections(idx):
			ig.add_vertex(ppos)
			ig.add_vertex(astar.get_point_position(cp))
	ig.end()


func _generate_astar_map(progress: Control) -> void:
	var arr: Array3D = GenParams.landmass_array
	astar.reserve_space(arr.size_x * arr.size_z)
	# points
	for x in range(-arr.radius_x, arr.radius_x):
		for z in range(-arr.radius_z, arr.radius_z):
			var idx := ((x + arr.radius_x) << arr.size_z_pow) + z + arr.radius_z
			var h := arr.get_height(x, z)
			if h < 0.0: continue
			#var w := 1.0 if h >= 1.0 else 100.0 # high underwater point weight
			astar.add_point(idx, Vector3(x, h, z))
			#if h < 1.0: astar.set_point_disabled(idx, true) # disable underwater points
		progress.set_part_progress(x as float / arr.radius_x / 4.0 + 0.25)
	# connections
	for x in range(-arr.radius_x, arr.radius_x - 1):
		for z in range(-arr.radius_z, arr.radius_z - 1):
			var idx := ((x + arr.radius_x) << arr.size_z_pow) + z + arr.radius_z
			var h := arr.get_height(x, z)
			var h_nx := arr.get_height(x + 1, z)
			var h_nz := arr.get_height(x, z + 1)
			var h_nxz := arr.get_height(x + 1, z + 1)
			if h < 0.0 or h_nx < 0.0 or h_nz < 0.0 or h_nxz < 0.0: continue # skip underwater points
			if abs(h - h_nx) <= max_path_slope:
				astar.connect_points(idx, idx + arr.size_z)
			if abs(h - h_nz) <= max_path_slope:
				astar.connect_points(idx, idx + 1)
			if abs(h - h_nxz) <= max_path_slope:
				astar.connect_points(idx, idx + arr.size_z + 1)
		progress.set_part_progress(x as float / arr.radius_x / 4.0 + 0.75)
