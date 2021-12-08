extends Node
# landmass generator


var meshes_container: Spatial


func generate_terrain(progress: Control) -> void:
	var arr: Array3D = GenParams.landmass_array
	var noise: OpenSimplexNoise = GenParams.landmass_noise
	for x in range(-GenParams.radius, GenParams.radius):
		for z in range(-GenParams.radius, GenParams.radius):
			var noise_value: float = noise.get_noise_2d(x, z)
			noise_value = GenParams.noise_lut_curve.interpolate_baked(
					(noise_value + 1.0) / 2.0) * 2.0 - 1.0
			
			var dist := Vector2(x, z).length() / GenParams.radius
			var scale := GenParams.noise_scale_curve.interpolate_baked(dist)
			var offset := GenParams.noise_offset_curve.interpolate_baked(dist)
			var height: int = clamp(noise_value * scale + offset, -1.0, 1.0) * GenParams.max_height
			#height = noise_value * GenParams.max_height
			arr.set_height(x, z, height)
		progress.set_part_progress(x as float / GenParams.radius / 2.0 + 0.5)


func generate_mesh_chunks(progress: Control, x_from: int, x_to: int) -> void:
	meshes_container = get_tree().current_scene.get_node("TerrainMeshes")
	var r2 := GenParams.radius * GenParams.radius
	var st := SurfaceTool.new()
	var chunks_in_radius: int = GenParams.radius / GenParams.CHUNK_SIZE
	for x1 in range(x_from, x_to):
		var chunk_off_x = x1 * GenParams.CHUNK_SIZE
		for z1 in range(-chunks_in_radius, chunks_in_radius):
			var chunk_off_z = z1 * GenParams.CHUNK_SIZE
			if Vector2(chunk_off_x, chunk_off_z).length_squared() \
					+ GenParams.CHUNK_SIZE <= r2:
				generate_mesh_surface(chunk_off_x, chunk_off_z, st)
				#generate_mesh_voxel(chunk_off_x, chunk_off_z, st)
			progress.add_to_part_progress()


func generate_mesh_surface(c_off_x: int, c_off_z: int, st: SurfaceTool) -> void:
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x2 in GenParams.CHUNK_SIZE:
		var x = c_off_x + x2
		if x + 1 >= GenParams.radius: continue
		for z2 in GenParams.CHUNK_SIZE:
			var z = c_off_z + z2
			if z + 1 >= GenParams.radius: continue
			var height := GenParams.landmass_array.get_height(x, z)
			var height_nx := GenParams.landmass_array.get_height(x + 1, z)
			var height_nz := GenParams.landmass_array.get_height(x, z + 1)
			var height_nxz := GenParams.landmass_array.get_height(x + 1, z + 1)
			
			st.add_color(Color(
					(height / 2.0 / GenParams.radius) + 0.5,
					(height / 2.0 / GenParams.radius) + 0.5,
					(height / 2.0 / GenParams.radius) + 0.5
			))
			st.add_vertex(Vector3(x, height, z))
			st.add_vertex(Vector3(x + 1, height_nx, z))
			st.add_vertex(Vector3(x, height_nz, z + 1))
			st.add_vertex(Vector3(x, height_nz, z + 1))
			st.add_vertex(Vector3(x + 1, height_nx, z))
			st.add_vertex(Vector3(x + 1, height_nxz, z + 1))
	add_chunk(st)


func generate_mesh_voxel(c_off_x: int, c_off_z: int, st: SurfaceTool) -> void:
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in GenParams.landmass_array.size_y:
		for x2 in GenParams.CHUNK_SIZE:
			var x = c_off_x + x2
			for z2 in GenParams.CHUNK_SIZE:
				var z = c_off_z + z2
				st.add_color(Color(
						0.5, 0.5, 0.5
				))
				_add_vertices_x_side(st, x, y, z)
				_add_vertices_y_side(st, x, y, z)
				_add_vertices_z_side(st, x, y, z)
	add_chunk(st, Vector3(0.125, 0, 0.125))


func generate_height_collisions() -> void:
	var sb := StaticBody.new()
	var cs := CollisionShape.new()
	var hms := HeightMapShape.new()
	hms.map_width = GenParams.radius * 2
	hms.map_depth = GenParams.radius * 2
	hms.map_data = GenParams.landmass_array._height_data
	cs.shape = hms
	sb.scale = Vector3.ONE * 0.25
	sb.add_child(cs)
	sb.translation = Vector3(-0.125, 0, -0.125)
	meshes_container.add_child(sb)


func _add_vertices_x_side(st: SurfaceTool, x: int, y: int, z: int) -> void:
	if x + 2 > GenParams.landmass_array.radius_x: return
	var cell_here := GenParams.landmass_array.is_cell_empty(x, y, z)
	var cell_next := GenParams.landmass_array.is_cell_empty(x + 1, y, z)
	if cell_here != cell_next:
		st.add_vertex(Vector3(x, y, z - 1))
		if cell_here:
			st.add_vertex(Vector3(x, y - 1, z))
			st.add_vertex(Vector3(x, y - 1, z - 1))
			st.add_vertex(Vector3(x, y, z))
			st.add_vertex(Vector3(x, y - 1, z))
		else:
			st.add_vertex(Vector3(x, y - 1, z - 1))
			st.add_vertex(Vector3(x, y - 1, z))
			st.add_vertex(Vector3(x, y - 1, z))
			st.add_vertex(Vector3(x, y, z))
		st.add_vertex(Vector3(x, y, z - 1))


func _add_vertices_y_side(st: SurfaceTool, x: int, y: int, z: int) -> void:
	if y + 2 > GenParams.landmass_array.radius_y: return
	var cell_here := GenParams.landmass_array.is_cell_empty(x, y, z)
	var cell_next := GenParams.landmass_array.is_cell_empty(x, y + 1, z)
	if cell_here != cell_next:
		st.add_vertex(Vector3(x, y, z))
		if cell_next:
			st.add_vertex(Vector3(x - 1, y, z))
			st.add_vertex(Vector3(x - 1, y, z - 1))
			st.add_vertex(Vector3(x - 1, y, z - 1))
			st.add_vertex(Vector3(x, y, z - 1))
		else:
			st.add_vertex(Vector3(x - 1, y, z - 1))
			st.add_vertex(Vector3(x - 1, y, z))
			st.add_vertex(Vector3(x, y, z - 1))
			st.add_vertex(Vector3(x - 1, y, z - 1))
		st.add_vertex(Vector3(x, y, z))


func _add_vertices_z_side(st: SurfaceTool, x: int, y: int, z: int) -> void:
	if z + 2 > GenParams.landmass_array.radius_z: return
	var cell_here := GenParams.landmass_array.is_cell_empty(x, y, z)
	var cell_next := GenParams.landmass_array.is_cell_empty(x, y, z + 1)
	if cell_here != cell_next:
		st.add_vertex(Vector3(x - 1, y, z))
		if cell_here:
			st.add_vertex(Vector3(x, y - 1, z))
			st.add_vertex(Vector3(x, y, z))
			st.add_vertex(Vector3(x - 1, y - 1, z))
			st.add_vertex(Vector3(x, y - 1, z))
		else:
			st.add_vertex(Vector3(x, y, z))
			st.add_vertex(Vector3(x, y - 1, z))
			st.add_vertex(Vector3(x, y - 1, z))
			st.add_vertex(Vector3(x - 1, y - 1, z))
		st.add_vertex(Vector3(x - 1, y, z))


func delete_old_chunk_meshes() -> void:
	for m in get_node("/root/Main/TerrainMeshes").get_children():
		#m.name = "PrevLandmass"
		m.queue_free()


func add_chunk(st: SurfaceTool, offset := Vector3.ZERO) -> void:
	st.generate_normals()
	var mi := MeshInstance.new()
	#mi.name = "Landmass"
	mi.mesh = st.commit()
	#mi.material_override = preload("res://materials/vertex_color_mat.tres")
	var sm := SpatialMaterial.new()
	sm.albedo_color = Color(randf(), randf(), randf())
	sm.vertex_color_use_as_albedo = true
	sm.flags_vertex_lighting = true
	mi.material_override = sm
	mi.translation = offset
	mi.scale = Vector3.ONE * 0.25
	#get_tree().current_scene.get_node("TerrainMeshes").add_child(mi)
	meshes_container.call_deferred("add_child", mi)
